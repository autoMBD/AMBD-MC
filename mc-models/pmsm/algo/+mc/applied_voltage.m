function voltage = applied_voltage(counts,vdc,gate,pwmPeriod)
%applied_voltage - Reconstruct the average voltage actually driven by PWM
%   V = mc.applied_voltage(COUNTS,VDC,GATE,PERIOD) returns single alpha/beta
%   voltage from three actual timer counts and the measured DC voltage for
%   that interval. Disabled gates return zero. The caller supplies the
%   previous interval's counts and gate state; no rotor position is used.
%   See also mc.plant_step, mc.observer_step

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
if ~gate
    voltage=single([0;0]);
    return
end
% Match the host inverter's count normalization and average-voltage map.
duty=double(counts)/double(pwmPeriod);
phase=double(vdc)*(duty-mean(duty));
voltage=single([(2/3)*(phase(1)-.5*(phase(2)+phase(3))); ...
    (phase(2)-phase(3))/sqrt(3)]);
end
