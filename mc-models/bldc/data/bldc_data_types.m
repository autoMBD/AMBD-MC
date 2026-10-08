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
% Date:        2026-10-09
% Version:     0.1.0
% Description: Layered Simulink data type definitions generated from
%              docs/BldcStruct.md.
% =================================================================================

BldcRaw16_T = createNumericType(false, 16, 0, 1, 0, '无符号 16 位原始表示');

BldcSingle_T = createAliasType('single', '', 'BLDC 单精度存储');
BldcUInt8_T = createAliasType('uint8', '', 'BLDC 无符号 8 位存储');
BldcInt8_T = createAliasType('int8', '', 'BLDC 有符号 8 位存储');
BldcUInt16_T = createAliasType('uint16', '', 'BLDC 无符号 16 位存储');
BldcUInt32_T = createAliasType('uint32', '', 'BLDC 无符号 32 位存储');
BldcInt32_T = createAliasType('int32', '', 'BLDC 有符号 32 位存储');
BldcBool_T = createAliasType('boolean', '', 'BLDC 逻辑存储');

BldcTime_V = createValueType('BldcSingle_T', 's', 0, [], '以秒为单位的时间');
BldcVoltage_V = createValueType('BldcSingle_T', 'V', [], [], '测量电压');
BldcCurrent_V = createValueType('BldcSingle_T', 'A', [], [], '相电流');

eBldcPositionMode = Simulink.data.dictionary.EnumTypeDefinition;
removeEnumeral(eBldcPositionMode, 1);
appendEnumeral(eBldcPositionMode, 'Hall', 0, '霍尔边沿反馈');
appendEnumeral(eBldcPositionMode, 'Sensorless', 1, '端电压过零反馈');
eBldcPositionMode.DefaultValue = 'Hall';
eBldcPositionMode.StorageType = 'uint8';

