function p = defaults()
%DEFAULTS Return host-portable PMSM controller calibrations in SI units.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
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
