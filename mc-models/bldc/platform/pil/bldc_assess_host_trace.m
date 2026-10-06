function assessment = bldc_assess_host_trace(trace,scenario)
%bldc_assess_host_trace - Verify full-rate physical BLDC behavior
%   ASSESSMENT = bldc_assess_host_trace(TRACE,SCENARIO) returns measured
%   metrics and every acceptance check, including full-trace validity.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
checks=struct('Name',{},'Passed',{},'Actual',{},'Limit',{});
required={'Time','OmegaTruth','CurrentTruth','ThetaTruth','Mode','FaultBits', ...
    'CurrentReference','CurrentDemand','Modulation','GateEnable','PhaseEnable', ...
    'DutyCounts','PhaseMask','GateOutput','PositionMode','Sector','OutputDirection', ...
    'FeedbackReady','AcquisitionReady','ZcCount'};
missing=setdiff(required,fieldnames(trace));
checks(end+1)=item('trace_contract',isempty(missing),missing,{});
if ~isempty(missing),assessment=finish(checks,NaN,NaN,[]);return;end
t=double(trace.Time(:));n=numel(t);expected=round(scenario.Duration*16000)+1;
grid=n==expected && n>1 && t(1)==0 && abs(t(end)-scenario.Duration)<1e-9 ...
    && all(isfinite(t)) && all(abs(diff(t)-1/16000)<1e-10);
checks(end+1)=item('complete_sample_grid',grid,n,expected);
names=fieldnames(trace);finite=true;shape=true;
for k=1:numel(names)
    value=trace.(names{k});
    if isnumeric(value) || islogical(value)
        finite=finite && isreal(value) && all(isfinite(value),'all');
        shape=shape && size(value,1)==n;
    end
end
checks(end+1)=item('finite_all_outputs',finite,finite,true);
checks(end+1)=item('full_rate_all_outputs',shape,shape,true);
if ~grid || ~finite || ~shape,assessment=finish(checks,NaN,NaN,[]);return;end
peakCurrent=max(abs(double(trace.CurrentTruth)),[],'all');
peakSpeed=max(abs(double(trace.OmegaTruth)),[],'all');
checks(end+1)=item('phase_current_envelope',peakCurrent<scenario.PeakCurrentLimit,peakCurrent,scenario.PeakCurrentLimit);
checks(end+1)=item('speed_envelope',peakSpeed<=scenario.PeakSpeedLimit,peakSpeed,scenario.PeakSpeedLimit);
kcl=max(abs(sum(double(trace.CurrentTruth),2)));
checks(end+1)=item('plant_current_conservation',kcl<1e-5,kcl,1e-5);
limit=double(scenario.Control.CurrentLimit);
reference=double(trace.CurrentReference);demand=double(trace.CurrentDemand);
checks(end+1)=item('current_reference_bound',all(reference>=0 & reference<=limit+1e-6) ...
    && all(demand>=0 & demand<=limit+1e-6),[min(reference),max(reference),max(demand)],[0,limit]);
checks(end+1)=item('modulation_bound',all(trace.Modulation>=0 & trace.Modulation<=scenario.Control.MaxModulation+single(1e-6)), ...
    [min(trace.Modulation),max(trace.Modulation)],[0,double(scenario.Control.MaxModulation)]);
gate=logical(trace.GateOutput);mask=logical(trace.PhaseMask);counts=trace.DutyCounts;
checks(end+1)=item('gate_and_mask_monitor',isequal(gate,logical(trace.GateEnable)) ...
    && isequal(mask,logical(trace.PhaseEnable)),0,0);
checks(end+1)=item('disabled_outputs',all(~any(mask(~gate,:),2)) ...
    && all(counts(~gate,:)==0,'all'),sum(any(mask(~gate,:),2)),0);
