function [output,next] = pi_step(error,state,kp,ki,dt,lower,upper)
%pi_step - Evaluate a PI controller with conditional integration
%   OUTPUT = pi_step(ERROR,STATE,KP,KI,DT,LOWER,UPPER) clamps the command
%   and prevents outward integration at either limit. KI is per second.
%
%   [OUTPUT,NEXT] = pi_step(...) also returns the explicit integral state.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
candidate=state+ki*dt*error;
raw=kp*error+candidate;
outward=(raw>upper && error>0) || (raw<lower && error<0);
if outward
    next=state;
else
    next=candidate;
end
output=min(max(kp*error+next,lower),upper);
end
