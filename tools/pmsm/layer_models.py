# =================================================================================
# The MIT License
# MIT许可证
#
# <https://opensource.org/license/mit>
#
# SPDX short identifier / SPDX 短标识符：MIT
#
# Copyright (c) 2026 autoMBD
# 版权所有 (c) 2026 autoMBD
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the “Software”),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
# 特此向获得本软件及相关文档（合称“本软件”）副本的任何人免费授予不受限制地利用本软
# 件的许可，包括而不限于：使用、复制、修改、合并、发布、分发、分许可和/或销售本软
# 件副本，并允许本软件的接收者也获得前述许可，但须遵守以下条件：
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
# 以上版权声明及本许可声明应包含在本软件的所有副本或主要部分中。
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALLTHE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# 本软件系“按原样”提供，不包含任何形式的明示或默示保证，包括但不限于适销性、特定
# 目的适用性及不侵权的保证。在任何情况下，无论是在合同、侵权或其他案件中，作者或版
# 权持有人均不对因本软件、或因本软件的使用或其他利用而引起的、引发的或与之相关的任
# 何权利主张、损害赔偿或其他责任承担责任。
# =================================================================================
# Project:     autoMBD Motor Control <https://github.com/autoMBD/AMBD-MC>
# File:        layer_models.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-06
# Version:     0.1.0
# Description: Author shared FOC core, lifecycle and native plant models using MATLAB
#              MCP.
# =================================================================================

"""Author the shared FOC transition, lifecycle wrapper and native host plant."""


def add(kind, name, **params):
    return dict(op="add_block", type=kind, name=name, ref=name, params=params)


def connect(builder, model, ids, pairs, scope="root", names=None):
    operations = []
    for source, destination in pairs:
        a, port_a = source.split(".")
        b, port_b = destination.split(".")
        operation = dict(op="connect", target=f"{ids[a]}.{port_a} -> {ids[b]}.{port_b}")
        if names and b in names:
            operation["params"] = dict(Name=b)
        operations.append(operation)
    builder.edit(model, operations, scope=scope)


def input_script(inputs, core=False):
    result = "uCore" if core else "u"
    current = "Current" if core else "CurrentRaw"
    code = f"function {result}=fcn(" + ",".join(name for name, _ in inputs) + ")\n%#codegen\n"
    code += f"{result}.{current}=[Ia;Ib;Ic];\n{result}.Control=McControl;\n"
    code += f"{result}.Fault=FaultEvent;\n"
    if core:
        code += f"{result}.Disable=Disable;\n"
    for field, port in [("CommandEvent", "McCtrlEvent"), ("DrivingEvent", "McDrivingEvent"),
                        ("TimerEvent", "McTimerEvent"), ("SpeedReq", "SpeedReq"),
                        ("Vdc", "DcBusVoltage"), ("Position", "RotorAngle")]:
        code += f"{result}.{field}={port};\n"
    code += f"{result}.AppliedVoltage=[AppliedVoltageAlpha;AppliedVoltageBeta];\n"
    return code + f"{result}.Tuning=McTuningPort;\nend"


