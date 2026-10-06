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
% File:        dataflow.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: BLDC current regulation and phase commands
% =================================================================================

function s = dataflow(u,s,~)
%DATAFLOW - Apply BLDC current regulation and phase commands
%   S = DATAFLOW(U,S,P) advances fast control only on the driving tick.

%#codegen
p=s.Parameters;
if s.Mode<=uint8(5) || s.FaultBits~=uint16(0)
    s=disabled(s);
    if s.Mode==uint8(0)
        s=bldc.initial_state(p);
    end
    return
end
if ~s.FastTick,return;end
if s.Mode==uint8(9)
    s=disabled(s);return
end
if s.Mode==uint8(15) && (s.PreviousMode==uint8(9) || s.CoastTicks>uint32(0))
    s.CoastTicks=s.CoastTicks+uint32(1);s=disabled(s);return
end
s.GateEnable=true;s.OutputDirection=s.Direction;
aligning=s.Mode==uint8(6);
forced=s.Mode==uint8(7) || s.Mode==uint8(8) || s.Mode==uint8(10);
stopping=s.Mode==uint8(15);
if aligning
    s.Sector=uint8(1);s.OutputDirection=int8(1);
    targetCurrent=p.AlignCurrent;s.SpeedIntegrator=single(0);
elseif forced
    target=min(abs(s.SpeedRequest),p.OpenSpeed);
    s.OmegaOpen=s.OmegaOpen+min(max(target-s.OmegaOpen,-p.OpenAccel*p.Ts),p.OpenAccel*p.Ts);
    s.ThetaOpen=single(mod(double(s.ThetaOpen)+double(s.Direction)*double(s.OmegaOpen)*double(p.Ts),2*pi));
    s.Sector=bldc.sector(s.ThetaOpen);targetCurrent=p.OpenCurrent;
else
    if p.PositionMode==uint8(0)
        s.Sector=s.HallSector;
    elseif s.ZcCountdown==int32(0) && s.ZcNextSector~=uint8(0)
        s.Sector=s.ZcNextSector;s.ZcCountdown=int32(-1);
    end
    if s.Mode~=s.PreviousMode && ...
            (s.Mode==uint8(12) && s.PreviousMode==uint8(6))
        s.SpeedRamped=abs(s.SpeedEstimate);
        s.SpeedIntegrator=s.CurrentRef;
    end
    if s.SpeedTick
        desired=abs(s.SpeedRequest);if stopping,desired=single(0);end
        dt=p.Ts*single(p.SpeedDivider);
        s.SpeedRamped=s.SpeedRamped+min(max(desired-s.SpeedRamped,-p.SpeedSlew*dt),p.SpeedSlew*dt);
        error=s.SpeedRamped-single(s.Direction)*s.SpeedEstimate;
        [kp,ki]=bldc.speed_gains(s.SpeedRequest,p);
        [targetCurrent,s.SpeedIntegrator]=bldc.pi_step(error,s.SpeedIntegrator, ...
            kp,ki,dt,single(0),p.CurrentLimit);
    else
        targetCurrent=s.CurrentDemand;
    end
    if stopping,targetCurrent=single(0);end
end
targetCurrent=min(max(targetCurrent,single(0)),p.CurrentLimit);
s.CurrentDemand=targetCurrent;
s.CurrentRef=s.CurrentRef+min(max(targetCurrent-s.CurrentRef,-p.CurrentSlew*p.Ts),p.CurrentSlew*p.Ts);
if stopping && (s.CoastTicks>uint32(0) || ...
        (s.CurrentRef<=single(.001) && max(abs(s.Current))<single(.2)))
    s.CoastTicks=s.CoastTicks+uint32(1);s=disabled(s);return
end
if s.Sector<uint8(1) || s.Sector>uint8(6)
    s.FaultBits=bitor(s.FaultBits,uint16(1024));s.Mode=uint8(3);s=disabled(s);return
end
pairs=uint8([1,2;1,3;2,3;2,1;3,1;3,2]);
source=pairs(s.Sector,1);
if s.OutputDirection<int8(0),source=pairs(s.Sector,2);end
s.CurrentMeasured=s.Current(source);
[voltage,s.CurrentIntegrator]=bldc.pi_step(s.CurrentRef-s.CurrentMeasured, ...
    s.CurrentIntegrator,p.KpCurrent,p.KiCurrent,p.Ts,single(0),u.Vdc*p.MaxModulation);
s.Modulation=voltage/u.Vdc;
[s.DutyCounts,s.PhaseEnable]=bldc.commutate(s.Sector,s.OutputDirection,s.Modulation,p.PwmPeriod);
end

function s = disabled(s)
s.GateEnable=false;s.PhaseEnable=false(3,1);s.DutyCounts=zeros(3,1,'uint16');
s.Modulation=single(0);s.CurrentRef=single(0);s.CurrentDemand=single(0);
s.CurrentIntegrator=single(0);s.SpeedIntegrator=single(0);
end
