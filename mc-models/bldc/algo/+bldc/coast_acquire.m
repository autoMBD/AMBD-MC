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
% File:        coast_acquire.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Seed commutation from fresh de-energized terminal samples
% =================================================================================

function s = coast_acquire(u,s,p)
%coast_acquire - Seed commutation from fresh de-energized terminal samples
%   S = coast_acquire(U,S,P) waits for measured current decay, then uses
%   two terminal-voltage snapshots to infer phase and signed speed.
%   Snapshot qualification never increments the real zero-cross count.

%#codegen
if s.AcquisitionReady,return;end
if u.AppliedSector~=uint8(0) || ~u.VoltageValid ...
        || max(abs(s.Current))>=p.FloatCurrentLimit
    s.AcquireStage=uint8(0);return
end
[theta,sector,valid]=bldc.voltage_angle(u.TerminalVoltage,s.Direction,u.Vdc,p.AcquireMinVoltage);
if ~valid,s.AcquireStage=uint8(0);return;end
if s.AcquireStage==uint8(0)
    s.AcquireTheta=theta;s.AcquireAge=uint32(0);s.AcquireStage=uint8(1);return
end
s.AcquireAge=s.AcquireAge+uint32(1);
if s.AcquireAge<uint32(p.AcquireSpacing),return;end
delta=single(mod(double(theta)-double(s.AcquireTheta)+pi,2*pi)-pi);
speed=delta/(single(s.AcquireAge)*p.Ts);
consistent=speed*single(s.Direction)>=p.ZcMinSpeed ...
    && abs(speed)>=single(.5)*s.OmegaOpen && abs(speed)<=single(1.5)*s.OmegaOpen;
if ~consistent
    s.AcquireStage=uint8(0);return
end
s.AcquisitionReady=true;s.SpeedEstimate=speed;s.RawSpeed=speed;s.ControlSpeed=speed;
s.ThetaOpen=theta;s.Sector=sector;s.SpeedRamped=abs(speed);
required=p.Friction*abs(speed)/(single(p.PolePairs)*single(2)*p.Ke);
s.CurrentRef=min(max(required,p.AlignCurrent),p.CurrentLimit);
s.CurrentDemand=s.CurrentRef;
s.SpeedIntegrator=s.CurrentRef;
s.CurrentIntegrator=single(2)*p.Rs*s.CurrentRef+single(2)*p.Ke*abs(speed)/single(p.PolePairs);
s.ZcPeriod=single(pi/3)/(abs(speed)*p.Ts);
s.ZcCount=uint16(0);s.ZcAge=uint32(0);s.FeedbackReady=false;
s.ZcArmed=false;s.ZcFound=false;
boundary=pi/6+(double(sector)-1)*pi/3;
if s.Direction>int8(0)
    distance=mod(boundary+pi/3-double(theta),2*pi);
else
    distance=mod(double(theta)-boundary,2*pi);
end
s.ZcCountdown=int32(max(round(distance/(double(abs(speed))*double(p.Ts))),1));
s.ZcNextSector=uint8(mod(int16(sector)-int16(1)+int16(s.Direction),int16(6))+int16(1));
end