def core_transition(builder, model, scope, modules):
    ins = [("uCore", "Bus: tMcCoreInput"), ("core", "Bus: tMcCoreRuntime"),
           ("p", "Bus: tMcControlParams")]
    outs = [("nextCore", "Bus: tMcCoreRuntime")]
    ids = builder.edit(model, builder.ports(ins, outs) +
                       [add("SubSystem", name) for name, _ in modules], scope=scope)
    for name, function in modules:
        sub_scope = ids[name]
        builder.read(model, sub_scope)
        inner = builder.edit(model, builder.ports(ins, outs) +
                             [add("MATLAB Function", "Compute")], scope=sub_scope)
        builder.script(model, inner["Compute"],
                       f"function nextCore=fcn(uCore,core,p)\n%#codegen\n"
                       f"nextCore=mc.{function}(uCore,core,p);\nend")
        connect(builder, model, inner, [("uCore.y1", "Compute.u1"), ("core.y1", "Compute.u2"),
                                      ("p.y1", "Compute.u3"), ("Compute.y1", "nextCore.u1")],
                sub_scope)
        builder.read(model, sub_scope)
        builder.check(model, sub_scope)
    previous = "core"
    pairs = []
    for name, _ in modules:
        pairs += [("uCore.y1", f"{name}.u1"), (f"{previous}.y1", f"{name}.u2"),
                  ("p.y1", f"{name}.u3")]
        previous = name
    # The final guard handles asynchronous disable/fault after dataflow.
    guard = builder.edit(model, [add("MATLAB Function", "OutputGuard")], scope=scope,
                         layout="incremental")
    ids.update(guard)
    builder.script(model, ids["OutputGuard"],
                   "function nextCore=fcn(uCore,core)\n%#codegen\nnextCore=core;\n"
                   "if uCore.Disable || core.FaultBits~=uint16(0) || core.Command==uint8(0)\n"
                   "nextCore.GateEnable=false;nextCore.Duty=single([.5;.5;.5]);"
                   "nextCore.Voltage=single([0;0]);\nend\nend")
    pairs += [("uCore.y1", "OutputGuard.u1"), (f"{previous}.y1", "OutputGuard.u2"),
              ("OutputGuard.y1", "nextCore.u1")]
    connect(builder, model, ids, pairs, scope)
    builder.read(model, scope)
    builder.check(model, scope)


def controller(builder, model, scope, inputs, outputs, core=False):
    state = "McCoreRuntime_Init" if core else "McRuntime_Init"
    ops = builder.ports(inputs, outputs) + [
        add("MATLAB Function", "InputPack"),
        add("Constant", "Parameters", Value="McControl_Params", OutDataTypeStr="Bus: tMcControlParams"),
        add("UnitDelay", "RuntimeMemory", InitialCondition=state, SampleTime="6.25e-5"),
        add("MATLAB Function", "McDebug")]
    if not core:
        ops += [add("MATLAB Function", "MotorManagement"),
                add("MATLAB Function", "MotorStatus")]
    ids = builder.edit(model, ops, scope=scope)
    # Simulink requires a saved library before adding a link to its sibling.
    builder.matlab(f"save_system('{model}');")
    ids.update(builder.edit(model, [
        dict(op="add_block", type="FocCore", name="FocCore", ref="FocCore",
             ReferenceBlock=model + "/FocCore")], scope=scope, layout="incremental"))
    builder.script(model, ids["InputPack"], input_script(inputs, core))
    pairs = [(f"{name}.y1", f"InputPack.u{i}") for i, (name, _) in enumerate(inputs, 1)]
    if core:
        pairs += [("InputPack.y1", "FocCore.u1"), ("RuntimeMemory.y1", "FocCore.u2"),
                  ("Parameters.y1", "FocCore.u3"), ("FocCore.y1", "RuntimeMemory.u1"),
                  ("FocCore.y1", "McDebug.u1")]
        debug = ("function [a,b,c,debug,gate,monitor]=fcn(core,p)\n%#codegen\n"
                 "[~,debug,monitor]=mc.core_monitor(core,p);\n"
                 "a=core.Duty(1);b=core.Duty(2);c=core.Duty(3);gate=core.GateEnable;\nend")
    else:
        builder.script(model, ids["MotorManagement"],
                       "function [uCore,prepared,previousCore]=fcn(u,s,p)\n%#codegen\n"
                       "[uCore,prepared]=mc.motor_prepare(u,s,p);\n"
                       "previousCore=prepared.Core;\nend")
        builder.script(model, ids["MotorStatus"],
                       "function next=fcn(prepared,core)\n%#codegen\n"
                       "next=mc.motor_finish(prepared,core);\nend")
        pairs += [("InputPack.y1", "MotorManagement.u1"),
                  ("RuntimeMemory.y1", "MotorManagement.u2"),
                  ("Parameters.y1", "MotorManagement.u3"),
                  ("MotorManagement.y1", "FocCore.u1"),
                  ("MotorManagement.y3", "FocCore.u2"),
                  ("Parameters.y1", "FocCore.u3"),
                  ("MotorManagement.y2", "MotorStatus.u1"),
                  ("FocCore.y1", "MotorStatus.u2"),
                  ("MotorStatus.y1", "RuntimeMemory.u1"), ("MotorStatus.y1", "McDebug.u1")]
        debug = ("function [a,b,c,debug,gate,monitor]=fcn(s,p)\n%#codegen\n"
                 "[counts,debug,monitor]=mc.monitor(s,p);\n"
                 "a=counts(1);b=counts(2);c=counts(3);gate=s.Core.GateEnable;\nend")
    builder.script(model, ids["McDebug"], debug)
    pairs += [("Parameters.y1", "McDebug.u2")]
    pairs += [(f"McDebug.y{i}", f"{name}.u1") for i, (name, _) in enumerate(outputs, 1)]
    connect(builder, model, ids, pairs, scope)
    builder.read(model, scope)
    builder.check(model, scope)


