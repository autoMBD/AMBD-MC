function s = dataflow(u,s,p)
%DATAFLOW Execute acquisition, estimation, FOC and modulation for one tick.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
if ~s.FastTick
    return
end
s.Current=mc.acquire(u.CurrentRaw,p);
ab=mc.clarke(s.Current);
pp=p;
pp.KpSpeed=s.Gains(1);pp.KiSpeed=s.Gains(2);
pp.KpD=s.Gains(3);pp.KiD=s.Gains(4);
pp.KpQ=s.Gains(5);pp.KiQ=s.Gains(6);
pp.ObserverBandwidth=s.Startup(4);
if s.Mode==uint8(15) && s.PreviousMode~=uint8(15)
    s.StopOpenLoop=p.PositionMode==uint8(0) && (~s.ObserverReady ...
        || (s.PreviousMode>=uint8(6) && s.PreviousMode<=uint8(11)) ...
        || s.PreviousMode==uint8(13));
    if s.StopOpenLoop
        s.ThetaOpen=s.ThetaControl;s.OmegaOpen=s.OmegaControl;
    end
end
enabled=s.Mode>=uint8(6) && s.Mode~=uint8(3) && s.FaultBits==uint16(0);
if ~enabled
    s.CurrentIntegral=single([0;0]);s.SpeedIntegral=single(0);
    s.ReferenceDq=single([0;0]);s.SpeedRamp=single(0);
    s.Voltage=single([0;0]);s.Duty=single([0.5;0.5;0.5]);
    s.GateEnable=false;s.OmegaOpen=single(0);s.ThetaOpen=single(0);
    s.Observer=mc.observer_initial(pp,single(0),ab);
    s.ObserverReady=false;s.ObserverGoodTicks=uint32(0);
    s.ThetaControl=single(0);s.OmegaControl=single(0);
    s.StopOpenLoop=false;s.PositionSpeed=single(0);
    if isfinite(u.Position), s.PositionPrev=u.Position;
    else, s.PositionPrev=single(0); end
    return
end
if p.PositionMode==uint8(1)
    instant=mc.wrap_angle(u.Position-s.PositionPrev)/p.Ts;
    s.PositionSpeed=s.PositionSpeed+min(single(1),p.Ts*p.ObserverSpeedBandwidth)*(instant-s.PositionSpeed);
    s.PositionPrev=u.Position;
end
if s.Mode==uint8(6)
    s.Observer=mc.observer_initial(pp,single(0),ab);
    s.ObserverGoodTicks=uint32(0);s.ObserverReady=false;
else
    s.Observer=mc.observer_step(ab,u.AppliedVoltage,s.Observer,pp);
    if ~all(isfinite(s.Observer.Flux)) || ~isfinite(s.Observer.Theta) ...
            || ~isfinite(s.Observer.Omega) || ~isfinite(s.Observer.Magnitude)
        s=numericalFault(s,p);return
    end
    plausible=s.Observer.Magnitude>single(0.4)*p.Flux ...
        && s.Observer.Magnitude<single(1.6)*p.Flux ...
        && abs(s.Observer.Omega)>p.ObserverMinSpeed ...
        && abs(s.Observer.Omega)<single(2)*p.SpeedLimit ...
        && s.Observer.Omega*s.Direction>single(0);
    if plausible
        s.ObserverGoodTicks=min(s.ObserverGoodTicks+uint32(1),uint32(1000000));
    else
        s.ObserverGoodTicks=uint32(0);
    end
    s.ObserverReady=single(s.ObserverGoodTicks)*p.Ts>=p.ObserverLockTime;
end
if p.PositionMode==uint8(1)
    estimateTheta=u.Position;estimateOmega=s.PositionSpeed;s.ObserverReady=true;
else
    estimateTheta=s.Observer.Theta;estimateOmega=s.Observer.Omega;
end
if s.Mode==uint8(15) && p.PositionMode==uint8(0) ...
        && ~s.ObserverReady && ~s.StopOpenLoop
    s.StopOpenLoop=true;
    s.ThetaOpen=s.ThetaControl;s.OmegaOpen=s.OmegaControl;
end
if s.Mode==uint8(6)
    s.ThetaControl=single(0);s.OmegaControl=single(0);
    s.ReferenceDq=single([s.Startup(1);0]);
