function s = tuning(u,s,p)
%TUNING - Latch calibrations only while the BLDC drive is disarmed
%   S = TUNING(U,S,P) captures P in reset, initialization or idle.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
if s.Mode<=uint8(2) && ~s.GateEnable
    s.Parameters=p;
end
% Keep the architectural module input contract uniform.
if ~u.DrivingEvent, s.SpeedTick=false; end
end
