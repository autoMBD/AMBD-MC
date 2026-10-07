% =================================================================================
% The MIT License
% MIT许可证
%
% <https://opensource.org/license/mit>
%
% SPDX short identifier / SPDX 短标识符：MIT
%
% Copyright (c) 2026 autoMBD
% 版权所有 (c) 2026 autoMBD
%
% Permission is hereby granted, free of charge, to any person obtaining a
% copy of this software and associated documentation files (the “Software”),
% to deal in the Software without restriction, including without limitation
% the rights to use, copy, modify, merge, publish, distribute, sublicense,
% and/or sell copies of the Software, and to permit persons to whom the
% Software is furnished to do so, subject to the following conditions:
% 特此向获得本软件及相关文档（合称“本软件”）副本的任何人免费授予不受限制地利用本软
% 件的许可，包括而不限于：使用、复制、修改、合并、发布、分发、分许可和/或销售本软
% 件副本，并允许本软件的接收者也获得前述许可，但须遵守以下条件：
%
% The above copyright notice and this permission notice shall be included
% in all copies or substantial portions of the Software.
% 以上版权声明及本许可声明应包含在本软件的所有副本或主要部分中。
%
% THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
% MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
% NONINFRINGEMENT. IN NO EVENT SHALLTHE AUTHORS OR COPYRIGHT
% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
% IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
% CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.
% 本软件系“按原样”提供，不包含任何形式的明示或默示保证，包括但不限于适销性、特定
% 目的适用性及不侵权的保证。在任何情况下，无论是在合同、侵权或其他案件中，作者或版
% 权持有人均不对因本软件、或因本软件的使用或其他利用而引起的、引发的或与之相关的任
% 何权利主张、损害赔偿或其他责任承担责任。
% =================================================================================
% Project:     autoMBD Motor Control <https://github.com/autoMBD/AMBD-MC>
% File:        plant_physical_checks.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Check BLDC plant voltage and current physics.
% =================================================================================

function r=plant_physical_checks()
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
