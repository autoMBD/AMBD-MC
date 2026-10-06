function x = plant_step(x,duty,vdc,loadTorque,gate,p,dt)
%PLANT_STEP Advance the independent average-voltage PMSM host plant.
%   X = [id; iq; mechanical speed; electrical angle] in double SI units.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
% Four RK4 substeps separate plant integration error from controller error.
h=dt/4;
phase=double(vdc)*(double(duty)-mean(double(duty)));
ab=[(2/3)*(phase(1)-0.5*(phase(2)+phase(3))); ...
    (phase(2)-phase(3))/sqrt(3)];
for substep=1:4
    k1=derivative(x,ab,loadTorque,gate,p);
    k2=derivative(x+0.5*h*k1,ab,loadTorque,gate,p);
    k3=derivative(x+0.5*h*k2,ab,loadTorque,gate,p);
    k4=derivative(x+h*k3,ab,loadTorque,gate,p);
    x=x+(h/6)*(k1+2*k2+2*k3+k4);
end
x(4)=mod(x(4)+pi,2*pi)-pi;
end

function dx=derivative(x,voltage,loadTorque,gate,p)
rs=double(p.Rs);ld=double(p.Ld);lq=double(p.Lq);
flux=double(p.Flux);pairs=double(p.PolePairs);
we=pairs*x(3);
if gate
    vd=cos(x(4))*voltage(1)+sin(x(4))*voltage(2);
    vq=-sin(x(4))*voltage(1)+cos(x(4))*voltage(2);
    did=(vd-rs*x(1)+we*lq*x(2))/ld;
    diq=(vq-rs*x(2)-we*(ld*x(1)+flux))/lq;
else
    % Gate-off abstraction: winding current decay and mechanical coast.
    % Switching deadtime, body diodes and DC-link regeneration are excluded.
    did=-rs*x(1)/ld;diq=-rs*x(2)/lq;
end
torque=1.5*pairs*(flux*x(2)+(ld-lq)*x(1)*x(2));
dw=(torque-double(p.Friction)*x(3)-double(loadTorque))/double(p.Inertia);
dx=[did;diq;dw;we];
end
