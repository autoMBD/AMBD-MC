function result = bldc_compare_outputs(reference,actual)
%bldc_compare_outputs - Compare every controller output on identical inputs
%   RESULT = bldc_compare_outputs(REFERENCE,ACTUAL) requires exact integer
%   outputs and reports strict byte equality separately for floating data.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
names={'Mode','FaultBits','Tick','Current','CurrentReference','CurrentDemand', ...
    'SpeedRequest','SpeedRamped','SpeedEstimate','ControlSpeed','Sector','Direction', ...
    'OutputDirection','Modulation','GateEnable','PhaseEnable','FeedbackReady', ...
    'ZcCount','ZcPeriod','ZcCountdown','AcquisitionReady','PositionMode','VoltageResidual', ...
    'CurrentIntegrator','SpeedIntegrator','HallSector','HallValid','AppliedAge', ...
    'CurrentMeasured','DutyCounts','PhaseMask','GateOutput','DebugData','DebugEnabled'};
result=struct('Passed',false,'TimeExactlyEqual',false,'StrictBitwisePassed',false, ...
    'AbsoluteTolerance',1e-5,'RelativeTolerance',1e-5,'Fields',struct);
if ~isfield(reference,'Time') || ~isfield(actual,'Time'),return;end
result.TimeExactlyEqual=isequal(reference.Time,actual.Time) && ~isempty(reference.Time) ...
    && all(isfinite(reference.Time));
passed=result.TimeExactlyEqual;strict=passed;
for k=1:numel(names)
    name=names{k};field=struct('Passed',false,'ExactRequired',false, ...
        'BitwiseEqual',false,'MaximumAbsoluteDifference',NaN,'MismatchCount',NaN);
    if isfield(reference,name) && isfield(actual,name)
        a=reference.(name);b=actual.(name);
        valid=isequal(size(a),size(b)) && strcmp(class(a),class(b)) ...
            && size(a,1)==numel(reference.Time) && all(isfinite(a),'all') && all(isfinite(b),'all');
        field.ExactRequired=isinteger(a) || islogical(a);
        if valid
            delta=abs(double(a)-double(b));field.MaximumAbsoluteDifference=max(delta,[],'all');
            if islogical(a),field.BitwiseEqual=isequal(a,b);
            else,field.BitwiseEqual=isequal(typecast(a(:),'uint8'),typecast(b(:),'uint8'));end
            if field.ExactRequired,mismatch=a~=b;
            else,mismatch=delta>result.AbsoluteTolerance+result.RelativeTolerance*abs(double(a));end
            field.MismatchCount=sum(mismatch,'all');field.Passed=~any(mismatch,'all');
        end
    end
    result.Fields.(name)=field;passed=passed && field.Passed;strict=strict && field.BitwiseEqual;
end
result.Passed=passed;result.StrictBitwisePassed=strict;
end
