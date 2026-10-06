function s = kernel(u,s,~)
%KERNEL - Advance explicit BLDC timing and sample feedback
%   S = KERNEL(U,S,P) handles one invocation without hidden memory.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
p=s.Parameters;
s.PreviousMode=s.Mode;s.FastTick=u.DrivingEvent;s.SpeedTick=false;
s.Current=(single(u.CurrentRaw)-p.AdcOffset)/p.AdcCountsPerAmp;
s.SensorFault=uint16(0);
if s.FastTick
    % Saturating ages retain timeout meaning even after long execution.
    s.Tick=s.Tick+uint32(1);s.ModeTicks=s.ModeTicks+uint32(1);
    s.SlowCounter=s.SlowCounter+uint16(1);
    if s.SlowCounter>=p.SpeedDivider
        s.SlowCounter=uint16(0);s.SpeedTick=u.TimerEvent;
    end
    s=bldc.feedback(u,s,p);
end
end
