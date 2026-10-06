function f = trapezoid(theta)
% SPDX-License-Identifier: MIT
%TRAPEZOID Evaluate the periodic normalized phase BEMF shape.
a=mod(double(theta)+pi/6,2*pi);
f=min(1,max(-1,6*a/pi-1));
fall=a>=pi;
f(fall)=max(-1,7-6*a(fall)/pi);
end
