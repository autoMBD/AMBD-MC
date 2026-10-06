function s = supervisor(u,s,~)
%SUPERVISOR - Advance the fault-first BLDC lifecycle
%   S = SUPERVISOR(U,S,P) preserves direction until a verified stop.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
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
