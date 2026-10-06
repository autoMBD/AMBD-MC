function [kp,ki] = speed_gains(request,p)
%speed_gains - Limit Hall speed-loop gains when edge information is sparse
%   KP = speed_gains(REQUEST,P) returns the scheduled proportional gain.
%
%   [KP,KI] = speed_gains(...) also returns the integral gain. Hall gains
%   scale linearly/quadratically below the calibrated electrical speed;
%   qualified sensorless control retains its nominal gains.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
scale=single(1);
if p.PositionMode==uint8(0)
    scale=min(single(1),max(p.HallMinGainScale,abs(request)/p.HallGainSpeed));
end
kp=p.KpSpeed*scale;ki=p.KiSpeed*scale*scale;
end
