function q = observer_initial(p,theta,current)
%OBSERVER_INITIAL Initialize stator flux using the known alignment angle.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
% Double evaluation makes the final rounding consistent across host tools.
c=cast(cos(double(theta)),'like',theta);
s=cast(sin(double(theta)),'like',theta);
q.Flux=single([p.Flux*c;p.Flux*s])+p.Lq*current;
q.Theta=single(theta);
q.Omega=single(0);
q.Magnitude=p.Flux;
end
