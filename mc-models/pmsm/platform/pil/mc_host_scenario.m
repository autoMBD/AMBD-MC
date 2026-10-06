function scenario = mc_host_scenario(name)
%MC_HOST_SCENARIO Create repeatable PC-only excitation and acceptance windows.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
arguments
    name (1,1) string
end
scenario.Name=name;
scenario.Control=mc.defaults();
scenario.Plant=mc.defaults();
scenario.Duration=3.3;
scenario.SteadyWindows=[2.6 3.2 200];
scenario.FaultWindows=zeros(0,2);
scenario.LatchWindows=zeros(0,2);
scenario.DisabledWindows=[0 0.049];
scenario.RequiredModes=uint8([0 1 2 4 5 6 7 8 9 11 12 14]);
scenario.ExpectedFaultMask=uint16(0);
scenario.PositionMode=uint8(0);
scenario.PeakCurrentLimit=9.9;
scenario.PeakSpeedLimit=240;
scenario.Replay=true;
scenario.SaturationWindows=zeros(0,3);
scenario.UnsaturatedWindows=zeros(0,2);

switch name
    case "sensored_steps"
        scenario.PositionMode=uint8(1);
        scenario.Duration=3;
        scenario.SteadyWindows=[1 1.4 100;2.4 2.9 200];
        scenario.RequiredModes=uint8([0 1 2 4 5 6 12 14]);
    case "sensorless_forward"
    case "sensorless_reverse"
        scenario.SteadyWindows=[2.6 3.2 -200];
    case "sensorless_100"
        scenario.Duration=3;
        scenario.SteadyWindows=[2 2.9 100];
        scenario.PeakSpeedLimit=120;
    case "load_voltage"
        scenario.Duration=4;
        scenario.SteadyWindows=[2.3 2.55 200;3.3 3.9 200];
    case "reversal"
        scenario.Duration=6.5;
        scenario.SteadyWindows=[2.4 2.7 200;5.7 6.4 -150];
        scenario.RequiredModes=uint8([0 1 2 4 5 6 7 8 9 11 12 14 15]);
    case "stop_restart"
        scenario.PositionMode=uint8(1);
        scenario.Duration=4;
        scenario.SteadyWindows=[1.3 1.45 150;2 2.15 0;3.4 3.9 150];
        scenario.DisabledWindows=[0 0.049;2 2.15];
        scenario.RequiredModes=uint8([0 1 2 4 5 6 12 14 15]);
        scenario.PeakSpeedLimit=180;
    case "stop_mid_tracking"
        scenario.Duration=3;
        scenario.SteadyWindows=[2.5 2.9 0];
        scenario.DisabledWindows=[0 0.049;2.5 2.9];
        scenario.RequiredModes=uint8([0 1 2 4 5 6 7 8 9 11 15]);
        scenario.PeakSpeedLimit=150;
    case "fault_recovery"
        scenario.Duration=5.5;
        scenario.SteadyWindows=[2.3 2.45 200;4.8 5.4 200];
        scenario.FaultWindows=[2.5 2.55];
        scenario.LatchWindows=[2.56 2.79];
        scenario.DisabledWindows=[0 0.049;2.5001 2.8499];
        scenario.RequiredModes=uint8([0 1 2 3 4 5 6 7 8 9 11 12 14]);
        scenario.ExpectedFaultMask=uint16(1);
    case "bus_fault"
        scenario.PositionMode=uint8(1);
        scenario.Duration=3.5;
        scenario.SteadyWindows=[1.2 1.4 150;2.9 3.4 150];
        scenario.FaultWindows=[1.5 1.6];
        scenario.LatchWindows=[1.61 1.79];
        scenario.DisabledWindows=[0 0.049;1.5001 1.8499];
        scenario.RequiredModes=uint8([0 1 2 3 4 5 6 12 14]);
        scenario.ExpectedFaultMask=uint16(4);
        scenario.PeakSpeedLimit=180;
    case "saturation_recovery"
        scenario.PositionMode=uint8(1);
        scenario.Duration=4;
        scenario.SteadyWindows=[3.3 3.9 250];
        scenario.RequiredModes=uint8([0 1 2 4 5 6 12 14]);
        scenario.PeakSpeedLimit=300;
        scenario.SaturationWindows=[1 2.8 0.1];
        scenario.UnsaturatedWindows=[3.3 3.9];
    case "parameter_variation"
        scenario.Duration=4;
        scenario.SteadyWindows=[2.7 3.9 200];
        scenario.Plant.Rs=scenario.Plant.Rs*single(1.10);
        scenario.Plant.Ld=scenario.Plant.Ld*single(0.95);
        scenario.Plant.Lq=scenario.Plant.Lq*single(1.05);
        scenario.Plant.Flux=scenario.Plant.Flux*single(0.98);
        scenario.Plant.Inertia=scenario.Plant.Inertia*single(1.20);
    case "low_speed_transition"
        scenario.Duration=7;
        scenario.SteadyWindows=[3.5 4.1 20;6 6.9 100];
        scenario.PeakSpeedLimit=120;
    otherwise
        error('mc:UnknownScenario','Unknown host scenario: %s',name);
