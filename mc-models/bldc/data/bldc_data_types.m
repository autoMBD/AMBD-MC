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
% File:        mc_data_types.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-07
% Version:     0.1.0
% Description: Layered Simulink data type definitions generated from
%              docs/BldcStruct.md.
% =================================================================================

BldcRaw16_T = createNumericType(false, 16, 0, 1, 0, 'Unsigned raw 16-bit representation');

BldcSingle_T = createAliasType('single', '', 'BLDC single storage');
BldcUInt8_T = createAliasType('uint8', '', 'BLDC uint8 storage');
BldcInt8_T = createAliasType('int8', '', 'BLDC int8 storage');
BldcUInt16_T = createAliasType('uint16', '', 'BLDC uint16 storage');
BldcUInt32_T = createAliasType('uint32', '', 'BLDC uint32 storage');
BldcInt32_T = createAliasType('int32', '', 'BLDC int32 storage');
BldcBool_T = createAliasType('boolean', '', 'BLDC logical storage');

BldcTime_V = createValueType('BldcSingle_T', 's', 0, [], 'Time in seconds');
BldcVoltage_V = createValueType('BldcSingle_T', 'V', [], [], 'Measured voltage');
BldcCurrent_V = createValueType('BldcSingle_T', 'A', [], [], 'Phase current');

eBldcPositionMode = Simulink.data.dictionary.EnumTypeDefinition;
removeEnumeral(eBldcPositionMode, 1);
appendEnumeral(eBldcPositionMode, 'Hall', 0, 'Hall edge feedback');
appendEnumeral(eBldcPositionMode, 'Sensorless', 1, 'Terminal voltage zero crossing feedback');
eBldcPositionMode.DefaultValue = 'Hall';
eBldcPositionMode.StorageType = 'uint8';

tBldcParams = createBusType('Fixed-size BLDC params interface.', {
    'Ts', 'ValueType: BldcTime_V', 1, 'Ts';
    'SpeedDivider', 'BldcUInt16_T', 1, 'SpeedDivider';
    'AdcOffset', 'BldcSingle_T', 1, 'AdcOffset';
    'AdcCountsPerAmp', 'BldcSingle_T', 1, 'AdcCountsPerAmp';
    'PwmPeriod', 'BldcUInt16_T', 1, 'PwmPeriod';
    'Rs', 'BldcSingle_T', 1, 'Rs';
    'Ls', 'BldcSingle_T', 1, 'Ls';
    'Ke', 'BldcSingle_T', 1, 'Ke';
    'PolePairs', 'BldcUInt8_T', 1, 'PolePairs';
    'Inertia', 'BldcSingle_T', 1, 'Inertia';
    'Friction', 'BldcSingle_T', 1, 'Friction';
    'PlantSubsteps', 'BldcUInt16_T', 1, 'PlantSubsteps';
    'NominalVdc', 'ValueType: BldcVoltage_V', 1, 'NominalVdc';
    'VdcMin', 'ValueType: BldcVoltage_V', 1, 'VdcMin';
    'VdcMax', 'ValueType: BldcVoltage_V', 1, 'VdcMax';
    'CurrentLimit', 'BldcSingle_T', 1, 'CurrentLimit';
    'TripCurrent', 'BldcSingle_T', 1, 'TripCurrent';
    'SpeedLimit', 'BldcSingle_T', 1, 'SpeedLimit';
    'MaxModulation', 'BldcSingle_T', 1, 'MaxModulation';
    'KpCurrent', 'BldcSingle_T', 1, 'KpCurrent';
    'KiCurrent', 'BldcSingle_T', 1, 'KiCurrent';
    'KpSpeed', 'BldcSingle_T', 1, 'KpSpeed';
    'KiSpeed', 'BldcSingle_T', 1, 'KiSpeed';
    'SpeedSlew', 'BldcSingle_T', 1, 'SpeedSlew';
    'CurrentSlew', 'BldcSingle_T', 1, 'CurrentSlew';
    'AlignTime', 'BldcSingle_T', 1, 'AlignTime';
    'AlignCurrent', 'BldcSingle_T', 1, 'AlignCurrent';
    'OpenCurrent', 'BldcSingle_T', 1, 'OpenCurrent';
    'OpenAccel', 'BldcSingle_T', 1, 'OpenAccel';
    'OpenSpeed', 'BldcSingle_T', 1, 'OpenSpeed';
    'TrackingTime', 'BldcSingle_T', 1, 'TrackingTime';
    'TrackingTimeout', 'BldcSingle_T', 1, 'Maximum tracking qualification duration';
    'StartTimeout', 'BldcSingle_T', 1, 'StartTimeout';
    'StopSpeed', 'BldcSingle_T', 1, 'StopSpeed';
    'StopTimeout', 'BldcSingle_T', 1, 'StopTimeout';
    'StopCoastTime', 'BldcSingle_T', 1, 'StopCoastTime';
    'HallTimeout', 'BldcSingle_T', 1, 'HallTimeout';
    'HallStartTimeout', 'BldcSingle_T', 1, 'HallStartTimeout';
    'HallStallCurrent', 'BldcSingle_T', 1, 'HallStallCurrent';
    'SpeedFilterAlpha', 'BldcSingle_T', 1, 'SpeedFilterAlpha';
    'HallGainSpeed', 'BldcSingle_T', 1, 'Electrical request in rad/s at full Hall speed-loop gains';
    'HallMinGainScale', 'BldcSingle_T', 1, 'Minimum Hall proportional gain scale; integral uses its square';
    'ZcBlankTicks', 'BldcUInt16_T', 1, 'ZcBlankTicks';
    'ZcHysteresis', 'BldcSingle_T', 1, 'ZcHysteresis';
    'FloatCurrentLimit', 'BldcSingle_T', 1, 'FloatCurrentLimit';
    'ZcMinTicks', 'BldcUInt32_T', 1, 'ZcMinTicks';
    'ZcMaxTicks', 'BldcUInt32_T', 1, 'ZcMaxTicks';
    'ZcRequired', 'BldcUInt16_T', 1, 'ZcRequired';
    'ZcTimeoutFactor', 'BldcSingle_T', 1, 'ZcTimeoutFactor';
    'ZcMinSpeed', 'BldcSingle_T', 1, 'ZcMinSpeed';
    'AcquireSpacing', 'BldcUInt16_T', 1, 'AcquireSpacing';
    'AcquireMinVoltage', 'BldcSingle_T', 1, 'AcquireMinVoltage';
    'AcquireTimeout', 'BldcSingle_T', 1, 'AcquireTimeout';
    'LowSpeedThreshold', 'BldcSingle_T', 1, 'LowSpeedThreshold';
    'PositionMode', 'BldcUInt8_T', 1, '0 Hall; 1 terminal-voltage sensorless';
    'CurrentSenseMode', 'BldcUInt8_T', 1, '0 three phase sensors; 1 valid-window DC-link shunt';
    'MinModulation', 'BldcSingle_T', 1, 'Minimum energized duty in DC-link mode';
    'DemagBlankFraction', 'BldcSingle_T', 1, 'Commutation-period fraction excluded after switching';
    'DemagRailMargin', 'BldcSingle_T', 1, 'Floating terminal must leave both clamp rails by this voltage';
    'DemagReleaseTicks', 'BldcUInt16_T', 1, 'Consecutive unclamped samples required before ZC arming';
    'ActuationDelayTicks', 'BldcUInt16_T', 1, 'Compensated output activation delay for DC-link commutation';
});