tBldcParams = createBusType('固定尺寸的 BLDC 参数接口。', {
    'Ts', 'ValueType: BldcTime_V', 1, '快速采样周期';
    'SpeedDivider', 'BldcUInt16_T', 1, '速度环分频系数';
    'AdcOffset', 'BldcSingle_T', 1, 'ADC 零点偏移';
    'AdcCountsPerAmp', 'BldcSingle_T', 1, '每安培对应的 ADC 计数';
    'PwmPeriod', 'BldcUInt16_T', 1, 'PWM 周期计数';
    'Rs', 'BldcSingle_T', 1, '相电阻';
    'Ls', 'BldcSingle_T', 1, '相电感';
    'Ke', 'BldcSingle_T', 1, '反电动势系数';
    'PolePairs', 'BldcUInt8_T', 1, '极对数';
    'Inertia', 'BldcSingle_T', 1, '转动惯量';
    'Friction', 'BldcSingle_T', 1, '黏性摩擦系数';
    'PlantSubsteps', 'BldcUInt16_T', 1, '被控对象积分子步数';
    'NominalVdc', 'ValueType: BldcVoltage_V', 1, '标称直流母线电压';
    'VdcMin', 'ValueType: BldcVoltage_V', 1, '母线欠压阈值';
    'VdcMax', 'ValueType: BldcVoltage_V', 1, '母线过压阈值';
    'CurrentLimit', 'BldcSingle_T', 1, '电流参考限值';
    'TripCurrent', 'BldcSingle_T', 1, '过流跳闸阈值';
    'SpeedLimit', 'BldcSingle_T', 1, '速度请求限值';
    'MaxModulation', 'BldcSingle_T', 1, '最大调制度';
    'KpCurrent', 'BldcSingle_T', 1, '电流环比例增益';
    'KiCurrent', 'BldcSingle_T', 1, '电流环积分增益';
    'KpSpeed', 'BldcSingle_T', 1, '速度环比例增益';
    'KiSpeed', 'BldcSingle_T', 1, '速度环积分增益';
    'SpeedSlew', 'BldcSingle_T', 1, '速度请求变化率限值';
    'CurrentSlew', 'BldcSingle_T', 1, '电流参考变化率限值';
    'AlignTime', 'BldcSingle_T', 1, '对齐持续时间';
    'AlignCurrent', 'BldcSingle_T', 1, '对齐电流';
    'OpenCurrent', 'BldcSingle_T', 1, '开环启动电流';
    'OpenAccel', 'BldcSingle_T', 1, '开环电角加速度';
    'OpenSpeed', 'BldcSingle_T', 1, '开环目标电角速度';
    'TrackingTime', 'BldcSingle_T', 1, '跟踪确认时间';
    'TrackingTimeout', 'BldcSingle_T', 1, '跟踪有效性确认的最大持续时间';
    'StartTimeout', 'BldcSingle_T', 1, '启动超时时间';
    'StopSpeed', 'BldcSingle_T', 1, '停止速度阈值';
    'StopTimeout', 'BldcSingle_T', 1, '停止超时时间';
    'StopCoastTime', 'BldcSingle_T', 1, '停止滑行时间';
    'HallTimeout', 'BldcSingle_T', 1, '霍尔运行边沿超时时间';
    'HallStartTimeout', 'BldcSingle_T', 1, '霍尔启动超时时间';
    'HallStallCurrent', 'BldcSingle_T', 1, '霍尔堵转检测电流阈值';
    'SpeedFilterAlpha', 'BldcSingle_T', 1, '速度滤波系数';
    'HallGainSpeed', 'BldcSingle_T', 1, '采用完整霍尔速度环增益时的请求电角速度，单位 rad/s';
    'HallMinGainScale', 'BldcSingle_T', 1, '霍尔比例增益的最小缩放比例；积分增益使用其平方';
    'ZcBlankTicks', 'BldcUInt16_T', 1, '过零检测消隐节拍数';
    'ZcHysteresis', 'BldcSingle_T', 1, '过零检测滞环电压';
    'FloatCurrentLimit', 'BldcSingle_T', 1, '悬浮相电流限值';
    'ZcMinTicks', 'BldcUInt32_T', 1, '有效过零间隔的最小节拍数';
    'ZcMaxTicks', 'BldcUInt32_T', 1, '有效过零间隔的最大节拍数';
    'ZcRequired', 'BldcUInt16_T', 1, '闭环就绪所需有效过零次数';
    'ZcTimeoutFactor', 'BldcSingle_T', 1, '过零超时系数';
    'ZcMinSpeed', 'BldcSingle_T', 1, '过零反馈的最低有效电角速度';
    'AcquireSpacing', 'BldcUInt16_T', 1, '捕获快照间隔节拍数';
    'AcquireMinVoltage', 'BldcSingle_T', 1, '捕获所需最小电压跨度';
    'AcquireTimeout', 'BldcSingle_T', 1, '捕获超时时间';
    'LowSpeedThreshold', 'BldcSingle_T', 1, '低速回退阈值';
    'PositionMode', 'BldcUInt8_T', 1, '0 霍尔；1 端电压无感';
    'CurrentSenseMode', 'BldcUInt8_T', 1, '0 三相电流传感器；1 有效采样窗口内的直流母线分流';
    'MinModulation', 'BldcSingle_T', 1, '直流母线采样模式下通电占空比下限';
    'DemagBlankFraction', 'BldcSingle_T', 1, '换相后排除的区间占换相周期的比例';
    'DemagRailMargin', 'BldcSingle_T', 1, '悬浮端脱离上下钳位电源轨所需的电压裕量';
    'DemagReleaseTicks', 'BldcUInt16_T', 1, '使能过零检测前所需连续未钳位样本数';
    'ActuationDelayTicks', 'BldcUInt16_T', 1, '直流母线采样换相所补偿的输出生效延迟';
});

tBldcInput = createBusType('固定尺寸的 BLDC 输入接口。', {
    'CurrentRaw', 'BldcUInt16_T', 3, '相电流 ADC 编码；直流母线模式仅使用第 1 个元素';
    'Hall', 'BldcUInt8_T', 1, '霍尔编码';
    'TerminalVoltage', 'BldcSingle_T', 3, '三相端电压；直流母线模式仅校验实际悬浮相';
    'Control', 'BldcUInt8_T', 1, '控制命令';
    'Fault', 'BldcBool_T', 1, '外部故障输入';
    'CommandEvent', 'BldcBool_T', 1, '命令事件';
    'DrivingEvent', 'BldcBool_T', 1, '驱动节拍事件';
    'TimerEvent', 'BldcBool_T', 1, '定时事件';
    'SpeedReq', 'BldcSingle_T', 1, '请求电角速度';
    'Vdc', 'ValueType: BldcVoltage_V', 1, '直流母线电压';
    'AppliedSector', 'BldcUInt8_T', 1, '采样区间实际生效的扇区';
    'AppliedDirection', 'BldcInt8_T', 1, '采样区间实际生效的方向';
    'VoltageValid', 'BldcBool_T', 1, '端电压采样有效标志';
});

