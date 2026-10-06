function duty = svpwm(voltage,vdc,enable)
%SVPWM Compute centered modulation with common-mode voltage injection.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
duty=single([0.5;0.5;0.5]);
if ~enable || vdc<=single(0) || ~isfinite(vdc)
    return
end
phase=single([voltage(1); -single(0.5)*voltage(1)+single(sqrt(3)/2)*voltage(2); ...
    -single(0.5)*voltage(1)-single(sqrt(3)/2)*voltage(2)]);
common=single(0.5)*(max(phase)+min(phase));
duty=min(max(single(0.5)+(phase-common)/vdc,single(0)),single(1));
end