def native_plant(builder, model, scope):
    """The disabled bridge imposes zero phase voltage (braking, not coasting)."""
    ins = [("Duty", "single"), ("GateEnable", "boolean"), ("Vdc", "single"),
           ("LoadTorque", "double")]
    outs = [("Current", "single"), ("Theta", "single"), ("Omega", "single"),
            ("AppliedVoltage", "single")]
    ops = builder.ports(ins, outs) + [
        dict(op="add_block", type="Average-Value Inverter", name="AverageInverter",
             ref="AverageInverter", ReferenceBlock="mcbplantlib/Average-Value Inverter"),
        dict(op="add_block", type="Interior PMSM", name="InteriorPMSM", ref="InteriorPMSM",
             ReferenceBlock="autolibpmsminterior/Interior PMSM", params={
                 "port_config": "Torque", "sim_type": "Continuous",
                 "P": "double(McPlant_Params.PolePairs)", "Rs": "double(McPlant_Params.Rs)",
                 "Ldq": "double([McPlant_Params.Ld McPlant_Params.Lq])",
                 "lambda_pm": "double(McPlant_Params.Flux)",
                 "mechanical": "[double(McPlant_Params.Inertia) double(McPlant_Params.Friction) 0]",
                 "idq0": "[0 0]", "theta_init": "0", "omega_init": "0"}),
        add("DataTypeConversion", "DutyDouble", OutDataTypeStr="double"),
        add("DataTypeConversion", "VdcDouble", OutDataTypeStr="double"),
        add("Switch", "GateVoltage", Criteria="u2 ~= 0"),
        add("Constant", "DisabledVoltage", Value="zeros(3,1)", OutDataTypeStr="double"),
        add("BusSelector", "MotorSignals", OutputSignals="MtrPos"),
        add("ZeroOrderHold", "SampleCurrent", SampleTime="1/16000"),
        add("ZeroOrderHold", "SamplePosition", SampleTime="1/16000"),
        add("ZeroOrderHold", "SampleSpeed", SampleTime="1/16000"),
        add("MATLAB Function", "Measurements"),
        add("Constant", "PlantParameters", Value="McPlant_Params", OutDataTypeStr="Bus: tMcControlParams"),
        add("MATLAB Function", "PhaseVoltageToAlphaBeta"),
        add("UnitDelay", "SampleIntervalVoltage", InitialCondition="single([0;0])",
            SampleTime="1/16000")]
    ids = builder.edit(model, ops, scope=scope)
    builder.script(model, ids["Measurements"],
                   "function [current,theta,omega]=fcn(i,t,w,p)\n%#codegen\n"
                   "current=single(i(:));theta=mc.wrap_angle(single(t)*single(p.PolePairs));\n"
                   "omega=single(w)*single(p.PolePairs);\nend")
    builder.script(model, ids["PhaseVoltageToAlphaBeta"],
                   "function voltage=fcn(phase)\n%#codegen\nvoltage=mc.clarke(single(phase(:)));\nend")
    pairs = [("Duty.y1", "DutyDouble.u1"), ("DutyDouble.y1", "AverageInverter.u1"),
             ("Vdc.y1", "VdcDouble.u1"), ("VdcDouble.y1", "AverageInverter.u2"),
             ("AverageInverter.y1", "GateVoltage.u1"), ("GateEnable.y1", "GateVoltage.u2"),
             ("DisabledVoltage.y1", "GateVoltage.u3"), ("GateVoltage.y1", "InteriorPMSM.u2"),
             ("LoadTorque.y1", "InteriorPMSM.u1"), ("InteriorPMSM.y1", "MotorSignals.u1"),
             ("InteriorPMSM.y2", "SampleCurrent.u1"), ("InteriorPMSM.y3", "SampleSpeed.u1"),
             ("MotorSignals.y1", "SamplePosition.u1"), ("SampleCurrent.y1", "Measurements.u1"),
             ("SamplePosition.y1", "Measurements.u2"), ("SampleSpeed.y1", "Measurements.u3"),
             ("PlantParameters.y1", "Measurements.u4"), ("Measurements.y1", "Current.u1"),
             ("Measurements.y2", "Theta.u1"), ("Measurements.y3", "Omega.u1"),
             ("GateVoltage.y1", "PhaseVoltageToAlphaBeta.u1"),
             ("PhaseVoltageToAlphaBeta.y1", "SampleIntervalVoltage.u1"),
             ("SampleIntervalVoltage.y1", "AppliedVoltage.u1")]
    connect(builder, model, ids, pairs, scope)
    builder.read(model, scope)
    builder.check(model, scope)


