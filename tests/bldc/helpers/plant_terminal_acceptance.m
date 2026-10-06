function result=plant_terminal_acceptance(trace)
% SPDX-License-Identifier: MIT
%PLANT_TERMINAL_ACCEPTANCE Qualify driven floating voltage and release events.
[traceValid,failureReason]=validate_complete_trace(trace);
if ~traceValid
    result=struct('applicable',true,'pass',false,'traceValid',false, ...
        'failureReason',failureReason,'coveragePass',false,'voltagePass',false, ...
        'crossingPass',false,'slopePass',false,'releasePass',false);
    return
end
t=trace.time(:); tn=trace.nativeTime(:); phase=trace.floatPhase;
Ts=trace.sampleTime; nativeStep=trace.nativeStep; sw=trace.switchTime;
nativeCurrent=double(trace.nativeCurrent);
nativeTerminal=double(trace.nativeTerminal);
alignedCurrent=interp1(tn,nativeCurrent,t,'linear');
alignedTerminal=interp1(tn,nativeTerminal,t,'linear');
hostCurrent=double(trace.hostCurrent); hostTerminal=double(trace.hostTerminal);
blanked=t>=sw+2*Ts;
clamped=blanked & abs(hostCurrent(:,phase))>=.05 & abs(alignedCurrent(:,phase))>=.05;
floating=blanked & abs(hostCurrent(:,phase))<=1e-5 & abs(alignedCurrent(:,phase))<=1e-5;
fitWindow=floating & abs(t-trace.expectedCrossing)<=2*Ts+eps(Ts);
coveragePass=nnz(clamped)>=2 && nnz(floating)>=20 && nnz(fitWindow)>=3 && ...
    any(floating & t<trace.expectedCrossing-2*Ts) && ...
    any(floating & t>trace.expectedCrossing+2*Ts);
clampError=maximum_or_inf(abs(hostTerminal(clamped,:)-alignedTerminal(clamped,:)));
floatError=maximum_or_inf(abs(hostTerminal(floating,:)-alignedTerminal(floating,:)));
clampedPhaseError=maximum_or_inf(abs(hostTerminal(clamped,phase)-alignedTerminal(clamped,phase)));
floatingPhaseError=maximum_or_inf(abs(hostTerminal(floating,phase)-alignedTerminal(floating,phase)));
hostRailError=maximum_or_inf(abs(hostTerminal(clamped,phase)-trace.rail));
nativeRailError=maximum_or_inf(abs(alignedTerminal(clamped,phase)-trace.rail));
voltagePass=max([clampError floatError hostRailError nativeRailError])<=.005;
[hostCross,hostCount]=crossing(t,hostTerminal(:,phase)-6,floating);
[nativeCross,nativeCount]=crossing(t,alignedTerminal(:,phase)-6,floating);
crossingPass=hostCount==1 && nativeCount==1 && ...
    abs(hostCross-nativeCross)<=Ts && ...
    abs(hostCross-trace.expectedCrossing)<=Ts && ...
    abs(nativeCross-trace.expectedCrossing)<=Ts;
hostSlope=NaN; nativeSlope=NaN;
if nnz(fitWindow)>=3
    fit=polyfit(t(fitWindow)-trace.expectedCrossing,hostTerminal(fitWindow,phase),1);
    hostSlope=fit(1);
    fit=polyfit(t(fitWindow)-trace.expectedCrossing,alignedTerminal(fitWindow,phase),1);
    nativeSlope=fit(1);
end
slopePass=abs(hostSlope/trace.expectedSlope-1)<=.05 && ...
    abs(nativeSlope/trace.expectedSlope-1)<=.05;
hostRelease=release_time(t,hostCurrent(:,phase),sw);
nativeRelease=release_time(tn,nativeCurrent(:,phase),sw);
hostVoltageRelease=voltage_release_time(t,hostTerminal(:,phase),sw+2*nativeStep,trace.rail);
nativeVoltageRelease=voltage_release_time(tn,nativeTerminal(:,phase),sw+2*nativeStep,trace.rail);
releaseTolerance=Ts+2*nativeStep;
releasePass=all(isfinite([hostRelease nativeRelease hostVoltageRelease nativeVoltageRelease])) && ...
    abs(hostRelease-nativeRelease)<=releaseTolerance && ...
    abs(hostVoltageRelease-nativeVoltageRelease)<=releaseTolerance && ...
    abs(hostRelease-hostVoltageRelease)<=releaseTolerance && ...
    abs(nativeRelease-nativeVoltageRelease)<=releaseTolerance && ...
    max(hostRelease,nativeRelease)<trace.expectedCrossing-2*Ts;
