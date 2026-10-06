function [voltage,integral,dq] = current_control(abc,theta,omega,reference,integral,p,vdc,enable)
%CURRENT_CONTROL Regulate dq current with decoupling and vector limiting.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
dq=mc.park(mc.clarke(abc),theta);
voltage=single([0;0]);
if ~enable
    integral=single([0;0]); return
end
error=reference-dq;
feedforward=single([-omega*p.Lq*dq(2);omega*(p.Ld*dq(1)+p.Flux)]);
proportional=single([p.KpD;p.KpQ]).*error;
candidate=integral+p.Ts*single([p.KiD;p.KiQ]).*error;
raw=proportional+candidate+feedforward;
limit=max(single(0),vdc)*single(1/sqrt(3))*p.VoltageMargin;
% Round a double square root once into the unchanged control precision.
normSquared=raw(1)*raw(1)+raw(2)*raw(2);
magnitude=cast(sqrt(double(normSquared)),'like',normSquared);
scale=min(single(1),limit/max(magnitude,single(1e-9)));
limited=scale*raw;
% Integrate an axis only when it is unsaturated or drives back from its limit.
for axis=1:2
    if scale==single(1) || error(axis)*(raw(axis)-limited(axis))<=single(0)
        integral(axis)=min(max(candidate(axis),-limit),limit);
    end
end
voltage=mc.invpark(limited,theta);
end
