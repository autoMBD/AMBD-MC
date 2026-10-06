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
% File:        defaults.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Return host-portable PMSM controller calibrations in SI units.
% =================================================================================

function p = defaults()
%DEFAULTS Return host-portable PMSM controller calibrations in SI units.
%#codegen
p.Ts = single(1/16000);
p.SpeedDivider = uint16(16);
p.AdcOffset = single(32768);
p.AdcCountsPerAmp = single(1000);
p.PwmPeriod = uint16(65535);
p.Rs = single(0.56);
p.Ld = single(0.000375);
p.Lq = single(0.000435);
p.Flux = single(0.0039052261);
p.PolePairs = uint8(2);
p.Inertia = single(1.2e-5);
p.Friction = single(0.0005);
p.NominalVdc = single(12);
p.VdcMin = single(8);
p.VdcMax = single(16);
p.CurrentLimit = single(6);
p.TripCurrent = single(10);
p.SpeedLimit = single(250);
p.VoltageMargin = single(0.90);
% Current pole cancellation at 500 Hz; integral gains are per second.
wc = single(2*pi*500);
p.KpD = p.Ld*wc;
p.KpQ = p.Lq*wc;
p.KiD = p.Rs*wc;
p.KiQ = p.Rs*wc;
% Critically damped 8 Hz speed design; error uses electrical rad/s.
ws = single(2*pi*8);
kt = single(1.5)*single(p.PolePairs)*p.Flux;
p.KpSpeed = (single(2)*p.Inertia*ws-p.Friction)/(kt*single(p.PolePairs));
p.KiSpeed = p.Inertia*ws*ws/(kt*single(p.PolePairs));
p.SpeedSlew = single(300);
p.CurrentSlew = single(100);
p.AlignTime = single(0.15);
p.AlignCurrent = single(1);
p.OpenLoopCurrent = single(3.5);
p.OpenLoopAccel = single(100);
p.OpenLoopSpeed = single(120);
p.TrackingTime = single(0.20);
p.StartTimeout = single(3);
p.ObserverBandwidth = single(80);
p.ObserverSpeedBandwidth = single(150);
p.ObserverMinSpeed = single(60);
p.ObserverLockTime = single(0.05);
p.StopDecel = single(500);
p.StopSpeed = single(15);
p.StopTimeout = single(1);
p.PositionMode = uint8(0); % 0: voltage/current observer; 1: position sensor.
p.TuningEnable = false;
end
