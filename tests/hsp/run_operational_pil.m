% =================================================================================
% The MIT License
% MIT许可证
%
% <https://opensource.org/license/mit>
%
% SPDX short identifier / SPDX 短标识符：MIT
%
% Copyright (c) 2026 autoMBD
% 版权所有 (c) 2026 autoMBD
%
% Permission is hereby granted, free of charge, to any person obtaining a
% copy of this software and associated documentation files (the “Software”),
% to deal in the Software without restriction, including without limitation
% the rights to use, copy, modify, merge, publish, distribute, sublicense,
% and/or sell copies of the Software, and to permit persons to whom the
% Software is furnished to do so, subject to the following conditions:
% 特此向获得本软件及相关文档（合称“本软件”）副本的任何人免费授予不受限制地利用本软
% 件的许可，包括而不限于：使用、复制、修改、合并、发布、分发、分许可和/或销售本软
% 件副本，并允许本软件的接收者也获得前述许可，但须遵守以下条件：
%
% The above copyright notice and this permission notice shall be included
% in all copies or substantial portions of the Software.
% 以上版权声明及本许可声明应包含在本软件的所有副本或主要部分中。
%
% THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
% MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
% NONINFRINGEMENT. IN NO EVENT SHALLTHE AUTHORS OR COPYRIGHT
% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
% IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
% CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.
% 本软件系“按原样”提供，不包含任何形式的明示或默示保证，包括但不限于适销性、特定
% 目的适用性及不侵权的保证。在任何情况下，无论是在合同、侵权或其他案件中，作者或版
% 权持有人均不对因本软件、或因本软件的使用或其他利用而引起的、引发的或与之相关的任
% 何权利主张、损害赔偿或其他责任承担责任。
% =================================================================================
% Project:     autoMBD Motor Control <https://github.com/autoMBD/AMBD-MC>
% File:        run_operational_pil.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-07
% Version:     0.1.0
% Description: Replay qualified motor transitions and Run windows on the target processor.
% =================================================================================

function result = run_operational_pil(model,family,traceFile,recordingFile,outputDirectory,execute)
%run_operational_pil - Replay a qualified operating-state window on the selected target
%   RESULT = run_operational_pil(MODEL,FAMILY,TRACE,RECORDING,OUTPUT)
%   captures the exact runtime state from a Normal prehistory, proves the
%   seeded window matches the accepted recording, then compares actual
%   PIL through alignment exit or sensorless acquisition/tracking to Run.
%   RECORDING is the PMSM input-recording MAT file; BLDC reads logged inputs.
%
%   RESULT = run_operational_pil(...,false) prepares and checks Normal
%   only. That result is explicitly incomplete and does not claim PIL.
%
%   See also ambd_mc, ambd.compare_outputs

if nargin<6,execute=true;end
if ~isfolder(outputDirectory),mkdir(outputDirectory);end
source=load(traceFile,'trace','scenario');
p=source.scenario.Control;
if strcmp(family,'bldc')
    recording=source.trace.Input;recording.Time=source.trace.Time;
    prototype=bldc.initial_state(p);
    parameterName='BldcControl_Params';parameterType='tBldcParams';
    stateName='BldcRuntime_Init';stateType='tBldcRuntime';
    sensorless=p.PositionMode==uint8(1);
else
    data=load(recordingFile,'inputRecording','scenario');
    assert(isequal(data.scenario.Control,p)&&isequal(data.inputRecording.Time,source.trace.Time), ...
        'ambd:RecordingIdentity','Input recording does not match the accepted scenario.');
    recording=data.inputRecording;prototype=mc.initial_state(p);
    parameterName='McControl_Params';parameterType='tMcControlParams';
    stateName='McRuntime_Init';stateType='tMcRuntime';
    sensorless=p.PositionMode==uint8(0);
