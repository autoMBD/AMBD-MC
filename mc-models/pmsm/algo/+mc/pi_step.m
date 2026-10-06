function [output,integral] = pi_step(error,integral,kp,ki,dt,limit,reset)
%PI_STEP Advance a symmetric PI with conditional integration anti-windup.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
if reset
    output=single(0); integral=single(0); return
end
candidate=integral+ki*dt*error;
unsaturated=kp*error+candidate;
output=min(max(unsaturated,-limit),limit);
if abs(unsaturated)<=limit || error*(unsaturated-output)<=single(0)
    integral=min(max(candidate,-limit),limit);
end
end
