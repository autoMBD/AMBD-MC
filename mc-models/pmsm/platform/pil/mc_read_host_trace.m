function trace = mc_read_host_trace(out)
%MC_READ_HOST_TRACE Extract full-rate host-harness outputs by contract.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
dataset=out.yout;
assert(dataset.numElements==6,'mc:OutputContract','Host harness must export six outputs.');
speed=dataset.getElement(1).Values;
trace.Time=double(speed.Time(:));
trace.OmegaTruth=samples(speed);
trace.CurrentTruth=samples(dataset.getElement(2).Values);
monitor=dataset.getElement(3).Values;
names=fieldnames(monitor);
for index=1:numel(names)
    trace.(names{index})=samples(monitor.(names{index}));
end
trace.DutyCounts=samples(dataset.getElement(4).Values);
trace.GateOutput=logical(samples(dataset.getElement(5).Values));
trace.ThetaTruth=samples(dataset.getElement(6).Values);
end

function data=samples(signal)
count=numel(signal.Time);
data=signal.Data;
if size(data,1)==count
    data=reshape(data,count,[]);
elseif size(data,ndims(data))==count
    data=reshape(permute(data,[ndims(data),1:ndims(data)-1]),count,[]);
else
    error('mc:SignalShape','Logged signal shape does not match its time vector.');
end
end