checks(end+1)=item('two_active_legs',all(sum(mask(gate,:),2)==2),unique(sum(mask(gate,:),2))',2);
safeMode=trace.Mode<=uint8(5) | (trace.PositionMode==uint8(1) & trace.Mode==uint8(9)) ...
    | trace.FaultBits~=uint16(0);
checks(end+1)=item('safe_mode_gate',~any(gate(safeMode)),sum(gate(safeMode)),0);
indices=find(gate);validSector=all(trace.Sector(indices)>=1 & trace.Sector(indices)<=6) ...
    && all(abs(trace.OutputDirection(indices))==1);
checks(end+1)=item('valid_active_sector',validSector,validSector,true);
if validSector
    pairs=[1,2;1,3;2,3;2,1;3,1;3,2];
    selected=pairs(double(trace.Sector(indices)),:);
    reverse=trace.OutputDirection(indices)<0;selected(reverse,:)=selected(reverse,[2,1]);
    source=indices+(selected(:,1)-1)*n;sink=indices+(selected(:,2)-1)*n;
    expectedMask=false(n,3);expectedMask(source)=true;expectedMask(sink)=true;
    expectedCounts=zeros(n,3,'uint16');
    q=uint16(floor((1+double(trace.Modulation(indices)))*double(scenario.Control.PwmPeriod)/2+.5));
    expectedCounts(source)=q;expectedCounts(sink)=scenario.Control.PwmPeriod-q;
    checks(end+1)=item('commutation_mask',isequal(mask,expectedMask),sum(mask~=expectedMask,'all'),0);
    checks(end+1)=item('exact_pwm_quantization',isequal(counts,expectedCounts),sum(counts~=expectedCounts,'all'),0);
end
checks(end+1)=item('selected_position_mode',all(trace.PositionMode==scenario.PositionMode), ...
    double(unique(trace.PositionMode))',double(scenario.PositionMode));
visited=unique(uint8(trace.Mode))';
checks(end+1)=item('required_modes',all(ismember(scenario.RequiredModes,visited)),double(visited),double(scenario.RequiredModes));
unexpected=bitand(uint16(trace.FaultBits),bitcmp(scenario.ExpectedFaultMask));
checks(end+1)=item('unexpected_faults',all(unexpected==0),double(unique(trace.FaultBits))',double(scenario.ExpectedFaultMask));
allowed=zeros(n,1,'uint16');
for k=1:size(scenario.FaultWindows,1)
    w=scenario.FaultWindows(k,:);last=Inf;
    if isfield(scenario,'Command')
        reset=find(t>=w(3)-1e-10 & scenario.Command==uint8(0),1);
        if ~isempty(reset),last=t(reset)+1/16000;end
    end
    ix=t>=w(1)-1e-10 & t<last;allowed(ix)=bitor(allowed(ix),uint16(w(4)));
end
premature=bitand(uint16(trace.FaultBits),bitcmp(allowed));
checks(end+1)=item('faults_only_in_declared_episodes',all(premature==0),sum(premature~=0),0);
checks(end+1)=item('valid_lifecycle_codes',all(trace.Mode<=uint8(15)),double(unique(trace.Mode))',[0,15]);
if isfield(scenario,'Command')
    inputMatch=isfield(trace,'Input') && isfield(scenario,'VoltageValid');
    inputNames={'Control','SpeedReq','Fault','Vdc','VoltageValid'};
    expectedInputs={scenario.Command,scenario.Speed,scenario.Fault,scenario.Vdc,scenario.VoltageValid};
    for k=1:numel(inputNames)
        inputMatch=inputMatch && isfield(trace.Input,inputNames{k}) ...
            && isequal(trace.Input.(inputNames{k}),expectedInputs{k});
    end
    checks(end+1)=item('recorded_commands_match_scenario',inputMatch,inputMatch,true);
end
for k=1:size(scenario.SteadyWindows,1)
    w=scenario.SteadyWindows(k,:);ix=t>=w(1) & t<=w(2);
    speed=double(trace.OmegaTruth(ix));error=mean(abs(speed-w(3)));
    tolerance=max(5,.05*abs(w(3)));ripple=max(speed)-min(speed);
    rippleLimit=max(10,.15*abs(w(3)));
    checks(end+1)=item(sprintf('steady_error_%d',k),any(ix) && error<=tolerance,error,tolerance); %#ok<AGROW>
    checks(end+1)=item(sprintf('steady_ripple_%d',k),any(ix) && ripple<=rippleLimit,ripple,rippleLimit); %#ok<AGROW>
end
for k=1:size(scenario.OvershootWindows,1)
    w=scenario.OvershootWindows(k,:);ix=t>=w(1) & t<w(2);
    peak=max(sign(w(3))*double(trace.OmegaTruth(ix)));bound=1.2*abs(w(3));
    checks(end+1)=item(sprintf('directional_overshoot_%d',k),any(ix) && peak<=bound,peak,bound); %#ok<AGROW>
end
for k=1:size(scenario.ClosedWindows,1)
    w=scenario.ClosedWindows(k,:);ix=t>=w(1) & t<=w(2);
    ready=all(trace.Mode(ix)==uint8(14) & trace.FeedbackReady(ix));
    if scenario.PositionMode==uint8(1)
        ready=ready && all(trace.AcquisitionReady(ix) & trace.ZcCount(ix)>=scenario.Control.ZcRequired);
    end
    checks(end+1)=item(sprintf('qualified_closed_loop_%d',k),any(ix) && ready,ready,true); %#ok<AGROW>
end
for k=1:size(scenario.LowForcedWindows,1)
    w=scenario.LowForcedWindows(k,:);ix=t>=w(1) & t<=w(2);
    checks(end+1)=item(sprintf('declared_low_forced_%d',k),any(ix) ...
        && all(trace.Mode(ix)==uint8(8) & ~trace.FeedbackReady(ix)),double(unique(trace.Mode(ix)))',8); %#ok<AGROW>
end
for k=1:size(scenario.DisabledWindows,1)
    w=scenario.DisabledWindows(k,:);ix=t>=w(1) & t<=w(2);
    checks(end+1)=item(sprintf('gate_disabled_%d',k),any(ix) && ~any(gate(ix)),sum(gate(ix)),0); %#ok<AGROW>
end
for k=1:size(scenario.FaultWindows,1)
    w=scenario.FaultWindows(k,:);ix=t>=w(2)-1e-10 & t<w(3);
    detected=all(bitand(uint16(trace.FaultBits(ix)),uint16(w(4)))==uint16(w(4)));
    checks(end+1)=item(sprintf('fault_deadline_%d',k),any(ix) && detected && ~any(gate(ix)),detected,true); %#ok<AGROW>
end
for k=1:size(scenario.LatchWindows,1)
    w=scenario.LatchWindows(k,:);ix=t>=w(1) & t<=w(2);
    expectedBits=scenario.ExpectedFaultMask;
    checks(end+1)=item(sprintf('fault_latch_%d',k),any(ix) && all(trace.Mode(ix)==uint8(3)) ...
        && all(bitand(trace.FaultBits(ix),expectedBits)==expectedBits) ...
        && ~any(gate(ix)),double(unique(trace.FaultBits(ix)))',double(expectedBits)); %#ok<AGROW>
end
for k=1:size(scenario.SaturationWindows,1)
    w=scenario.SaturationWindows(k,:);ix=t>=w(1) & t<w(2);
    dwell=sum(ix & reference>=.99*limit)/16000;
    checks(end+1)=item(sprintf('saturation_dwell_%d',k),dwell>=w(3),dwell,w(3)); %#ok<AGROW>
end
for k=1:size(scenario.UnsaturatedWindows,1)
    w=scenario.UnsaturatedWindows(k,:);ix=t>=w(1) & t<=w(2);peak=max(reference(ix));
    checks(end+1)=item(sprintf('saturation_recovery_%d',k),any(ix) && peak<.95*limit,peak,.95*limit); %#ok<AGROW>
end
for k=1:size(scenario.StopOrigins,1)
    w=scenario.StopOrigins(k,:);ix=find(t>=w(1)-1e-10,1);
    correct=~isempty(ix) && ix>1 && trace.Mode(ix-1)==uint8(w(2)) && trace.Mode(ix)==uint8(15);
    checks(end+1)=item(sprintf('stop_origin_%d',k),correct,correct,true); %#ok<AGROW>
end
for k=1:size(scenario.StopWindows,1)
    w=scenario.StopWindows(k,:);deadline=min(w(2),w(1)+double(scenario.Control.StopTimeout));
    idle=find(t>=w(1)-1e-10 & t<=deadline+1e-10 & trace.Mode==uint8(2),1);
    settled=~isempty(idle) && ~gate(idle) && abs(trace.OmegaTruth(idle))<=scenario.Control.StopSpeed;
    checks(end+1)=item(sprintf('bounded_stop_to_idle_%d',k),settled,settled,true); %#ok<AGROW>
end
for k=1:size(scenario.ReversalWindows,1)
    w=scenario.ReversalWindows(k,:);start=find(t>=w(1)-1e-10,1);
    armed=find(t>=w(1)-1e-10 & trace.Direction==int8(w(3)),1);
    safe=~isempty(armed) && ~isempty(start) && armed>start;
    if safe
        lastDriven=find(gate(1:armed-1),1,'last');coast=Inf;
        if ~isempty(lastDriven),coast=t(armed)-t(lastDriven)-1/16000;end
        previous=start:armed-1;
        safe=t(armed)-w(1)<=double(scenario.Control.StopTimeout) ...
            && abs(trace.OmegaTruth(armed))<=scenario.Control.StopSpeed ...
            && any(trace.Mode(previous)==uint8(15)) ...
            && any(trace.Mode(previous)==uint8(2)) ...
            && ~any(gate(previous) & trace.OutputDirection(previous)==int8(w(3))) ...
            && coast>=double(scenario.Control.StopCoastTime)-2/16000;
    end
    checks(end+1)=item(sprintf('reversal_after_verified_stop_%d',k),safe,safe,true); %#ok<AGROW>
end
assessment=finish(checks,peakCurrent,peakSpeed,visited);
end

function result=finish(checks,current,speed,modes)
result=struct('Passed',all([checks.Passed]),'Checks',checks, ...
    'PeakCurrent',current,'PeakSpeed',speed,'VisitedModes',modes);
end

function value=item(name,passed,actual,limit)
value=struct('Name',name,'Passed',logical(passed));
value.Actual=actual;value.Limit=limit;
end
