function ab = clarke(abc)
%CLARKE Apply the amplitude-invariant three-phase Clarke transformation.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
ab = single([single(2/3)*(abc(1)-single(0.5)*(abc(2)+abc(3))); ...
    single(1/sqrt(3))*(abc(2)-abc(3))]);
end
