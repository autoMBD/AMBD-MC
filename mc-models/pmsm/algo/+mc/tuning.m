function s = tuning(u,s,p)
%TUNING Latch bounded calibrations only while disarmed.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
if ~(s.Mode==uint8(0) || s.Mode==uint8(2))
    return
end
if ~p.TuningEnable
    % Offline calibration is authoritative over stored runtime seed values.
    s.Gains=single([p.KpSpeed;p.KiSpeed;p.KpD;p.KiD;p.KpQ;p.KiQ]);
    s.Startup=single([p.AlignCurrent;p.AlignTime;p.OpenLoopAccel;p.ObserverBandwidth]);
    return
end
g=single([u.Tuning.SpdKp;u.Tuning.SpdKi;u.Tuning.IdKp; ...
    u.Tuning.IdKi;u.Tuning.IqKp;u.Tuning.IqKi]);
g=g.*single([0.001;0.001;0.001;1;0.001;1]);
% Zero gains represent an uninitialized calibration frame, not a new tune.
if all(g>single(0)) && all(g<=single([2;100;20;10000;20;10000]))
    s.Gains=g;
end
startup=single([u.Tuning.AlignCurrent;u.Tuning.AlignTime; ...
    u.Tuning.OpenLoopAccel;u.Tuning.TrackingGain]).*single([0.001;0.001;1;1]);
if all(startup>single(0)) && all(startup<=single([p.CurrentLimit;2;1000;1000]))
    s.Startup=startup;
end
end