tBldcInput = createBusType('Fixed-size BLDC input interface.', {
    'CurrentRaw', 'BldcUInt16_T', 3, 'Phase ADC encodings; DC-link mode uses element 1 only';
    'Hall', 'BldcUInt8_T', 1, 'Hall';
    'TerminalVoltage', 'BldcSingle_T', 3, 'Three phase terminal voltages; DC-link mode qualifies the applied floating phase only';
    'Control', 'BldcUInt8_T', 1, 'Control';
    'Fault', 'BldcBool_T', 1, 'Fault';
    'CommandEvent', 'BldcBool_T', 1, 'CommandEvent';
    'DrivingEvent', 'BldcBool_T', 1, 'DrivingEvent';
    'TimerEvent', 'BldcBool_T', 1, 'TimerEvent';
    'SpeedReq', 'BldcSingle_T', 1, 'SpeedReq';
    'Vdc', 'ValueType: BldcVoltage_V', 1, 'Vdc';
    'AppliedSector', 'BldcUInt8_T', 1, 'AppliedSector';
    'AppliedDirection', 'BldcInt8_T', 1, 'AppliedDirection';
    'VoltageValid', 'BldcBool_T', 1, 'VoltageValid';
});

tBldcRuntime = createBusType('Fixed-size BLDC runtime interface.', {
    'Parameters', 'Bus: tBldcParams', 1, 'Complete independent controller calibration';
    'Mode', 'BldcUInt8_T', 1, 'Mode';
    'PreviousMode', 'BldcUInt8_T', 1, 'PreviousMode';
    'ModeTicks', 'BldcUInt32_T', 1, 'ModeTicks';
    'Tick', 'BldcUInt32_T', 1, 'Tick';
    'SlowCounter', 'BldcUInt16_T', 1, 'SlowCounter';
    'FastTick', 'BldcBool_T', 1, 'FastTick';
    'SpeedTick', 'BldcBool_T', 1, 'SpeedTick';
    'Command', 'BldcUInt8_T', 1, 'Command';
    'SpeedRequest', 'BldcSingle_T', 1, 'SpeedRequest';
    'SpeedRamped', 'BldcSingle_T', 1, 'SpeedRamped';
    'CoastTicks', 'BldcUInt32_T', 1, 'CoastTicks';
    'Direction', 'BldcInt8_T', 1, 'Direction';
    'OutputDirection', 'BldcInt8_T', 1, 'OutputDirection';
    'Sector', 'BldcUInt8_T', 1, 'Sector';
    'GateEnable', 'BldcBool_T', 1, 'GateEnable';
    'PhaseEnable', 'BldcBool_T', 3, 'PhaseEnable';
    'DutyCounts', 'BldcUInt16_T', 3, 'DutyCounts';
    'Modulation', 'BldcSingle_T', 1, 'Modulation';
    'Current', 'BldcSingle_T', 3, 'Three phase currents in A';
    'CurrentRef', 'ValueType: BldcCurrent_V', 1, 'CurrentRef';
    'CurrentDemand', 'ValueType: BldcCurrent_V', 1, 'Saturated speed-loop current demand before slew';
    'CurrentMeasured', 'ValueType: BldcCurrent_V', 1, 'CurrentMeasured';
    'CurrentIntegrator', 'BldcSingle_T', 1, 'CurrentIntegrator';
    'SpeedIntegrator', 'BldcSingle_T', 1, 'SpeedIntegrator';
    'SpeedEstimate', 'BldcSingle_T', 1, 'SpeedEstimate';
    'ControlSpeed', 'BldcSingle_T', 1, 'ControlSpeed';
    'RawSpeed', 'BldcSingle_T', 1, 'RawSpeed';
    'HallLast', 'BldcUInt8_T', 1, 'HallLast';
    'HallSector', 'BldcUInt8_T', 1, 'HallSector';
    'HallAge', 'BldcUInt32_T', 1, 'HallAge';
    'HallValid', 'BldcBool_T', 1, 'HallValid';
    'HallDirection', 'BldcInt8_T', 1, 'HallDirection';
    'FeedbackReady', 'BldcBool_T', 1, 'FeedbackReady';
    'OmegaOpen', 'BldcSingle_T', 1, 'OmegaOpen';
    'ThetaOpen', 'BldcSingle_T', 1, 'ThetaOpen';
    'AppliedLastSector', 'BldcUInt8_T', 1, 'AppliedLastSector';
    'AppliedAge', 'BldcUInt32_T', 1, 'AppliedAge';
    'ZcAge', 'BldcUInt32_T', 1, 'ZcAge';
    'ZcPeriod', 'BldcSingle_T', 1, 'ZcPeriod';
    'ZcCount', 'BldcUInt16_T', 1, 'ZcCount';
    'ZcFound', 'BldcBool_T', 1, 'ZcFound';
    'ZcArmed', 'BldcBool_T', 1, 'ZcArmed';
    'ZcValue', 'BldcSingle_T', 1, 'ZcValue';
    'ZcCountdown', 'BldcInt32_T', 1, 'ZcCountdown';
    'ZcNextSector', 'BldcUInt8_T', 1, 'ZcNextSector';
    'AcquireStage', 'BldcUInt8_T', 1, 'AcquireStage';
    'AcquireTheta', 'BldcSingle_T', 1, 'AcquireTheta';
    'AcquireAge', 'BldcUInt32_T', 1, 'AcquireAge';
    'AcquisitionReady', 'BldcBool_T', 1, 'Terminal voltage coast acquisition qualified';
    'SensorFault', 'BldcUInt16_T', 1, 'SensorFault';
    'ActiveFaults', 'BldcUInt16_T', 1, 'ActiveFaults';
    'FaultBits', 'BldcUInt16_T', 1, 'FaultBits';
    'PhaseCurrentsValid', 'BldcBool_T', 1, 'True only for actual phase-current sensing';
    'DcCurrent', 'ValueType: BldcCurrent_V', 1, 'Last valid DC-link current; not a three-phase reconstruction';
    'DcCurrentValid', 'BldcBool_T', 1, 'Current frame sampled in a qualified conduction window';
    'ZcUnclampedCount', 'BldcUInt16_T', 1, 'Consecutive floating-voltage rail-release observations';
});

