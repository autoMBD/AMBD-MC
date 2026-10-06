function assessment = mc_assess_host_trace(trace,scenario)
%MC_ASSESS_HOST_TRACE Check physical behavior, lifecycle and fault containment.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
checks=struct('Name',{},'Passed',{},'Actual',{},'Limit',{});
checks(end+1)=check('full_time_interval', ...
    trace.Time(end)>=scenario.Duration-1e-8,trace.Time(end),scenario.Duration);
checks(end+1)=check('full_sample_log', ...
    numel(trace.Time)==round(scenario.Duration*16000)+1, ...
    numel(trace.Time),round(scenario.Duration*16000)+1);
checks(end+1)=check('sample_grid',trace.Time(1)==0 ...
    && all(isfinite(trace.Time)) && all(abs(diff(trace.Time)-1/16000)<1e-9),0,0);
finiteNames={'OmegaTruth','CurrentTruth','ThetaTruth','Omega','Theta','Current', ...
    'CurrentDq','ReferenceDq','Voltage','Duty','FluxMagnitude'};
finite=true;
for index=1:numel(finiteNames)
    finite=finite && all(isfinite(trace.(finiteNames{index})),'all');
end
checks(end+1)=check('finite_signals',finite,double(finite),1);
peakCurrent=max(abs(double(trace.CurrentTruth)),[],'all');
checks(end+1)=check('phase_current_trip_envelope', ...
    peakCurrent<scenario.PeakCurrentLimit,peakCurrent,scenario.PeakCurrentLimit);
peakSpeed=max(abs(double(trace.OmegaTruth)),[],'all');
checks(end+1)=check('speed_overshoot_envelope', ...
    peakSpeed<=scenario.PeakSpeedLimit,peakSpeed,scenario.PeakSpeedLimit);
for index=1:size(scenario.OvershootWindows,1)
    window=scenario.OvershootWindows(index,:);
    selected=trace.Time>=window(1) & trace.Time<window(2);
    peak=max(sign(window(3))*double(trace.OmegaTruth(selected)));
    limit=1.2*abs(window(3));
    checks(end+1)=check(sprintf('directional_overshoot_%d',index), ...
        any(selected) && peak<=limit,peak,limit);
end
referenceMagnitude=sqrt(sum(double(trace.ReferenceDq).^2,2));
referenceLimit=double(scenario.Control.CurrentLimit);
checks(end+1)=check('current_reference_bound', ...
    all(referenceMagnitude<=referenceLimit+1e-5),max(referenceMagnitude),referenceLimit);
for index=1:size(scenario.SaturationWindows,1)
    window=scenario.SaturationWindows(index,:);
    selected=trace.Time>=window(1) & trace.Time<window(2);
    dwell=sum(selected & referenceMagnitude>=0.99*referenceLimit)/16000;
    checks(end+1)=check(sprintf('current_saturation_dwell_%d',index), ...
        dwell>=window(3),dwell,window(3));
end
for index=1:size(scenario.UnsaturatedWindows,1)
    window=scenario.UnsaturatedWindows(index,:);
    selected=trace.Time>=window(1) & trace.Time<=window(2);
    peak=max(referenceMagnitude(selected));
    checks(end+1)=check(sprintf('current_limit_recovery_%d',index), ...
        any(selected) && peak<0.95*referenceLimit,peak,0.95*referenceLimit);
end
checks(end+1)=check('duty_bounds',all(trace.Duty>=0 & trace.Duty<=1,'all'), ...
    [min(trace.Duty,[],'all'),max(trace.Duty,[],'all')],[0,1]);
checks(end+1)=check('selected_position_mode', ...
    all(trace.PositionMode==scenario.PositionMode),double(unique(trace.PositionMode))',double(scenario.PositionMode));
checks(end+1)=check('gate_matches_monitor', ...
    isequal(trace.GateOutput,logical(trace.GateEnable)),0,0);
visited=unique(uint8(trace.Mode))';
checks(end+1)=check('required_lifecycle_modes', ...
    all(ismember(scenario.RequiredModes,visited)),double(visited),double(scenario.RequiredModes));
faultMask=scenario.ExpectedFaultMask;
unexpected=bitand(uint16(trace.FaultBits),bitcmp(faultMask));
checks(end+1)=check('no_unexpected_faults',all(unexpected==0),double(unique(trace.FaultBits))',double(faultMask));
for index=1:size(scenario.SteadyWindows,1)
    window=scenario.SteadyWindows(index,:);
    selected=trace.Time>=window(1) & trace.Time<=window(2);
    errorValue=max(abs(double(trace.OmegaTruth(selected))-window(3)));
    tolerance=max(5,0.05*abs(window(3)));
    checks(end+1)=check(sprintf('steady_speed_%d',index), ...
        any(selected) && errorValue<=tolerance,errorValue,tolerance);
end
for index=1:size(scenario.DisabledWindows,1)
    window=scenario.DisabledWindows(index,:);
    selected=trace.Time>=window(1) & trace.Time<=window(2);
    checks(end+1)=check(sprintf('gate_disabled_%d',index), ...
        any(selected) && ~any(trace.GateOutput(selected)),double(sum(trace.GateOutput(selected))),0);
end
for index=1:size(scenario.FaultWindows,1)
    window=scenario.FaultWindows(index,:);
    % Allow exactly one controller sample for a sampled external fault.
    selected=trace.Time>=window(1)+1/16000-1e-9 & trace.Time<window(2);
    detected=bitand(uint16(trace.FaultBits(selected)),faultMask)~=0;
    checks(end+1)=check(sprintf('fault_latency_%d',index), ...
        any(selected) && all(detected) && ~any(trace.GateOutput(selected)),double(all(detected)),1);
end
for index=1:size(scenario.LatchWindows,1)
    window=scenario.LatchWindows(index,:);
    selected=trace.Time>=window(1) & trace.Time<=window(2);
    checks(end+1)=check(sprintf('fault_latch_%d',index), ...
        any(selected) && all(trace.Mode(selected)==uint8(3)) ...
        && ~any(trace.GateOutput(selected)),double(unique(trace.Mode(selected)))',3);
end
assessment.Passed=all([checks.Passed]);
assessment.Checks=checks;
assessment.PeakCurrent=peakCurrent;
assessment.PeakSpeed=peakSpeed;
assessment.VisitedModes=visited;
end

function item=check(name,passed,actual,limit)
item=struct('Name',name,'Passed',logical(passed),'Actual',actual,'Limit',limit);
end
