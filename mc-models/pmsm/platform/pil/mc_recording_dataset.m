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
% File:        mc_recording_dataset.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Extract full-rate host-harness outputs by contract.
% =================================================================================

function dataset = mc_recording_dataset(recording)
%mc_recording_dataset - Replay actual typed controller inputs
%   DATASET = mc_recording_dataset(RECORDING) preserves sample events,
%   voltage feedback and time-varying tuning. Current is in amperes for
%   the core; CurrentRaw contains ADC counts for the motor controller.
%   See also mc_read_host_trace, mc_run_replay

required={'Time','Control','Fault','CommandEvent','DrivingEvent','TimerEvent', ...
    'SpeedReq','Vdc','Position','AppliedVoltage','Tuning'};
assert(all(isfield(recording,required)),'mc:RecordingContract', ...
    'Recording must contain the actual controller fields, including events.');
t=double(recording.Time(:));count=numel(t);
assert(count>0 && all(isfinite(t)) && all(diff(t)>0), ...
    'mc:RecordingContract','Recording time must be finite and increasing.');
core=isfield(recording,'Current');
if core
    assert(isfield(recording,'Disable') && ~isfield(recording,'CurrentRaw'), ...
        'mc:RecordingContract','A core recording requires Current and Disable.');
    current=recording.Current;
    assert(isa(current,'single'),'mc:RecordingContract','Core current must be single amperes.');
else
    assert(isfield(recording,'CurrentRaw'),'mc:RecordingContract','Missing current samples.');
    current=recording.CurrentRaw;
    assert(isa(current,'uint16'),'mc:RecordingContract','Raw current must be uint16 counts.');
end
assert(isequal(size(current),[count,3]),'mc:RecordingContract', ...
    'Current recording must contain three channels at every sample.');
assert(isequal(size(recording.AppliedVoltage),[count,2]),'mc:RecordingContract', ...
    'Voltage feedback must contain two channels at every sample.');
values={current(:,1),current(:,2),current(:,3),recording.Control,recording.Fault, ...
    recording.CommandEvent,recording.DrivingEvent,recording.TimerEvent,recording.Tuning, ...
    recording.SpeedReq,recording.Vdc,recording.Position, ...
    recording.AppliedVoltage(:,1),recording.AppliedVoltage(:,2)};
names={'Ia','Ib','Ic','McControl','FaultEvent','McCtrlEvent','McDrivingEvent', ...
    'McTimerEvent','McTuningPort','SpeedReq','DcBusVoltage','RotorAngle', ...
    'AppliedVoltageAlpha','AppliedVoltageBeta'};
if core,values{end+1}=recording.Disable;names{end+1}='Disable';end
dataset=Simulink.SimulationData.Dataset;
for index=1:numel(values)
    signal=Simulink.SimulationData.Signal;signal.Name=names{index};
    signal.Values=recordedSignal(values{index},t,names{index});
    dataset=addElement(dataset,signal,names{index});
end
end

function signal=recordedSignal(data,time,name)
if isstruct(data)
    signal=struct;
    for field=fieldnames(data)'
        key=field{1};signal.(key)=recordedSignal(data.(key),time,key);
    end
else
    assert(size(data,1)==numel(time),'mc:RecordingContract', ...
        'Every recorded field must have one row per sample; missing rows cannot be invented.');
    signal=setinterpmethod(timeseries(data,time,'Name',name),'zoh');
end
end
