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
% Description: Advance the phase-domain BLDC with diode zero-current events.
% =================================================================================

function next = plant_step(x,counts,phaseEnable,gate,vdc,loadTorque,p,dt)
%PLANT_STEP Advance the phase-domain BLDC with diode zero-current events.
next=double(x(:));
n=max(1,double(p.PlantSubsteps)); h=double(dt)/n;
R=double(p.Rs); tau=double(p.Ls)/R; J=double(p.Inertia);
B=double(p.Friction); ke=double(p.Ke); pp=double(p.PolePairs);
active=logical(phaseEnable(:)) & logical(gate);
for sub=1:n
    shape=bldc.trapezoid(next(4)+[0;-2*pi/3;2*pi/3]);
    e=ke*next(5)*shape; remaining=h; integral=zeros(3,1);
    for segment=1:12
        if remaining<=eps(h), break; end
        i=next(1:3);
        [v,vn,conducting]=bldc.phase_network(i,e,counts,phaseEnable,gate,vdc,p);
        target=(v-vn-e)/R;
        target(~conducting)=0;
        duration=remaining; event=zeros(3,1);
        for phase=1:3
            if ~active(phase) && abs(i(phase))>1e-12 && i(phase)*target(phase)<0
                crossing=-tau*log(-target(phase)/(i(phase)-target(phase)));
                if crossing>=0 && crossing<=duration
                    duration=crossing;
                end
                event(phase)=crossing;
            end
        end
        decay=exp(-duration/tau);
        integral=integral+target*duration+(i-target)*(-tau*expm1(-duration/tau));
        updated=target+(i-target)*decay;
        updated(~conducting)=0;
        hit=event>0 & abs(event-duration)<1e-13*max(1,h);
        updated(hit)=0;
        % Remove floating point KCL residue only from a conducting winding.
        [~,correction]=max(abs(updated));
        updated(correction)=updated(correction)-sum(updated);
        next(1:3)=updated;
        remaining=remaining-duration;
    end
    torque=ke*dot(shape,integral/h)-double(loadTorque);
    oldOmega=next(5);
    if B>0
        next(5)=oldOmega*exp(-B*h/J)+torque/B*(-expm1(-B*h/J));
    else
        next(5)=oldOmega+torque*h/J;
    end
    next(4)=mod(next(4)+pp*(oldOmega+next(5))*h/2,2*pi);
end
end
