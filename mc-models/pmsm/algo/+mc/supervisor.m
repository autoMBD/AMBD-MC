function s = supervisor(u,s,p)
%SUPERVISOR Advance the McStruct lifecycle with fault-first priority.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
if s.FaultBits~=uint16(0)
    s.Mode=uint8(3);
elseif s.Command==uint8(0)
    s.Mode=uint8(0);
elseif s.FastTick
    elapsed=single(s.ModeTicks)*p.Ts;
    running=s.Command==uint8(1);
    stopping=~running || abs(s.SpeedRequest)<=single(1);
    reversed=s.SpeedRequest*s.Direction<single(-1);
    % Stop/reversal preempts every bridge state, before any energization.
    if (stopping || reversed) && s.Mode>=uint8(4) && s.Mode<=uint8(14)
        if s.Mode<=uint8(5)
            s.Mode=uint8(2);
        else
            s.Mode=uint8(15);
        end
        s.ModeTicks=uint32(0);
        if s.Mode==uint8(2), s.GateEnable=false; end
        return
    end
    switch s.Mode
        case 0
            s.Mode=uint8(1);
        case 1
            s.Mode=uint8(2);
        case 2
            if running && ~stopping, s.Mode=uint8(4); end
        case 3
            % A latched fault can leave only via the safe reset branch above.
        case 4
            s.Mode=uint8(5);
        case 5
            s.Mode=uint8(6);
        case 6
            if stopping || reversed
                s.Mode=uint8(15);
            elseif elapsed>=s.Startup(2)
                if p.PositionMode==uint8(1), s.Mode=uint8(12);
                else, s.Mode=uint8(7); end
            end
        case 7
            s.Mode=uint8(8);
        case 8
            if stopping || reversed
                s.Mode=uint8(15);
            elseif s.ObserverReady && abs(s.SpeedRequest)>=single(1.25)*p.ObserverMinSpeed ...
                    && abs(s.OmegaOpen)>=single(0.95)*min(abs(s.SpeedRequest),p.OpenLoopSpeed)
                s.Mode=uint8(9);
            elseif elapsed>p.StartTimeout && abs(s.SpeedRequest)>=single(1.25)*p.ObserverMinSpeed
                s.FaultBits=bitor(s.FaultBits,uint16(64));s.Mode=uint8(3);
            end
        case 9
            s.Mode=uint8(11);
        case 10
            s.Mode=uint8(8);
        case 11
            if stopping || reversed
                s.Mode=uint8(15);
            elseif ~s.ObserverReady
                s.Mode=uint8(10);
            elseif elapsed>=p.TrackingTime
                s.Mode=uint8(12);
            end
        case 12
            s.Mode=uint8(14);
        case 13
            s.Mode=uint8(10);
        case 14
            if stopping || reversed
                s.Mode=uint8(15);
            elseif p.PositionMode==uint8(0) && (~s.ObserverReady ...
                    || abs(s.SpeedRequest)<single(1.25)*p.ObserverMinSpeed)
                s.Mode=uint8(13);
            end
        case 15
            if abs(s.OmegaControl)<p.StopSpeed
                s.Mode=uint8(2);
            elseif elapsed>p.StopTimeout
                s.FaultBits=bitor(s.FaultBits,uint16(128));s.Mode=uint8(3);
            end
        otherwise
            s.FaultBits=bitor(s.FaultBits,uint16(256));s.Mode=uint8(3);
    end
end
if s.Mode~=s.PreviousMode, s.ModeTicks=uint32(0); end
if s.Mode<=uint8(5) || s.FaultBits~=uint16(0)
    s.GateEnable=false;
end
% u is deliberately part of the stable module interface.
if ~u.DrivingEvent && s.Mode==uint8(0), s.GateEnable=false; end
end
