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
% File:        kit_bldc_reference.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-07
% Version:     0.1.0
% Description: Generate physical DC-shunt replay inputs without inventing unobserved phase currents.
% =================================================================================

function [inputs,expected,truth] = kit_bldc_reference(p,plantp,n,direction,hardware)
%kit_bldc_reference - Exercise the DC-link controller against a phase plant
%   [INPUTS,EXPECTED,TRUTH] = kit_bldc_reference(P,PLANTP,N,DIRECTION)
%   runs an independent switched electrical plant with synchronous unipolar
%   PWM, two-capture commutation activation, and active-vector sampling.
%   This is a virtual electrical reference, not a physical motor test.
%#codegen
if nargin<5
    hardware=struct('adcMaximum',16383,'adcOffset',8192,'dutyTicks',10000,'samplePeriod',1/16000,'deadtimeFraction',.0096);
end
adcMaximum=hardware.adcMaximum;adcOffset=hardware.adcOffset;dutyTicks=hardware.dutyTicks;
inputs=zeros(n,17);expected=zeros(n,14);truth=zeros(n,3);
s=bldc.initial_state(p);x=[0;0;0;.1;0];
requestCounts=zeros(3,1,'uint16');writtenCounts=requestCounts;
requestMask=false(3,1);writtenMask=requestMask;activeMask=requestMask;
requestSector=uint8(0);writtenSector=uint8(0);activeSector=uint8(0);
requestDirection=int8(1);writtenDirection=int8(1);activeDirection=int8(1);
wait=uint8(0);vdc=single(12);
for row=1:n
    activeCounts=writtenCounts;
    gate=any(activeMask);sampleCounts=zeros(3,1,'uint16');source=1;
    if gate
        [~,source]=max(activeCounts);sampleCounts(source)=uint16(65535);
    end
    [~,hall,terminal,current,~,omega]=bldc.plant_measure(x,sampleCounts,activeMask,gate,vdc,plantp);
    u=bldc.default_input(p);u.Control=uint8(row>160);u.SpeedReq=single(direction)*single(200);
    if row>40000,u.SpeedReq=single(direction)*single(300);end
    if gate,dc=current(source);else,dc=single(0);end
    raw=min((adcMaximum-1),max(1,round(adcOffset+double(dc)*adcMaximum/50)));
    dc=single((raw-adcOffset)*50/adcMaximum);
    u.CurrentRaw=uint16([min(65534,max(1,round(32768+double(dc)*1000)));32768;32768]);
    u.Hall=hall;u.TerminalVoltage=terminal;u.AppliedSector=activeSector;
    u.AppliedDirection=activeDirection;u.VoltageValid=gate;u.Vdc=vdc;
    inputs(row,:)=[double(u.CurrentRaw(:))',double(u.Hall),double(u.TerminalVoltage(:))', ...
        double(u.Control),double(u.Fault),double(u.CommandEvent),double(u.DrivingEvent), ...
        double(u.TimerEvent),double(u.SpeedReq),double(u.Vdc),double(u.AppliedSector), ...
        double(u.AppliedDirection),double(u.VoltageValid)];
    if wait>uint8(0)
        wait=wait-uint8(1);
        if wait==uint8(0) && writtenSector==requestSector && writtenDirection==requestDirection
            activeMask=writtenMask;activeSector=writtenSector;activeDirection=writtenDirection;
        end
    end
    writtenCounts=requestCounts;writtenMask=requestMask;writtenSector=requestSector;writtenDirection=requestDirection;
    s=bldc.step(u,s,p);
    expected(row,:)=[double(s.Mode),double(s.FaultBits),double(s.DutyCounts(:))',double(s.GateEnable), ...
        double(s.SpeedEstimate),double(s.ZcCount),double(s.Sector),double(s.CurrentRef),double(s.CurrentMeasured), ...
        double(s.PhaseEnable(:))'];
    truth(row,:)=[double(omega),double(u.SpeedReq),max(abs(x(1:3)))];
    nextCounts=zeros(3,1,'uint16');nextMask=s.PhaseEnable&s.GateEnable;
    if s.GateEnable
        [high,source]=max(s.DutyCounts);low=uint16(65535)-high;
        duty=double(high)-double(low);q15=round(duty*32768/65535);ticks=round(q15*dutyTicks/32768);
        nextCounts(source)=uint16(round(ticks*65535/dutyTicks));
    end
    if ~any(nextMask)
        activeMask=false(3,1);activeSector=uint8(0);wait=uint8(0);
    elseif ~isequal(nextMask,requestMask)||s.Sector~=requestSector||s.OutputDirection~=requestDirection
        activeMask=false(3,1);activeSector=uint8(0);wait=uint8(2);
    end
    requestCounts=nextCounts;requestMask=nextMask;requestSector=s.Sector;requestDirection=s.OutputDirection;
    loadTorque=single(.005*tanh(x(5)));
    % From this center-of-pulse sample to the next: current pulse tail,
    % synchronous low-side freewheel, and next pulse head. Averaging pole
    % voltage before resolving floating-leg diodes would corrupt BEMF samples.
    onCounts=zeros(3,1,'uint16');nextOnCounts=onCounts;
    [currentDuty,currentSource]=max(activeCounts);[nextDuty,nextSource]=max(writtenCounts);
    onCounts(currentSource)=uint16(65535);nextOnCounts(nextSource)=uint16(65535);
    tail=double(currentDuty)/65535*double(p.Ts)/2;
    head=double(nextDuty)/65535*double(p.Ts)/2;
    off=max(0,double(p.Ts)-tail-head);
    if tail>0,x=bldc.plant_step(x,onCounts,activeMask,any(activeMask),vdc,loadTorque,plantp,tail);end
    if off>0,x=bldc.plant_step(x,zeros(3,1,'uint16'),activeMask,any(activeMask),vdc,loadTorque,plantp,off);end
    if head>0,x=bldc.plant_step(x,nextOnCounts,activeMask,any(activeMask),vdc,loadTorque,plantp,head);end
end
end
