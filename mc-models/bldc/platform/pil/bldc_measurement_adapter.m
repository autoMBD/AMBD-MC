function [raw,hall,terminal,next] = bldc_measurement_adapter(current,hallIn,terminalIn,mode,currentOffset,terminalOffset,p,state)
% SPDX-License-Identifier: MIT
% Host sensor fault adapter with explicit sample memory.
% Freeze modes retain the preceding valid sample until normal input resumes.
%#codegen
raw=uint16(min(65535,max(0,round(double(p.AdcOffset)+ ...
    double(p.AdcCountsPerAmp)*(double(current)+double(currentOffset))))));
hall=hallIn;terminal=terminalIn+terminalOffset;next=state;
switch mode
    case uint8(1)
        hall=uint8(0);
    case uint8(2)
        hall=uint8(7);
    case uint8(3)
        hall=state.Hall;
    case uint8(4)
        sector=bldc.hall_decode(hallIn);
        lookup=uint8([5 4 6 2 3 1]);
        if sector>0,hall=lookup(mod(double(sector)+1,6)+1);end
    case uint8(5)
        terminal=state.Terminal;
    case uint8(6)
        terminal=nan(3,1,'single');
end
if mode~=uint8(3) && hall>=uint8(1) && hall<=uint8(6)
    next.Hall=hall;
end
if mode~=uint8(5) && all(isfinite(terminal))
    next.Terminal=terminal;
end
end
