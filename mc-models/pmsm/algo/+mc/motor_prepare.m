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
% File:        motor_prepare.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-11
% Version:     0.1.0
% Description: Construct deterministic controller memory without side effects.
% =================================================================================

function [v,s] = motor_prepare(u,s,p)
%motor_prepare - Qualify raw samples and issue commands to the FOC core
%   [V,S] = motor_prepare(U,S,P) advances only application-owned state.
%   Calibration requires consecutive stable samples with output disabled.
%   A held reset does not continuously restart a healthy calibration.
%   See also motor_finish, core_step, initial_state

%#codegen
previousCommand=s.Command;
if u.CommandEvent
    s.Command=u.Control;
    if isfinite(u.SpeedReq)
        s.SpeedRequest=min(max(u.SpeedReq,-p.SpeedLimit),p.SpeedLimit);
    end
end
active=uint16(0);
if u.Fault,active=bitor(active,uint16(1));end
if u.Vdc<p.VdcMin,active=bitor(active,uint16(4));end
if u.Vdc>p.VdcMax,active=bitor(active,uint16(8));end
if ~isfinite(u.Vdc) || ~isfinite(u.SpeedReq) || u.Control>uint8(2) ...
        || ~all(isfinite(u.AppliedVoltage)) ...
        || (p.PositionMode==uint8(1) && ~isfinite(u.Position))
    active=bitor(active,uint16(16));
end
if any(u.CurrentRaw==uint16(0) | u.CurrentRaw==intmax('uint16'))
    active=bitor(active,uint16(32));
end
if ~any(s.Mode==uint8([0 1 2 3 4 5]))
    active=bitor(active,uint16(256));
end
s.ActiveFaults=active;
reset=u.CommandEvent && u.Control==uint8(0) ...
    && (previousCommand~=uint8(0) || ~s.PreviousCommandEvent);
s.PreviousCommandEvent=u.CommandEvent;
if reset && active==uint16(0) && s.FaultBits~=uint16(0)
    s.FaultBits=uint16(0);
    s.Mode=uint8(0);
    if ~s.Calibrated
        s.CalibrationCount=uint16(0);s.CalibrationTicks=uint32(0);
        s.CalibrationSum=single([0;0;0]);
        s.CalibrationMin=single([65535;65535;65535]);
        s.CalibrationMax=single([0;0;0]);
    end
end
s.FaultBits=bitor(s.FaultBits,active);
if s.FaultBits~=uint16(0)
    s.Mode=uint8(3);
elseif reset && previousCommand~=uint8(0)
    s.Mode=uint8(0);
elseif u.DrivingEvent
    switch s.Mode
        case 0
            if s.Calibrated,s.Mode=uint8(2);else,s.Mode=uint8(1);end
        case 1
            s=calibrate(u.CurrentRaw,s,p);
        case 2
            if s.Command==uint8(1) && abs(s.SpeedRequest)>single(1)
                s.Mode=uint8(4);
            end
        case 4
            if s.Command==uint8(1) && abs(s.SpeedRequest)>single(1)
                s.Mode=uint8(5);
            else
                s.Mode=uint8(2);
            end
        case 5
            % Core owns align, I/f, tracking, closed loop and stopping.
        case 3
            % Only an explicit safe reset can clear this latch.
    end
end
v=mc.core_default_input(p);
v.Current=(single(u.CurrentRaw)-s.AdcOffsets)/p.AdcCountsPerAmp;
v.Control=uint8(0);
v.Disable=s.Mode~=uint8(5) || ~s.Calibrated || s.FaultBits~=uint16(0);
if ~v.Disable,v.Control=s.Command;end
v.Fault=u.Fault;
% A permission transition is an internal command even without a new user event.
v.CommandEvent=true;
v.DrivingEvent=u.DrivingEvent;v.TimerEvent=u.TimerEvent;
v.SpeedReq=s.SpeedRequest;v.Vdc=u.Vdc;v.Position=u.Position;
v.AppliedVoltage=u.AppliedVoltage;v.Tuning=u.Tuning;
end

function s=calibrate(raw,s,p)
sample=single(raw);
s.CalibrationTicks=min(s.CalibrationTicks+uint32(1),intmax('uint32'));
if s.Core.GateEnable || p.CalibrationSamples==uint16(0) ...
        || any(abs(sample-p.AdcOffset)>p.CalibrationMaxOffset)
    s.FaultBits=bitor(s.FaultBits,uint16(1024));
    s.Mode=uint8(3);return
end
s.CalibrationMin=min(s.CalibrationMin,sample);
s.CalibrationMax=max(s.CalibrationMax,sample);
if any(s.CalibrationMax-s.CalibrationMin>p.CalibrationMaxSpread)
    s.FaultBits=bitor(s.FaultBits,uint16(1024));
    s.Mode=uint8(3);return
end
s.CalibrationSum=s.CalibrationSum+sample;
s.CalibrationCount=s.CalibrationCount+uint16(1);
if s.CalibrationCount>=p.CalibrationSamples
    s.AdcOffsets=s.CalibrationSum/single(s.CalibrationCount);
    s.Calibrated=true;s.Mode=uint8(2);
elseif single(s.CalibrationTicks)*p.Ts>=p.CalibrationTimeout
    s.FaultBits=bitor(s.FaultBits,uint16(1024));s.Mode=uint8(3);
end
end
