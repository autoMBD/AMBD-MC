function trace = bldc_read_trace(out,kind)
%bldc_read_trace - Read exact full-rate host or controller replay outputs
%   TRACE = bldc_read_trace(OUT,KIND) reads KIND "host" or "replay" and
%   rejects missing signals, incompatible sample counts or shifted clocks.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
data=out.yout;
if string(kind)=="host"
    assert(data.numElements==9,'bldc:OutputContract','Expected nine host outputs.');
    trace.Time=double(data.getElement(1).Values.Time(:));
    trace.OmegaTruth=samples(data.getElement(1).Values,trace.Time);
    trace.CurrentTruth=samples(data.getElement(2).Values,trace.Time);
    trace.ThetaTruth=samples(data.getElement(3).Values,trace.Time);
    monitor=data.getElement(4).Values;
    trace.DutyCounts=samples(data.getElement(5).Values,trace.Time);
    trace.PhaseMask=logical(samples(data.getElement(6).Values,trace.Time));
    trace.GateOutput=logical(samples(data.getElement(7).Values,trace.Time));
    debug=data.getElement(8).Values;recorded=data.getElement(9).Values;
    names=fieldnames(recorded);trace.Input=struct;
    for k=1:numel(names),trace.Input.(names{k})=samples(recorded.(names{k}),trace.Time);end
elseif string(kind)=="replay"
    assert(data.numElements==7,'bldc:OutputContract','Expected seven controller outputs.');
    trace.Time=double(data.getElement(1).Values.Time(:));
    trace.DutyCounts=[samples(data.getElement(1).Values,trace.Time), ...
        samples(data.getElement(2).Values,trace.Time),samples(data.getElement(3).Values,trace.Time)];
    trace.PhaseMask=logical(samples(data.getElement(4).Values,trace.Time));
    trace.GateOutput=logical(samples(data.getElement(5).Values,trace.Time));
    debug=data.getElement(6).Values;monitor=data.getElement(7).Values;
else
    error('bldc:TraceKind','Trace kind must be host or replay.');
end
trace.DebugData=samples(debug.Data,trace.Time);
trace.DebugEnabled=logical(samples(debug.Enabled,trace.Time));
names=fieldnames(monitor);
for k=1:numel(names),trace.(names{k})=samples(monitor.(names{k}),trace.Time);end
end

function value=samples(signal,time)
assert(isequal(double(signal.Time(:)),time),'bldc:TraceTime','Signal clocks differ.');
count=numel(time);value=signal.Data;
if size(value,1)==count,value=reshape(value,count,[]);
elseif size(value,ndims(value))==count
    value=reshape(permute(value,[ndims(value),1:ndims(value)-1]),count,[]);
else
    error('bldc:TraceShape','Signal shape does not match the full clock.');
end
end
