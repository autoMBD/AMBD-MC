function ab = invpark(dq,theta)
%INVPARK Transform rotor-frame components into the stationary frame.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
% Avoid different single math libraries seeding the controller integrators.
c=cast(cos(double(theta)),'like',theta);
s=cast(sin(double(theta)),'like',theta);
ab=single([c*dq(1)-s*dq(2);s*dq(1)+c*dq(2)]);
end