def host_top(builder, name, reference, inputs, outputs, core=False):
    path = builder.fresh(name, "platform/pil")
    ins = [("SpeedReq", "single"), ("Control", "uint8"), ("Fault", "boolean"),
           ("LoadTorque", "double"), ("Vdc", "single")]
    input_type = "tMcCoreInput" if core else "tMcInput"
    outs = [("OmegaTruth", "single"), ("CurrentTruth", "single"),
            ("Monitor", "Bus: tMcMonitor"), ("Duty", "uint16"),
            ("GateEnable", "boolean"), ("ThetaTruth", "single"),
            ("ControllerInput", "Bus: " + input_type)]
    ops = builder.ports(ins, outs) + [
        add("ModelReference", "Controller", ModelName=reference),
        dict(op="add_block", type="AveragePlant", name="Plant", ref="Plant",
             ReferenceBlock="McControllerLibrary/AveragePlant"),
        add("MATLAB Function", "SensorAdapter"),
        add("MATLAB Function", "InputLog"),
        add("MATLAB Function", "PwmAdapter"),
        add("BusSelector", "ControllerSignals", OutputSignals=(
            "Current" if core else "CurrentRaw") +
            ",Control,Fault,CommandEvent,DrivingEvent,TimerEvent,Tuning,SpeedReq,Vdc,Position,AppliedVoltage" +
            (",Disable" if core else "")),
        add("Demux", "CurrentChannels", Outputs="3"),
        add("Demux", "VoltageChannels", Outputs="2"),
        add("Constant", "PlantParameters", Value="McPlant_Params", OutDataTypeStr="Bus: tMcControlParams"),
        add("Constant", "ControlParameters", Value="McControl_Params", OutDataTypeStr="Bus: tMcControlParams"),
        add("Constant", "Tuning", Value="McInput_Default.Tuning", OutDataTypeStr="Bus: tMcTuning"),
        add("Constant", "Events", Value="true", OutDataTypeStr="boolean"),
        add("Constant", "Disable", Value="false", OutDataTypeStr="boolean"),
        add("UnitDelay", "DutyDelay", InitialCondition="single([.5;.5;.5])", SampleTime="6.25e-5"),
        add("UnitDelay", "GateDelay", InitialCondition="false", SampleTime="6.25e-5"),
        add("Logic", "GateQualified", Operator="AND", Inputs="2"),
        add("Terminator", "DebugSink")]
    ids = builder.edit(name, ops)
    sensor = "current=measured;" if core else "current=uint16(round(double(measured)*double(p.AdcCountsPerAmp)+double(p.AdcOffset)));"
    builder.script(name, ids["SensorAdapter"],
                   "function current=fcn(measured,p)\n%#codegen\n" + sensor + "\nend")
    # This bus is both the actual controller source and the replay recording.
    bus = "uCore" if core else "u"
    field = "Current" if core else "CurrentRaw"
    builder.script(name, ids["InputLog"],
                   f"function {bus}=fcn(current,control,fault,event,tuning,speed,vdc,position,voltage,disable)\n"
                   f"%#codegen\n{bus}.{field}=current;{bus}.Control=control;{bus}.Fault=fault;\n" +
                   (f"{bus}.Disable=disable;\n" if core else "") +
                   f"{bus}.CommandEvent=event;{bus}.DrivingEvent=event;{bus}.TimerEvent=event;\n"
                   f"{bus}.SpeedReq=speed;{bus}.Vdc=vdc;{bus}.Position=position;\n"
                   f"{bus}.AppliedVoltage=voltage;{bus}.Tuning=tuning;\nend")
    pwm = ("counts=uint16(round(min(max(single([a;b;c]),single(0)),single(1))*single(p.PwmPeriod)));"
           if core else "counts=[a;b;c];")
    builder.script(name, ids["PwmAdapter"],
                   "function [duty,counts]=fcn(a,b,c,p)\n%#codegen\n" + pwm +
                   "\nduty=single(counts)/single(p.PwmPeriod);\nend")
    pairs = [("Plant.y1", "SensorAdapter.u1"), ("PlantParameters.y1", "SensorAdapter.u2"),
             ("SensorAdapter.y1", "InputLog.u1"), ("Control.y1", "InputLog.u2"),
             ("Fault.y1", "InputLog.u3"), ("Events.y1", "InputLog.u4"),
             ("Tuning.y1", "InputLog.u5"), ("SpeedReq.y1", "InputLog.u6"),
             ("Vdc.y1", "InputLog.u7"), ("Plant.y2", "InputLog.u8"),
             ("Plant.y4", "InputLog.u9"), ("Disable.y1", "InputLog.u10"),
             ("InputLog.y1", "ControllerSignals.u1"), ("InputLog.y1", "ControllerInput.u1"),
             ("ControllerSignals.y1", "CurrentChannels.u1"),
             ("ControllerSignals.y11", "VoltageChannels.u1"),
             ("Controller.y1", "PwmAdapter.u1"), ("Controller.y2", "PwmAdapter.u2"),
             ("Controller.y3", "PwmAdapter.u3"), ("ControlParameters.y1", "PwmAdapter.u4"),
             ("PwmAdapter.y1", "DutyDelay.u1"), ("PwmAdapter.y2", "Duty.u1"),
             ("Controller.y5", "GateDelay.u1"), ("Controller.y5", "GateEnable.u1"),
             ("Controller.y5", "GateQualified.u1"), ("GateDelay.y1", "GateQualified.u2"),
             ("DutyDelay.y1", "Plant.u1"), ("GateQualified.y1", "Plant.u2"),
             ("Vdc.y1", "Plant.u3"), ("LoadTorque.y1", "Plant.u4"),
             ("Plant.y1", "CurrentTruth.u1"), ("Plant.y2", "ThetaTruth.u1"),
             ("Plant.y3", "OmegaTruth.u1"), ("Controller.y6", "Monitor.u1"),
             ("Controller.y4", "DebugSink.u1")]
    pairs += [(f"CurrentChannels.y{i}", f"Controller.u{i}") for i in range(1, 4)]
    pairs += [(f"ControllerSignals.y{i}", f"Controller.u{i+2}") for i in range(2, 11)]
    pairs += [("VoltageChannels.y1", "Controller.u13"), ("VoltageChannels.y2", "Controller.u14")]
    if core:
        pairs += [("ControllerSignals.y12", "Controller.u15")]
    connect(builder, name, ids, pairs, names={n for n, _ in outs})
    builder.finish(name, path)
    builder.mapping[name] = ids