tBldcDebug = createBusType('Fixed-size BLDC debug interface.', {
    'Enabled', 'BldcBool_T', 1, 'Enabled';
    'Data', 'BldcSingle_T', 16, '16 ordered monitor channels; see bldc.monitor';
});

tBldcMonitor = createBusType('Fixed-size BLDC monitor interface.', {
    'Mode', 'BldcUInt8_T', 1, 'Mode';
    'FaultBits', 'BldcUInt16_T', 1, 'FaultBits';
    'Tick', 'BldcUInt32_T', 1, 'Tick';
    'Current', 'BldcSingle_T', 3, 'Three phase currents in A';
    'CurrentReference', 'ValueType: BldcCurrent_V', 1, 'CurrentReference';
    'CurrentDemand', 'ValueType: BldcCurrent_V', 1, 'Saturated speed-loop current demand before slew';
    'SpeedRequest', 'BldcSingle_T', 1, 'SpeedRequest';
    'SpeedRamped', 'BldcSingle_T', 1, 'SpeedRamped';
    'SpeedEstimate', 'BldcSingle_T', 1, 'SpeedEstimate';
    'ControlSpeed', 'BldcSingle_T', 1, 'ControlSpeed';
    'Sector', 'BldcUInt8_T', 1, 'Sector';
    'Direction', 'BldcInt8_T', 1, 'Direction';
    'OutputDirection', 'BldcInt8_T', 1, 'OutputDirection';
    'Modulation', 'BldcSingle_T', 1, 'Modulation';
    'GateEnable', 'BldcBool_T', 1, 'GateEnable';
    'PhaseEnable', 'BldcBool_T', 3, 'PhaseEnable';
    'FeedbackReady', 'BldcBool_T', 1, 'FeedbackReady';
    'ZcCount', 'BldcUInt16_T', 1, 'ZcCount';
    'ZcPeriod', 'BldcSingle_T', 1, 'ZcPeriod';
    'ZcCountdown', 'BldcInt32_T', 1, 'ZcCountdown';
    'AcquisitionReady', 'BldcBool_T', 1, 'Terminal voltage coast acquisition qualified';
    'PositionMode', 'BldcUInt8_T', 1, '0 Hall; 1 terminal-voltage sensorless';
    'VoltageResidual', 'BldcSingle_T', 1, 'VoltageResidual';
    'CurrentIntegrator', 'BldcSingle_T', 1, 'CurrentIntegrator';
    'SpeedIntegrator', 'BldcSingle_T', 1, 'SpeedIntegrator';
    'HallSector', 'BldcUInt8_T', 1, 'HallSector';
    'HallValid', 'BldcBool_T', 1, 'HallValid';
    'AppliedAge', 'BldcUInt32_T', 1, 'AppliedAge';
    'CurrentMeasured', 'ValueType: BldcCurrent_V', 1, 'CurrentMeasured';
    'CurrentSenseMode', 'BldcUInt8_T', 1, '0 phase sensors; 1 DC-link shunt';
    'PhaseCurrentsValid', 'BldcBool_T', 1, 'Validity of the Current vector';
    'DcCurrent', 'ValueType: BldcCurrent_V', 1, 'Last valid DC-link current';
    'DcCurrentValid', 'BldcBool_T', 1, 'Validity of this DC-link sample';
});

