function scenario = bldc_host_scenario(name)
%bldc_host_scenario - Define reproducible BLDC physical acceptance profiles
%   SCENARIO = bldc_host_scenario(NAME) includes exact sampled inputs,
%   independent plant parameters and predeclared physical assertion windows.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
name=string(name);
switch name
    case {"hall_steps","hall_negative_steps","hall_low_speed","hall_load_voltage","hall_parameters", ...
            "hall_saturation_recovery","sensorless_load_voltage", ...
            "hall_negative_load_voltage","sensorless_negative_load_voltage"}
        duration=4;
    case {"hall_reverse","sensorless_forward","sensorless_reverse","sensorless_100","sensorless_minus_100", ...
            "sensorless_parameters_low_flux","sensorless_parameters_high_flux"}
        duration=3.5;
    case {"hall_invalid_zero","hall_invalid_seven","hall_bus_under","hall_bus_over"}
        duration=3.5;
    case {"hall_jump","hall_stall","hall_overcurrent","hall_adc_rail"}
        duration=1.8;
    case "hall_speed_range"
        duration=6;
    case "hall_stop_restart"
        duration=4.5;
    case "hall_reversal"
        duration=4.5;
    case "sensorless_stop_restart"
        duration=6;
    case "sensorless_reversal"
        duration=7;
    case {"hall_stop_alignment","sensorless_stop_open","sensorless_stop_acquisition","sensorless_stop_tracking"}
        duration=2.5;
    case "sensorless_low_transition"
        duration=7;
    case "sensorless_low_fallback"
        duration=8;
    case "sensorless_external_recovery"
        duration=6;
    case {"hall_zero_request","sensorless_voltage_loss","sensorless_voltage_freeze","sensorless_invalid_voltage"}
        duration=3;
    otherwise
        error('bldc:UnknownScenario','Unknown BLDC host scenario: %s.',name);
end
scenario.Name=name;scenario.Duration=duration;
scenario.Control=bldc.defaults();scenario.Plant=bldc.defaults();
scenario.PositionMode=uint8(startsWith(name,"sensorless_"));
scenario.Control.PositionMode=scenario.PositionMode;
scenario.Model="BLDC_PIL_Hall_top";
if scenario.PositionMode==uint8(1),scenario.Model="BLDC_PIL_Sensorless_top";end
scenario.PlantInitial=zeros(5,1);
scenario.SteadyWindows=[duration-.7,duration-.1,200];
scenario.ClosedWindows=[duration-.7,duration-.1];
scenario.OvershootWindows=[.7,duration,200];
scenario.DisabledWindows=[0,.0199];scenario.LowForcedWindows=zeros(0,2);
scenario.FaultWindows=zeros(0,4);scenario.LatchWindows=zeros(0,2);
scenario.SaturationWindows=zeros(0,3);scenario.UnsaturatedWindows=zeros(0,2);
scenario.StopOrigins=zeros(0,2);scenario.StopWindows=zeros(0,2);
scenario.ReversalWindows=zeros(0,3);scenario.ExpectedFaultMask=uint16(0);
scenario.PeakCurrentLimit=9.9;scenario.PeakSpeedLimit=300;
scenario.RequiredModes=uint8([0,1,2,4,5,6,12,14]);
if scenario.PositionMode==uint8(1)
    scenario.RequiredModes=uint8([0,1,2,4,5,6,7,8,9,11,12,14]);
