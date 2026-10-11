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
% File:        pil_fixture.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-07
% Version:     0.1.0
% Description: Create deterministic startup, fault and reset input replays for PIL.
% =================================================================================

function [in,faultSamples] = pil_fixture(model,family)
%pil_fixture - Create a bounded target input replay
%   [IN,FAULTSAMPLES] = pil_fixture(MODEL,FAMILY) creates 129 samples at
%   the staged target period, exercising reset, startup, injected fault, reset and restart.
%   Current and position inputs vary deterministically. The saved model
%   and calibration dictionary are not changed.
%
%   See also Simulink.SimulationInput, ambd.compare_outputs

cfg=autombd.hsp.config.read(model);period=cfg.environment.execution.basePeriodSeconds;
time=(0:128)'*period;
if strcmp(family,'bldc')
    p=bldc.defaults;p.Ts=single(period);
    p.SpeedDivider=uint16(round(.001/period));
    if contains(model,'Sensorless'),p.PositionMode=uint8(1);end
    u=bldc.default_input(p);
    names={'CurrentRaw','Hall','TerminalVoltage','Control','Fault','CommandEvent', ...
        'DrivingEvent','TimerEvent','SpeedReq','Vdc','AppliedSector','AppliedDirection','VoltageValid'};
    values=cellfun(@(name)u.(name),names,'UniformOutput',false);
    controlName='Control';faultName='Fault';
    parameterName='BldcControl_Params';parameterType='tBldcParams';
    stateName='BldcRuntime_Init';stateType='tBldcRuntime';state=bldc.initial_state(p);
else
    p=mc.defaults;p.Ts=single(period);
    p.SpeedDivider=uint16(round(.001/period));
    if contains(model,'Algth'),p.PositionMode=uint8(1);end
    p.CalibrationSamples=uint16(8);
    u=mc.default_input(p);
    names={'Ia','Ib','Ic','McControl','FaultEvent','McCtrlEvent','McDrivingEvent', ...
        'McTimerEvent','McTuningPort','SpeedReq','DcBusVoltage','RotorAngle', ...
        'AppliedVoltageAlpha','AppliedVoltageBeta'};
    values={u.CurrentRaw(1),u.CurrentRaw(2),u.CurrentRaw(3),u.Control,u.Fault, ...
        u.CommandEvent,u.DrivingEvent,u.TimerEvent,u.Tuning,u.SpeedReq,u.Vdc, ...
        u.Position,u.AppliedVoltage(1),u.AppliedVoltage(2)};
    controlName='McControl';faultName='FaultEvent';
    parameterName='McControl_Params';parameterType='tMcControlParams';
    stateName='McRuntime_Init';stateType='tMcRuntime';state=mc.initial_state(p);
    if contains(model,'Algth')
        current=mc.core_default_input(p);
        values(1:3)={current.Current(1),current.Current(2),current.Current(3)};
        values{end+1}=false;names{end+1}='Disable';
        stateName='McCoreRuntime_Init';stateType='tMcCoreRuntime';state=mc.core_initial_state(p);
    end
end
inputs=Simulink.SimulationData.Dataset;
for index=1:numel(names)
    name=names{index};
    if isstruct(values{index})
        signal=busSignal(values{index},time);
    else
        data=repmat(values{index}(:)',numel(time),1);
        if strcmp(name,controlName)
            data(9:64)=uint8(1);data(97:end)=uint8(1);
        elseif strcmp(name,faultName)
            data(65:80)=true;
        elseif strcmp(name,'SpeedReq')
            data(:)=single(80);
        elseif strcmp(name,'CurrentRaw')
            data=uint16(32768+round(250*sin(2*pi*80*time+[0,-2*pi/3,2*pi/3])));
        elseif ismember(name,{'Ia','Ib','Ic'})
            phase=find(strcmp(name,{'Ia','Ib','Ic'}))-1;
            wave=sin(2*pi*80*time-phase*2*pi/3);
            if contains(model,'Algth')
                data=single(.25*wave);
            else
                data=uint16(32768+round(250*wave));
                data(1:16)=uint16(32768); % Stable pre-run calibration frame.
            end
        elseif strcmp(name,'RotorAngle')
            data=single(80*time);
        end
        signal=setinterpmethod(timeseries(data,time,'Name',name),'zoh');
    end
    inputs=addElement(inputs,signal,name);
end
in=Simulink.SimulationInput(model);
in=in.setExternalInput(inputs);
in=in.setModelParameter('StopTime',num2str(time(end),17),'SaveOutput','on', ...
    'OutputSaveName','yout','SaveFormat','Dataset','ReturnWorkspaceOutputs','on', ...
    'SaveTime','on','TimeSaveName','tout','LimitDataPoints','off','Decimation','1');
in=in.setVariable(parameterName,parameter(p,parameterType));
in=in.setVariable(stateName,parameter(state,stateType));
faultSamples=65:80;
end

function value=parameter(data,type)
value=Simulink.Parameter(data);value.DataType=['Bus: ',type];
end

function result=busSignal(value,time)
result=struct;
fields=fieldnames(value);
for index=1:numel(fields)
    name=fields{index};data=value.(name);
    if isstruct(data),result.(name)=busSignal(data,time);
    else,result.(name)=setinterpmethod(timeseries(repmat(data(:)',numel(time),1),time),'zoh');end
end
end
