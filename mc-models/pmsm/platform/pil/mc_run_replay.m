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
% File:        mc_run_replay.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Compare recorded-input Normal and real host SIL execution
% =================================================================================

function result = mc_run_replay(traceFile,outputDirectory,buildDirectory)
%mc_run_replay - Compare recorded-input Normal and real host SIL execution
%   RESULT = mc_run_replay(TRACEFILE) reconstructs controller inputs from a
%   saved host Normal trace, checks Normal replay against that recording,
%   then runs the identical Dataset through actual SIL. Discrete outputs
%   stay exact. PWM permits adjacent counts only with a proven shared
%   rounding boundary. Duty uses a 1e-6 absolute bound; other floats use
%   absolute and relative bounds of 1e-4. Strict results remain separate.
%   RESULT = mc_run_replay(TRACEFILE,OUTPUTDIRECTORY) selects an artifact
%   directory below .agent-env; no production model or dictionary is saved.
%   See also mc_run_host_case, ambd_mc
arguments
    traceFile (1,1) string
    outputDirectory (1,1) string = ""
    buildDirectory (1,1) string = ""
end
info=mc_initialize(OutputDirectory=buildDirectory);
artifactRoot=fullfile(info.RepositoryRoot,'.agent-env');
traceFile=string(java.io.File(char(traceFile)).getCanonicalPath());
assert(isfile(traceFile),'mc:MissingReplayTrace','Missing trace: %s',traceFile);
source=load(traceFile,'trace','scenario');
assert(isfield(source,'trace') && isfield(source,'scenario'), ...
    'mc:ReplaySourceContract','Source must contain trace and scenario.');
recorded=source.trace;
scenario=source.scenario;
if outputDirectory==""
    outputDirectory=fullfile(ambd_instance_root(info.RepositoryRoot),'pmsm','replay',scenario.Name);
end
outputDirectory=string(java.io.File(char(outputDirectory)).getCanonicalPath());
assert(startsWith(lower(outputDirectory),lower(artifactRoot+filesep)), ...
    'mc:OutputOutsideArtifactRoot','Replay artifacts must be below .agent-env.');
ambd_claim_directory(info.RepositoryRoot,outputDirectory);
if ~isfolder(outputDirectory),mkdir(outputDirectory);end

modelName='FOC_SIL_Replay';
modelFile=fullfile(artifactRoot,'pmsm-models',modelName+".slx");
assert(isfile(modelFile),'mc:MissingReplayModel', ...
    ['Replay harness is missing. From the repository root, run ', ...
     'python tools/pmsm/create_replay_model.py.']);
open_system(modelFile);
references=find_system(modelName,'SearchDepth',1,'BlockType','ModelReference');
assert(isscalar(references),'mc:ReferenceContract', ...
    'Replay harness must contain one controller Model block.');
reference=references{1};
controllerName=string(get_param(reference,'ModelName'));
assert(controllerName=="FOC_PIL_StateMch_model", ...
    'mc:ReplayReferenceContract','Unexpected replay controller reference.');

inputRecording=reconstructInputs(recorded,scenario);
inputs=recordingDataset(inputRecording);
save(fullfile(outputDirectory,'input-recording.mat'), ...
    'inputRecording','scenario','-v7.3');
result=struct('SourceTrace',traceFile,'Scenario',scenario.Name, ...
    'Model',modelName,'ControllerReference',controllerName, ...
    'ReferenceBlock',string(reference),'TopSimulationMode',"normal", ...
    'Samples',numel(inputRecording.Time),'AbsoluteTolerance',1e-4, ...
    'RelativeTolerance',1e-4,'IntegerOutputsExceptPWMExact',true, ...
    'ContinuousDutyAbsoluteTolerance',1e-6,'PWMMaximumCountDifference',1, ...
    'PWMPolicy',"quantization-aware",'StrictBitwisePassed',false, ...
    'MATLAB',string(version),'Passed',false);

