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
# File:        build_models.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-06
# Version:     0.1.0
# Description: Rebuild original host PMSM models through the pinned official MATLAB
#              MCP.
# =================================================================================

"""Rebuild original host PMSM models through the pinned official MATLAB MCP.

Run from the repository root: python tools/pmsm/build_models.py
Existing project models and dictionary are backed up below .agent-env first.
No hardware libraries, external reference trees or legacy assets are loaded.
"""
from __future__ import annotations

import hashlib
import argparse
import json
from pathlib import Path
import re
import shutil
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS = ROOT / '.agent-env/pmsm-models'
PMSM = ROOT / 'mc-models/pmsm'
INPUTS = [('Ia','uint16'),('Ib','uint16'),('Ic','uint16'),
          ('McControl','uint8'),('FaultEvent','boolean'),('McCtrlEvent','boolean'),
          ('McDrivingEvent','boolean'),('McTimerEvent','boolean'),
          ('McTuningPort','Bus: tMcTuning'),('SpeedReq','single'),
          ('DcBusVoltage','single'),('RotorAngle','single'),
          ('AppliedVoltageAlpha','single'),('AppliedVoltageBeta','single')]
OUTPUTS = [('DutyA','uint16'),('DutyB','uint16'),('DutyC','uint16'),
           ('DebugPort','Bus: tMcDebug'),('GateEnable','boolean'),('Monitor','Bus: tMcMonitor')]
MODULES = [('McKernel','kernel'),('McTuning','tuning'),('McEventHub','event_hub'),
           ('McFault','protection'),('McStateMachine','supervisor'),('McDataFlow','dataflow')]

CORE_INPUTS = [(name, 'single' if index < 3 else dtype)
               for index, (name, dtype) in enumerate(INPUTS)] + [('Disable', 'boolean')]
CORE_OUTPUTS = [(name, 'single' if index < 3 else dtype)
                for index, (name, dtype) in enumerate(OUTPUTS)]


def interface_for(name):
    return (CORE_INPUTS, CORE_OUTPUTS) if 'Algth' in name else (INPUTS, OUTPUTS)


def library_component(name):
    return 'AlgthController' if 'Algth' in name else 'Controller'


sys.path.insert(0, str(Path(__file__).resolve().parent))
from layer_models import core_transition, controller, native_plant, host_top


def quote(value):
    return "'" + str(value).replace("'","''") + "'"


def add(kind,name,**params):
    return dict(op='add_block',type=kind,name=name,ref=name,params=params)


def wire(source,target):
    return dict(op='connect',target=f'{source} -> {target}')