tBldcRuntime = createBusType('固定尺寸的 BLDC 运行时接口。', {
    'Parameters', 'Bus: tBldcParams', 1, '完整且独立的控制器标定';
    'Mode', 'BldcUInt8_T', 1, '当前模式';
    'PreviousMode', 'BldcUInt8_T', 1, '上一模式';
    'ModeTicks', 'BldcUInt32_T', 1, '当前模式持续节拍数';
    'Tick', 'BldcUInt32_T', 1, '快速节拍计数';
    'SlowCounter', 'BldcUInt16_T', 1, '慢速分频计数器';
    'FastTick', 'BldcBool_T', 1, '快速更新标志';
    'SpeedTick', 'BldcBool_T', 1, '速度环更新标志';
    'Command', 'BldcUInt8_T', 1, '已锁存控制命令';
    'SpeedRequest', 'BldcSingle_T', 1, '已锁存速度请求';
    'SpeedRamped', 'BldcSingle_T', 1, '变化率限制后的速度请求';
    'CoastTicks', 'BldcUInt32_T', 1, '滑行节拍计数';
    'Direction', 'BldcInt8_T', 1, '控制方向';
    'OutputDirection', 'BldcInt8_T', 1, '输出方向';
    'Sector', 'BldcUInt8_T', 1, '换相扇区';
    'GateEnable', 'BldcBool_T', 1, '全局门极使能';
    'PhaseEnable', 'BldcBool_T', 3, '各相桥臂使能';
    'DutyCounts', 'BldcUInt16_T', 3, '三相占空比计数';
    'Modulation', 'BldcSingle_T', 1, '调制度';
    'Current', 'BldcSingle_T', 3, '三相电流，单位 A';
    'CurrentRef', 'ValueType: BldcCurrent_V', 1, '电流参考';
    'CurrentDemand', 'ValueType: BldcCurrent_V', 1, '变化率限制前已限幅的速度环电流需求';
    'CurrentMeasured', 'ValueType: BldcCurrent_V', 1, '用于调节的测量电流';
    'CurrentIntegrator', 'BldcSingle_T', 1, '电流环积分状态';
    'SpeedIntegrator', 'BldcSingle_T', 1, '速度环积分状态';
    'SpeedEstimate', 'BldcSingle_T', 1, '估算电角速度';
    'ControlSpeed', 'BldcSingle_T', 1, '控制所用电角速度';
    'RawSpeed', 'BldcSingle_T', 1, '未滤波电角速度';
    'HallLast', 'BldcUInt8_T', 1, '上一霍尔编码';
    'HallSector', 'BldcUInt8_T', 1, '霍尔扇区';
    'HallAge', 'BldcUInt32_T', 1, '距上一霍尔边沿的节拍数';
    'HallValid', 'BldcBool_T', 1, '霍尔反馈有效标志';
    'HallDirection', 'BldcInt8_T', 1, '霍尔检测方向';
    'FeedbackReady', 'BldcBool_T', 1, '反馈就绪标志';
    'OmegaOpen', 'BldcSingle_T', 1, '开环电角速度';
    'ThetaOpen', 'BldcSingle_T', 1, '开环电角度';
    'AppliedLastSector', 'BldcUInt8_T', 1, '上一实际生效扇区';
    'AppliedAge', 'BldcUInt32_T', 1, '当前实际生效扇区持续节拍数';
    'ZcAge', 'BldcUInt32_T', 1, '距上一过零的节拍数';
    'ZcPeriod', 'BldcSingle_T', 1, '估算的过零周期';
    'ZcCount', 'BldcUInt16_T', 1, '有效过零计数';
    'ZcFound', 'BldcBool_T', 1, '过零检测结果';
    'ZcArmed', 'BldcBool_T', 1, '过零检测已使能标志';
    'ZcValue', 'BldcSingle_T', 1, '过零检测电压值';
    'ZcCountdown', 'BldcInt32_T', 1, '换相倒计时';
    'ZcNextSector', 'BldcUInt8_T', 1, '下一换相扇区';
    'AcquireStage', 'BldcUInt8_T', 1, '捕获阶段';
    'AcquireTheta', 'BldcSingle_T', 1, '捕获电角度';
    'AcquireAge', 'BldcUInt32_T', 1, '捕获阶段节拍计数';
    'AcquisitionReady', 'BldcBool_T', 1, '滑行端电压捕获已通过有效性确认';
    'SensorFault', 'BldcUInt16_T', 1, '传感器故障位';
    'ActiveFaults', 'BldcUInt16_T', 1, '当前活动故障位';
    'FaultBits', 'BldcUInt16_T', 1, '锁存故障位';
    'PhaseCurrentsValid', 'BldcBool_T', 1, '仅在实际测量相电流时为 true';
    'DcCurrent', 'ValueType: BldcCurrent_V', 1, '最近一次有效母线电流，不代表三相电流重建';
    'DcCurrentValid', 'BldcBool_T', 1, '本帧电流在合格的导通窗口内采样';
    'ZcUnclampedCount', 'BldcUInt16_T', 1, '连续观测到悬浮端电压脱离电源轨的次数';
});

