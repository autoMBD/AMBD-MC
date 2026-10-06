function r=plant_torque_checks()
% SPDX-License-Identifier: MIT
p=plant_parameters(); p.PlantSubsteps=uint16(1); p.Friction=0;
pairs=[1 2;1 3;2 3;2 1;3 1;3 2]; h=1e-6;
tau=p.Ls/p.Rs; target=12/(2*p.Rs);
average=target+(2-target)*tau/h*(-expm1(-h/tau));
expected=2*p.Ke*average*h/p.Inertia;
errors=zeros(2,6); signedAcceleration=errors;
for sector=1:6
    for direction=[-1 1]
        pair=pairs(sector,:);
        if direction<0, pair=fliplr(pair); end
        x=[0;0;0;sector*pi/3;0]; x(pair(1))=2; x(pair(2))=-2;
        q=zeros(3,1,'uint16'); q(pair(1))=65535;
        enabled=false(3,1); enabled(pair)=true;
        next=bldc.plant_step(x,q,enabled,true,12,0,p,h);
        errors((direction+3)/2,sector)=abs(next(5)-direction*expected);
        signedAcceleration((direction+3)/2,sector)=next(5)*direction;
    end
end
r=struct('maxError',max(errors,[],'all'), ...
    'minimumSignedAcceleration',min(signedAcceleration,[],'all'));
end
