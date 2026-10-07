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
% File:        plant_terminal_fixture.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Create terminal-voltage acceptance test samples.
% =================================================================================

function trace=plant_terminal_fixture(mode)
Ts=1/16000; t=(0:Ts:.004)'; released=t>=.001375;
current=repmat([.5 .5 -1],numel(t),1);
current(released,:)=repmat([2 -2 0],sum(released),1);
terminal=repmat([12 0 12],numel(t),1);
terminal(released,3)=6-300*(t(released)-.003);
nativeTime=(0:Ts/100:.004)'; nativeReleased=nativeTime>=.001375;
nativeCurrent=repmat([.5 .5 -1],numel(nativeTime),1);
nativeCurrent(nativeReleased,:)=repmat([2 -2 0],sum(nativeReleased),1);
nativeTerminal=repmat([12 0 12],numel(nativeTime),1);
nativeTerminal(nativeReleased,3)=6-300*(nativeTime(nativeReleased)-.003);
trace=struct('time',t,'nativeTime',nativeTime,'hostCurrent',current, ...
    'nativeCurrent',nativeCurrent,'hostTerminal',terminal,'nativeTerminal',nativeTerminal, ...
    'switchTime',.001,'expectedCrossing',.003,'expectedSlope',-300, ...
    'rail',12,'floatPhase',3,'sampleTime',Ts,'nativeStep',Ts/100);
switch mode
    case 'biasedVoltage'
        trace.hostTerminal(released,3)=trace.hostTerminal(released,3)+.02;
    case 'reversedSlope'
        trace.hostTerminal(released,3)=12-trace.hostTerminal(released,3);
    case {'delayedCrossing','sharedDelay'}
        trace.hostTerminal(released,3)=trace.hostTerminal(released,3)+300*2*Ts;
        if strcmp(mode,'sharedDelay')
            trace.nativeTerminal(nativeReleased,3)=trace.nativeTerminal(nativeReleased,3)+300*2*Ts;
        end
    case 'delayedRelease'
        late=t>=.001375 & t<.001375+2*Ts;
        trace.hostCurrent(late,3)=-1; trace.hostTerminal(late,3)=12;
    case 'noUsableSamples'
        trace.hostCurrent(:,3)=-.1;
    case 'nanHostCurrent'
        trace.hostCurrent(end-2,3)=NaN;
    case 'nanNativeCurrent'
        trace.nativeCurrent(end-2,3)=NaN;
    case 'nanHostTerminal'
        trace.hostTerminal(1,1)=NaN;
    case 'infNativeTerminal'
        trace.nativeTerminal(1,2)=Inf;
    case 'nanTime'
        trace.time(end-2)=NaN;
    case 'nanNativeTime'
        trace.nativeTime(2)=NaN;
    case 'duplicateNativeTime'
        trace.nativeTime(2)=trace.nativeTime(1);
    case 'nonmonotonicTime'
        trace.time(end-1:end)=flipud(trace.time(end-1:end));
    case 'shapeMismatch'
        trace.hostCurrent=trace.hostCurrent(:,1:2);
    case 'outOfRangeTime'
        trace.time(1)=-Ts;
    case 'complexCurrent'
        trace.hostCurrent(end,1)=1+1i;
end
end
