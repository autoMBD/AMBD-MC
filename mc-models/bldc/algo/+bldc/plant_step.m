function next = plant_step(x,counts,phaseEnable,gate,vdc,loadTorque,p,dt)
% SPDX-License-Identifier: MIT
%PLANT_STEP Advance the phase-domain BLDC with diode zero-current events.
next=double(x(:));
n=max(1,double(p.PlantSubsteps)); h=double(dt)/n;
R=double(p.Rs); tau=double(p.Ls)/R; J=double(p.Inertia);
B=double(p.Friction); ke=double(p.Ke); pp=double(p.PolePairs);
active=logical(phaseEnable(:)) & logical(gate);
for sub=1:n
    shape=bldc.trapezoid(next(4)+[0;-2*pi/3;2*pi/3]);
    e=ke*next(5)*shape; remaining=h; integral=zeros(3,1);
    for segment=1:12
        if remaining<=eps(h), break; end
        i=next(1:3);
        [v,vn,conducting]=bldc.phase_network(i,e,counts,phaseEnable,gate,vdc,p);
        target=(v-vn-e)/R;
        target(~conducting)=0;
        duration=remaining; event=zeros(3,1);
        for phase=1:3
            if ~active(phase) && abs(i(phase))>1e-12 && i(phase)*target(phase)<0
                crossing=-tau*log(-target(phase)/(i(phase)-target(phase)));
                if crossing>=0 && crossing<=duration
                    duration=crossing;
                end
                event(phase)=crossing;
            end
        end
        decay=exp(-duration/tau);
        integral=integral+target*duration+(i-target)*(-tau*expm1(-duration/tau));
        updated=target+(i-target)*decay;
        updated(~conducting)=0;
        hit=event>0 & abs(event-duration)<1e-13*max(1,h);
        updated(hit)=0;
        % Remove floating point KCL residue only from a conducting winding.
        [~,correction]=max(abs(updated));
        updated(correction)=updated(correction)-sum(updated);
        next(1:3)=updated;
        remaining=remaining-duration;
    end
    torque=ke*dot(shape,integral/h)-double(loadTorque);
    oldOmega=next(5);
    if B>0
        next(5)=oldOmega*exp(-B*h/J)+torque/B*(-expm1(-B*h/J));
    else
        next(5)=oldOmega+torque*h/J;
    end
    next(4)=mod(next(4)+pp*(oldOmega+next(5))*h/2,2*pi);
end
end