end
replayPeriod=(double(recording.Time(end))-double(recording.Time(1)))/(numel(recording.Time)-1);
assert(isfinite(replayPeriod)&&replayPeriod>0,'ambd:RecordingTime','Invalid recording period.');
assert(max(abs(double(recording.Time(:))-(double(recording.Time(1))+(0:numel(recording.Time)-1)'*replayPeriod)))<=6.25e-11, ...
    'ambd:RecordingTime','Recording must have a uniform sample grid.');
originalCfg=autombd.hsp.config.read(model);
originalDirty=get_param(model,'Dirty');
restore=onCleanup(@()restoreConfiguration(model,originalCfg,originalDirty));
replayCfg=originalCfg;replayCfg.environment.execution.basePeriodSeconds=replayPeriod;
autombd.hsp.config.write(model,replayCfg);autombd.hsp.config.apply(model);
running=source.trace.Mode==uint8(14)&source.trace.GateOutput&source.trace.FaultBits==uint16(0);
if sensorless
    if strcmp(family,'bldc'),running=running&source.trace.FeedbackReady;
    else,running=running&source.trace.ObserverReady;end
end
qualified=find(conv(double(running),ones(1024,1),'valid')==1024,1);
assert(~isempty(qualified),'ambd:OperatingWindow','Recording has no qualified 1024-sample Run window.');
if sensorless
    if strcmp(family,'bldc') && p.CurrentSenseMode==uint8(1)
        entry=find(source.trace.Mode(1:qualified)==uint8(11),1);
        required=uint8([8,11,12,14]);
    else
        entry=find(source.trace.Mode(1:qualified)==uint8(9),1);
        required=uint8([8,9,11,12,14]);
    end
else
    entry=find(source.trace.Mode(1:qualified)==uint8(12),1);
    required=uint8([6,12,14]);
end
assert(~isempty(entry),'ambd:OperatingWindow','Recording lacks the requested transition.');
first=max(1,entry-32);last=qualified+1023;
if strcmp(family,'bldc')
    seen=false(6,1);cycleEnd=[];
    for index=qualified:numel(recording.Time)
        sector=double(source.trace.Sector(index));
        if running(index)&&sector>=1&&sector<=6,seen(sector)=true;end
        if all(seen),cycleEnd=index;break;end
    end
    assert(~isempty(cycleEnd),'ambd:OperatingWindow','Recording has no complete six-sector Run cycle.');
    last=max(last,cycleEnd);
end
rows=first:last;
assert(all(ismember(required,source.trace.Mode(rows))), ...
    'ambd:OperatingWindow','Recorded window does not include the required states.');
result=struct('Passed',false,'PILExecuted',false,'Model',model,'Family',family, ...
    'Scenario',source.scenario.Name,'SourceTrace',traceFile,'Sensorless',sensorless, ...
    'RequiredStates',required,'SourceFirstSample',first,'SourceLastSample',last, ...
    'SourceStartTime',double(recording.Time(first)),'SourceStopTime',double(recording.Time(last)), ...
    'Samples',numel(rows),'NativeSamplePeriod',originalCfg.environment.execution.basePeriodSeconds, ...
    'ReplaySamplePeriod',replayPeriod,'Stage','normal-prehistory');
writeResult(outputDirectory,result);
try
    in=Simulink.SimulationInput(model);
    in=in.setExternalInput(inputDataset(recording,family,1:first,false));
    in=in.setModelParameter('SimulationMode','normal', ...
        'StopTime',num2str(recording.Time(first),17),'SaveOutput','on', ...
        'OutputSaveName','yout','SaveFormat','Dataset','ReturnWorkspaceOutputs','on', ...
        'SaveFinalState','on','FinalStateName','xFinal','SaveOperatingPoint','off');
    in=in.setVariable(parameterName,parameter(p,parameterType));
    in=in.setVariable(stateName,parameter(prototype,stateType));
    warm=sim(in);
    assert(numElements(warm.xFinal)==1,'ambd:RuntimeState','Expected one explicit controller memory.');
    % Fixed-step final DSTATE is the memory presented at the final sample.
    % Replaying that same sample avoids an off-by-one state transfer.
    state=readState(warm.xFinal{1}.Values,prototype);
    in=Simulink.SimulationInput(model);
    in=in.setExternalInput(inputDataset(recording,family,rows,true));
    in=in.setModelParameter('SimulationMode','normal','StopTime',num2str((numel(rows)-1)*replayPeriod,17), ...
        'SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset', ...
        'ReturnWorkspaceOutputs','on','LimitDataPoints','off','Decimation','1');
    in=in.setVariable(parameterName,parameter(p,parameterType));
    in=in.setVariable(stateName,parameter(state,stateType));
    normal=sim(in);normalTrace=readTrace(normal,family);
    recorded=windowTrace(source.trace,rows);
    result.MaximumTimeGridError=max(abs((recorded.Time-recorded.Time(1))-normalTrace.Time));
    assert(result.MaximumTimeGridError<=6.25e-11,'ambd:RecordingTime','Window sample grids differ.');
    recorded.Time=normalTrace.Time;
    if strcmp(family,'bldc')
        result.RecordedNormalAlignment=bldc_compare_outputs(recorded,normalTrace);
        aligned=result.RecordedNormalAlignment.StrictBitwisePassed;
    else
        result.RecordedNormalAlignment=mc_compare_replay(recorded,normalTrace,double(p.PwmPeriod),"RecordedNormalAlignment");
        aligned=result.RecordedNormalAlignment.Passed;
    end
    assert(aligned,'ambd:StateTransfer','Seeded Normal outputs differ from the accepted recording.');
    result.NormalPrepared=true;result.Stage='normal-prepared';
    save(fullfile(outputDirectory,'normal-window.mat'),'warm','normal','in','state','result','-v7.3');
    writeResult(outputDirectory,result);
    if ~execute,return;end
    in=in.setModelParameter('SimulationMode',autombd.hsp.pil.simulationMode('pil'));
    target=[];
    failure=[];log=evalc('try;target=sim(in);catch exception;failure=exception;end');
    writeText(fullfile(outputDirectory,'pil.log'),log);
    if ~isempty(failure),rethrow(failure);end
    result.ExecutionMode=target.SimulationMetadata.ModelInfo.SimulationMode;
    result.PILExecuted=strcmpi(result.ExecutionMode,'processor-in-the-loop (pil)');
    actual=readTrace(target,family);
    if strcmp(family,'bldc')
        result.Comparison=bldc_compare_outputs(normalTrace,actual);
    else
        result.Comparison=mc_compare_replay(normalTrace,actual,double(p.PwmPeriod));
        result.Comparison.Mode="NormalVersusPIL";
    end
    result.ExactOutputs=ambd.compare_outputs(normal.yout,target.yout);
    result.ObservedStates=unique(actual.Mode)';
    result.RunSamples=sum(actual.Mode==uint8(14)&actual.GateOutput&actual.FaultBits==uint16(0));
    result.StatesCovered=all(ismember(required,result.ObservedStates));
    result.FeedbackQualified=true;
    run=actual.Mode==uint8(14);
    if sensorless
        if strcmp(family,'bldc'),result.FeedbackQualified=all(actual.FeedbackReady(run));
        else,result.FeedbackQualified=all(actual.ObserverReady(run));end
    end
    result.CommutationCovered=true;
    if strcmp(family,'bldc')
        result.RunSectors=unique(actual.Sector(run&actual.GateOutput))';
        result.CommutationCovered=all(ismember(uint8(1:6),result.RunSectors));
    end
    cfg=autombd.hsp.config.read(model);
    result.DownloadReceipt=fullfile(cfg.outputDirectory,'pil','download-result.json');
    receipt=jsondecode(fileread(result.DownloadReceipt));
    result.ElfSha256=receipt.elfSha256;
    result.Passed=result.PILExecuted&&result.Comparison.Passed&&result.ExactOutputs.Passed&&result.StatesCovered ...
        &&result.RunSamples>=1024&&result.FeedbackQualified&&result.CommutationCovered ...
        &&strcmp(receipt.status,'command-completed')&&receipt.executionRequested ...
        &&strcmpi(autombd.hsp.pil.sha256File(receipt.elf),receipt.elfSha256);
    result.Stage='complete';
    save(fullfile(outputDirectory,'operational-traces.mat'),'normal','target','in','state','result','-v7.3');
    writeResult(outputDirectory,result);
    assert(result.Passed,'ambd:OperationalPIL','Operating-state PIL validation failed.');
catch exception
    result.Passed=false;result.Stage='failed';result.Error=exception.message;
    if exist('normal','var')&&exist('target','var')&&isa(target,'Simulink.SimulationOutput')
        save(fullfile(outputDirectory,'operational-traces.mat'),'normal','target','in','state','result','-v7.3');
    end
    writeResult(outputDirectory,result);rethrow(exception);
end
end

function value=parameter(data,type)
value=Simulink.Parameter(data);value.DataType=['Bus: ',type];
end

function state=readState(value,prototype)
if isstruct(prototype)
    assert(isequal(fieldnames(value),fieldnames(prototype)),'ambd:RuntimeState','State fields differ.');
    state=struct;
    for field=fieldnames(prototype)'
        name=field{1};state.(name)=readState(value.(name),prototype.(name));
    end
else
    assert(isa(value,'timeseries')&&isscalar(value.Time)&& ...
        numel(value.Data)==numel(prototype)&&strcmp(class(value.Data),class(prototype)), ...
        'ambd:RuntimeState','State type, shape or final-sample count differs.');
    state=reshape(value.Data,size(prototype));
end
end

function dataset=inputDataset(recording,family,rows,relative)
time=double(recording.Time(rows));
if relative
    period=(double(recording.Time(end))-double(recording.Time(1)))/(numel(recording.Time)-1);
    time=(0:numel(rows)-1)'*period;
end
if strcmp(family,'bldc')
    names={'CurrentRaw','Hall','TerminalVoltage','Control','Fault','CommandEvent', ...
        'DrivingEvent','TimerEvent','SpeedReq','Vdc','AppliedSector','AppliedDirection','VoltageValid'};
    values=cellfun(@(name)recording.(name)(rows,:),names,'UniformOutput',false);
else
    names={'Ia','Ib','Ic','McControl','FaultEvent','McCtrlEvent','McDrivingEvent', ...
        'McTimerEvent','McTuningPort','SpeedReq','DcBusVoltage','RotorAngle', ...
        'AppliedVoltageAlpha','AppliedVoltageBeta'};
    event=true(numel(rows),1);
    values={recording.CurrentRaw(rows,1),recording.CurrentRaw(rows,2),recording.CurrentRaw(rows,3), ...
        recording.Control(rows,:),recording.Fault(rows,:),event,event,event,recording.Tuning, ...
        recording.SpeedReq(rows,:),recording.Vdc(rows,:),recording.Position(rows,:), ...
        recording.AppliedVoltage(rows,1),recording.AppliedVoltage(rows,2)};
end
dataset=Simulink.SimulationData.Dataset;
for index=1:numel(names)
    signal=Simulink.SimulationData.Signal;signal.Name=names{index};
    if isstruct(values{index})
        bus=struct;
        for field=fieldnames(values{index})'
            name=field{1};bus.(name)=setinterpmethod(timeseries( ...
                repmat(values{index}.(name),numel(time),1),time),'zoh');
        end
        signal.Values=bus;
    else
        signal.Values=setinterpmethod(timeseries(values{index},time),'zoh');
    end
    dataset=addElement(dataset,signal,names{index});
end
end

function trace=readTrace(out,family)
if strcmp(family,'bldc'),trace=bldc_read_trace(out,"replay");return;end
data=out.yout;assert(numElements(data)==6,'ambd:OutputContract','Expected six PMSM outputs.');
trace.Time=double(data{1}.Values.Time(:));
trace.DutyCounts=[samples(data{1}.Values),samples(data{2}.Values),samples(data{3}.Values)];
trace.GateOutput=logical(samples(data{5}.Values));
monitor=data{6}.Values;debug=data{4}.Values;
for field=fieldnames(monitor)',name=field{1};trace.(name)=samples(monitor.(name));end
for field=fieldnames(debug)',name=field{1};trace.(['Debug_',name])=samples(debug.(name));end
end

function value=samples(signal)
count=numel(signal.Time);value=signal.Data;
if size(value,1)==count
    value=reshape(value,count,[]);
elseif size(value,ndims(value))==count
    value=reshape(permute(value,[ndims(value),1:ndims(value)-1]),count,[]);
else
    error('ambd:OutputShape','Output samples do not match time.');
end
end

function result=windowTrace(trace,rows)
result=struct;
for field=fieldnames(trace)'
    name=field{1};
    if isnumeric(trace.(name))||islogical(trace.(name)),result.(name)=trace.(name)(rows,:);end
end
end

function writeResult(folder,result)
writeText(fullfile(folder,'result.json'),jsonencode(result,PrettyPrint=true));
end

function writeText(path,text)
fid=fopen(path,'w','n','UTF-8');assert(fid>=0,'ambd:ReportWrite','Cannot write %s.',path);
cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s',text);
end

function restoreConfiguration(model,cfg,dirty)
autombd.hsp.config.write(model,cfg);autombd.hsp.config.apply(model);
set_param(model,'Dirty',dirty);
end
