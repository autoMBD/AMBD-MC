function s = protection(u,s,~)
%PROTECTION - Latch measured and internal faults before drive outputs
%   S = PROTECTION(U,S,P) clears a latch only on a safe reset command.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
p=s.Parameters;active=uint16(0);
if u.Fault,active=bitor(active,uint16(1));end
if any(abs(s.Current)>=p.TripCurrent),active=bitor(active,uint16(2));end
if u.Vdc<p.VdcMin,active=bitor(active,uint16(4));end
if u.Vdc>p.VdcMax,active=bitor(active,uint16(8));end
if ~isfinite(u.Vdc) || ~isfinite(u.SpeedReq) || any(~isfinite(u.TerminalVoltage)) ...
        || u.Control>uint8(2) || u.AppliedSector>uint8(6) ...
        || abs(u.AppliedDirection)~=int8(1)
    active=bitor(active,uint16(16));
end
if any(u.CurrentRaw==uint16(0) | u.CurrentRaw==uint16(65535))
    active=bitor(active,uint16(32));
end
if s.Mode>uint8(15),active=bitor(active,uint16(256));end
numbers=[s.CurrentIntegrator;s.SpeedIntegrator;s.SpeedEstimate;s.ControlSpeed; ...
    s.RawSpeed;s.ThetaOpen;s.OmegaOpen;s.CurrentRef;s.Modulation;s.ZcPeriod];
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
if s.Command==uint8(0) && active==uint16(0)
    s.FaultBits=uint16(0);
else
    s.FaultBits=bitor(s.FaultBits,active);
end
if s.FaultBits~=uint16(0),s.GateEnable=false;end
end
