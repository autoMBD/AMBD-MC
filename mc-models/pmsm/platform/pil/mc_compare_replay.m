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
% File:        mc_compare_replay.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Assess recorded controller outputs without simulation
% =================================================================================

function comparison = mc_compare_replay(reference,actual,pwmPeriod,mode)
%mc_compare_replay - Assess recorded controller outputs without simulation
%   C = mc_compare_replay(REFERENCE,ACTUAL,PERIOD) keeps discrete outputs
%   exact and permits one PWM count only with exact requantization and a
%   common half-count boundary. Continuous duty has an absolute 1e-6 bound;
%   other floating outputs use absolute and relative tolerances of 1e-4.
%   C = mc_compare_replay(...,"RecordedNormalAlignment") requires all
%   recorded controller values and timestamps to be bitwise identical.
%   C reports strict bitwise equality separately from accepted equivalence.
%   See also mc_run_replay

arguments
    reference (1,1) struct
    actual (1,1) struct
    pwmPeriod (1,1) double {mustBeFinite,mustBeInteger, ...
        mustBeBetween(pwmPeriod,1,65535)}
    mode (1,1) string {mustBeMember(mode, ...
        ["NormalVersusSIL","RecordedNormalAlignment"])} = "NormalVersusSIL"
end
alignment=mode=="RecordedNormalAlignment";
required={'Time','DutyCounts','GateOutput','Mode','FaultBits','Tick', ...
    'SpeedRequest','Omega','Theta','Current','CurrentDq','ReferenceDq', ...
    'Voltage','Duty','GateEnable','ObserverReady','FluxMagnitude','PositionMode'};
assert(all(isfield(reference,required)) && all(isfield(actual,required)), ...
    'mc:ReplayRequiredField','Replay evidence is missing required controller outputs.');
assert(~isempty(reference.Time) && ~isempty(actual.Time), ...
    'mc:ReplayRequiredField','Replay evidence must contain samples.');
debugRequired={'Debug_DebugEn','Debug_DebugChannel','Debug_DebugData'};
assert(all(isfield(actual,debugRequired)) ...
    && (alignment || all(isfield(reference,debugRequired))), ...
    'mc:ReplayRequiredField','Replay evidence is missing debug outputs.');
[quantization,pwmViolation]=classifyPWM(reference,actual,pwmPeriod);
comparison=struct('Mode',mode,'Passed',isequal(reference.Time,actual.Time), ...
    'TimeExactlyEqual',isequal(reference.Time,actual.Time), ...
    'AllValuesExactlyEqual',true,'FiniteOutputs',true, ...
    'StrictBitwisePassed',false,'StrictPWMBitwisePassed', ...
    isequal(reference.DutyCounts,actual.DutyCounts), ...
    'PWMPolicy',"quantization-aware", ...
    'PWMPolicyRationale',"Finite-precision duty differences may cross a half-count rounding boundary; both count arrays must equal their own rounded duty and every accepted difference must be adjacent across that same boundary.", ...
    'ContinuousDutyAbsoluteTolerance',1e-6, ...
    'OtherFloatingAbsoluteTolerance',1e-4, ...
    'OtherFloatingRelativeTolerance',1e-4, ...
    'PWMMaximumCountDifference',1,'Fields',struct, ...
    'PWMQuantization',quantization);
if alignment,comparison.PWMPolicy="bitwise-recording-alignment";end
for field=fieldnames(actual)'
    name=field{1};
    if strcmp(name,'Time') || (alignment && startsWith(name,'Debug_'))
        continue
    end
    assert(isfield(reference,name),'mc:ReplayFieldContract', ...
        'Recorded reference is missing output %s.',name);
    a=reference.(name);b=actual.(name);
    assert(isequal(size(a),size(b)) && strcmp(class(a),class(b)), ...
        'mc:ReplayOutputType', ...
        'Replay output %s has different shape or data type.',name);
    exactDifference=bitDifferences(a,b);
    finite=all(isfinite(a),'all') && all(isfinite(b),'all');
    difference=abs(double(a)-double(b));
    strict=alignment || isinteger(a) || islogical(a);
    if alignment
        mismatch=exactDifference | ~isfinite(a) | ~isfinite(b);
    elseif strcmp(name,'DutyCounts')
        strict=false;
        mismatch=pwmViolation;
    elseif strict
        mismatch=exactDifference;
    elseif strcmp(name,'Duty')
        mismatch=~isfinite(a)|~isfinite(b)|difference>1e-6;
    else
        bound=1e-4+1e-4*max(abs(double(a)),abs(double(b)));
        mismatch=~isfinite(a)|~isfinite(b)|difference>bound;
    end
    first=find(any(mismatch,2),1);
    metric=struct('Passed',~any(mismatch,'all'),'ExactRequired',strict, ...
        'ExactlyEqual',~any(exactDifference,'all'), ...
        'MaxAbsoluteDifference',max(difference,[],'all'), ...
        'ExactDifferenceCount',nnz(exactDifference), ...
        'MismatchCount',nnz(mismatch),'FirstMismatchIndex',[], ...
        'FirstMismatchTime',[]);
    if ~isempty(first)
        metric.FirstMismatchIndex=first;
        metric.FirstMismatchTime=actual.Time(first);
    end
    comparison.Fields.(name)=metric;
    comparison.Passed=comparison.Passed&&metric.Passed;
    comparison.FiniteOutputs=comparison.FiniteOutputs&&finite;
    comparison.AllValuesExactlyEqual= ...
        comparison.AllValuesExactlyEqual&&metric.ExactlyEqual;