elseif s.Mode==uint8(7) || s.Mode==uint8(8) || s.Mode==uint8(9) ...
        || s.Mode==uint8(10) || s.Mode==uint8(13)
    if (s.Mode==uint8(13) && s.PreviousMode~=uint8(13)) ...
            || (s.Mode==uint8(10) && s.PreviousMode~=uint8(10) && s.PreviousMode~=uint8(13))
        s.ThetaOpen=s.ThetaControl;
        s.OmegaOpen=s.OmegaControl;
    end
    target=s.Direction*min(abs(s.SpeedRequest),p.OpenLoopSpeed);
    s.OmegaOpen=approach(s.OmegaOpen,target,s.Startup(3)*p.Ts);
    s.ThetaOpen=mc.wrap_angle(s.ThetaOpen+p.Ts*s.OmegaOpen);
    s.ThetaControl=s.ThetaOpen;s.OmegaControl=s.OmegaOpen;
    iqTarget=p.OpenLoopCurrent;
    if abs(s.SpeedRequest)<single(1.25)*p.ObserverMinSpeed
        % Low-frequency I/f needs less torque than the full-speed startup.
        % Scale the current target, retaining the ordinary current slew.
        iqTarget=iqTarget*min(abs(s.SpeedRequest),p.OpenLoopSpeed)/p.OpenLoopSpeed;
    end
    iq=approach(s.ReferenceDq(2),s.Direction*iqTarget,p.CurrentSlew*p.Ts);
    s.ReferenceDq=single([0;iq]);
elseif s.Mode==uint8(15) && s.StopOpenLoop
    s.OmegaOpen=approach(s.OmegaOpen,single(0),p.StopDecel*p.Ts);
    s.ThetaOpen=mc.wrap_angle(s.ThetaOpen+p.Ts*s.OmegaOpen);
    s.ThetaControl=s.ThetaOpen;s.OmegaControl=s.OmegaOpen;
    s.ReferenceDq=single([0;approach(s.ReferenceDq(2),single(0),p.CurrentSlew*p.Ts)]);
else
    if s.PreviousMode~=s.Mode && (s.Mode==uint8(11) || s.Mode==uint8(12))
        s.SpeedRamp=estimateOmega;
        measured=mc.park(ab,estimateTheta);
        s.SpeedIntegral=min(max(measured(2),-p.CurrentLimit),p.CurrentLimit);
    end
    if s.Mode==uint8(11)
        s.ThetaOpen=mc.wrap_angle(s.ThetaOpen+p.Ts*s.OmegaOpen);
        blend=min(single(1),single(s.ModeTicks)*p.Ts/p.TrackingTime);
        s.ThetaControl=mc.wrap_angle(s.ThetaOpen+blend*mc.wrap_angle(estimateTheta-s.ThetaOpen));
        s.OmegaControl=(single(1)-blend)*s.OmegaOpen+blend*estimateOmega;
    else
        s.ThetaControl=estimateTheta;s.OmegaControl=estimateOmega;
    end
    if s.SlowTick || s.Mode~=s.PreviousMode
        dt=p.Ts*single(p.SpeedDivider);
        if s.Mode==uint8(15)
            desired=single(0);slew=p.StopDecel;
        else
            desired=s.SpeedRequest;slew=p.SpeedSlew;
        end
        s.SpeedRamp=approach(s.SpeedRamp,desired,slew*dt);
        [iq,s.SpeedIntegral]=mc.pi_step(s.SpeedRamp-estimateOmega,s.SpeedIntegral, ...
            pp.KpSpeed,pp.KiSpeed,dt,p.CurrentLimit,false);
        s.ReferenceDq=single([0;approach(s.ReferenceDq(2),iq,p.CurrentSlew*dt)]);
    end
end
s.GateEnable=true;
[s.Voltage,s.CurrentIntegral,s.CurrentDq]=mc.current_control(s.Current, ...
    s.ThetaControl,s.OmegaControl,s.ReferenceDq,s.CurrentIntegral,pp,u.Vdc,true);
if ~all(isfinite(s.Voltage)) || ~all(isfinite(s.CurrentIntegral)) ...
        || ~all(isfinite(s.CurrentDq)) || ~isfinite(s.SpeedIntegral)
    s=numericalFault(s,p);return
end
s.Duty=mc.svpwm(s.Voltage,u.Vdc,true);
% Telemetry for this command; the observer consumes driver feedback next tick.
phase=u.Vdc*(s.Duty-mean(s.Duty));
s.Voltage=mc.clarke(phase);
end

function value=approach(value,target,increment)
value=value+min(max(target-value,-increment),increment);
end

function s=numericalFault(s,p)
tick=s.Tick;command=s.Command;bits=s.FaultBits;
s=mc.initial_state(p);
s.Tick=tick;s.Command=command;s.Mode=uint8(3);s.PreviousMode=uint8(3);
s.FaultBits=bitor(bits,uint16(512));s.ActiveFaults=uint16(512);
end
