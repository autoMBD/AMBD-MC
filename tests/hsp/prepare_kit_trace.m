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
% File:        prepare_kit_trace.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-07
% Version:     0.1.0
% Description: Bind full Simulink replay traces to kit electrical-reference samples.
% =================================================================================

function result = prepare_kit_trace(model,family,referenceFile,outputDirectory)
%prepare_kit_trace - Verify full model replay against kit electrical reference
%   RESULT = prepare_kit_trace(MODEL,FAMILY,REFERENCEFILE,OUTPUTDIRECTORY)
%   preserves all typed root inputs and verifies mode, fault, duty and gate
%   samples against the reference before publishing a trace for PIL replay.
reference=load(referenceFile,'p','plantp','hardware','inputs','expected','truth');
p=reference.p;n=size(reference.inputs,1);period=reference.hardware.samplePeriod;time=(0:n-1)'*period;
if ~isfolder(outputDirectory),mkdir(outputDirectory);end
if strcmp(family,'bldc')
    names={'CurrentRaw','Hall','TerminalVoltage','Control','Fault','CommandEvent', ...
        'DrivingEvent','TimerEvent','SpeedReq','Vdc','AppliedSector','AppliedDirection','VoltageValid'};
    columns={1:3,4,5:7,8,9,10,11,12,13,14,15,16,17};
    prototype=bldc.default_input(p);inputRecording=struct;
    for k=1:numel(names),name=names{k};inputRecording.(name)=cast(reference.inputs(:,columns{k}),'like',prototype.(name));end
    values=cellfun(@(name)inputRecording.(name),names,'UniformOutput',false);
    prefix='Bldc';parameterType='tBldcParams';stateType='tBldcRuntime';state=bldc.initial_state(p);
else
    prototype=mc.default_input(p);inputRecording=struct;
    inputRecording.CurrentRaw=uint16(reference.inputs(:,1:3));
    inputRecording.Control=uint8(reference.inputs(:,4));inputRecording.Fault=logical(reference.inputs(:,5));
    inputRecording.SpeedReq=single(reference.inputs(:,6));inputRecording.Vdc=single(reference.inputs(:,7));
    inputRecording.Position=single(reference.inputs(:,8));inputRecording.AppliedVoltage=single(reference.inputs(:,9:10));
    inputRecording.Tuning=prototype.Tuning;
    names={'Ia','Ib','Ic','McControl','FaultEvent','McCtrlEvent','McDrivingEvent', ...
        'McTimerEvent','McTuningPort','SpeedReq','DcBusVoltage','RotorAngle','AppliedVoltageAlpha','AppliedVoltageBeta'};
    event=true(n,1);
    values={inputRecording.CurrentRaw(:,1),inputRecording.CurrentRaw(:,2),inputRecording.CurrentRaw(:,3), ...
        inputRecording.Control,inputRecording.Fault,event,event,event,inputRecording.Tuning, ...
        inputRecording.SpeedReq,inputRecording.Vdc,inputRecording.Position,inputRecording.AppliedVoltage(:,1),inputRecording.AppliedVoltage(:,2)};
    prefix='Mc';parameterType='tMcControlParams';stateType='tMcRuntime';state=mc.initial_state(p);
end
inputRecording.Time=time;dataset=Simulink.SimulationData.Dataset;
for k=1:numel(names)
    signal=Simulink.SimulationData.Signal;signal.Name=names{k};
    if isstruct(values{k})
        bus=struct;
        for field=fieldnames(values{k})',key=field{1};bus.(key)=setinterpmethod(timeseries(repmat(values{k}.(key),n,1),time),'zoh');end
        signal.Values=bus;
    else
        signal.Values=setinterpmethod(timeseries(values{k},time),'zoh');
    end
    dataset=addElement(dataset,signal,names{k});
end
in=Simulink.SimulationInput(model);in=in.setExternalInput(dataset);
in=in.setModelParameter('FixedStep',num2str(period,17),'SimulationMode','normal','StopTime',num2str(time(end),17), ...
    'SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset','ReturnWorkspaceOutputs','on', ...
    'LimitDataPoints','off','Decimation','1');
in=in.setVariable([prefix,'Control_Params'],parameter(p,parameterType));
in=in.setVariable([prefix,'Runtime_Init'],parameter(state,stateType));
out=sim(in);
if strcmp(family,'bldc')
    trace=bldc_read_trace(out,'replay');trace.Input=inputRecording;
