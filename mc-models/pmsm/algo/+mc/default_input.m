function u = default_input(p)
%DEFAULT_INPUT Return a disarmed, healthy input frame for host adapters.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
u.CurrentRaw=repmat(uint16(p.AdcOffset),3,1);
u.Control=uint8(0);
u.Fault=false;
u.CommandEvent=true;
u.DrivingEvent=true;
u.TimerEvent=true;
u.SpeedReq=single(0);
u.Vdc=p.NominalVdc;
u.Position=single(0);
u.AppliedVoltage=single([0;0]);
u.Tuning.SpdKp=uint16(p.KpSpeed*single(1000));
u.Tuning.SpdKi=uint16(p.KiSpeed*single(1000));
u.Tuning.IdKp=uint16(p.KpD*single(1000));
u.Tuning.IdKi=uint16(p.KiD);
u.Tuning.IqKp=uint16(p.KpQ*single(1000));
u.Tuning.IqKi=uint16(p.KiQ);
u.Tuning.AlignCurrent=uint16(p.AlignCurrent*single(1000));
u.Tuning.AlignTime=uint16(p.AlignTime*single(1000));
u.Tuning.OpenLoopAccel=uint16(p.OpenLoopAccel);
u.Tuning.TrackingGain=uint16(p.ObserverBandwidth);
end
