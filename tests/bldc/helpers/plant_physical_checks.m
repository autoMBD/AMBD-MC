function r=plant_physical_checks()
% SPDX-License-Identifier: MIT
p=plant_parameters(); pairs=[1 2;1 3;2 3;2 1;3 1;3 2];
tf=zeros(1,6); tr=tf; pe=tf; ze=zeros(2,6); slopes=zeros(2,6);
for k=1:6
    theta=k*pi/3; f=bldc.trapezoid(theta+[0;-2*pi/3;2*pi/3]);
    i=zeros(3,1); i(pairs(k,1))=2; i(pairs(k,2))=-2;
    tf(k)=p.Ke*dot(f,i); tr(k)=p.Ke*dot(f,-i);
    pe(k)=dot(p.Ke*100*f,i)-tf(k)*100;
    en=false(3,1); en(pairs(k,:))=true;
    q=zeros(3,1,'uint16'); q(pairs(k,1))=50000; q(pairs(k,2))=15535;
    for sign=[-1 1]
        [~,~,v]=bldc.plant_measure([0;0;0;theta;sign*100],q,en,true,12,p);
        ze((sign+3)/2,k)=double(v(~en))-6;
        [~,~,before]=bldc.plant_measure([0;0;0;theta-sign*1e-3;sign*100],q,en,true,12,p);
        [~,~,after]=bldc.plant_measure([0;0;0;theta+sign*1e-3;sign*100],q,en,true,12,p);
        slopes((sign+3)/2,k)=double(after(~en)-before(~en))*(-1)^k;
    end
end
x=[3;-2;-1;1;100]; eg=zeros(1,300); kc=eg;
for n=1:300
    old=.5*p.Ls*sum(x(1:3).^2)+.5*p.Inertia*x(5)^2;
    x=bldc.plant_step(x,zeros(3,1,'uint16'),false(3,1),false,12,0,p,double(p.Ts));
    eg(n)=.5*p.Ls*sum(x(1:3).^2)+.5*p.Inertia*x(5)^2-old; kc(n)=abs(sum(x(1:3)));
end
steps=[10 20 80]; ends=zeros(5,3);
for j=1:3
    p.PlantSubsteps=uint16(steps(j)); x=[0;0;0;1;60];
    for n=1:200
        x=bldc.plant_step(x,uint16([43000;22535;0]),logical([1;1;0]),true,12,.002,p,double(p.Ts));
    end
    ends(:,j)=x;
end
r=struct('maxKcl',max(kc),'maxOffEnergyGain',max(eg), ...
    'coarseError',norm(ends(:,1)-ends(:,3)),'fineError',norm(ends(:,2)-ends(:,3)), ...
    'minForwardTorque',min(tf),'maxReverseTorque',max(tr), ...
    'maxPowerError',max(abs(pe)),'maxCrossError',max(abs(ze),[],'all'), ...
    'minCorrectCrossingSlope',min(slopes,[],'all'));
end
