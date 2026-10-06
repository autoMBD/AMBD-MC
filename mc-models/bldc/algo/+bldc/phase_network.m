function [pole,neutral,conducting] = phase_network(current,bemf,counts,phaseEnable,gate,vdc,p)
% SPDX-License-Identifier: MIT
%PHASE_NETWORK Resolve average inverter poles and ideal freewheel diodes.
i=double(current(:)); e=double(bemf(:)); bus=double(vdc);
active=logical(phaseEnable(:)) & logical(gate);
pole=bus*double(counts(:))/double(p.PwmPeriod);
conducting=active | abs(i)>1e-12;
pole(~active & i>1e-12)=0;
pole(~active & i< -1e-12)=bus;
if ~any(conducting)
    lo=-min(e); hi=bus-max(e);
    if lo<=hi
        neutral=(lo+hi)/2;
        pole=neutral+e;
        return
    end
    [~,low]=min(e); [~,high]=max(e);
    conducting([low high])=true; pole(low)=0; pole(high)=bus;
end
neutral=0;
for pass=1:3
    neutral=sum(pole(conducting)-e(conducting)-double(p.Rs)*i(conducting))/sum(conducting);
    free=~conducting;
    candidate=neutral+e;
    lower=free & candidate<0;
    upper=free & candidate>bus;
    if ~any(lower | upper)
        pole(free)=candidate(free);
        return
    end
    pole(lower)=0; pole(upper)=bus;
    conducting=conducting | lower | upper;
end
end