tBldcDebug = createBusType('固定尺寸的 BLDC 调试接口。', {
    'Enabled', 'BldcBool_T', 1, '调试使能';
    'Data', 'BldcSingle_T', 16, '16 个有序监视通道，见 bldc.monitor';
});

tBldcMonitor = createBusType('固定尺寸的 BLDC 监视接口。', {
    'Mode', 'BldcUInt8_T', 1, '当前模式';
    'FaultBits', 'BldcUInt16_T', 1, '锁存故障位';
    'Tick', 'BldcUInt32_T', 1, '快速节拍计数';
    'Current', 'BldcSingle_T', 3, '三相电流，单位 A';
    'CurrentReference', 'ValueType: BldcCurrent_V', 1, '电流参考';
    'CurrentDemand', 'ValueType: BldcCurrent_V', 1, '变化率限制前已限幅的速度环电流需求';
    'SpeedRequest', 'BldcSingle_T', 1, '已锁存速度请求';
    'SpeedRamped', 'BldcSingle_T', 1, '变化率限制后的速度请求';
    'SpeedEstimate', 'BldcSingle_T', 1, '估算电角速度';
    'ControlSpeed', 'BldcSingle_T', 1, '控制所用电角速度';
    'Sector', 'BldcUInt8_T', 1, '换相扇区';
    'Direction', 'BldcInt8_T', 1, '控制方向';
    'OutputDirection', 'BldcInt8_T', 1, '输出方向';
    'Modulation', 'BldcSingle_T', 1, '调制度';
    'GateEnable', 'BldcBool_T', 1, '全局门极使能';
    'PhaseEnable', 'BldcBool_T', 3, '各相桥臂使能';
    'FeedbackReady', 'BldcBool_T', 1, '反馈就绪标志';
    'ZcCount', 'BldcUInt16_T', 1, '有效过零计数';
    'ZcPeriod', 'BldcSingle_T', 1, '估算的过零周期';
    'ZcCountdown', 'BldcInt32_T', 1, '换相倒计时';
    'AcquisitionReady', 'BldcBool_T', 1, '滑行端电压捕获已通过有效性确认';
    'PositionMode', 'BldcUInt8_T', 1, '0 霍尔；1 端电压无感';
    'VoltageResidual', 'BldcSingle_T', 1, '端电压残差';
    'CurrentIntegrator', 'BldcSingle_T', 1, '电流环积分状态';
    'SpeedIntegrator', 'BldcSingle_T', 1, '速度环积分状态';
    'HallSector', 'BldcUInt8_T', 1, '霍尔扇区';
    'HallValid', 'BldcBool_T', 1, '霍尔反馈有效标志';
    'AppliedAge', 'BldcUInt32_T', 1, '当前实际生效扇区持续节拍数';
    'CurrentMeasured', 'ValueType: BldcCurrent_V', 1, '用于调节的测量电流';
    'CurrentSenseMode', 'BldcUInt8_T', 1, '0 相电流传感器；1 直流母线分流';
    'PhaseCurrentsValid', 'BldcBool_T', 1, 'Current 向量有效标志';
    'DcCurrent', 'ValueType: BldcCurrent_V', 1, '最近一次有效母线电流';
    'DcCurrentValid', 'BldcBool_T', 1, '本次母线电流采样有效标志';
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
