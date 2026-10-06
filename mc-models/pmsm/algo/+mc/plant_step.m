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
% File:        plant_step.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Advance the independent average-voltage PMSM host plant.
% =================================================================================

function x = plant_step(x,duty,vdc,loadTorque,gate,p,dt)
%PLANT_STEP Advance the independent average-voltage PMSM host plant.
%   X = [id; iq; mechanical speed; electrical angle] in double SI units.
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