end
scenario.OvershootWindows=[0.05 scenario.Duration 200];
switch name
    case "sensored_steps"
        scenario.OvershootWindows=[0.05 1.5 100;1.5 3 200];
    case "sensorless_reverse"
        scenario.OvershootWindows=[0.05 scenario.Duration -200];
    case "sensorless_100"
        scenario.OvershootWindows=[0.05 scenario.Duration 100];
    case "reversal"
        scenario.OvershootWindows=[0.05 2.8 200;2.8 6.5 -150];
    case {"stop_restart","bus_fault"}
        scenario.OvershootWindows=[0.05 scenario.Duration 150];
    case "saturation_recovery"
        scenario.OvershootWindows=[0.05 scenario.Duration 250];
    case "low_speed_transition"
        scenario.OvershootWindows=[0.05 4.3 20;4.3 7 100];
end
scenario.Control.PositionMode=scenario.PositionMode;
dt=1/16000;
t=(0:dt:scenario.Duration)';
speed=single(200)*ones(size(t),'single');
control=uint8(t>=0.05);
fault=false(size(t));
loadTorque=zeros(size(t));
vdc=single(12)*ones(size(t),'single');
switch name
    case "sensored_steps"
        speed(t<1.5)=single(100);
    case "sensorless_reverse"
        speed(:)=single(-200);
    case "sensorless_100"
        speed(:)=single(100);
    case "load_voltage"
        vdc(t>=2)=single(10);
        loadTorque(t>=2.7)=0.005;
    case "reversal"
        speed(t>=2.8)=single(-150);
    case "stop_restart"
        speed(:)=single(150);
        control(t>=1.5 & t<2.2)=uint8(2);
    case "stop_mid_tracking"
        control(t>=1.44)=uint8(2);
    case "fault_recovery"
        fault(t>=2.5 & t<2.55)=true;
        control(t>=2.8 & t<2.85)=uint8(0);
    case "bus_fault"
        speed(:)=single(150);
        vdc(t>=1.5 & t<1.6)=single(6);
        control(t>=1.8 & t<1.85)=uint8(0);
    case "saturation_recovery"
        speed(:)=single(250);
        loadTorque(t>=1 & t<2.8)=0.018;
    case "low_speed_transition"
        speed(t<4.3)=single(20);
        speed(t>=4.3)=single(100);
end
signals={speed,control,fault,loadTorque,vdc};
names={'SpeedReq','Control','Fault','LoadTorque','Vdc'};
inputs=Simulink.SimulationData.Dataset;
for index=1:numel(signals)
    value=timeseries(signals{index},t,'Name',names{index});
    value=setinterpmethod(value,'zoh');
    inputs=addElement(inputs,value,names{index});
end
scenario.Inputs=inputs;
scenario.Time=t;
scenario.Command=control;
scenario.Speed=speed;
scenario.Vdc=vdc;
scenario.LoadTorque=loadTorque;
scenario.Fault=fault;
end
