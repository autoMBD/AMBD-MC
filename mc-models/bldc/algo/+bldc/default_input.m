function u = default_input(p)
%default_input - Return a typed disabled BLDC input sample
%   U = default_input(P) creates a safe sample using calibrations P.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
u.CurrentRaw=repmat(uint16(p.AdcOffset),3,1);
u.Hall=uint8(5);u.TerminalVoltage=repmat(p.NominalVdc/single(2),3,1);
u.Control=uint8(0);u.Fault=false;
u.CommandEvent=true;u.DrivingEvent=true;u.TimerEvent=true;
u.SpeedReq=single(0);u.Vdc=p.NominalVdc;
u.AppliedSector=uint8(0);u.AppliedDirection=int8(1);u.VoltageValid=true;
end