end
comparison.StrictBitwisePassed=comparison.TimeExactlyEqual ...
    && comparison.AllValuesExactlyEqual && comparison.FiniteOutputs;
if alignment
    comparison.Passed=comparison.Passed&&comparison.StrictBitwisePassed;
end
end

function mask=bitDifferences(a,b)
if isa(a,'single')
    mask=reshape(typecast(a(:),'uint32')~=typecast(b(:),'uint32'),size(a));
elseif isa(a,'double')
    mask=reshape(typecast(a(:),'uint64')~=typecast(b(:),'uint64'),size(a));
else
    mask=a~=b;
end
end

function [report,violation]=classifyPWM(reference,actual,pwmPeriod)
assert(isa(reference.Duty,'single') && isa(actual.Duty,'single'), ...
    'mc:ReplayDutyType','Normalized controller duty must be single.');
assert(isequal(size(reference.Duty),size(actual.Duty)) ...
    && isequal(size(reference.DutyCounts),size(actual.DutyCounts)), ...
    'mc:ReplayDutyShape','PWM recordings must have matching shapes.');
scaledReference=min(max(reference.Duty,single(0)),single(1))*single(pwmPeriod);
scaledActual=min(max(actual.Duty,single(0)),single(1))*single(pwmPeriod);
referenceMatch=uint16(round(scaledReference))==reference.DutyCounts;
actualMatch=uint16(round(scaledActual))==actual.DutyCounts;
mask=reference.DutyCounts~=actual.DutyCounts;
countDifference=abs(double(reference.DutyCounts)-double(actual.DutyCounts));
halfCount=min(double(reference.DutyCounts),double(actual.DutyCounts))+.5;
straddles=min(double(scaledReference),double(scaledActual))<halfCount ...
    & max(double(scaledReference),double(scaledActual))>=halfCount;
violation=~referenceMatch|~actualMatch|countDifference>1 ...
    | (mask & (~straddles | countDifference~=1));
report=struct('ReferenceRequantizationMatches',all(referenceMatch,'all'), ...
    'ActualRequantizationMatches',all(actualMatch,'all'), ...
    'MismatchCount',nnz(mask),'AllMismatchesAdjacent', ...
    all(countDifference(mask)==1),'AllMismatchesStraddleHalfCount', ...
    all(straddles(mask)),'StraddleViolationCount',nnz(~straddles(mask)), ...
    'QuantizationViolationCount',nnz(violation), ...
    'MaximumCountDifference',max(countDifference,[],'all'), ...
    'MaxNormalizedDutyDifference', ...
    max(abs(double(reference.Duty)-double(actual.Duty)),[],'all'), ...
    'MaxScaledDutyDifference', ...
    max(abs(double(scaledReference)-double(scaledActual)),[],'all'), ...
    'MaxMismatchHalfCountDistance',0,'FirstBoundaryExample',struct);
if any(mask,'all')
    values=double(scaledReference(mask));
    report.MaxMismatchHalfCountDistance=max(abs(values-floor(values)-.5));
    row=find(any(mask,2),1);
    phase=find(mask(row,:),1);
    report.FirstBoundaryExample=struct('Time',actual.Time(row), ...
        'Phase',phase,'ReferenceScaledDuty',double(scaledReference(row,phase)), ...
        'ActualScaledDuty',double(scaledActual(row,phase)), ...
        'ReferenceCounts',reference.DutyCounts(row,phase), ...
        'ActualCounts',actual.DutyCounts(row,phase));
end
end
