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
% File:        protection.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Latch measured and internal faults before drive outputs
% =================================================================================

function s = protection(u,s,~)
%PROTECTION - Latch measured and internal faults before drive outputs
%   S = PROTECTION(U,S,P) clears a latch only on a safe reset command.

%#codegen
p=s.Parameters;active=uint16(0);
if u.Fault,active=bitor(active,uint16(1));end
if any(abs(s.Current)>=p.TripCurrent),active=bitor(active,uint16(2));end
if p.CurrentSenseMode==uint8(1) && s.DcCurrentValid && abs(s.DcCurrent)>=p.TripCurrent
    active=bitor(active,uint16(2));
end
if u.Vdc<p.VdcMin,active=bitor(active,uint16(4));end
if u.Vdc>p.VdcMax,active=bitor(active,uint16(8));end
if ~isfinite(u.Vdc) || ~isfinite(u.SpeedReq) || any(~isfinite(u.TerminalVoltage)) ...
        || u.Control>uint8(2) || u.AppliedSector>uint8(6) ...
        || abs(u.AppliedDirection)~=int8(1) || p.CurrentSenseMode>uint8(1)
    active=bitor(active,uint16(16));
end
raw=u.CurrentRaw;
if p.CurrentSenseMode==uint8(1),raw(2:3)=uint16(32768);end
if any(raw==uint16(0) | raw==uint16(65535))
    active=bitor(active,uint16(32));
end
if s.Mode>uint8(15),active=bitor(active,uint16(256));end
numbers=[s.CurrentIntegrator;s.SpeedIntegrator;s.SpeedEstimate;s.ControlSpeed; ...
    s.RawSpeed;s.ThetaOpen;s.OmegaOpen;s.CurrentRef;s.Modulation;s.ZcPeriod;s.DcCurrent];
if any(~isfinite(numbers))
    active=bitor(active,uint16(512));
    s.CurrentIntegrator=single(0);s.SpeedIntegrator=single(0);
    s.SpeedEstimate=single(0);s.ControlSpeed=single(0);s.RawSpeed=single(0);
    s.ThetaOpen=single(5*pi/6);s.OmegaOpen=single(0);s.CurrentRef=single(0);
    s.Modulation=single(0);s.ZcPeriod=single(0);
end
if s.Command~=uint8(0)
    active=bitor(active,s.SensorFault);
end
if p.PositionMode==uint8(0) && bldc.hall_decode(u.Hall)==uint8(0)
    active=bitor(active,uint16(1024));
end
s.ActiveFaults=active;
resetReady=p.CurrentSenseMode==uint8(0) || s.FaultBits==uint16(0) ...
    || (~s.GateEnable && u.AppliedSector==uint8(0) && single(s.CoastTicks)*p.Ts>=p.StopCoastTime);
if s.Command==uint8(0) && active==uint16(0) && resetReady
    s.FaultBits=uint16(0);
else
    s.FaultBits=bitor(s.FaultBits,active);
end
if s.FaultBits~=uint16(0),s.GateEnable=false;end
end