function numeric_type = createNumericType(signed_flag, word_length, fraction_length, slope, bias, description)
numeric_type = Simulink.NumericType; numeric_type.DataTypeMode = 'Fixed-point: binary point scaling';
numeric_type.SignednessBool = logical(signed_flag); numeric_type.WordLength = word_length; numeric_type.FractionLength = fraction_length;
numeric_type.Slope = slope; numeric_type.Bias = bias; numeric_type.Description = description;
end

function alias_type = createAliasType(base_type, header_file, description)
alias_type = Simulink.AliasType; alias_type.BaseType = base_type;
if ~isempty(header_file), alias_type.HeaderFile = header_file; end; alias_type.Description = description;
end

function value_type = createValueType(data_type, unit, min_value, max_value, description)
value_type = Simulink.ValueType; value_type.DataType = data_type;
if ~isempty(unit), value_type.Unit = unit; end; if ~isempty(min_value), value_type.Min = min_value; end; if ~isempty(max_value), value_type.Max = max_value; end;
value_type.Description = description;
end

function bus_type = createBusType(description, field_defs)
elems = repmat(Simulink.BusElement, size(field_defs, 1), 1);
for idx = 1:size(field_defs, 1), elems(idx).Name = field_defs{idx,1}; elems(idx).DataType = field_defs{idx,2}; elems(idx).Dimensions = field_defs{idx,3}; elems(idx).Description = field_defs{idx,4}; end
bus_type = Simulink.Bus; bus_type.DataScope = 'Auto'; bus_type.Description = description; bus_type.Elements = elems;
end
