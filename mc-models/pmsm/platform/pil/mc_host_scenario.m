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
% File:        mc_host_scenario.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Create repeatable PC-only excitation and acceptance windows.
% =================================================================================

function scenario = mc_host_scenario(name,layer)
%MC_HOST_SCENARIO Create repeatable PC-only excitation and acceptance windows.
arguments
    name (1,1) string
    layer (1,1) string {mustBeMember(layer,["core","motor"])} = "motor"
end
scenario.Name=name;
scenario.Layer=layer;
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
    case "sensored_reverse"
        scenario.PositionMode=uint8(1);
        scenario.Duration=3;
        scenario.SteadyWindows=[2 2.9 -100];
        scenario.PeakSpeedLimit=120;
        scenario.RequiredModes=uint8([0 1 2 4 5 6 12 14]);
    case "calibration_offset"
        assert(layer=="motor",'mc:ScenarioLayer','Calibration requires the motor layer.');
        scenario.PositionMode=uint8(1);
        scenario.Duration=3;
        scenario.SteadyWindows=[2 2.9 100];
        scenario.PeakSpeedLimit=120;
        scenario.RequiredModes=uint8([0 1 2 4 5 6 12 14]);
        scenario.Plant.AdcOffset=scenario.Plant.AdcOffset+single(100);
    case "calibration_failure"
        assert(layer=="motor",'mc:ScenarioLayer','Calibration requires the motor layer.');
        scenario.Duration=0.1;
        scenario.SteadyWindows=zeros(0,3);
        scenario.RequiredModes=uint8([1 3]);
        scenario.ExpectedFaultMask=uint16(1024);
        scenario.FaultWindows=[0.001 0.1];
        scenario.LatchWindows=[0.001 0.1];
        scenario.DisabledWindows=[0 0.1];
        scenario.Plant.AdcOffset=scenario.Plant.AdcOffset+single(501);
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
if layer=="core"
    scenario.RequiredModes=scenario.RequiredModes(~ismember(scenario.RequiredModes,uint8([1 2 4 5])));
else
    scenario.RequiredModes=scenario.RequiredModes(~ismember(scenario.RequiredModes,uint8([0 5])));
end
scenario.OvershootWindows=[0.05 scenario.Duration 200];
switch name
    case "sensored_steps"
        scenario.OvershootWindows=[0.05 1.5 100;1.5 3 200];
    case "sensored_reverse"
        scenario.OvershootWindows=[0.05 scenario.Duration -100];
    case "calibration_offset"
        scenario.OvershootWindows=[0.05 scenario.Duration 100];
    case "calibration_failure"
        scenario.OvershootWindows=zeros(0,3);
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
    case "sensored_reverse"
        speed(:)=single(-100);
    case "calibration_offset"
        speed(:)=single(100);
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
