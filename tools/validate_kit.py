# =================================================================================
# The MIT License
# MIT许可证
#
# <https://opensource.org/license/mit>
#
# SPDX short identifier / SPDX 短标识符：MIT
#
# Copyright (c) 2026 autoMBD
# 版权所有 (c) 2026 autoMBD
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the “Software”),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
# 特此向获得本软件及相关文档（合称“本软件”）副本的任何人免费授予不受限制地利用本软
# 件的许可，包括而不限于：使用、复制、修改、合并、发布、分发、分许可和/或销售本软
# 件副本，并允许本软件的接收者也获得前述许可，但须遵守以下条件：
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
# 以上版权声明及本许可声明应包含在本软件的所有副本或主要部分中。
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALLTHE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# 本软件系“按原样”提供，不包含任何形式的明示或默示保证，包括但不限于适销性、特定
# 目的适用性及不侵权的保证。在任何情况下，无论是在合同、侵权或其他案件中，作者或版
# 权持有人均不对因本软件、或因本软件的使用或其他利用而引起的、引发的或与之相关的任
# 何权利主张、损害赔偿或其他责任承担责任。
# =================================================================================
# Project:     autoMBD Motor Control <https://github.com/autoMBD/AMBD-MC>
# File:        validate_kit.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-07
# Version:     0.1.0
# Description: Validate Hall, sensored and sensorless operating transitions through PIL.
# =================================================================================

"""Validate kit-specific electrical references, full Normal traces and optional PIL windows."""
from pathlib import Path
import argparse
import importlib.util
import json
import sys
import uuid

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/agent'))
import configuration
import environment
from mcp_client import Client
spec=importlib.util.spec_from_file_location('kit_target',ROOT/'tools/hsp/validate_target.py')
TARGET=importlib.util.module_from_spec(spec);spec.loader.exec_module(TARGET)


def quote(value):
    return "'"+str(value).replace(chr(92),'/').replace("'","''")+"'"


