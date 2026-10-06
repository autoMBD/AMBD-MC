function s = initial_state(p)
%initial_state - Return explicit typed BLDC controller memory
%   S = initial_state(P) resets every state and stores calibrations P.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
s.Parameters=p;
s.Mode=uint8(0);s.PreviousMode=uint8(0);s.ModeTicks=uint32(0);
s.Tick=uint32(0);s.SlowCounter=uint16(0);s.FastTick=false;s.SpeedTick=false;
s.Command=uint8(0);s.SpeedRequest=single(0);s.SpeedRamped=single(0);
s.CoastTicks=uint32(0);
s.Direction=int8(1);s.OutputDirection=int8(1);s.Sector=uint8(0);
s.GateEnable=false;s.PhaseEnable=false(3,1);s.DutyCounts=zeros(3,1,'uint16');
s.Modulation=single(0);s.Current=zeros(3,1,'single');
s.CurrentRef=single(0);s.CurrentDemand=single(0);s.CurrentMeasured=single(0);
s.CurrentIntegrator=single(0);s.SpeedIntegrator=single(0);
s.SpeedEstimate=single(0);s.ControlSpeed=single(0);s.RawSpeed=single(0);
s.HallLast=uint8(0);s.HallSector=uint8(0);s.HallAge=uint32(0);
s.HallValid=false;s.HallDirection=int8(0);s.FeedbackReady=false;
s.OmegaOpen=single(0);s.ThetaOpen=single(5*pi/6);
s.AppliedLastSector=uint8(0);s.AppliedAge=uint32(0);
s.ZcAge=uint32(0);s.ZcPeriod=single(0);s.ZcCount=uint16(0);
s.ZcFound=false;s.ZcArmed=false;s.ZcValue=single(0);
s.ZcCountdown=int32(-1);s.ZcNextSector=uint8(0);
s.AcquireStage=uint8(0);s.AcquireTheta=single(0);s.AcquireAge=uint32(0);
s.AcquisitionReady=false;
s.SensorFault=uint16(0);s.ActiveFaults=uint16(0);s.FaultBits=uint16(0);
end
