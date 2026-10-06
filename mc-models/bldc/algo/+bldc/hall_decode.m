function sector = hall_decode(code)
%hall_decode - Convert an encoded Hall sample to a commutation sector
%   SECTOR = hall_decode(CODE) maps the declared six Hall codes to 1:6.
%   Invalid codes return zero and cannot select an enabled phase pair.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
lookup=uint8([6,4,5,2,1,3]);
sector=uint8(0);
if code>=uint8(1) && code<=uint8(6)
    sector=lookup(code);
end
end
