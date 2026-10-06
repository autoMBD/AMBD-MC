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
% File:        supervisor.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Advance the fault-first BLDC lifecycle
% =================================================================================

function s = supervisor(u,s,~)
%SUPERVISOR - Advance the fault-first BLDC lifecycle
%   S = SUPERVISOR(U,S,P) preserves direction until a verified stop.

%#codegen
p=s.Parameters;
if s.FaultBits~=uint16(0)
    s.Mode=uint8(3);
elseif s.Command==uint8(0)
    s.Mode=uint8(0);
elseif s.FastTick
    elapsed=single(s.ModeTicks)*p.Ts;
    stopping=s.Command~=uint8(1) || abs(s.SpeedRequest)<=single(1);
    reversed=s.SpeedRequest*single(s.Direction)<single(-1);
    if (stopping || reversed) && s.Mode>=uint8(4) && s.Mode<=uint8(14)
        if s.Mode<=uint8(5),s.Mode=uint8(2);else,s.Mode=uint8(15);end
        s.ModeTicks=uint32(0);s.CoastTicks=uint32(0);
        return
    end
    switch s.Mode
        case 0
            s.Mode=uint8(1);
        case 1
            s.Mode=uint8(2);
        case 2
            if ~stopping
                s.Mode=uint8(4);s.Direction=int8(1);
                if s.SpeedRequest<single(0),s.Direction=int8(-1);end
                s.HallAge=uint32(0);s.HallValid=false;s.FeedbackReady=false;
                s.ZcAge=uint32(0);s.ZcCount=uint16(0);s.ZcPeriod=single(0);
                s.ZcCountdown=int32(-1);s.AppliedLastSector=uint8(0);
                s.AcquireStage=uint8(0);s.AcquisitionReady=false;
                s.ThetaOpen=single(5*pi/6);s.OmegaOpen=single(0);
                s.SpeedRamped=single(0);s.CoastTicks=uint32(0);
            end
        case 3
            % Only an explicit safe reset exits a latched fault.
        case 4
            s.Mode=uint8(5);
        case 5
            s.Mode=uint8(6);
        case 6
            if elapsed>=p.AlignTime
                if p.PositionMode==uint8(0),s.Mode=uint8(12);else,s.Mode=uint8(7);end
            end
        case 7
            s.Mode=uint8(8);
        case 8
            if abs(s.SpeedRequest)>=p.LowSpeedThreshold ...
                    && s.OmegaOpen>=single(.99)*min(abs(s.SpeedRequest),p.OpenSpeed)
                s.Mode=uint8(9);
                s.AcquireStage=uint8(0);s.AcquisitionReady=false;
            elseif elapsed>p.StartTimeout && abs(s.SpeedRequest)>=p.LowSpeedThreshold
                s.FaultBits=bitor(s.FaultBits,uint16(64));s.Mode=uint8(3);
            end
        case 9
            if s.AcquisitionReady
                s.Mode=uint8(11);
            elseif elapsed>p.AcquireTimeout
                s.FaultBits=bitor(s.FaultBits,uint16(64));s.Mode=uint8(3);
            end
        case 10
            s.Mode=uint8(8);
        case 11
            if s.FeedbackReady && elapsed>=p.TrackingTime
                s.Mode=uint8(12);
            elseif elapsed>p.TrackingTimeout
                s.FaultBits=bitor(s.FaultBits,uint16(64));s.Mode=uint8(3);
            end
        case 12
            s.Mode=uint8(14);
        case 13
            s.Mode=uint8(10);
        case 14
            if p.PositionMode==uint8(1) && abs(s.SpeedRequest)<p.LowSpeedThreshold
                s.Mode=uint8(13);
                s.AcquisitionReady=false;
                s.ThetaOpen=single((double(s.Sector)-1)*pi/3+pi/3);
                s.OmegaOpen=abs(s.SpeedEstimate);
            end
        case 15
            if s.CoastTicks>uint32(0) && ...
                    single(s.CoastTicks)*p.Ts>=p.StopCoastTime
                s.Mode=uint8(2);
            elseif elapsed>p.StopTimeout
                s.FaultBits=bitor(s.FaultBits,uint16(128));s.Mode=uint8(3);
            end
        otherwise
            s.FaultBits=bitor(s.FaultBits,uint16(256));s.Mode=uint8(3);
    end
end
if s.Mode~=s.PreviousMode,s.ModeTicks=uint32(0);end
if s.Mode<=uint8(5) || s.FaultBits~=uint16(0),s.GateEnable=false;end
if ~u.DrivingEvent && s.Mode==uint8(0),s.GateEnable=false;end
end
