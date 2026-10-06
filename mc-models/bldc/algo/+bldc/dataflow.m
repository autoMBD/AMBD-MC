function s = dataflow(u,s,~)
%DATAFLOW - Apply BLDC current regulation and phase commands
%   S = DATAFLOW(U,S,P) advances fast control only on the driving tick.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
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
