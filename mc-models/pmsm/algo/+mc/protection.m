function s = protection(u,s,p)
%PROTECTION Latch electrical/input faults and force immediate gate disable.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
active=uint16(0);
current=mc.acquire(u.CurrentRaw,p);
if u.Fault, active=bitor(active,uint16(1)); end
if max(abs(current))>=p.TripCurrent, active=bitor(active,uint16(2)); end
if u.Vdc<p.VdcMin, active=bitor(active,uint16(4)); end
if u.Vdc>p.VdcMax, active=bitor(active,uint16(8)); end
if ~isfinite(u.Vdc) || ~isfinite(u.SpeedReq) || u.Control>uint8(2) ...
        || ~all(isfinite(u.AppliedVoltage)) ...
        || (p.PositionMode==uint8(1) && ~isfinite(u.Position))
    active=bitor(active,uint16(16));
end
if any(u.CurrentRaw==uint16(0) | u.CurrentRaw==intmax('uint16'))
    active=bitor(active,uint16(32));
end
s.ActiveFaults=active;
if s.Command==uint8(0) && u.CommandEvent
    s.FaultBits=active;
else
    s.FaultBits=bitor(s.FaultBits,active);
end
if s.FaultBits~=uint16(0)
    s.GateEnable=false;
end
end