for executionMode=["Normal","SIL"]
    modeDirectory=fullfile(outputDirectory,executionMode);
    if ~isfolder(modeDirectory),mkdir(modeDirectory);end
    if executionMode=="SIL"
        referenceMode='Software-in-the-loop (SIL)';
    else
        referenceMode='Normal';
    end
    in=Simulink.SimulationInput(modelName);
    in=in.setExternalInput(inputs);
    in=in.setModelParameter('StartTime','0', ...
        'StopTime',num2str(inputRecording.Time(end),17), ...
        'SimulationMode','normal','SaveOutput','on', ...
        'OutputSaveName','yout','SaveFormat','Dataset','SaveTime','on', ...
        'TimeSaveName','tout','LimitDataPoints','off','Decimation','1', ...
        'ReturnWorkspaceOutputs','on');
    in=in.setBlockParameter(reference,'SimulationMode',referenceMode);
    in=in.setVariable('McControl_Params', ...
        busParameter(scenario.Control,'tMcControlParams'));
    in=in.setVariable('McRuntime_Init', ...
        busParameter(mc.initial_state(scenario.Control),'tMcRuntime'));
    % Consumed by sim(in) inside the command-window capture below.
    in=in.setVariable('McInput_Default', ...
        busParameter(mc.default_input(scenario.Control),'tMcInput')); %#ok<NASGU>
    simulationError=[];
    logText=evalc('try; out=sim(in); catch caughtError; simulationError=caughtError; end');
    logFile=fullfile(modeDirectory,'simulation.log');
    writeText(logFile,logText);
    modeResult=struct('RequestedMode',executionMode, ...
        'RequestedReferenceMode',string(referenceMode),'LogFile',logFile, ...
        'SILExecutionEvidence',contains(logText,'Starting SIL simulation') ...
        || contains(logText,'SIL simulation for component') ...
        || ~isempty(regexp(logText, ...
        '(启动|开始)[^\n]*SIL|SIL[^\n]*仿真[^\n]*组件','once')));
    result.Execution.(executionMode)=modeResult;
    if ~isempty(simulationError)
        result.ErrorIdentifier=string(simulationError.identifier);
        result.ErrorMessage=string(simulationError.message);
        writeResult(outputDirectory,result);
        rethrow(simulationError);
    end
    trace=readReplayTrace(out);
    save(fullfile(modeDirectory,'trace.mat'),'trace','-v7.3');
    if executionMode=="Normal"
        normalTrace=trace;
        result.RecordedNormalAlignment=mc_compare_replay( ...
            recorded,trace,scenario.Control.PwmPeriod,"RecordedNormalAlignment");
        writeResult(outputDirectory,result);
        assert(result.RecordedNormalAlignment.Passed, ...
            'mc:ReplayAlignmentMismatch', ...
            'Normal replay differs from recorded outputs; inspect result.json.');
    else
        result.NormalVersusSIL=mc_compare_replay( ...
            normalTrace,trace,scenario.Control.PwmPeriod,"NormalVersusSIL");
        result.StrictBitwisePassed=result.NormalVersusSIL.StrictBitwisePassed;
        result.StrictPWMBitwisePassed=result.NormalVersusSIL.StrictPWMBitwisePassed;
        result.PWMPolicyRationale=result.NormalVersusSIL.PWMPolicyRationale;
        result.Passed=result.RecordedNormalAlignment.Passed ...
            && result.NormalVersusSIL.Passed && modeResult.SILExecutionEvidence;
    end
end
writeResult(outputDirectory,result);
assert(result.Execution.SIL.SILExecutionEvidence,'mc:MissingSILEvidence', ...
    'Requested SIL but the transcript contains no SIL execution marker.');
assert(result.Passed,'mc:ReplayMismatch', ...
    'Exact-input Normal/SIL replay comparison failed; inspect result.json.');
fprintf('AMBD_REPLAY %s: PASS, samples=%d, quantization-aware PWM, strictBitwise=%d\n', ...
    scenario.Name,result.Samples,result.StrictBitwisePassed);
end

function recording=reconstructInputs(trace,scenario)
t=double(trace.Time(:));
assert(~isempty(t) && t(1)==0 && all(isfinite(t)) && all(diff(t)>0), ...
    'mc:ReplayTimeContract','Recording time must start at zero and increase.');
sourceTime=double(scenario.Time(:));
dt=1/16000;
indices=round((t-sourceTime(1))/dt)+1;
assert(all(indices>=1 & indices<=numel(sourceTime)), ...
    'mc:ReplayTimeRange','Recording extends beyond the scenario input times.');
assert(all(abs(t-sourceTime(indices))<=dt*1e-6), ...
    'mc:ReplayTimeAlignment','Recording is not on the scenario sample grid.');
