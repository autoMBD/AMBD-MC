function q = observer_step(current,appliedVoltage,q,p)
%OBSERVER_STEP Estimate active flux angle from voltage and current alone.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
active=q.Flux-p.Lq*current;
% Keep state precision while evaluating transcendentals consistently.
c=cast(cos(double(q.Theta)),'like',q.Theta);
s=cast(sin(double(q.Theta)),'like',q.Theta);
id=current(1)*c+current(2)*s;
expected=max(p.Flux+(p.Ld-p.Lq)*id,single(0.25)*p.Flux);
normError=single(1)-(active(1)*active(1)+active(2)*active(2))/(expected*expected);
correction=single(0.5)*p.ObserverBandwidth*normError*active;
q.Flux=q.Flux+p.Ts*(appliedVoltage-p.Rs*current+correction);
active=q.Flux-p.Lq*current;
angle=cast(atan2(double(active(2)),double(active(1))),'like',active);
instantOmega=mc.wrap_angle(angle-q.Theta)/p.Ts;
alpha=min(single(1),p.ObserverSpeedBandwidth*p.Ts);
q.Omega=q.Omega+alpha*(instantOmega-q.Omega);
q.Theta=angle;
normSquared=active(1)*active(1)+active(2)*active(2);
q.Magnitude=cast(sqrt(double(normSquared)),'like',normSquared);
end
