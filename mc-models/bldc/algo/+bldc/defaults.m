function p = defaults()
%DEFAULTS - Return virtual BLDC motor and controller calibrations
%   P = DEFAULTS returns fixed-size SI parameters for host verification.
%   The motor parameters describe a virtual fixture, not an identified motor.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
p.Ts=single(1/16000);p.SpeedDivider=uint16(16);
p.AdcOffset=single(32768);p.AdcCountsPerAmp=single(1000);
p.PwmPeriod=uint16(65535);
p.Rs=single(.56);p.Ls=single(.0004);p.Ke=single(.0078104522);
p.PolePairs=uint8(2);p.Inertia=single(1.2e-5);p.Friction=single(.0005);
p.PlantSubsteps=uint16(10);
p.NominalVdc=single(12);p.VdcMin=single(8);p.VdcMax=single(16);
p.CurrentLimit=single(6);p.TripCurrent=single(10);
p.SpeedLimit=single(250);p.MaxModulation=single(.95);
% Two conducting phase windings; output is line voltage, not duty.
wc=single(2*pi*500);p.KpCurrent=single(2)*p.Ls*wc;
p.KiCurrent=single(2)*p.Rs*wc;
ws=single(2*pi*8);kt=single(2)*p.Ke;
p.KpSpeed=(single(2)*p.Inertia*ws-p.Friction)/(kt*single(p.PolePairs));
p.KiSpeed=p.Inertia*ws*ws/(kt*single(p.PolePairs));
p.SpeedSlew=single(200);p.CurrentSlew=single(60);
p.AlignTime=single(.15);p.AlignCurrent=single(1.2);
p.OpenCurrent=single(3.5);p.OpenAccel=single(100);p.OpenSpeed=single(120);
p.TrackingTime=single(.15);p.TrackingTimeout=single(1);p.StartTimeout=single(3);
p.StopSpeed=single(8);p.StopTimeout=single(1.5);p.StopCoastTime=single(.25);
p.HallTimeout=single(.3);p.HallStartTimeout=single(1);
p.HallStallCurrent=single(.5);p.SpeedFilterAlpha=single(.02);
p.ZcBlankTicks=uint16(4);p.ZcHysteresis=single(.02);
p.FloatCurrentLimit=single(.05);p.ZcMinTicks=uint32(20);
p.ZcMaxTicks=uint32(8000);p.ZcRequired=uint16(6);
p.ZcTimeoutFactor=single(2.5);p.ZcMinSpeed=single(60);
p.AcquireSpacing=uint16(4);p.AcquireMinVoltage=single(.2);
p.AcquireTimeout=single(.01);
p.LowSpeedThreshold=single(75);p.PositionMode=uint8(0);
end
