function s = event_hub(u,s,p)
%EVENT_HUB Capture commands and limit the requested operating envelope.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
if u.CommandEvent
    previousRequest=s.SpeedRequest;
    s.Command=u.Control;
    if isfinite(u.SpeedReq)
        s.SpeedRequest=min(max(u.SpeedReq,-p.SpeedLimit),p.SpeedLimit);
    end
    if p.PositionMode==uint8(0) && s.Mode==uint8(8) ...
            && abs(previousRequest)<single(1.25)*p.ObserverMinSpeed ...
            && abs(s.SpeedRequest)>=single(1.25)*p.ObserverMinSpeed
        % A low-speed I/f dwell is not part of a later acquisition attempt.
        s.ModeTicks=uint32(0);
    end
end
if (s.Mode==uint8(0) || s.Mode==uint8(2)) && abs(s.SpeedRequest)>single(1)
    s.Direction=sign(s.SpeedRequest);
end
end
