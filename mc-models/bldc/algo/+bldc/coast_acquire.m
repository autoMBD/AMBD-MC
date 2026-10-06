function s = coast_acquire(u,s,p)
%coast_acquire - Seed commutation from fresh de-energized terminal samples
%   S = coast_acquire(U,S,P) waits for measured current decay, then uses
%   two terminal-voltage snapshots to infer phase and signed speed.
%   Snapshot qualification never increments the real zero-cross count.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
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
