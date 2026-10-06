function current = acquire(raw,p)
%ACQUIRE Convert offset-binary phase-current ADC counts to amperes.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
current=(single(raw)-p.AdcOffset)/p.AdcCountsPerAmp;
end
