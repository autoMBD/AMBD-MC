function [counts,enabled,gate,debug,m] = monitor(s,p)
%MONITOR - Export typed BLDC actuator and verification signals
%   COUNTS = MONITOR(S,P) returns the high-side PWM counts from state S.
%
%   [COUNTS,ENABLED,GATE,DEBUG,M] = MONITOR(...) also returns phase/global
%   enables, fixed-size debug data and the complete verification monitor.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
counts=s.DutyCounts;enabled=s.PhaseEnable;gate=s.GateEnable;
m.Mode=s.Mode;m.FaultBits=s.FaultBits;m.Tick=s.Tick;
m.Current=s.Current;m.CurrentReference=s.CurrentRef;m.CurrentDemand=s.CurrentDemand;
m.SpeedRequest=s.SpeedRequest;m.SpeedRamped=s.SpeedRamped;
m.SpeedEstimate=s.SpeedEstimate;m.ControlSpeed=s.ControlSpeed;
m.Sector=s.Sector;m.Direction=s.Direction;m.OutputDirection=s.OutputDirection;
m.Modulation=s.Modulation;m.GateEnable=s.GateEnable;m.PhaseEnable=s.PhaseEnable;
m.FeedbackReady=s.FeedbackReady;m.ZcCount=s.ZcCount;m.ZcPeriod=s.ZcPeriod;
m.ZcCountdown=s.ZcCountdown;m.AcquisitionReady=s.AcquisitionReady;
m.PositionMode=s.Parameters.PositionMode;m.VoltageResidual=s.ZcValue;
m.CurrentIntegrator=s.CurrentIntegrator;m.SpeedIntegrator=s.SpeedIntegrator;
m.HallSector=s.HallSector;m.HallValid=s.HallValid;m.AppliedAge=s.AppliedAge;
m.CurrentMeasured=s.CurrentMeasured;
debug.Enabled=true;
debug.Data=single([single(s.Mode);single(s.FaultBits);s.SpeedRequest; ...
    s.SpeedEstimate;s.CurrentRef;s.CurrentMeasured;s.Modulation; ...
    single(s.Sector);single(s.Direction);single(s.FeedbackReady); ...
    single(s.ZcCount);s.ZcPeriod;s.ZcValue;s.CurrentIntegrator; ...
    s.SpeedIntegrator;single(p.PwmPeriod)]);
end
