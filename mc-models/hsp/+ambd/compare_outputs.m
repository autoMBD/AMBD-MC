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
% File:        compare_outputs.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-07
% Version:     0.1.0
% Description: Compare typed Normal and target results with exact finite-value checks.
% =================================================================================

function result = compare_outputs(reference,target)
%compare_outputs - Compare every typed output value and sample timestamp
%   RESULT = compare_outputs(REFERENCE,TARGET) compares logged Datasets,
%   including nested bus signals. It requires exact numeric equality,
%   identical types and shapes, aligned times and finite, nonempty data.
%
%   See also Simulink.SimulationData.Dataset

records=struct('Signal',{},'Passed',{},'ValueCount',{},'MaxAbsoluteError',{});
result=struct('Passed',false,'ValueCount',0,'Signals',records);
if ~isa(reference,'Simulink.SimulationData.Dataset') || ...
        ~isa(target,'Simulink.SimulationData.Dataset') || ...
        numElements(reference)==0 || numElements(reference)~=numElements(target)
    return;
end
for index=1:numElements(reference)
    first=reference{index};second=target{index};
    if isa(first,'Simulink.SimulationData.Signal'),first=first.Values;end
    if isa(second,'Simulink.SimulationData.Signal'),second=second.Values;end
    records=[records;compareValue(first,second, ...
        sprintf('port%d',index))]; %#ok<AGROW>
end
result.Signals=records;
result.ValueCount=sum([records.ValueCount]);
result.Passed=~isempty(records)&&result.ValueCount>0&&all([records.Passed]);
end

function records=compareValue(a,b,name)
records=struct('Signal',name,'Passed',false,'ValueCount',0,'MaxAbsoluteError',Inf);
if isstruct(a)&&isstruct(b)
    fields=fieldnames(a);
    if isempty(fields)||~isequal(fields,fieldnames(b)),return;end
    records=repmat(records,0,1);
    for index=1:numel(fields)
        field=fields{index};
        records=[records;compareValue(a.(field),b.(field),[name,'.',field])]; %#ok<AGROW>
    end
elseif isa(a,'timeseries')&&isa(b,'timeseries')
    if isempty(a.Time)||isempty(a.Data)||~isequal(a.Time,b.Time)|| ...
            ~strcmp(class(a.Data),class(b.Data))||~isequal(size(a.Data),size(b.Data))
        return;
    end
    first=double(a.Data(:));second=double(b.Data(:));
    records.ValueCount=numel(first);
    records.MaxAbsoluteError=max(abs(first-second));
    records.Passed=all(isfinite(first))&&all(isfinite(second))&&isequal(a.Data,b.Data);
end
end
