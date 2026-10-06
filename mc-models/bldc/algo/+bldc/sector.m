function value = sector(theta)
%SECTOR - Map electrical angle to the declared six-step sector
%   VALUE = SECTOR(THETA) returns a uint8 sector for THETA in radians.
%   A nonfinite angle returns zero.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
value=uint8(0);
if isfinite(theta)
    value=uint8(floor(mod(double(theta)-pi/6,2*pi)/(pi/3))+1);
end
end