class Builder:
    def __init__(self, call, output_directory=None):
        self.call_tool = call
        self.seq = 0
        self.mapping = {}
        self.artifacts=Path(output_directory or ARTIFACTS).resolve()
        if not self.artifacts.is_relative_to((ROOT/'.agent-env').resolve()):
            raise ValueError('Build artifacts must stay below .agent-env.')

    def call(self,name,**arguments):
        self.seq += 1
        result = self.call_tool(name,arguments)
        self.artifacts.mkdir(parents=True,exist_ok=True)
        (self.artifacts/f'build-{self.seq:03}-{name}.json').write_text(
            json.dumps(dict(arguments=arguments,result=result),indent=2),encoding='utf-8')
        txt='\n'.join(c.get('text','') for c in result.get('content',[]))
        print(f'{self.seq:03} {name}: {txt[:110]}',flush=True)
        if result.get('isError') or result.get('error'):
            raise RuntimeError(result)
        return txt

    def matlab(self,code):
        return self.call('evaluate_matlab_code',code=code)

    def read(self,model,scope='root'):
        return self.call('model_read',model=model,scope=scope,depth='1')

    def check(self,model,scope='root'):
        text=self.call('model_check',model=model,scope=scope,checks='["all"]')
        if 'status: has_errors' in text:
            raise RuntimeError(text)
        return text

    def edit(self,model,ops,scope='root',layout='full'):
        text=self.call('model_edit',model=model,scope=scope,layout_mode=layout,
                       operations=json.dumps(ops,separators=(',',':')))
        if 'status: partial' in text or 'status: error' in text:
            self.read(model,scope); self.check(model,scope)
            raise RuntimeError(text)
        return {name:'blk_'+sid for name,sid in re.findall(r'(\w+): blk_(\d+)',text)}

    def script(self,model,bid,code):
        sid=bid.removeprefix('blk_')
        # The pinned model_read does not publish EMChart Data IDs, and
        # model_edit rejects its native sf ID. Use documented Stateflow Data
        # metadata for named struct outputs, alongside FunctionScript API.
        self.matlab(f"cfg=get_param(Simulink.ID.getFullName('{model}:{sid}'),'MATLABFunctionConfiguration'); "
                    f"cfg.FunctionScript=sprintf({quote(code.replace('%','%%').replace(chr(10),'\\n'))});"
                    f"ch=sfroot().find('-isa','Stateflow.EMChart','Path',Simulink.ID.getFullName('{model}:{sid}'));"
                    "d=ch.find('-isa','Stateflow.Data','Scope','Output');"
                    "for k=1:numel(d); switch d(k).Name;"
                    "case 'u',d(k).DataType='Bus: tMcInput';case 'uCore',d(k).DataType='Bus: tMcCoreInput';case {'core','previousCore','nextCore'},d(k).DataType='Bus: tMcCoreRuntime';case 'prepared',d(k).DataType='Bus: tMcRuntime';"
                    "case 'next',d(k).DataType='Bus: tMcRuntime';"
                    "case 'debug',d(k).DataType='Bus: tMcDebug';"
                    "case 'monitor',d(k).DataType='Bus: tMcMonitor';end;if startsWith(d(k).DataType,'Bus:'),d(k).Props.Array.Size='1';end;end;")

    def fresh(self,name,directory):
        # Old hardware wrappers are inspected as saved XML, never opened.
        self.matlab(f"if bdIsLoaded('{name}'), bdclose('{name}'); end; new_system('{name}'); open_system('{name}');")
        self.read(name)
        # Root DataDictionary is not a ConfigSet parameter; official model_edit
        # root blk_0 handling is defective in the pinned toolkit (recorded probe).
        self.matlab(f"set_param('{name}','DataDictionary','McData.sldd');")
        return PMSM / directory / (name+'.slx')

    def ports(self,ins,outs):
        return [add('Inport',name,Port=str(i),OutDataTypeStr=typ,SampleTime='6.25e-5')
                for i,(name,typ) in enumerate(ins,1)] + [
                add('Outport',name,Port=str(i),OutDataTypeStr=typ)
                for i,(name,typ) in enumerate(outs,1)]

    def finish(self,name,path,compile_model=True):
        self.edit(name,[dict(op='configure',target='config:'+name,params={
            'SolverType':'Fixed-step','Solver':'ode4' if name.endswith('_top') else 'FixedStepDiscrete',
            'FixedStep':'1/16000/16' if name.endswith('_top') else '6.25e-5',
            'StopTime':'4','SaveOutput':'on','SaveFormat':'Dataset','SignalLogging':'on',
            'ReturnWorkspaceOutputs':'on'})])
        self.read(name);self.check(name)
        result=self.matlab(f"save_system('{name}',{quote(path)});" +
                    (f"set_param('{name}','SimulationCommand','update'); disp('COMPILE PASS {name}');" if compile_model else ''))
        if compile_model and f'COMPILE PASS {name}' not in result:
            raise RuntimeError(result)

    def core(self,name='McControllerLibrary',directory='algo'):
        path=self.fresh(name,directory)
        motor_scope=self.library_scopes[name]
        core_scope=self.add_library_subsystem(name,'FocCore')
        algorithm_scope=self.add_library_subsystem(name,'AlgthController')
        plant_scope=self.add_library_subsystem(name,'AveragePlant')
        core_transition(self,name,core_scope,MODULES)
        self.matlab(f"save_system('{name}',{quote(path)});")
        controller(self,name,algorithm_scope,CORE_INPUTS,CORE_OUTPUTS,core=True)
        controller(self,name,motor_scope,INPUTS,OUTPUTS)
        native_plant(self,name,plant_scope)
        self.finish(name,path)

    def wrapper(self,name,directory,reference='MotorFramework',compile_model=True):
        path=self.fresh(name,directory)
        inputs,outputs=interface_for(reference)
        ids=self.edit(name,self.ports(inputs,outputs)+[add('ModelReference','Controller',ModelName=reference,CodeInterface='Top model')])
        self.edit(name,[wire(ids[n]+'.y1',ids['Controller']+f'.u{i}') for i,(n,_) in enumerate(inputs,1)]+
                  [wire(ids['Controller']+f'.y{i}',ids[n]+'.u1') for i,(n,_) in enumerate(outputs,1)])
        self.finish(name,path,compile_model=compile_model);self.mapping[name]=ids

    def top(self,name,reference):
        inputs,outputs=interface_for(reference)
        host_top(self,name,reference,inputs,outputs,core='Algth' in reference)

    def backup(self):
        folder=self.artifacts/('before-'+time.strftime('%Y%m%d-%H%M%S'));records={}
        for f in PMSM.rglob('*'):
            if f.suffix not in ('.slx','.sldd'):continue
            relative=f.relative_to(ROOT);target=folder/relative
            target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,target)
            records[str(relative)]={'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
            if f.suffix=='.slx':
                with zipfile.ZipFile(f) as archive:
                    records[str(relative)]['saved_xml']={n:archive.read(n).decode() for n in archive.namelist()
                        if n.endswith('.xml') and (n.startswith('simulink/systems/') or n=='simulink/blockdiagram.xml')}
        (folder/'manifest.json').write_text(json.dumps(records,indent=2),encoding='utf-8')



if __name__ == '__main__':
    import runpy
    sys.argv[1:1] = ['--family', 'pmsm']
    runpy.run_path(str(ROOT / 'tools/hsp/build_models.py'), run_name='__main__')