def hashes():
    values=TARGET.source_hashes(['bldc','pmsm'])
    extra=[Path(__file__),*list((ROOT/'tests/hsp').glob('*.m'))]
    values.update({p.relative_to(ROOT).as_posix():TARGET.digest(p) for p in extra})
    return values


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference-report',type=Path,help='A complete reference summary to replay on target.')
    parser.add_argument('--settings',type=Path,help='Local HSP settings required for target replay.')
    args=parser.parse_args()
    if args.reference_report and not args.settings:parser.error('PIL requires --settings.')
    folder=ROOT/'.agent-env/kit-validation'/uuid.uuid4().hex[:8];folder.mkdir(parents=True)
    baseline=hashes();settings_hash=TARGET.digest(args.settings) if args.settings else None
    summary={'Passed':False,'Mode':'PIL' if args.reference_report else 'reference',
             'SourceHashes':baseline,'Cases':[]}
    artifact_hashes={}
    def save():
        (folder/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    def unchanged():
        if hashes()!=baseline:raise RuntimeError('Sources changed during kit verification.')
        for name,value in artifact_hashes.items():
            if TARGET.digest(ROOT/name)!=value:raise RuntimeError('Reference artifact changed: '+name)
        if args.settings and TARGET.digest(args.settings)!=settings_hash:raise RuntimeError('Local settings changed.')
    print('Kit report: '+str(folder),flush=True);save()
    command,env=environment.runtime(configuration.read_state(ROOT)['active'],session='new')
    try:
        if args.reference_report:
            reference_path=args.reference_report.resolve()
            artifact_hashes[reference_path.relative_to(ROOT).as_posix()]=TARGET.digest(reference_path)
            accepted=json.loads(reference_path.read_text())
            if accepted.get('Passed') is not True or accepted.get('Mode')!='reference':raise RuntimeError('Complete passed kit reference required.')
            for name,value in accepted['SourceHashes'].items():
                if TARGET.digest(ROOT/name)!=value:raise RuntimeError('Stale reference source: '+name)
            for case in accepted['Cases']:
                for key in ('Trace','Recording','Reference'):
                    name=case[key];artifact_hashes[name]=TARGET.digest(ROOT/name)
                    if artifact_hashes[name]!=case[key+'Sha256']:raise RuntimeError('Stale reference file: '+name)
            unchanged();summary['SourceArtifacts']=artifact_hashes
        with Client(command,cwd=ROOT,env=env,timeout=1800) as client:
            client.initialize()
            def evaluate(code,marker):
                response=client.call('evaluate_matlab_code',dict(project_path=str(ROOT),code=code))
                output='\n'.join(block.get('text','') for block in response.get('content',[]))
                if response.get('isError') or marker not in output.splitlines():raise RuntimeError(output)
                print(marker,flush=True)
            evaluate("addpath(pwd,fullfile(pwd,'tests','hsp'));disp('KIT_READY');",'KIT_READY')
            for family in ['bldc','pmsm']:
                model='BLDC_Ctrl_CodeModel' if family=='bldc' else 'FOC_Ctrl_CodeModel'
                if args.reference_report:
                    evaluate(f"stage=hsp_stage({quote(family)},{quote(args.settings.resolve())});disp('KIT_STAGE_READY');",'KIT_STAGE_READY')
                    for case in [x for x in accepted['Cases'] if x['Family']==family]:
                        unchanged();destination=folder/case['Name']
                        evaluate(f"result=run_operational_pil({quote(model)},{quote(family)},{quote(ROOT/case['Trace'])},"
                                 f"{quote(ROOT/case['Recording'])},{quote(destination)});assert(result.Passed);"
                                 f"loaded=load({quote(destination/'operational-traces.mat')},'result');assert(isequaln(loaded.result,result));disp('KIT_PIL_PASS');",'KIT_PIL_PASS')
                        unchanged();result=json.loads((destination/'result.json').read_text());result['Name']=case['Name']
                        summary['Cases'].append(result);save()
                    evaluate(f"for entry=stage.Models(:)',if bdIsLoaded(entry.name),close_system(entry.name,0);end;end;clear stage;disp('KIT_STAGE_CLOSED');",'KIT_STAGE_CLOSED')
                else:
                    reference_function='kit_'+family+'_reference'
                    mex_name=reference_function+'_mex'
                    evaluate(f"info={family}_setup;open_system({quote(ROOT/'mc-models'/family/'platform/codegen'/(model+'.slx'))});"
                             f"addpath({quote(folder)},'-begin');p=ambd.kit_parameters({quote(family)});plantp=p;plantp.Friction=single(1e-5);"
                             +( "plantp.PlantSubsteps=uint16(4);" if family=='bldc' else '')+
                             f"cfg=coder.config('mex');cfg.GenerateReport=false;codegen('-config',cfg,{quote(reference_function)},"
                             f"'-args',{{p,plantp,coder.Constant(64001),int8(1)}},'-d',{quote(folder/(family+'-mex'))},'-o',{quote(folder/mex_name)});disp('KIT_MEX_READY');",'KIT_MEX_READY')
                    positions=[0,1] if family=='bldc' else [0]
                    for position in positions:
                        for direction in [1,-1]:
                            unchanged();name=f'{family}_mode{position}_dir{direction}';destination=folder/name;destination.mkdir()
                            reference=destination/'reference.mat'
                            evaluate(f"p=ambd.kit_parameters({quote(family)});p.PositionMode=uint8({position});"
                                     f"[inputs,expected,truth]={mex_name}(p,plantp,64001,int8({direction}));"
                                     f"save({quote(reference)},'p','plantp','inputs','expected','truth','-v7.3');"
                                     f"result=prepare_kit_trace({quote(model)},{quote(family)},{quote(reference)},{quote(destination)});"
                                     "assert(result.Passed);disp('KIT_REFERENCE_PASS');",'KIT_REFERENCE_PASS')
                            unchanged();result=json.loads((destination/'result.json').read_text());result['Name']=name
                            for key,filename in [('Reference','reference.mat'),('Trace','trace.mat'),('Recording','input-recording.mat')]:
                                path=destination/filename;result[key]=path.relative_to(ROOT).as_posix();result[key+'Sha256']=TARGET.digest(path)
                                artifact_hashes[result[key]]=result[key+'Sha256']
                            summary['Cases'].append(result);save()
        unchanged();summary['SourcesUnchanged']=True;summary['SettingsUnchanged']=True
        summary['ArtifactsUnchanged']=True;summary['Passed']=len(summary['Cases'])==6 and all(c['Passed'] for c in summary['Cases'])
        save()
        if not summary['Passed']:raise RuntimeError('Kit matrix incomplete.')
    except Exception as exception:
        summary['Passed']=False;summary['Error']=str(exception);save();raise


if __name__=='__main__':main()