end
t=(0:round(duration*16000))'/16000;n=numel(t);
speed=repmat(single(200),n,1);control=uint8(t>=.02);fault=false(n,1);
loadTorque=zeros(n,1);vdc=repmat(single(12),n,1);sensor=zeros(n,1,'uint8');
currentOffset=zeros(n,3,'single');terminalOffset=zeros(n,3,'single');voltageValid=true(n,1);
switch name
    case {"hall_steps","hall_negative_steps"}
        speed(t<1.5)=single(100);control(t>=3.3)=uint8(2);
        scenario.SteadyWindows=[1,1.4,100;2.7,3.15,200;3.85,4,0];
        scenario.ClosedWindows=[1,1.4;2.7,3.15];
        scenario.OvershootWindows=[.7,1.5,100;1.5,3.3,200];
        scenario.DisabledWindows=[0,.0199;3.85,4];
        scenario.RequiredModes=[scenario.RequiredModes,uint8(15)];
        scenario.StopWindows=[3.3,4];
        if name=="hall_negative_steps"
            speed=-speed;scenario.SteadyWindows(:,3)=-scenario.SteadyWindows(:,3);
            scenario.OvershootWindows(:,3)=-scenario.OvershootWindows(:,3);
        end
    case {"hall_reverse","sensorless_reverse"}
        speed(:)=single(-200);scenario.SteadyWindows(:,3)=-200;
        scenario.OvershootWindows(:,3)=-200;
    case "hall_low_speed"
        speed(:)=single(20);
        scenario.SteadyWindows=[2.8,3.9,20];scenario.ClosedWindows=[2.8,3.9];
        scenario.OvershootWindows=[1.5,4,20];scenario.PeakSpeedLimit=100;
    case "hall_speed_range"
        speed(:)=single(20);speed(t>=2 & t<3.5)=single(100);
        scenario.SteadyWindows=[1.5,1.9,20;3,3.4,100;5.3,5.9,20];
        scenario.ClosedWindows=[1.5,1.9;3,3.4;5.3,5.9];
        scenario.OvershootWindows=[1.5,2,20;2.7,3.5,100;5.3,6,20];
        scenario.PeakSpeedLimit=140;
    case {"hall_load_voltage","sensorless_load_voltage","hall_negative_load_voltage","sensorless_negative_load_voltage"}
        vdc(t>=2)=single(10);vdc(t>=3.1)=single(14);loadTorque(t>=2.6)=.01;
        scenario.SteadyWindows=[2.3,2.5,200;3.3,3.9,200];
        scenario.ClosedWindows=[2.3,2.5;3.3,3.9];
        if contains(name,"negative")
            speed=-speed;loadTorque=-loadTorque;
            scenario.SteadyWindows(:,3)=-scenario.SteadyWindows(:,3);
            scenario.OvershootWindows(:,3)=-scenario.OvershootWindows(:,3);
        end
    case "hall_stop_restart"
        control(t>=1.6 & t<2.4)=uint8(2);
        scenario.SteadyWindows=[1.3,1.5,200;2.2,2.35,0;3.8,4.4,200];
        scenario.ClosedWindows=[1.3,1.5;3.8,4.4];
        scenario.DisabledWindows=[0,.0199;2.2,2.35];
        scenario.RequiredModes=[scenario.RequiredModes,uint8(15)];
        scenario.StopWindows=[1.6,2.39];
    case "hall_reversal"
        speed(t>=1.7)=single(-150);
        scenario.SteadyWindows=[1.3,1.6,200;3.7,4.4,-150];
        scenario.ClosedWindows=[1.3,1.6;3.7,4.4];
        scenario.OvershootWindows=[.7,1.7,200;2.3,4.5,-150];
        scenario.RequiredModes=[scenario.RequiredModes,uint8(15)];
        scenario.StopWindows=[1.7,3.2];scenario.ReversalWindows=[1.7,1,-1];
    case "hall_zero_request"
        speed(t>=1.6)=single(0);scenario.StopOrigins=[1.6,14];
        scenario.StopWindows=[1.6,3];scenario.SteadyWindows=[2.4,2.9,0];
        scenario.ClosedWindows=zeros(0,2);scenario.DisabledWindows=[0,.0199;2.4,3];
        scenario.RequiredModes=[scenario.RequiredModes,uint8(15)];
    case "hall_stop_alignment"
        control(t>=.1)=uint8(2);scenario.StopOrigins=[.1,6];
        scenario.StopWindows=[.1,1.6];scenario.SteadyWindows=[1,2.4,0];
        scenario.ClosedWindows=zeros(0,2);scenario.OvershootWindows=zeros(0,3);
        scenario.DisabledWindows=[0,.0199;1,2.5];
        scenario.RequiredModes=uint8([0,1,2,4,5,6,15]);
    case {"hall_invalid_zero","hall_invalid_seven"}
        sensor(t>=.8 & t<.95)=uint8(1+double(name=="hall_invalid_seven"));
        control(t>=.9 & t<1)=uint8(0);
        scenario.ExpectedFaultMask=uint16(1024);
        scenario.FaultWindows=[.8,.8+1/16000,.95,1024];
        scenario.LatchWindows=[.81,.949];
        scenario.DisabledWindows=[0,.0199;.8+1/16000,.999];
        scenario.RequiredModes=[scenario.RequiredModes,uint8(3)];
    case {"hall_jump","hall_stall"}
        sensor(t>=.8)=uint8(4);mask=1024;deadline=.8+1/16000;
        if name=="hall_stall",sensor(t>=.8)=uint8(3);mask=2048;deadline=1.12;end
        scenario.ExpectedFaultMask=uint16(mask);
        scenario.FaultWindows=[.8,deadline,1.8,mask];
        scenario.LatchWindows=[1.2,1.79];scenario.DisabledWindows=[0,.0199;1.2,1.8];
        scenario.SteadyWindows=zeros(0,3);scenario.ClosedWindows=zeros(0,2);
        scenario.RequiredModes=[scenario.RequiredModes,uint8(3)];
    case {"hall_bus_under","hall_bus_over"}
        bus=6;mask=4;if name=="hall_bus_over",bus=18;mask=8;end
        vdc(t>=1.4 & t<1.5)=single(bus);control(t>=1.8 & t<1.85)=uint8(0);
        scenario.ExpectedFaultMask=uint16(mask);
        scenario.FaultWindows=[1.4,1.4+1/16000,1.5,mask];
        scenario.LatchWindows=[1.51,1.79];
        scenario.DisabledWindows=[0,.0199;1.4+1/16000,1.849];
        scenario.SteadyWindows=[3.1,3.45,200];scenario.ClosedWindows=[3.1,3.45];
        scenario.RequiredModes=[scenario.RequiredModes,uint8(3)];
    case {"hall_overcurrent","hall_adc_rail"}
        offset=14;mask=2;if name=="hall_adc_rail",offset=40;mask=34;end
        ix=t>=.8 & t<.85;currentOffset(ix,:)=repmat(single([offset,-offset,0]),sum(ix),1);
        scenario.ExpectedFaultMask=uint16(mask);
        scenario.FaultWindows=[.8,.8+1/16000,.85,mask];scenario.LatchWindows=[.86,1.79];
        scenario.DisabledWindows=[0,.0199;.8+1/16000,1.8];
        scenario.SteadyWindows=zeros(0,3);scenario.ClosedWindows=zeros(0,2);
        scenario.RequiredModes=[scenario.RequiredModes,uint8(3)];
    case "hall_saturation_recovery"
        speed(:)=single(250);loadTorque(t>=1.2 & t<2.7)=.04;
        scenario.SaturationWindows=[1.3,2.6,.1];scenario.UnsaturatedWindows=[3.3,3.9];
        scenario.SteadyWindows=[3.3,3.9,250];scenario.ClosedWindows=[3.3,3.9];
        scenario.OvershootWindows=[.7,4,250];
    case {"hall_parameters","sensorless_parameters_low_flux","sensorless_parameters_high_flux"}
        scenario.Plant.Rs=scenario.Plant.Rs*single(1.1);
        scenario.Plant.Ls=scenario.Plant.Ls*single(.9);
        scenario.Plant.Inertia=scenario.Plant.Inertia*single(1.1);
        scenario.Plant.Friction=scenario.Plant.Friction*single(1.05);
        scale=single(.9);if name=="sensorless_parameters_high_flux",scale=single(1.1);end
        scenario.Plant.Ke=scenario.Plant.Ke*scale;
        scenario.PlantInitial(4)=1.234;
        terminalOffset(:,1)=single(.002*sin(2*pi*137*t));
        terminalOffset(:,2)=single(.002*sin(2*pi*173*t));
        terminalOffset(:,3)=single(.002*sin(2*pi*211*t));
    case "sensorless_forward"
    case {"sensorless_100","sensorless_minus_100"}
        speed(:)=single(100);scenario.SteadyWindows=[2.7,3.4,100];
        scenario.ClosedWindows=[2.7,3.4];scenario.OvershootWindows=[1.5,3.5,100];
        scenario.PeakSpeedLimit=140;
        if name=="sensorless_minus_100"
            speed=-speed;scenario.SteadyWindows(:,3)=-scenario.SteadyWindows(:,3);
            scenario.OvershootWindows(:,3)=-scenario.OvershootWindows(:,3);
        end
    case "sensorless_stop_restart"
        control(t>=2.3 & t<3.1)=uint8(2);
        scenario.SteadyWindows=[2.05,2.25,200;2.9,3.05,0;5.3,5.9,200];
        scenario.ClosedWindows=[2.05,2.25;5.3,5.9];
        scenario.DisabledWindows=[0,.0199;2.9,3.05];
        scenario.RequiredModes=[scenario.RequiredModes,uint8(15)];
        scenario.StopWindows=[2.3,3.09];
    case "sensorless_reversal"
        speed(t>=2.7)=single(-150);
        scenario.SteadyWindows=[2.3,2.6,200;6.2,6.9,-150];
        scenario.ClosedWindows=[2.3,2.6;6.2,6.9];
        scenario.OvershootWindows=[1.5,2.7,200;4,7,-150];
        scenario.RequiredModes=[scenario.RequiredModes,uint8(15)];
        scenario.StopWindows=[2.7,4.2];scenario.ReversalWindows=[2.7,1,-1];
    case {"sensorless_stop_open","sensorless_stop_acquisition","sensorless_stop_tracking"}
        stop=.8;origin=8;
        if name=="sensorless_stop_acquisition",stop=1.35875;origin=9;end
        if name=="sensorless_stop_tracking",stop=1.4;origin=11;end
        control(t>=stop)=uint8(2);scenario.StopOrigins=[stop,origin];
        scenario.StopWindows=[stop,min(stop+double(scenario.Control.StopTimeout),duration)];
        scenario.SteadyWindows=[2.1,2.4,0];scenario.ClosedWindows=zeros(0,2);
        scenario.OvershootWindows=zeros(0,3);scenario.DisabledWindows=[0,.0199;2.1,2.5];
        scenario.RequiredModes=uint8([0,1,2,4,5,6,7,8,15]);
        if origin>=9,scenario.RequiredModes=[scenario.RequiredModes,uint8(9)];end
        if origin==11,scenario.RequiredModes=[scenario.RequiredModes,uint8(11)];end
    case "sensorless_low_transition"
        speed(t<3.5)=single(20);speed(t>=3.5)=single(100);
        scenario.SteadyWindows=[6,6.9,100];scenario.ClosedWindows=[6,6.9];
        scenario.LowForcedWindows=[1.5,3.4];scenario.OvershootWindows=[5,7,100];
        scenario.PeakSpeedLimit=150;
    case "sensorless_low_fallback"
        speed(t>=2.5 & t<4.5)=single(20);speed(t>=4.5)=single(100);
        scenario.SteadyWindows=[2.1,2.4,200;7,7.9,100];
        scenario.ClosedWindows=[2.1,2.4;7,7.9];
        scenario.LowForcedWindows=[4.2,4.4];scenario.OvershootWindows=[1.5,2.5,200;6,8,100];
        scenario.RequiredModes=[scenario.RequiredModes,uint8([10,13])];
    case "sensorless_external_recovery"
        fault(t>=2.3 & t<2.35)=true;control(t>=2.65 & t<2.75)=uint8(0);
        scenario.ExpectedFaultMask=uint16(1);scenario.FaultWindows=[2.3,2.3+1/16000,2.35,1];
        scenario.LatchWindows=[2.36,2.64];scenario.DisabledWindows=[0,.0199;2.3+1/16000,2.749];
        scenario.SteadyWindows=[2.1,2.25,200;5.3,5.9,200];
        scenario.ClosedWindows=[2.1,2.25;5.3,5.9];
        scenario.RequiredModes=[scenario.RequiredModes,uint8(3)];
    case {"sensorless_voltage_loss","sensorless_voltage_freeze","sensorless_invalid_voltage"}
        mask=4096;deadline=2.33;
        if name=="sensorless_voltage_loss",voltageValid(t>=2.3)=false;end
        if name=="sensorless_voltage_freeze",sensor(t>=2.3)=uint8(5);end
        if name=="sensorless_invalid_voltage"
            sensor(t>=2.3)=uint8(6);mask=16;deadline=2.3+1/16000;
        end
        scenario.ExpectedFaultMask=uint16(mask);scenario.FaultWindows=[2.3,deadline,3,mask];
        scenario.LatchWindows=[2.4,2.99];scenario.DisabledWindows=[0,.0199;2.4,3];
        scenario.SteadyWindows=[2.05,2.25,200];scenario.ClosedWindows=[2.05,2.25];
        scenario.RequiredModes=[scenario.RequiredModes,uint8(3)];
end
signals={speed,control,fault,loadTorque,vdc,sensor,currentOffset,terminalOffset,voltageValid};
names={'SpeedReq','Control','Fault','LoadTorque','Vdc','SensorFault','CurrentOffset','TerminalOffset','VoltageValid'};
inputs=Simulink.SimulationData.Dataset;
for k=1:numel(signals)
    signal=timeseries(signals{k},t,'Name',names{k});signal=setinterpmethod(signal,'zoh');
    inputs=addElement(inputs,signal,names{k});
end
scenario.Inputs=inputs;scenario.Time=t;scenario.Speed=speed;scenario.Command=control;
scenario.Fault=fault;scenario.Vdc=vdc;scenario.LoadTorque=loadTorque;scenario.SensorFault=sensor;
scenario.VoltageValid=voltageValid;
end
