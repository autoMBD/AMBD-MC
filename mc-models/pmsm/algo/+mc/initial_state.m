function s = initial_state(p)
%INITIAL_STATE Construct deterministic controller memory without side effects.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
s.Tick=uint32(0);
s.Mode=uint8(0);
s.PreviousMode=uint8(0);
s.ModeTicks=uint32(0);
s.FaultBits=uint16(0);
s.ActiveFaults=uint16(0);
s.FastTick=false;
s.SlowTick=false;
s.Command=uint8(0);
s.Direction=single(1);
s.SpeedRequest=single(0);
s.SpeedRamp=single(0);
s.ThetaOpen=single(0);
s.OmegaOpen=single(0);
s.ThetaControl=single(0);
s.OmegaControl=single(0);
s.ReferenceDq=single([0;0]);
s.CurrentIntegral=single([0;0]);
s.SpeedIntegral=single(0);
s.Current=single([0;0;0]);
s.CurrentDq=single([0;0]);
s.Voltage=single([0;0]);
s.Duty=single([0.5;0.5;0.5]);
s.GateEnable=false;
s.StopOpenLoop=false;
s.ObserverReady=false;
s.ObserverGoodTicks=uint32(0);
s.Observer=mc.observer_initial(p,single(0),single([0;0]));
s.PositionPrev=single(0);
s.PositionSpeed=single(0);
s.Gains=single([p.KpSpeed;p.KiSpeed;p.KpD;p.KiD;p.KpQ;p.KiQ]);
s.Startup=single([p.AlignCurrent;p.AlignTime;p.OpenLoopAccel;p.ObserverBandwidth]);
end
