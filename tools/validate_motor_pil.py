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
# File:        validate_motor_pil.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-07
# Version:     0.1.0
# Description: Validate Hall, sensored and sensorless operating transitions through PIL.
# =================================================================================

"""Verify operating-state transitions against accepted host recordings on S32K344."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import importlib.util
import json
import sys
import uuid

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('hsp_target_validation',ROOT/'tools/hsp/validate_target.py')
TARGET=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(TARGET)
CASES={
    'bldc': [('BLDC_PIL_Hall_model','hall_steps'),('BLDC_PIL_Sensorless_model','sensorless_forward')],
    'pmsm': [('FOC_PIL_Algth_model','sensored_steps'),('FOC_PIL_StateMch_model','sensorless_forward')],
}


def artifact_hashes(reports):
    """Bind the accepted host report and every replay input before execution."""
    paths=[]
    for family,folder in reports.items():
        paths.append(folder/'summary.json')
        for _,scenario in CASES[family]:
            paths.append(folder/'closed-loop'/scenario/'Normal/trace.mat')
            if family=='pmsm':paths.append(folder/'replay'/scenario/'input-recording.mat')
    return {str(path):TARGET.digest(path) for path in paths}


def require_unchanged_artifacts(expected):
    for path,value in expected.items():
        if TARGET.digest(Path(path))!=value:
            raise RuntimeError('Host evidence changed during validation: '+path)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--settings',type=Path,required=True)
    parser.add_argument('--bldc-report',type=Path)
    parser.add_argument('--pmsm-report',type=Path)
    args=parser.parse_args()
    reports={name:getattr(args,name+'_report') for name in CASES if getattr(args,name+'_report')}
    if not reports:parser.error('Provide at least one accepted full host report directory.')
    reports={family:path.resolve() for family,path in reports.items()}
    artifacts=artifact_hashes(reports)
    source_reports={}
    for family,path in reports.items():
        path=path.resolve();reports[family]=path
        report=json.loads((path/'summary.json').read_text(encoding='utf-8'))
        if not report.get('Passed') or not report.get('CompleteMatrix'):
            parser.error(f'{family} needs a passed complete host matrix.')
        for relative,expected in report['SourceHashes'].items():
            if TARGET.digest(ROOT/relative)!=expected:
                parser.error('Host evidence is stale: '+relative)
        source_reports[family]=TARGET.digest(path/'summary.json')
    require_unchanged_artifacts(artifacts)
    folder=ROOT/'.agent-env/operational-pil'/uuid.uuid4().hex[:8];folder.mkdir(parents=True)
    baseline=TARGET.source_hashes(list(reports))
    for relative in ('tools/validate_motor_pil.py','tests/hsp/run_operational_pil.m'):
        baseline[relative]=TARGET.digest(ROOT/relative)
    summary=dict(Passed=False,CompleteMatrix=set(reports)==set(CASES),SourceHashes=baseline,
                 SourceReports=source_reports,SourceArtifacts=artifacts,
                 SettingsSha256=TARGET.digest(args.settings.resolve()),
                 StartedUTC=datetime.now(timezone.utc).isoformat(),Cases=[])
    transcript=[]
    def save():
        for name,value in [('transcript.json',transcript),('summary.json',summary)]:
            pending=folder/(name+'.tmp');pending.write_text(json.dumps(value,indent=2,ensure_ascii=False),encoding='utf-8')
            pending.replace(folder/name)
    def evaluate(client,code,marker):
        reply=client.call('evaluate_matlab_code',dict(project_path=str(ROOT),code=code))
        transcript.append(dict(Code=code,Result=reply));save()
        text='\n'.join(item.get('text','') for item in reply.get('content',[]))
        if reply.get('isError') or marker not in text.splitlines():raise RuntimeError(text or str(reply))
        print(marker,flush=True)
    sys.path.insert(0,str(ROOT/'tools/agent'))
    import configuration,environment
    from mcp_client import Client
    save();print('Operational PIL reports: '+str(folder),flush=True)
    try:
        for family,host_folder in reports.items():
            command,env=environment.runtime(configuration.read_state(ROOT)['active'],session='new')
            with Client(command,cwd=ROOT,env=env,timeout=1800) as client:
                client.initialize()
                evaluate(client,f"addpath({TARGET.quote(ROOT)},{TARGET.quote(ROOT/'tests/hsp')});"
                         f"stageInfo=hsp_stage({TARGET.quote(family)},{TARGET.quote(args.settings.resolve())});"
                         "disp('OPERATIONAL_STAGE_READY');",'OPERATIONAL_STAGE_READY')
                for model,scenario in CASES[family]:
                    trace=host_folder/'closed-loop'/scenario/'Normal/trace.mat'
                    recording=host_folder/'replay'/scenario/'input-recording.mat' if family=='pmsm' else None
                    case_folder=folder/model
                    marker='OPERATIONAL_PIL_PASS_'+model
                    require_unchanged_artifacts(artifacts)
                    evaluate(client,f"result=run_operational_pil({TARGET.quote(model)},{TARGET.quote(family)},"
                             f"{TARGET.quote(trace)},{TARGET.quote(recording or '')},{TARGET.quote(case_folder)});"
                             f"assert(result.Passed);saved=load({TARGET.quote(case_folder/'operational-traces.mat')},'result');"
                             f"assert(isequaln(saved.result,result));disp('{marker}');",marker)
                    require_unchanged_artifacts(artifacts)
                    result=json.loads((case_folder/'result.json').read_text(encoding='utf-8'))
                    result['SourceTraceSha256']=artifacts[str(trace)]
                    if recording:result['InputRecordingSha256']=artifacts[str(recording)]
                    summary['Cases'].append(result);save()
        require_unchanged_artifacts(artifacts)
        summary['SourceArtifactsUnchanged']=True
        summary['SourcesUnchanged']=all(TARGET.digest(ROOT/name)==value for name,value in baseline.items())
        summary['SettingsUnchanged']=TARGET.digest(args.settings.resolve())==summary['SettingsSha256']
        summary['Passed']=summary['SourcesUnchanged'] and summary['SettingsUnchanged'] and len(summary['Cases'])==2*len(reports) and all(c['Passed'] for c in summary['Cases'])
        if not summary['Passed']:raise RuntimeError('Operating-state evidence is incomplete or validation inputs changed.')
    except BaseException as error:
        summary['Passed']=False;summary['Error']=str(error);raise
    finally:
        summary['FinishedUTC']=datetime.now(timezone.utc).isoformat();save()
    print(f"PASS: {len(summary['Cases'])} operating-state target replays. {folder}",flush=True)


if __name__=='__main__':main()