result=struct('applicable',true,'pass',coveragePass && voltagePass && ...
    crossingPass && slopePass && releasePass, ...
    'traceValid',true,'failureReason','', ...
    'coveragePass',coveragePass,'voltagePass',voltagePass, ...
    'crossingPass',crossingPass,'slopePass',slopePass,'releasePass',releasePass, ...
    'clampedSamples',nnz(clamped),'floatingSamples',nnz(floating), ...
    'maxClampedVoltageErrorV',clampError,'maxFloatingVoltageErrorV',floatError, ...
    'maxClampedPhaseVoltageErrorV',clampedPhaseError, ...
    'maxFloatingPhaseVoltageErrorV',floatingPhaseError, ...
    'maxHostRailErrorV',hostRailError,'maxNativeRailErrorV',nativeRailError, ...
    'hostCrossingTime',hostCross,'nativeCrossingTime',nativeCross, ...
    'expectedCrossingTime',trace.expectedCrossing, ...
    'hostSlopeVPerS',hostSlope,'nativeSlopeVPerS',nativeSlope, ...
    'expectedSlopeVPerS',trace.expectedSlope, ...
    'hostCurrentReleaseTime',hostRelease,'nativeCurrentReleaseTime',nativeRelease, ...
    'hostVoltageReleaseTime',hostVoltageRelease,'nativeVoltageReleaseTime',nativeVoltageRelease, ...
    'releaseToleranceS',releaseTolerance,'clampedMask',clamped,'floatingMask',floating);
end

function [valid,reason]=validate_complete_trace(trace)
valid=false; reason='Trace must be a scalar struct with the complete measurement contract.';
required={'time','nativeTime','hostCurrent','nativeCurrent','hostTerminal','nativeTerminal', ...
    'floatPhase','sampleTime','nativeStep','switchTime','expectedCrossing','expectedSlope','rail'};
if ~isstruct(trace) || ~isscalar(trace) || ~all(isfield(trace,required)), return; end
for name={'time','nativeTime'}
    data=trace.(name{1});
    reason=[name{1} ' must be a finite real increasing time vector.'];
    if ~isnumeric(data) || ~isreal(data) || ~isvector(data) || numel(data)<2 || ...
            ~all(isfinite(data),'all') || any(diff(data(:))<=0) || data(1)<0
        return
    end
end
for name={'hostCurrent','hostTerminal','nativeCurrent','nativeTerminal'}
    data=trace.(name{1}); count=numel(trace.time);
    if startsWith(name{1},'native'), count=numel(trace.nativeTime); end
    reason=[name{1} ' must contain exactly one finite real three-phase row per timestamp.'];
    if ~isnumeric(data) || ~isreal(data) || ~isequal(size(data),[count 3]) || ...
            ~all(isfinite(data),'all')
        return
    end
end
for name={'floatPhase','sampleTime','nativeStep','switchTime','expectedCrossing','expectedSlope','rail'}
    data=trace.(name{1}); reason=[name{1} ' must be a finite real numeric scalar.'];
    if ~isnumeric(data) || ~isreal(data) || ~isscalar(data) || ~isfinite(data), return; end
end
t=double(trace.time(:)); tn=double(trace.nativeTime(:));
reason='Phase, time coverage, acquisition grid, or event metadata is inconsistent.';
timeTolerance=max(1e-12,32*eps(max([1;t;tn])));
if ~ismember(trace.floatPhase,1:3) || trace.sampleTime<=0 || trace.nativeStep<=0 || ...
        trace.nativeStep>trace.sampleTime || t(1)<tn(1) || t(end)>tn(end) || ...
        any(abs(diff(t)-trace.sampleTime)>timeTolerance) || ...
        any(diff(tn)>trace.nativeStep+timeTolerance) || ...
        trace.switchTime<t(1) || trace.switchTime>=trace.expectedCrossing || ...
        trace.expectedCrossing>=t(end) || trace.expectedSlope>=0 || ~ismember(trace.rail,[0 12])
    return
end
valid=true; reason='';
end

function value=maximum_or_inf(data)
value=Inf;
if ~isempty(data) && all(isfinite(data),'all'), value=max(data,[],'all'); end
end

function [time,count]=crossing(t,v,valid)
ix=find(valid(1:end-1) & valid(2:end) & v(1:end-1)>0 & v(2:end)<=0);
count=numel(ix); time=NaN;
if count==1
    n=ix(1); time=t(n)-v(n)*(t(n+1)-t(n))/(v(n+1)-v(n));
end
end

function time=release_time(t,current,sw)
time=NaN; ix=find(t>=sw & abs(current)<=1e-5,1,'first');
if ~isempty(ix) && any(t>=sw & t<t(ix) & abs(current)>=.05), time=t(ix); end
end

function time=voltage_release_time(t,voltage,start,rail)
time=NaN; ix=find(t>=start & abs(voltage-rail)>.05,1,'first');
if ~isempty(ix), time=t(ix); end
end
