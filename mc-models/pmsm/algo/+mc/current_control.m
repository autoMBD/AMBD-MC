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
% File:        current_control.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Regulate dq current with decoupling and vector limiting.
% =================================================================================

function [voltage,integral,dq] = current_control(abc,theta,omega,reference,integral,p,vdc,enable)
%CURRENT_CONTROL Regulate dq current with decoupling and vector limiting.
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
