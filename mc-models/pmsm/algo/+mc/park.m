function dq = park(ab,theta)
%PARK Transform stationary components into the rotor electrical frame.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
% Evaluate transcendentals in double, then restore the input precision.
c=cast(cos(double(theta)),'like',theta);
s=cast(sin(double(theta)),'like',theta);
dq=single([c*ab(1)+s*ab(2);-s*ab(1)+c*ab(2)]);
end
