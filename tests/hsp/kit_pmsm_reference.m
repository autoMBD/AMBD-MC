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
% File:        kit_pmsm_reference.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-07
% Version:     0.1.0
% Description: Generate kit two-shunt PMSM replay inputs with delayed applied-voltage feedback.
% =================================================================================

function [inputs,expected,truth] = kit_pmsm_reference(p,plantp,n,direction,hardware)
%kit_pmsm_reference - Exercise kit sensing and buffered PWM in an average plant
%   [INPUTS,EXPECTED,TRUTH] = kit_pmsm_reference(P,PLANTP,N,DIRECTION)
%   runs two ADC shunts with quantization, complementary PWM deadtime and
%   a two-capture command pipeline. Switching ripple is not represented.
%#codegen
if nargin<5
    hardware=struct('adcMaximum',16383,'adcOffset',8192,'dutyTicks',10000,'samplePeriod',1/16000,'deadtimeFraction',.0096);
end
adcMaximum=hardware.adcMaximum;adcOffset=hardware.adcOffset;dutyTicks=hardware.dutyTicks;
inputs=zeros(n,10);expected=zeros(n,9);truth=zeros(n,3);
s=mc.initial_state(p);x=zeros(4,1);vdc=single(12);
request=single([.5;.5;.5]);written=request;
requestGate=false;writtenGate=false;
previousVoltage=single([0;0]);
for row=1:n
    [~,current,~,omega]=mc.plant_measure(x,plantp);
    raw=min((adcMaximum-1),max(1,round(adcOffset-double(current(1:2))*adcMaximum/62.5)));
    measured=zeros(3,1,'single');measured(1:2)=single((adcOffset-raw)*62.5/adcMaximum);
    measured(3)=-measured(1)-measured(2);
    u=mc.default_input(p);
    u.CurrentRaw=uint16(min(65534,max(1,round(32768+double(measured)*1000))));
    u.Control=uint8(row>160);u.SpeedReq=single(direction)*single(200);
    if row>40000,u.SpeedReq=single(direction)*single(300);end
    u.Position=single(0);u.Vdc=vdc;u.AppliedVoltage=previousVoltage;
    inputs(row,:)=[double(u.CurrentRaw(:))',double(u.Control),double(u.Fault), ...
        double(u.SpeedReq),double(u.Vdc),double(u.Position),double(u.AppliedVoltage(:))'];
    active=written;activeGate=writtenGate;written=request;writtenGate=requestGate;
    s=mc.step(u,s,p);
    [counts,~,status]=mc.monitor(s,p);
    expected(row,:)=[double(status.Mode),double(status.FaultBits),double(counts(:))', ...
        double(status.GateEnable),double(status.Omega),double(status.ObserverReady),double(status.Theta)];
    truth(row,:)=[double(omega),double(u.SpeedReq),max(abs(double(current)))];
    q15=round(min(58982,max(6554,double(counts)))*32768/65535);
    request=single(round(q15*dutyTicks/32768))/single(dutyTicks);
    requestGate=s.Core.GateEnable;
    if ~s.Core.GateEnable,activeGate=false;writtenGate=false;end
    applied=active-sign(measured)*single(hardware.deadtimeFraction);
    if activeGate
        previousVoltage=vdc*single([(2*applied(1)-applied(2)-applied(3))/3;(applied(2)-applied(3))/sqrt(3)]);
    else
        previousVoltage=single([0;0]);
    end
    loadTorque=single(.005*tanh(x(3)));
    x=mc.plant_step(x,applied,vdc,loadTorque,activeGate,plantp,double(p.Ts));
end
end
