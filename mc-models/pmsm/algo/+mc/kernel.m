function s = kernel(u,s,p)
%KERNEL Schedule fast and divided slow tasks using accepted sample ticks.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
s.FastTick=u.DrivingEvent;
s.SlowTick=false;
s.PreviousMode=s.Mode;
if s.FastTick
    if s.Tick==intmax('uint32')
        s.Tick=uint32(0);
    else
        s.Tick=s.Tick+uint32(1);
    end
    s.SlowTick=rem(s.Tick,uint32(p.SpeedDivider))==uint32(0);
    if s.ModeTicks<intmax('uint32')
        s.ModeTicks=s.ModeTicks+uint32(1);
    end
end
end
