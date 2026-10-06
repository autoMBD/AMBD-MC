function [counts,debug,monitor] = monitor(s,p)
%MONITOR Expose typed control telemetry and explicit PWM count scaling.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
counts=uint16(round(min(max(s.Duty,single(0)),single(1))*single(p.PwmPeriod)));
debug.DebugEn=true;
debug.DebugChannel=uint8(0);
debug.DebugData=zeros(8,1,'uint8');
debug.DebugData(1)=s.Mode;
debug.DebugData(2)=uint8(bitand(s.FaultBits,uint16(255)));
debug.DebugData(3)=uint8(bitshift(s.FaultBits,-8));
debug.DebugData(4)=uint8(s.GateEnable);
debug.DebugData(5)=uint8(s.ObserverReady);
debug.DebugData(6)=uint8(bitand(s.Tick,uint32(255)));
debug.DebugData(7)=uint8(bitand(bitshift(s.Tick,-8),uint32(255)));
debug.DebugData(8)=p.PositionMode;
monitor.Mode=s.Mode;
monitor.FaultBits=s.FaultBits;
monitor.Tick=s.Tick;
monitor.SpeedRequest=s.SpeedRequest;
monitor.Omega=s.OmegaControl;
monitor.Theta=s.ThetaControl;
monitor.Current=s.Current;
monitor.CurrentDq=s.CurrentDq;
monitor.ReferenceDq=s.ReferenceDq;
monitor.Voltage=s.Voltage;
monitor.Duty=s.Duty;
monitor.GateEnable=s.GateEnable;
monitor.ObserverReady=s.ObserverReady;
monitor.FluxMagnitude=s.Observer.Magnitude;
monitor.PositionMode=p.PositionMode;
end
