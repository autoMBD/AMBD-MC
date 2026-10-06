function s = feedback(u,s,p)
%FEEDBACK - Estimate Hall or terminal-voltage commutation timing
%   S = FEEDBACK(U,S,P) uses measured samples and explicit age counters.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
if ~s.FastTick, return; end
if p.PositionMode==uint8(0)
    s=hallFeedback(u,s,p);
else
    s=voltageFeedback(u,s,p);
    if s.Mode==uint8(9),s=bldc.coast_acquire(u,s,p);end
end
s.ControlSpeed=s.SpeedEstimate;
end

function s = hallFeedback(u,s,p)
s.HallAge=s.HallAge+uint32(1);
sector=bldc.hall_decode(u.Hall);s.HallSector=sector;
if sector==uint8(0)
    s.SensorFault=bitor(s.SensorFault,uint16(1024));
elseif s.HallLast==uint8(0)
    s.HallLast=sector;s.HallAge=uint32(0);
elseif sector~=s.HallLast
    delta=mod(int16(sector)-int16(s.HallLast),int16(6));
    if delta==int16(1) || delta==int16(5)
        direction=int8(1);if delta==int16(5),direction=int8(-1);end
        s.RawSpeed=single(direction)*single(pi/3)/(max(single(s.HallAge),single(1))*p.Ts);
        if ~s.HallValid, s.SpeedEstimate=s.RawSpeed;end
        s.HallDirection=direction;s.HallValid=true;
    else
        s.SensorFault=bitor(s.SensorFault,uint16(1024));
    end
    s.HallLast=sector;s.HallAge=uint32(0);
end
age=single(s.HallAge)*p.Ts;
observed=s.HallValid || s.HallDirection~=int8(0);
% A missing edge bounds the actual speed from above even before timeout.
if age>single(0) && s.HallValid
    bound=single(pi/3)/age;
    s.RawSpeed=single(s.HallDirection)*min(abs(s.RawSpeed),bound);
end
if age>p.HallTimeout, s.RawSpeed=single(0);s.HallValid=false;end
s.SpeedEstimate=s.SpeedEstimate+p.SpeedFilterAlpha*(s.RawSpeed-s.SpeedEstimate);
s.FeedbackReady=s.HallValid;
active=s.GateEnable && s.Mode>=uint8(6) && s.CurrentRef>p.HallStallCurrent;
if active && ((observed && age>p.HallTimeout) || ...
        (~observed && age>p.HallStartTimeout))
    s.SensorFault=bitor(s.SensorFault,uint16(2048));
end
end

function s = voltageFeedback(u,s,p)
s.ZcAge=s.ZcAge+uint32(1);
if s.ZcCountdown>int32(0),s.ZcCountdown=s.ZcCountdown-int32(1);end
if u.AppliedSector~=s.AppliedLastSector
    s.AppliedLastSector=u.AppliedSector;s.AppliedAge=uint32(0);
    s.ZcArmed=false;s.ZcFound=false;
else
    s.AppliedAge=s.AppliedAge+uint32(1);
end
valid=u.AppliedSector>=uint8(1) && u.AppliedSector<=uint8(6) ...
    && u.VoltageValid && all(isfinite(u.TerminalVoltage)) && isfinite(u.Vdc);
if valid
    floats=uint8([3,2,1,3,2,1]);slopes=single([-1,1,-1,1,-1,1]);
    floating=floats(u.AppliedSector);
    z=u.TerminalVoltage(floating)-u.Vdc/single(2);s.ZcValue=z;
    signed=slopes(u.AppliedSector)*z;
    sampleReady=s.AppliedAge>=uint32(p.ZcBlankTicks) ...
        && abs(s.Current(floating))<p.FloatCurrentLimit && ~s.ZcFound;
    if sampleReady
        if signed < -p.ZcHysteresis,s.ZcArmed=true;end
        if s.ZcArmed && signed>=p.ZcHysteresis
            interval=single(s.ZcAge);
            firstSeeded=s.AcquisitionReady && s.ZcCount==uint16(0) ...
                && s.ZcPeriod>single(0) && s.Mode>=uint8(11) && s.Mode<=uint8(14);
            plausible=firstSeeded || (s.ZcAge>=p.ZcMinTicks && s.ZcAge<=p.ZcMaxTicks);
            if s.ZcPeriod>single(0) && ~firstSeeded
                plausible=plausible && interval>=single(.5)*s.ZcPeriod ...
                    && interval<=single(1.8)*s.ZcPeriod;
            end
            if plausible
                if ~firstSeeded
                    if s.ZcCount<=uint16(1),s.ZcPeriod=interval;
                    else,s.ZcPeriod=s.ZcPeriod+single(.3)*(interval-s.ZcPeriod);end
                end
                s.ZcCount=s.ZcCount+uint16(1);
                s.RawSpeed=single(s.Direction)*single(pi/3)/(s.ZcPeriod*p.Ts);
                s.SpeedEstimate=s.RawSpeed;
                s.ZcCountdown=int32(max(round(double(s.ZcPeriod)/2),1));
                s.ZcNextSector=uint8(mod(int16(u.AppliedSector)-int16(1)+int16(s.Direction),int16(6))+int16(1));
                s.ZcAge=uint32(0);s.ZcFound=true;s.ZcArmed=false;
            else
                if s.Mode>=uint8(11) && s.Mode<=uint8(14)
                    s.SensorFault=bitor(s.SensorFault,uint16(4096));
                else
                    s.ZcCount=uint16(0);s.ZcPeriod=single(0);s.ZcAge=uint32(0);
                    s.AcquisitionReady=false;
                end
                s.ZcFound=true;s.ZcArmed=false;
            end
        end
    end
end
s.FeedbackReady=s.ZcCount>=p.ZcRequired && abs(s.SpeedEstimate)>=p.ZcMinSpeed;
timeout=max(single(2)*single(p.ZcBlankTicks),p.ZcTimeoutFactor*s.ZcPeriod);
if s.ZcPeriod>single(0) && single(s.ZcAge)>timeout
    s.FeedbackReady=false;
    if s.Mode>=uint8(11) && s.Mode<=uint8(14)
        s.SensorFault=bitor(s.SensorFault,uint16(4096));
    else
        s.ZcCount=uint16(0);s.ZcPeriod=single(0);s.AcquisitionReady=false;
    end
end
end
