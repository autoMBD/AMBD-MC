function [counts,enabled] = commutate(sector,direction,modulation,period)
%COMMUTATE - Generate complementary active-leg timer counts
%   COUNTS = COMMUTATE(SECTOR,DIRECTION,MODULATION,PERIOD) returns the
%   three high-side counts for bipolar six-step modulation.
%
%   [COUNTS,ENABLED] = COMMUTATE(...) also returns the phase enable mask.
%   A disabled phase has both switches off; an enabled low side is the
%   complement of its high side, with deadtime supplied by the adapter.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
counts=zeros(3,1,'uint16');enabled=false(3,1);
if sector<uint8(1) || sector>uint8(6) || abs(direction)~=int8(1) ...
        || ~isfinite(modulation) || period==uint16(0)
    return
end
pairs=uint8([1,2;1,3;2,3;2,1;3,1;3,2]);
source=pairs(sector,1);sink=pairs(sector,2);
if direction<int8(0)
    temporary=source;source=sink;sink=temporary;
end
m=min(max(double(modulation),0),1);
q=uint16(floor((1+m)*double(period)/2+.5));
counts(source)=q;counts(sink)=period-q;
enabled(source)=true;enabled(sink)=true;
end
