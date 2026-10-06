# SPDX-License-Identifier: MIT
"""Build BLDC host models using the pinned official MATLAB MCP server.

All structural edits go through model_edit. Output, backups and transcripts
stay under .agent-env. Existing hardware wrappers are inspected as ZIP XML
without loading their callbacks, then replaced with the host implementation.
"""
from __future__ import annotations
import argparse
import importlib.util
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
ARTIFACTS=ROOT/'.agent-env/bldc-models'
BLDC=ROOT/'mc-models/bldc'
spec=importlib.util.spec_from_file_location('pmsm_model_builder',ROOT/'tools/pmsm/build_models.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
quote,add,wire=base.quote,base.add,base.wire
INPUTS=[('CurrentRaw','uint16',3),('Hall','uint8',1),('TerminalVoltage','single',3),
 ('Control','uint8',1),('Fault','boolean',1),('CommandEvent','boolean',1),
 ('DrivingEvent','boolean',1),('TimerEvent','boolean',1),('SpeedReq','single',1),
 ('Vdc','single',1),('AppliedSector','uint8',1),('AppliedDirection','int8',1),('VoltageValid','boolean',1)]
OUTPUTS=[('DutyA','uint16',1),('DutyB','uint16',1),('DutyC','uint16',1),
 ('PhaseEnable','boolean',3),('GateEnable','boolean',1),('Debug','Bus: tBldcDebug',1),('Monitor','Bus: tBldcMonitor',1)]
MODULES=[('McTuning','tuning'),('McKernel','kernel'),('McEventHub','event_hub'),
 ('McFault','protection'),('McStateMachine','supervisor'),('McDataFlow','dataflow')]

class Builder(base.Builder):
    def __init__(self,call,output_directory=None):
        super().__init__(call,output_directory or ARTIFACTS)

    def script(self,model,bid,code):
        sid=bid.removeprefix('blk_')
        # Pinned SATK does not publish MATLAB Function Data IDs. The documented
        # FunctionScript/Stateflow.Data metadata fallback follows the recorded
        # PMSM probe; no topology or ConfigSet editing happens here.
        self.matlab(f"cfg=get_param(Simulink.ID.getFullName('{model}:{sid}'),'MATLABFunctionConfiguration');"
          f"cfg.FunctionScript=sprintf({quote(code.replace('%','%%').replace(chr(10),'\\n'))});"
          f"ch=sfroot().find('-isa','Stateflow.EMChart','Path',Simulink.ID.getFullName('{model}:{sid}'));"
          "d=ch.find('-isa','Stateflow.Data','Scope','Output');for k=1:numel(d);switch d(k).Name;"
          "case 'u',d(k).DataType='Bus: tBldcInput';case 'next',d(k).DataType='Bus: tBldcRuntime';"
          "case 'debug',d(k).DataType='Bus: tBldcDebug';case 'monitor',d(k).DataType='Bus: tBldcMonitor';end;end;")

    def fresh(self,name,directory):
        marker=f'FRESH_MODEL {name}'
        result=self.matlab(
            f"if bdIsLoaded('{name}'),"
            f"assert(~strcmp(get_param('{name}','Dirty'),'on'),'bldc:DirtyLoadedModel',"
            f"'Refusing to replace dirty loaded model {name}.');bdclose('{name}');end;"
            f"new_system('{name}');open_system('{name}');disp({quote(marker)});")
        # MATLAB execution errors can arrive as ordinary MCP text content.
        # Do not inspect, bind a dictionary, or edit unless creation completed.
        if marker not in result.splitlines():
            raise RuntimeError(f'Model creation was not confirmed for {name}: {result}')
        self.read(name)
        # Pinned model_edit root dictionary binding defect (same PMSM probe).
        self.matlab(f"set_param('{name}','DataDictionary','BldcData.sldd');")
        directory=Path(directory)
        path=(directory if directory.is_absolute() else BLDC/directory)/(name+'.slx')
        path.parent.mkdir(parents=True,exist_ok=True)
        return path

    def ports(self,ins,outs):
        def unpack(item):return (*item,1) if len(item)==2 else item
        return [add('Inport',n,Port=str(i),OutDataTypeStr=t,PortDimensions=str(d),SampleTime='6.25e-5')
                for i,(n,t,d) in enumerate(map(unpack,ins),1)]+[
                add('Outport',n,Port=str(i),OutDataTypeStr=t,PortDimensions=str(d))
                for i,(n,t,d) in enumerate(map(unpack,outs),1)]

    def bus_probe(self):
        name='BLDC_TypedBusProbe';path=self.fresh(name,self.artifacts)
        types=['Params','Input','Runtime','Debug','Monitor']
        ids=self.edit(name,self.ports([('Probe'+t,'Bus: tBldc'+t,1) for t in types],
                                     [('Result'+t,'Bus: tBldc'+t,1) for t in types]))
        self.edit(name,[wire(ids['Probe'+t]+'.y1',ids['Result'+t]+'.u1') for t in types])
        self.finish(name,path)
        self.matlab(f"bdclose('{name}');")

    def core(self):
        name='BLDCFramework';path=self.fresh(name,'algo')
        ids=self.edit(name,self.ports(INPUTS,OUTPUTS)+[
          add('MATLAB Function','InputPack'),
          add('Constant','Parameters',Value='BldcControl_Params',OutDataTypeStr='Bus: tBldcParams'),
          add('UnitDelay','RuntimeMemory',InitialCondition='BldcRuntime_Init',SampleTime='6.25e-5')]+
          [add('SubSystem',s) for s,_ in MODULES]+[add('MATLAB Function','McDebug')])
        self.script(name,ids['InputPack'],self.pack_script())
        for scope,fn in MODULES:
            sid=ids[scope];self.read(name,sid)
            sub=self.edit(name,self.ports([('u','Bus: tBldcInput'),('s','Bus: tBldcRuntime'),('p','Bus: tBldcParams')],[('next','Bus: tBldcRuntime')])+[add('MATLAB Function','Compute')],scope=sid)
            self.script(name,sub['Compute'],f'function next=fcn(u,s,p)\n%#codegen\nnext=bldc.{fn}(u,s,p);\nend')
            self.edit(name,[wire(sub[n]+'.y1',sub['Compute']+f'.u{i}') for i,n in enumerate(['u','s','p'],1)]+[wire(sub['Compute']+'.y1',sub['next']+'.u1')],scope=sid)
            self.read(name,sid);self.check(name,sid)
        self.script(name,ids['McDebug'],'function [a,b,c,enabled,gate,debug,monitor]=fcn(s,p)\n%#codegen\n[counts,enabled,gate,debug,monitor]=bldc.monitor(s,p);\na=counts(1);b=counts(2);c=counts(3);\nend')
        w=[wire(ids[n]+'.y1',ids['InputPack']+f'.u{i}') for i,(n,_,_) in enumerate(INPUTS,1)]
        prev=ids['RuntimeMemory']
        for scope,_ in MODULES:
            w += [wire(ids['InputPack']+'.y1',ids[scope]+'.u1'),wire(prev+'.y1',ids[scope]+'.u2'),wire(ids['Parameters']+'.y1',ids[scope]+'.u3')];prev=ids[scope]
        w += [wire(prev+'.y1',ids['RuntimeMemory']+'.u1'),wire(prev+'.y1',ids['McDebug']+'.u1'),wire(ids['Parameters']+'.y1',ids['McDebug']+'.u2')]
        w += [wire(ids['McDebug']+f'.y{i}',ids[n]+'.u1') for i,(n,_,_) in enumerate(OUTPUTS,1)]
        self.edit(name,w);self.finish(name,path);self.mapping[name]=ids

    def pack_script(self):
        return 'function u=fcn('+','.join(n for n,_,_ in INPUTS)+')\n%#codegen\n'+''.join(f'u.{n}={n};\n' for n,_,_ in INPUTS)+'end'

    def wrapper(self,name,directory,reference='BLDCFramework',compile_model=True):
        path=self.fresh(name,directory)
        ids=self.edit(name,self.ports(INPUTS,OUTPUTS)+[add('ModelReference','Controller',ModelName=reference)])
        self.edit(name,[wire(ids[n]+'.y1',ids['Controller']+f'.u{i}') for i,(n,_,_) in enumerate(INPUTS,1)]+[wire(ids['Controller']+f'.y{i}',ids[n]+'.u1') for i,(n,_,_) in enumerate(OUTPUTS,1)])
        self.finish(name,path,compile_model=compile_model);self.mapping[name]=ids

    def top(self,name,controller):
        path=self.fresh(name,'platform/pil')
        ins=[('SpeedReq','single',1),('Control','uint8',1),('Fault','boolean',1),('LoadTorque','double',1),('Vdc','single',1),('SensorFault','uint8',1),('CurrentOffset','single',3),('TerminalOffset','single',3),('VoltageValid','boolean',1)]
        outs=[('OmegaTruth','single',1),('CurrentTruth','single',3),('ThetaTruth','single',1),('Monitor','Bus: tBldcMonitor',1),('Duty','uint16',3),('PhaseEnable','boolean',3),('GateEnable','boolean',1),('Debug','Bus: tBldcDebug',1),('RecordedInput','Bus: tBldcInput',1)]
        ops=self.ports(ins,outs)+[add('ModelReference','Controller',ModelName=controller),
          add('MATLAB Function','Plant'),add('MATLAB Function','MeasurementAdapter'),add('MATLAB Function','PackDuty'),
          add('MATLAB Function','AppliedMetadata'),add('MATLAB Function','RecordedInputPack'),
          add('Constant','InitialPlantState',Value='[0;0;0;0;0]',OutDataTypeStr='double'),
          add('Constant','PlantParameters',Value='BldcPlant_Params',OutDataTypeStr='Bus: tBldcParams'),
          add('Constant','Events',Value='true',OutDataTypeStr='boolean'),add('Terminator','RawPlantSink')]
        for block,initial in [('DutyDelay','uint16([0;0;0])'),('PhaseDelay','false(3,1)'),('GateDelay','false'),('SectorDelay','uint8(0)'),('DirectionDelay','int8(1)')]:
            ops.append(add('UnitDelay',block,InitialCondition=initial,SampleTime='6.25e-5'))
        ids=self.edit(name,ops)
        self.script(name,ids['Plant'],self.plant_script())
        self.script(name,ids['MeasurementAdapter'],'function [raw,hall,terminal]=fcn(current,hallIn,terminalIn,mode,currentOffset,terminalOffset,p)\n%#codegen\npersistent state\nif isempty(state),state=struct(\'Hall\',uint8(5),\'Terminal\',repmat(p.NominalVdc/single(2),3,1));end\n[raw,hall,terminal,state]=bldc_measurement_adapter(current,hallIn,terminalIn,mode,currentOffset,terminalOffset,p,state);\nend')
        self.script(name,ids['PackDuty'],'function duty=fcn(a,b,c)\n%#codegen\nduty=[a;b;c];\nend')
        self.script(name,ids['AppliedMetadata'],'function [sector,direction]=fcn(monitor)\n%#codegen\nsector=uint8(0);if monitor.GateEnable,sector=monitor.Sector;end\ndirection=monitor.OutputDirection;\nend')
        self.script(name,ids['RecordedInputPack'],self.pack_script())
        w=[]
        def c(a,b):
            a0,ap=a.split('.');b0,bp=b.split('.');w.append(wire(ids[a0]+'.'+ap,ids[b0]+'.'+bp))
        for a,b in [('DutyDelay.y1','Plant.u1'),('PhaseDelay.y1','Plant.u2'),('GateDelay.y1','Plant.u3'),('Vdc.y1','Plant.u4'),('LoadTorque.y1','Plant.u5'),('PlantParameters.y1','Plant.u6'),('Plant.y1','RawPlantSink.u1'),('Plant.y4','MeasurementAdapter.u1'),('Plant.y2','MeasurementAdapter.u2'),('Plant.y3','MeasurementAdapter.u3'),('SensorFault.y1','MeasurementAdapter.u4'),('CurrentOffset.y1','MeasurementAdapter.u5'),('TerminalOffset.y1','MeasurementAdapter.u6'),('PlantParameters.y1','MeasurementAdapter.u7'),('Plant.y6','OmegaTruth.u1'),('Plant.y4','CurrentTruth.u1'),('Plant.y5','ThetaTruth.u1'),('PackDuty.y1','DutyDelay.u1'),('PackDuty.y1','Duty.u1'),('Controller.y4','PhaseDelay.u1'),('Controller.y4','PhaseEnable.u1'),('Controller.y5','GateDelay.u1'),('Controller.y5','GateEnable.u1'),('Controller.y6','Debug.u1'),('Controller.y7','Monitor.u1'),('Controller.y7','AppliedMetadata.u1'),('AppliedMetadata.y1','SectorDelay.u1'),('AppliedMetadata.y2','DirectionDelay.u1'),('RecordedInputPack.y1','RecordedInput.u1')]:c(a,b)
        for i in range(1,4):c(f'Controller.y{i}',f'PackDuty.u{i}')
        c('InitialPlantState.y1','Plant.u7')
        inputs=['MeasurementAdapter.y1','MeasurementAdapter.y2','MeasurementAdapter.y3','Control.y1','Fault.y1','Events.y1','Events.y1','Events.y1','SpeedReq.y1','Vdc.y1','SectorDelay.y1','DirectionDelay.y1','VoltageValid.y1']
        for i,source in enumerate(inputs,1):c(source,f'Controller.u{i}');c(source,f'RecordedInputPack.u{i}')
        out_ids={ids[n]:n for n,_,_ in outs}
        for connection in w:
            destination=connection['target'].split(' -> ')[1].split('.')[0]
            if destination in out_ids:connection['params']={'Name':out_ids[destination]}
        self.edit(name,w);self.finish(name,path);self.mapping[name]=ids

    def plant_script(self):
        return 'function [raw,hall,terminal,current,theta,omega]=fcn(duty,enabled,gate,vdc,loadTorque,p,initialState)\n%#codegen\npersistent x\nif isempty(x)\nx=initialState;\nelse\nx=bldc.plant_step(x,duty,enabled,gate,vdc,loadTorque,p,6.25e-5);\nend\n[raw,hall,terminal,current,theta,omega]=bldc.plant_measure(x,duty,enabled,gate,vdc,p);\nend'

    def configure_codegen(self):
        skill=ROOT/'.agents/skills/ambd-mathworks/simulink-generate-embedded-code/scripts'
        for model in ['BLDC_PIL_Hall_top','BLDC_PIL_Sensorless_top','BLDC_Ctrl_CodeModel','BLDC_Ctrl_MBD']:
            result=self.call('evaluate_matlab_code',project_path=str(skill),code=f"configJson=configure_for_codegen('{model}',Target=\"ert\",Language=\"C\",Hardware=\"Intel->x86-64 (Windows64)\",Objective=\"Debug\",Interface=\"Nonreusable function\",ConfigOnly=true,Build=false,Compliance=\"\",OutputDir={quote(self.artifacts/'codegen')});disp(configJson);configResult=jsondecode(configJson);if configResult.success,disp('CONFIGURATION PASS');end;")
            if 'CONFIGURATION PASS' not in result:raise RuntimeError(result)
        for model in self.mapping:
            self.read(model)
            self.edit(model,[dict(op='configure',target='config:'+model,params={'SupportVariableSizeSignals':'off','Toolchain':'MinGW64 | gmake (64-bit Windows)'})])
            self.read(model);self.check(model)
        self.matlab('for model={'+','.join(quote(n) for n in self.mapping)+"};save_system(model{1});end;"+f'cd({quote(ROOT)});')

    def backup(self):
        original=base.PMSM
        try:base.PMSM=BLDC;super().backup()
        finally:base.PMSM=original

    def run(self):
        gate=self.matlab('disp(jsonencode(library.settingsLookup()));')
        if not ('"found":false' in gate or '"gatePass":true' in gate):raise RuntimeError(gate)
        self.backup()
        for d in ['algo','platform/codegen','platform/pil']:(BLDC/d).mkdir(parents=True,exist_ok=True)
        self.matlab(f'addpath({quote(ROOT)});info=bldc_setup();Simulink.fileGenControl(\'set\',\'CacheFolder\',{quote(self.artifacts/"cache")},\'CodeGenFolder\',{quote(self.artifacts/"codegen")},\'createDir\',true);')
        self.bus_probe();self.core()
        for name in ['BLDC_PIL_Hall_model','BLDC_PIL_Sensorless_model']:self.wrapper(name,'platform/pil')
        for name in ['BLDC_Ctrl_CodeModel','BLDC_Ctrl_MBD']:self.wrapper(name,'platform/codegen')
        for stem in ['BLDC_PIL_Hall','BLDC_PIL_Sensorless']:self.top(stem+'_top',stem+'_model')
        (self.artifacts/'model-map.json').write_text(json.dumps(self.mapping,indent=2))
        self.configure_codegen()
        text=self.matlab('for model={'+','.join(quote(n) for n in self.mapping)+"};set_param(model{1},'SimulationCommand','update');fprintf('COMPILE PASS %s\\n',model{1});end;")
        if any(f'COMPILE PASS {name}' not in text for name in self.mapping):raise RuntimeError(text)
        result=self.matlab("slbuild('BLDC_Ctrl_CodeModel');disp('BLDC CODE BUILD PASS');")
        if 'BLDC CODE BUILD PASS' not in result:raise RuntimeError(result)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-directory',type=Path,default=ARTIFACTS)
    options=parser.parse_args()
    sys.path.insert(0,str(ROOT/'tools/agent'))
    import configuration,environment
    from mcp_client import Client
    command,env=environment.runtime(configuration.read_state(ROOT)['active'],session='new')
    with Client(command,cwd=ROOT,env=env,timeout=1200) as client:
        client.initialize();Builder(client.call,options.output_directory).run()
