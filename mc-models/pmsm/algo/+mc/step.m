function s = step(u,s,p)
%STEP Execute the same ordered modules used by MotorFramework.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
s=mc.kernel(u,s,p);
s=mc.tuning(u,s,p);
s=mc.event_hub(u,s,p);
s=mc.protection(u,s,p);
s=mc.supervisor(u,s,p);
s=mc.dataflow(u,s,p);
end
