function angle = wrap_angle(angle)
%WRAP_ANGLE Wrap electrical angle to the half-open interval [-pi,pi).
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
angle=mod(angle+single(pi),single(2*pi))-single(pi);
end