current=trace.CurrentTruth;
assert(isa(current,'single') && isequal(size(current),[numel(t),3]), ...
    'mc:ReplayCurrentContract','Recorded plant currents must be single Nx3.');
% plant_measure quantizes these same single currents through double math.
counts=double(scenario.Plant.AdcOffset) ...
    +double(scenario.Plant.AdcCountsPerAmp)*double(current);
recording.Time=t;
recording.CurrentRaw=uint16(min(max(round(counts),0),65535));
recording.Control=uint8(scenario.Command(indices));
recording.Fault=logical(scenario.Fault(indices));
recording.SpeedReq=single(scenario.Speed(indices));
recording.Vdc=single(scenario.Vdc(indices));
recording.Position=single(trace.ThetaTruth);
previousCounts=[repmat(uint16(32768),1,3);trace.DutyCounts(1:end-1,:)];
previousGate=[false;logical(trace.GateOutput(1:end-1))];
recording.AppliedVoltage=zeros(numel(t),2,'single');
for index=1:numel(t)
    recording.AppliedVoltage(index,:)=mc.applied_voltage( ...
        previousCounts(index,:)',recording.Vdc(index),previousGate(index), ...
        scenario.Plant.PwmPeriod)';
end
defaultInput=mc.default_input(scenario.Control);
recording.Tuning=defaultInput.Tuning;
end

function dataset=recordingDataset(recording)
t=recording.Time;
event=true(size(t));
values={recording.CurrentRaw(:,1),recording.CurrentRaw(:,2), ...
    recording.CurrentRaw(:,3),recording.Control,recording.Fault, ...
    event,event,event,[],recording.SpeedReq,recording.Vdc,recording.Position, ...
    recording.AppliedVoltage(:,1),recording.AppliedVoltage(:,2)};
names={'Ia','Ib','Ic','McControl','FaultEvent','McCtrlEvent', ...
    'McDrivingEvent','McTimerEvent','McTuningPort','SpeedReq', ...
    'DcBusVoltage','RotorAngle','AppliedVoltageAlpha','AppliedVoltageBeta'};
dataset=Simulink.SimulationData.Dataset;
for index=1:numel(values)
    signal=Simulink.SimulationData.Signal;
    signal.Name=names{index};
    if index==9
        fields=fieldnames(recording.Tuning);
        bus=struct;
        for field=fields'
            name=field{1};
            bus.(name)=zoh(repmat(recording.Tuning.(name),numel(t),1),t,name);
        end
        signal.Values=bus;
    else
        signal.Values=zoh(values{index},t,names{index});
    end
    dataset=addElement(dataset,signal,names{index});
end
end

function signal=zoh(data,time,name)
signal=timeseries(data,time,'Name',name);
signal=setinterpmethod(signal,'zoh');
end

function trace=readReplayTrace(out)
dataset=out.yout;
assert(dataset.numElements==6,'mc:ReplayOutputContract', ...
    'Replay harness must export six controller outputs.');
trace.Time=double(dataset.getElement(1).Values.Time(:));
trace.DutyCounts=[samples(dataset.getElement(1).Values), ...
    samples(dataset.getElement(2).Values),samples(dataset.getElement(3).Values)];
trace.GateOutput=logical(samples(dataset.getElement(5).Values));
monitor=dataset.getElement(6).Values;
for field=fieldnames(monitor)'
    trace.(field{1})=samples(monitor.(field{1}));
end
debug=dataset.getElement(4).Values;
for field=fieldnames(debug)'
    trace.(['Debug_',field{1}])=samples(debug.(field{1}));
end
end

function data=samples(signal)
count=numel(signal.Time);
data=signal.Data;
if size(data,1)==count
    data=reshape(data,count,[]);
elseif size(data,ndims(data))==count
    data=reshape(permute(data,[ndims(data),1:ndims(data)-1]),count,[]);
else
    error('mc:SignalShape','Logged signal shape does not match time.');
end
end

function value=busParameter(data,bus)
value=Simulink.Parameter;
value.Value=data;
value.DataType=['Bus: ',bus];
end

function writeResult(folder,result)
writeText(fullfile(folder,'result.json'),jsonencode(result,PrettyPrint=true));
end

function writeText(path,text)
file=fopen(path,'w','n','UTF-8');
assert(file>=0,'mc:ReportOpen','Cannot open replay artifact.');
cleanup=onCleanup(@() fclose(file));
fprintf(file,'%s',text);
end