else
    trace.Time=double(out.yout{1}.Values.Time(:));
    trace.DutyCounts=[samples(out.yout{1}.Values),samples(out.yout{2}.Values),samples(out.yout{3}.Values)];
    trace.GateOutput=logical(samples(out.yout{5}.Values));monitor=out.yout{6}.Values;debug=out.yout{4}.Values;
    for field=fieldnames(monitor)',name=field{1};trace.(name)=samples(monitor.(name));end
    for field=fieldnames(debug)',name=field{1};trace.(['Debug_',name])=samples(debug.(name));end
end
result=struct('Passed',false,'Family',family,'Model',model,'Samples',n);
assert(numel(trace.Time)==n,'ambd:RecordingTime','Model output sample count differs from the input grid.');
result.MaximumInputTimeGridError=max(abs(trace.Time-time));
assert(all(isfinite(trace.Time))&&result.MaximumInputTimeGridError<=6.25e-11, ...
    'ambd:RecordingTime','Model output and input sample grids differ.');
% Store one canonical clock for both artifacts after checking every sample.
inputRecording.Time=trace.Time;
if strcmp(family,'bldc'),trace.Input=inputRecording;end
result.ModeExact=isequal(double(trace.Mode),reference.expected(:,1));
result.FaultExact=isequal(double(trace.FaultBits),reference.expected(:,2));
result.DutyExact=isequal(double(trace.DutyCounts),reference.expected(:,3:5));
result.GateExact=isequal(double(trace.GateOutput),reference.expected(:,6));
actual=[double(trace.Mode),double(trace.FaultBits),double(trace.DutyCounts),double(trace.GateOutput)];
if strcmp(family,'bldc')
    actual=[actual,double(trace.SpeedEstimate),double(trace.ZcCount),double(trace.Sector), ...
        double(trace.CurrentReference),double(trace.CurrentMeasured),double(trace.PhaseMask)];
    result.ReferenceColumns={'Mode','FaultBits','DutyA','DutyB','DutyC','Gate', ...
        'SpeedEstimate','ZcCount','Sector','CurrentReference','CurrentMeasured','PhaseA','PhaseB','PhaseC'};
else
    actual=[actual,double(trace.Omega),double(trace.ObserverReady),double(trace.Theta)];
    result.ReferenceColumns={'Mode','FaultBits','DutyA','DutyB','DutyC','Gate','Omega','ObserverReady','Theta'};
end
result.ReferenceOutputsExact=isequal(actual,reference.expected);
result.RunSamples=sum(trace.Mode==uint8(14)&trace.GateOutput&trace.FaultBits==0);
result.NoFault=all(trace.FaultBits==0);result.FinalSpeed=mean(reference.truth(end-1000:end,1));
result.FinalRequest=reference.truth(end,2);result.MaximumPhaseCurrent=max(reference.truth(:,3));
result.Passed=result.ModeExact&&result.FaultExact&&result.DutyExact&&result.GateExact&&result.ReferenceOutputsExact ...
    &&result.NoFault&&result.RunSamples>=1024&&abs(result.FinalSpeed-result.FinalRequest)<5;
scenario=struct('Name',string(family)+"_kit_"+string(p.PositionMode)+"_"+string(sign(result.FinalRequest)), ...
    'Control',p,'Plant',reference.plantp);
result.Scenario=scenario.Name;
save(fullfile(outputDirectory,'trace.mat'),'trace','scenario','result','-v7.3');
save(fullfile(outputDirectory,'input-recording.mat'),'inputRecording','scenario','-v7.3');
file=fopen(fullfile(outputDirectory,'result.json'),'w','n','UTF-8');
assert(file>=0,'ambd:ReportWrite','Cannot write kit result.');cleanup=onCleanup(@()fclose(file));
fprintf(file,'%s',jsonencode(result,PrettyPrint=true));
assert(result.Passed,'ambd:KitReference','Kit reference or full model replay did not pass.');
end
function value=parameter(data,type)
value=Simulink.Parameter(data);value.DataType=['Bus: ',type];
end
function value=samples(signal)
n=numel(signal.Time);value=signal.Data;
if size(value,1)==n,value=reshape(value,n,[]);
else,value=reshape(permute(value,[ndims(value),1:ndims(value)-1]),n,[]);end
end
