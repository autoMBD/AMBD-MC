% =================================================================================
% The MIT License
% MIT许可证
%
% <https://opensource.org/license/mit>
%
% SPDX short identifier / SPDX 短标识符：MIT
%
% Copyright (c) 2026 autoMBD
% 版权所有 (c) 2026 autoMBD
%
% Permission is hereby granted, free of charge, to any person obtaining a
% copy of this software and associated documentation files (the “Software”),
% to deal in the Software without restriction, including without limitation
% the rights to use, copy, modify, merge, publish, distribute, sublicense,
% and/or sell copies of the Software, and to permit persons to whom the
% Software is furnished to do so, subject to the following conditions:
% 特此向获得本软件及相关文档（合称“本软件”）副本的任何人免费授予不受限制地利用本软
% 件的许可，包括而不限于：使用、复制、修改、合并、发布、分发、分许可和/或销售本软
% 件副本，并允许本软件的接收者也获得前述许可，但须遵守以下条件：
%
% The above copyright notice and this permission notice shall be included
% in all copies or substantial portions of the Software.
% 以上版权声明及本许可声明应包含在本软件的所有副本或主要部分中。
%
% THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
% MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
% NONINFRINGEMENT. IN NO EVENT SHALLTHE AUTHORS OR COPYRIGHT
% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
% IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
% CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.
% 本软件系“按原样”提供，不包含任何形式的明示或默示保证，包括但不限于适销性、特定
% 目的适用性及不侵权的保证。在任何情况下，无论是在合同、侵权或其他案件中，作者或版
% 权持有人均不对因本软件、或因本软件的使用或其他利用而引起的、引发的或与之相关的任
% 何权利主张、损害赔偿或其他责任承担责任。
% =================================================================================
% Project:     autoMBD Motor Control <https://github.com/autoMBD/AMBD-MC>
% File:        bldc_read_trace.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Read exact full-rate host or controller replay outputs
% =================================================================================

function trace = bldc_read_trace(out,kind)
%bldc_read_trace - Read exact full-rate host or controller replay outputs
%   TRACE = bldc_read_trace(OUT,KIND) reads KIND "host" or "replay" and
%   rejects missing signals, incompatible sample counts or shifted clocks.

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
