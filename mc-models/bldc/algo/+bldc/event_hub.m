function s = event_hub(u,s,~)
%event_hub - Latch commands with unconditional safe-reset priority
%   S = event_hub(U,S,P) bounds the signed electrical speed request.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
p=s.Parameters;
if u.CommandEvent || u.Control==uint8(0)
    previousRequest=s.SpeedRequest;
    s.Command=u.Control;
    if isfinite(u.SpeedReq)
        s.SpeedRequest=min(max(u.SpeedReq,-p.SpeedLimit),p.SpeedLimit);
    else
        s.SpeedRequest=single(0);
    end
    if p.PositionMode==uint8(1) && s.Mode==uint8(8) ...
            && abs(previousRequest)<p.LowSpeedThreshold ...
            && abs(s.SpeedRequest)>=p.LowSpeedThreshold
        s.ModeTicks=uint32(0);
    end
end
end
