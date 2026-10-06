function s = step(u,s,p)
%STEP - Execute the complete explicit-state BLDC control frame
%   S = STEP(U,S,P) follows the same module order as BLDCFramework.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
s=bldc.tuning(u,s,p);
s=bldc.kernel(u,s,p);
s=bldc.event_hub(u,s,p);
s=bldc.protection(u,s,p);
s=bldc.supervisor(u,s,p);
s=bldc.dataflow(u,s,p);
end
