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
% Date:        2026-10-11
% Version:     0.1.0
% Description: Layered Simulink data type definitions generated from
%              docs/McStruct.md.
% =================================================================================

McU8Raw_T = createNumericType(false, 8, 0, 1, 0, '8 位无符号原始编码，适用于数字量与轻量状态载体');
McU16Raw_T = createNumericType(false, 16, 0, 1, 0, '16 位无符号原始编码，适用于 ADC/PWM/调参原始量');
McS8Idx_T = createNumericType(true, 8, 0, 1, 0, '8 位有符号索引或编号量');
McU32Cnt_T = createNumericType(false, 32, 0, 1, 0, '32 位无符号计数、频率或时间基准载体');

McBool_T = createAliasType('boolean', '', '逻辑开关与使能标志');
McUInt8_T = createAliasType('uint8', '', '通用 8 位无符号代码类型');
McInt8_T = createAliasType('int8', '', '通用 8 位有符号代码类型');
McUInt16_T = createAliasType('uint16', '', '通用 16 位无符号代码类型');
McUInt32_T = createAliasType('uint32', '', '通用 32 位无符号代码类型');
McSingle_T = createAliasType('single', '', '通用 32 位浮点代码类型');

HallLevel_V = createValueType('McUInt8_T', '', 0, 1, '霍尔数字量采样');
ResolverLevel_V = createValueType('McUInt8_T', '', 0, 1, '旋变数字接口电平');
EncoderLevel_V = createValueType('McUInt8_T', '', 0, 1, '编码器数字接口电平');
AdcCurrentRaw_V = createValueType('McUInt16_T', '', 0, 65535, '电流 ADC 原始采样值');
AdcVoltageRaw_V = createValueType('McUInt16_T', '', 0, 65535, '电压 ADC 原始采样值');
AdcBemfRaw_V = createValueType('McUInt16_T', '', 0, 65535, '反电动势 ADC 原始采样值');
DutyCount_V = createValueType('McUInt16_T', '', 0, 65535, 'PWM 占空比计数值');
DutyRatio_V = createValueType('McSingle_T', '1', 0, 1, '归一化占空比');
Gain_V = createValueType('McSingle_T', '1', [], [], '无量纲增益或系数');
Time_S_V = createValueType('McSingle_T', 's', 0, [], '时间量');
AngleRad_V = createValueType('McSingle_T', 'rad', [], [], '角度量');
AngularSpeedRadPerSec_V = createValueType('McSingle_T', 'rad/s', [], [], '角速度量');
LogicBool_V = createValueType('McBool_T', '', 0, 1, '通用逻辑量');
Voltage_V = createValueType('McSingle_T', 'V', 0, [], '电压物理量');
Current_A_V = createValueType('McSingle_T', 'A', [], [], '电流物理量');
SpeedRpm_V = createValueType('McSingle_T', 'rpm', 0, [], '机械转速');
Freq_Hz_V = createValueType('McUInt32_T', 'Hz', 0, [], '频率配置量');
MotorIndex_V = createValueType('McInt8_T', '', -128, 127, '电机编号或实例索引');
PolePairCount_V = createValueType('McUInt8_T', '', 0, 255, '极对数');
Inductance_H_V = createValueType('McSingle_T', 'H', 0, [], '电感量');
Resistance_Ohm_V = createValueType('McSingle_T', 'Ohm', 0, [], '电阻量');
Flux_Wb_V = createValueType('McSingle_T', 'Wb', 0, [], '磁链量');
Inertia_KgM2_V = createValueType('McSingle_T', 'kg*m^2', 0, [], '转动惯量');
Torque_Nm_V = createValueType('McSingle_T', 'N*m', [], [], '转矩量');
TorquePerAmp_NmPerA_V = createValueType('McSingle_T', 'N*m/A', [], [], '转矩常数');
BemfConst_VsPerRad_V = createValueType('McSingle_T', 'V*s/rad', [], [], '反电动势常数');
Count_V = createValueType('McUInt32_T', '', 0, [], '计数量');

eMotorType = Simulink.data.dictionary.EnumTypeDefinition;
removeEnumeral(eMotorType, 1);
appendEnumeral(eMotorType, 'MC_MOTOR_NA', 0, '未定义');
appendEnumeral(eMotorType, 'MC_MOTOR_PMSM', 1, '永磁同步电机');
appendEnumeral(eMotorType, 'MC_MOTOR_BLDC', 2, '无刷直流电机');
appendEnumeral(eMotorType, 'MC_MOTOR_DCM', 3, '有刷直流电机');
eMotorType.DefaultValue = 'MC_MOTOR_NA';
eMotorType.StorageType = 'uint8';

eSmCmd = Simulink.data.dictionary.EnumTypeDefinition;
removeEnumeral(eSmCmd, 1);
appendEnumeral(eSmCmd, 'SmReset', 0, '状态机复位');
appendEnumeral(eSmCmd, 'FaultTrigger', 1, '触发故障');
appendEnumeral(eSmCmd, 'FaultClear', 2, '清除故障');
appendEnumeral(eSmCmd, 'AppOn', 3, '应用开启');
appendEnumeral(eSmCmd, 'AppOff', 4, '应用关闭');
appendEnumeral(eSmCmd, 'MotorRun', 5, '电机运行');
appendEnumeral(eSmCmd, 'MotorStop', 6, '电机停止');
eSmCmd.DefaultValue = 'SmReset';
eSmCmd.StorageType = 'uint8';

eSmEvent = Simulink.data.dictionary.EnumTypeDefinition;
removeEnumeral(eSmEvent, 1);
appendEnumeral(eSmEvent, 'EventNA', 0, '无事件');
appendEnumeral(eSmEvent, 'InitDone', 1, '初始化完成');
appendEnumeral(eSmEvent, 'FaultDetected', 2, '检测到故障');
appendEnumeral(eSmEvent, 'StopDone', 3, '停机完成');
appendEnumeral(eSmEvent, 'Shutdown', 4, '系统关闭');
appendEnumeral(eSmEvent, 'AlignDone', 5, '转子对齐完成');
appendEnumeral(eSmEvent, 'OpenIfDone', 6, '开环 I/F 启动完成');
appendEnumeral(eSmEvent, 'OpenVfDone', 7, '开环 V/F 启动完成');
appendEnumeral(eSmEvent, 'TrackingDone', 8, '位置跟踪完成');
appendEnumeral(eSmEvent, 'RunBackward', 9, '反转运行');
appendEnumeral(eSmEvent, 'TrackingBackward', 10, '反向跟踪');
eSmEvent.DefaultValue = '';
eSmEvent.StorageType = 'uint8';

eSmStates = Simulink.data.dictionary.EnumTypeDefinition;
removeEnumeral(eSmStates, 1);
appendEnumeral(eSmStates, 'MC_STATE_RESET', 0, '复位状态');
appendEnumeral(eSmStates, 'MC_STATE_INIT', 1, '初始化状态');
appendEnumeral(eSmStates, 'MC_STATE_IDLE', 2, '空闲状态');
appendEnumeral(eSmStates, 'MC_STATE_FAULT', 3, '故障状态');
appendEnumeral(eSmStates, 'MC_STATE_READY', 4, '就绪状态');
appendEnumeral(eSmStates, 'MC_STATE_READY_2_ALIGN', 5, '就绪→对齐 过渡态');
appendEnumeral(eSmStates, 'MC_STATE_ALIGN', 6, '转子对齐状态');
appendEnumeral(eSmStates, 'MC_STATE_ALIGN_2_OPEN_IF', 7, '对齐→开环 I/F 过渡态');
appendEnumeral(eSmStates, 'MC_STATE_OPEN_IF', 8, '开环 I/F 运行状态');
appendEnumeral(eSmStates, 'MC_STATE_OPEN_IF_2_TRACKING', 9, '开环 I/F→跟踪 过渡态');
appendEnumeral(eSmStates, 'MC_STATE_TRACKING_2_OPEN_IF', 10, '跟踪→开环 I/F 过渡态');
appendEnumeral(eSmStates, 'MC_STATE_TRACKING', 11, '位置跟踪状态');
appendEnumeral(eSmStates, 'MC_STATE_TRACKING_2_RUN', 12, '跟踪→闭环运行 过渡态');
appendEnumeral(eSmStates, 'MC_STATE_RUN_2_TRACKING', 13, '闭环运行→跟踪 过渡态');
appendEnumeral(eSmStates, 'MC_STATE_RUN', 14, '闭环运行状态');
appendEnumeral(eSmStates, 'MC_STATE_STOP', 15, '停机状态');
eSmStates.DefaultValue = '';
eSmStates.StorageType = 'uint8';

eMcCtrl = Simulink.data.dictionary.EnumTypeDefinition;
removeEnumeral(eMcCtrl, 1);
appendEnumeral(eMcCtrl, 'McNotStart', 0, '未启动');
appendEnumeral(eMcCtrl, 'McStart', 1, '启动');
appendEnumeral(eMcCtrl, 'McExit', 2, '退出');
eMcCtrl.DefaultValue = 'McNotStart';
eMcCtrl.StorageType = 'uint8';

ePosAlgo = Simulink.data.dictionary.EnumTypeDefinition;
removeEnumeral(ePosAlgo, 1);
appendEnumeral(ePosAlgo, 'PosNA', 0, '未选择');
appendEnumeral(ePosAlgo, 'PosEncoder', 1, '编码器');
appendEnumeral(ePosAlgo, 'PosHall', 2, '霍尔传感器');
appendEnumeral(ePosAlgo, 'PosResolver', 3, '旋变传感器');
appendEnumeral(ePosAlgo, 'PosBemf', 4, '反电动势过零检测');
appendEnumeral(ePosAlgo, 'PosHfi', 5, '高频注入法（HFI）');
appendEnumeral(ePosAlgo, 'PosFlux', 6, '磁链观测器');
ePosAlgo.DefaultValue = 'PosNA';
ePosAlgo.StorageType = 'uint8';

tSnrHall = createBusType('霍尔传感器信号，三路数字量输入，用于检测转子位置（60°分辨率）。', {
    'HA', 'ValueType: HallLevel_V', 1, 'A 相霍尔信号';
    'HB', 'ValueType: HallLevel_V', 1, 'B 相霍尔信号';
    'HC', 'ValueType: HallLevel_V', 1, 'C 相霍尔信号';
});

tSnrResolver = createBusType('旋变传感器信号，用于高精度转子位置检测。', {
    'A', 'ValueType: ResolverLevel_V', 1, 'A 路信号';
    'B', 'ValueType: ResolverLevel_V', 1, 'B 路信号';
    'C', 'ValueType: ResolverLevel_V', 1, 'C 路信号';
});

tSnrEncoder = createBusType('编码器传感器信号，用于增量式位置检测。', {
    'A', 'ValueType: EncoderLevel_V', 1, 'A 路信号';
    'B', 'ValueType: EncoderLevel_V', 1, 'B 路信号';
    'C', 'ValueType: EncoderLevel_V', 1, 'C 路（Index）信号';
});

tSnrBemf = createBusType('反电动势（Back-EMF）检测信号，用于无传感器位置估算。', {
    'BemfA', 'ValueType: AdcBemfRaw_V', 1, 'A 相反电动势 ADC 采样值';
    'BemfB', 'ValueType: AdcBemfRaw_V', 1, 'B 相反电动势 ADC 采样值';
    'BemfC', 'ValueType: AdcBemfRaw_V', 1, 'C 相反电动势 ADC 采样值';
});

tSnrVot = createBusType('三相电压采样信号。', {
    'Va', 'ValueType: AdcVoltageRaw_V', 1, 'A 相电压 ADC 采样值';
    'Vb', 'ValueType: AdcVoltageRaw_V', 1, 'B 相电压 ADC 采样值';
    'Vc', 'ValueType: AdcVoltageRaw_V', 1, 'C 相电压 ADC 采样值';
});

tSnrCur = createBusType('三相电流采样信号。', {
    'Ia', 'ValueType: AdcCurrentRaw_V', 1, 'A 相电流 ADC 采样值';
    'Ib', 'ValueType: AdcCurrentRaw_V', 1, 'B 相电流 ADC 采样值';
    'Ic', 'ValueType: AdcCurrentRaw_V', 1, 'C 相电流 ADC 采样值';
});

tMcSensor = createBusType('传感器聚合结构，汇集了所有传感器子模块的数据。', {
    'AdcI', 'Bus: tSnrCur', 1, '三相电流 ADC 采样';
    'AdcV', 'Bus: tSnrVot', 1, '三相电压 ADC 采样';
    'Bemf', 'Bus: tSnrBemf', 1, '反电动势采样';
    'Hall', 'Bus: tSnrHall', 1, '霍尔传感器信号';
    'Resolver', 'Bus: tSnrResolver', 1, '旋变传感器信号';
    'Encoder', 'Bus: tSnrEncoder', 1, '编码器信号';
});

tActrDuty = createBusType('三相六路 PWM 占空比，对应三相全桥逆变器的上下桥臂。', {
    'AH', 'ValueType: DutyCount_V', 1, 'A 相上桥臂占空比';
    'AL', 'ValueType: DutyCount_V', 1, 'A 相下桥臂占空比';
    'BH', 'ValueType: DutyCount_V', 1, 'B 相上桥臂占空比';
    'BL', 'ValueType: DutyCount_V', 1, 'B 相下桥臂占空比';
    'CH', 'ValueType: DutyCount_V', 1, 'C 相上桥臂占空比';
    'CL', 'ValueType: DutyCount_V', 1, 'C 相下桥臂占空比';
});

tMcActuator = createBusType('执行器顶层结构，包含执行器状态和 PWM 占空比。', {
    'ActrState', 'McUInt8_T', 1, '执行器工作状态';
    'PwmDuty', 'Bus: tActrDuty', 1, 'PWM 占空比输出';
});

tAlgoPI = createBusType('标准 PI 控制器参数结构。', {
    'Kp', 'ValueType: Gain_V', 1, '比例增益';
    'Ki', 'ValueType: Gain_V', 1, '积分增益';
    'Ts', 'ValueType: Time_S_V', 1, '采样周期（秒）';
    'Integral', 'McSingle_T', 1, '积分累积值';
});

tMcAlgorithm = createBusType('电机控制算法集合，包含速度环和电流环 PI 控制器。', {
    'SpdPI', 'Bus: tAlgoPI', 1, '速度环 PI 控制器';
    'IdPI', 'Bus: tAlgoPI', 1, 'd 轴电流环 PI 控制器';
    'IqPI', 'Bus: tAlgoPI', 1, 'q 轴电流环 PI 控制器';
});

tDataDualF32 = createBusType('双路浮点数据包（如 αβ/dq 坐标对）', {
    'D1', 'McSingle_T', 1, 'tDataDualF32 member 1';
    'D2', 'McSingle_T', 1, 'tDataDualF32 member 2';
});

tDataHexaF32 = createBusType('六路浮点数据包（如六路 PWM 占空比）', {
    'D1', 'McSingle_T', 1, 'tDataHexaF32 member 1';
    'D2', 'McSingle_T', 1, 'tDataHexaF32 member 2';
    'D3', 'McSingle_T', 1, 'tDataHexaF32 member 3';
    'D4', 'McSingle_T', 1, 'tDataHexaF32 member 4';
    'D5', 'McSingle_T', 1, 'tDataHexaF32 member 5';
    'D6', 'McSingle_T', 1, 'tDataHexaF32 member 6';
});

tDataTriF32 = createBusType('三路浮点数据包（如三相物理量）', {
    'D1', 'McSingle_T', 1, 'tDataTriF32 member 1';
    'D2', 'McSingle_T', 1, 'tDataTriF32 member 2';
    'D3', 'McSingle_T', 1, 'tDataTriF32 member 3';
});

tDataTriU16 = createBusType('三路 uint16 数据包', {
    'D1', 'McUInt16_T', 1, 'tDataTriU16 member 1';
    'D2', 'McUInt16_T', 1, 'tDataTriU16 member 2';
    'D3', 'McUInt16_T', 1, 'tDataTriU16 member 3';
});

tMcDataFlow = createBusType('', {
    'AngleElc', 'ValueType: AngleRad_V', 1, '电角度（rad）';
    'WElc', 'ValueType: AngularSpeedRadPerSec_V', 1, '电角速度（rad/s）';
    'WReqElc', 'ValueType: AngularSpeedRadPerSec_V', 1, '目标电角速度（rad/s）';
    'DcBusCurRaw', 'ValueType: AdcCurrentRaw_V', 1, '母线电流 ADC 原始值';
    'DcBusCurFlt', 'ValueType: Current_A_V', 1, '母线电流滤波值（A）';
    'DcBusVotRaw', 'ValueType: AdcVoltageRaw_V', 1, '母线电压 ADC 原始值';
    'DcBusVotFlt', 'ValueType: Voltage_V', 1, '母线电压滤波值（V）';
    'CurPhRaw', 'Bus: tDataTriU16', 1, '三相电流 ADC 原始值';
    'CurPhFlt', 'Bus: tDataTriF32', 1, '三相电流滤波值（A）';
    'CurAlBeFlt', 'Bus: tDataDualF32', 1, 'αβ 坐标系电流（Clarke 变换后）';
    'CurDqFlt', 'Bus: tDataDualF32', 1, 'dq 坐标系电流（Park 变换后）';
    'CurDqReqFlt', 'Bus: tDataDualF32', 1, 'dq 轴目标电流';
    'VotDqFlt', 'Bus: tDataDualF32', 1, 'dq 轴输出电压';
    'VotAlBeFlt', 'Bus: tDataDualF32', 1, 'αβ 坐标系输出电压（反 Park 变换后）';
    'VotPhFlt', 'Bus: tDataTriF32', 1, '三相输出电压（反 Clarke 变换后）';
    'DutyTriFlt', 'Bus: tDataTriF32', 1, '三相占空比（浮点）';
    'DutyHexaFlt', 'Bus: tDataHexaF32', 1, '六路占空比（浮点，含上下桥臂）';
});

tMcStateMachine = createBusType('', {
    'State', 'Enum: eSmStates', 1, '当前状态机状态';
    'Cmd', 'Enum: eSmCmd', 1, '状态机控制指令';
    'Event', 'Enum: eSmEvent', 1, '状态机触发事件';
});

tMcFault = createBusType('故障信息结构，按模块分类记录故障标志。', {
    'SnrFault', 'McUInt8_T', 1, '传感器故障标志';
    'AlgoFault', 'McUInt8_T', 1, '算法故障标志';
    'ActrFault', 'McUInt8_T', 1, '执行器故障标志';
    'HwFault', 'McUInt8_T', 1, '硬件故障标志';
});

tMcDebug = createBusType('调试信息结构，用于运行时数据监控。', {
    'DebugEn', 'ValueType: LogicBool_V', 1, '调试使能开关';
    'DebugChannel', 'McUInt8_T', 1, '调试通道选择';
    'DebugData', 'McUInt8_T', 8, '调试数据缓冲区（8 字节）';
});

tMcTuning = createBusType('在线调参结构，用于运行时调整 PI 参数和启动参数。', {
    'SpdKp', 'McUInt16_T', 1, '速度环比例增益';
    'SpdKi', 'McUInt16_T', 1, '速度环积分增益';
    'IdKp', 'McUInt16_T', 1, 'd 轴电流环比例增益';
    'IdKi', 'McUInt16_T', 1, 'd 轴电流环积分增益';
    'IqKp', 'McUInt16_T', 1, 'q 轴电流环比例增益';
    'IqKi', 'McUInt16_T', 1, 'q 轴电流环积分增益';
    'AlignCurrent', 'McUInt16_T', 1, '对齐电流设定值';
    'AlignTime', 'McUInt16_T', 1, '对齐时间设定值';
    'OpenLoopAccel', 'McUInt16_T', 1, '开环加速度';
    'TrackingGain', 'McUInt16_T', 1, '跟踪增益';
});

tMcType = createBusType('电机控制类型配置，定义系统所用的电机类型、算法类型等。', {
    'MotorType', 'Enum: eMotorType', 1, '电机类型（PMSM/BLDC/DCM）';
    'AlgorithmType', 'McUInt8_T', 1, '控制算法类型';
    'SensorType', 'McUInt8_T', 1, '传感器类型';
    'ControlType', 'McUInt8_T', 1, '控制模式类型';
});

tMcCfg = createBusType('电机控制系统配置参数。', {
    'MotorNum', 'ValueType: MotorIndex_V', 1, '电机编号';
    'TuningEn', 'ValueType: LogicBool_V', 1, '在线调参使能';
    'DebugEn', 'ValueType: LogicBool_V', 1, '调试使能';
    'SampleRate', 'ValueType: Freq_Hz_V', 1, '采样频率（Hz）';
    'PwmFreq', 'ValueType: Freq_Hz_V', 1, 'PWM 开关频率（Hz）';
    'PosAlgo', 'Enum: ePosAlgo', 1, '位置估算算法选择';
});

tMotorPara = createBusType('电机物理参数，用于 FOC 算法计算。', {
    'NomVoltage', 'ValueType: Voltage_V', 1, '额定电压（V）';
    'NomCurrent', 'ValueType: Current_A_V', 1, '额定电流（A）';
    'NornSpd', 'ValueType: SpeedRpm_V', 1, '额定转速（RPM）';
    'PolePairNum', 'ValueType: PolePairCount_V', 1, '极对数';
    'Ld', 'ValueType: Inductance_H_V', 1, 'd 轴电感（H）';
    'Lq', 'ValueType: Inductance_H_V', 1, 'q 轴电感（H）';
    'Rs', 'ValueType: Resistance_Ohm_V', 1, '定子电阻（Ω）';
    'Bemf', 'ValueType: BemfConst_VsPerRad_V', 1, '反电动势常数';
    'Flux', 'ValueType: Flux_Wb_V', 1, '永磁磁链（Wb）';
    'RotorInertia', 'ValueType: Inertia_KgM2_V', 1, '转子转动惯量（kg·m²）';
    'Kt', 'ValueType: TorquePerAmp_NmPerA_V', 1, '转矩常数（N·m/A）';
    'Ke', 'ValueType: BemfConst_VsPerRad_V', 1, '反电动势常数（V·s/rad）';
    'Fdamp', 'McSingle_T', 1, '阻尼系数';
});

tMcDrive = createBusType('电机控制驱动顶层结构，聚合了配置、状态机、调参、电机参数等所有子模块。', {
    'BasicCnt', 'ValueType: Count_V', 1, '基础计数器（系统 tick）';
    'McCtrl', 'Enum: eMcCtrl', 1, '电机控制状态（启动/退出）';
    'McType', 'Bus: tMcType', 1, '电机控制类型配置';
    'StateMachine', 'Bus: tMcStateMachine', 1, '状态机';
    'DebugInfo', 'Bus: tMcDebug', 1, '调试信息';
    'Tunning', 'Bus: tMcTuning', 1, '在线调参参数';
    'McCfg', 'Bus: tMcCfg', 1, '系统配置';
    'MotorPara', 'Bus: tMotorPara', 1, '电机物理参数';
});

tMcControlParams = createBusType('', {
    'Ts', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'SpeedDivider', 'McUInt16_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'AdcOffset', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'AdcCountsPerAmp', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'CalibrationSamples', 'McUInt16_T', 1, '启动零偏校准所需稳定采样数，默认64；仅整机层使用';
    'CalibrationMaxOffset', 'McSingle_T', 1, '零偏与标称ADC零点允许的最大偏差，默认500 count';
    'CalibrationMaxSpread', 'McSingle_T', 1, '同一次校准各通道最大极差，默认20 count';
    'CalibrationTimeout', 'McSingle_T', 1, '校准超时，按有效快速采样节拍累计，默认0.25 s';
    'PwmPeriod', 'McUInt16_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'Rs', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'Ld', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'Lq', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'Flux', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'PolePairs', 'McUInt8_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'Inertia', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'Friction', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'NominalVdc', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'VdcMin', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'VdcMax', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'CurrentLimit', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'TripCurrent', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'SpeedLimit', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'VoltageMargin', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'KpD', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'KpQ', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'KiD', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'KiQ', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'KpSpeed', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'KiSpeed', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'SpeedSlew', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'CurrentSlew', 'McSingle_T', 1, '开环及回退电流参考变化率，A/s';
    'AlignTime', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'AlignCurrent', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'OpenLoopCurrent', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'OpenLoopAccel', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'OpenLoopSpeed', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'TrackingTime', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'StartTimeout', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'ObserverBandwidth', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'ObserverSpeedBandwidth', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'ObserverMinSpeed', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'ObserverLockTime', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'StopDecel', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'StopSpeed', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'StopTimeout', 'McSingle_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'PositionMode', 'McUInt8_T', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
    'TuningEnable', 'ValueType: LogicBool_V', 1, '控制标定；单位与默认值见 mc.defaults 和框架架构规格';
});

tMcObserver = createBusType('', {
    'Flux', 'McSingle_T', 2, '定子磁链积分状态，alpha/beta，Wb';
    'Theta', 'ValueType: AngleRad_V', 1, '估计电角度，rad';
    'Omega', 'ValueType: AngularSpeedRadPerSec_V', 1, '估计电角速度，rad/s';
    'Magnitude', 'ValueType: Flux_Wb_V', 1, '估计有效转子磁链幅值，Wb';
});

tMcCoreRuntime = createBusType('', {
    'Tick', 'McUInt32_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'Mode', 'McUInt8_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'PreviousMode', 'McUInt8_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'ModeTicks', 'McUInt32_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'FaultBits', 'McUInt16_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'ActiveFaults', 'McUInt16_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'FastTick', 'ValueType: LogicBool_V', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'SlowTick', 'ValueType: LogicBool_V', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'Command', 'McUInt8_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'Direction', 'McSingle_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'SpeedRequest', 'McSingle_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'SpeedRamp', 'McSingle_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'ThetaOpen', 'McSingle_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'OmegaOpen', 'McSingle_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'ThetaControl', 'McSingle_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'OmegaControl', 'McSingle_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'ReferenceDq', 'McSingle_T', 2, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'CurrentIntegral', 'McSingle_T', 2, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'SpeedIntegral', 'McSingle_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'Current', 'McSingle_T', 3, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'CurrentDq', 'McSingle_T', 2, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'Voltage', 'McSingle_T', 2, '本拍调制命令alpha/beta电压（非实际反馈），单位V；生命周期见 pmsm-framework-architecture.md';
    'Duty', 'McSingle_T', 3, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'GateEnable', 'ValueType: LogicBool_V', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'StopOpenLoop', 'ValueType: LogicBool_V', 1, '无可信位置时从最后有效控制坐标系执行受控停机';
    'ObserverReady', 'ValueType: LogicBool_V', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'ObserverGoodTicks', 'McUInt32_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'Observer', 'Bus: tMcObserver', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'PositionPrev', 'McSingle_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'PositionSpeed', 'McSingle_T', 1, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'Gains', 'McSingle_T', 6, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
    'Startup', 'McSingle_T', 4, '显式离散控制状态；生命周期和单位见 pmsm-framework-architecture.md';
});

tMcRuntime = createBusType('整机状态与核心算法状态分开存储。外层不能修改核心的算法阶段；通过命令请求、核心返回状态与故障握手。', {
    'Mode', 'McUInt8_T', 1, '整机状态：0复位、1初始化/校准、2空闲、3故障、4就绪、5核心活动';
    'Command', 'McUInt8_T', 1, '已接受的用户命令：0复位、1运行、2受控停止';
    'PreviousCommandEvent', 'ValueType: LogicBool_V', 1, '上拍命令帧有效电平；识别新的安全复位请求';
    'SpeedRequest', 'ValueType: AngularSpeedRadPerSec_V', 1, '已接受且限幅的目标电角速度';
    'FaultBits', 'McUInt16_T', 1, '整机锁存故障，含核心返回故障；1024为校准失败';
    'ActiveFaults', 'McUInt16_T', 1, '本拍原始采样与外部输入故障';
    'Calibrated', 'ValueType: LogicBool_V', 1, '零偏校准有效，运行资格之一';
    'CalibrationCount', 'McUInt16_T', 1, '已累积的稳定采样数';
    'CalibrationTicks', 'McUInt32_T', 1, '校准期间有效快速采样节拍数';
    'CalibrationSum', 'McSingle_T', 3, '三相ADC校准累积值，count';
    'CalibrationMin', 'McSingle_T', 3, '三相ADC校准最小值，count';
    'CalibrationMax', 'McSingle_T', 3, '三相ADC校准最大值，count';
    'AdcOffsets', 'McSingle_T', 3, '已应用的各通道零偏，count';
    'Core', 'Bus: tMcCoreRuntime', 1, '唯一的FOC核心状态，由共享FocCore更新';
});

tMcCoreInput = createBusType('', {
    'Current', 'McSingle_T', 3, '已处理的三相电流，A，无ADC编码';
    'Control', 'McUInt8_T', 1, '0复位/撤使能、1运行、2受控停止';
    'Fault', 'ValueType: LogicBool_V', 1, '外部故障电平，核心锁存';
    'Disable', 'ValueType: LogicBool_V', 1, '立即禁止输出；不依赖快速节拍，不等同受控停止';
    'CommandEvent', 'ValueType: LogicBool_V', 1, '命令帧有效';
    'DrivingEvent', 'ValueType: LogicBool_V', 1, '电流采样节拍有效';
    'TimerEvent', 'ValueType: LogicBool_V', 1, '保留的诊断事件，不产生额外积分';
    'SpeedReq', 'ValueType: AngularSpeedRadPerSec_V', 1, '目标电角速度，rad/s';
    'Vdc', 'ValueType: Voltage_V', 1, '实测直流母线电压，V';
    'Position', 'ValueType: AngleRad_V', 1, '有感模式电角度，rad；无感模式不使用';
    'AppliedVoltage', 'McSingle_T', 2, '与当前电流对应的实际施加alpha/beta电压，V';
    'Tuning', 'Bus: tMcTuning', 1, '待锁存调参帧';
});

tMcInput = createBusType('', {
    'CurrentRaw', 'McUInt16_T', 3, 'offset-binary 三相电流 ADC';
    'Control', 'McUInt8_T', 1, '0复位/撤使能、1运行、2受控停机';
    'Fault', 'ValueType: LogicBool_V', 1, '外部硬件故障电平';
    'CommandEvent', 'ValueType: LogicBool_V', 1, '命令帧有效';
    'DrivingEvent', 'ValueType: LogicBool_V', 1, '电流采样节拍有效';
    'TimerEvent', 'ValueType: LogicBool_V', 1, '慢周期诊断指示';
    'SpeedReq', 'ValueType: AngularSpeedRadPerSec_V', 1, '目标电角速度，rad/s';
    'Vdc', 'ValueType: Voltage_V', 1, '实测直流母线电压，V';
    'Position', 'ValueType: AngleRad_V', 1, '可选位置传感器电角度，rad；无感模式不使用';
    'AppliedVoltage', 'McSingle_T', 2, '刚结束采样区间实际施加的有符号α/β平均电压，单位V；由上一拍PWM计数、门极状态和该区间母线电压重建，不使用转子真值';
    'Tuning', 'Bus: tMcTuning', 1, '待锁存调参帧';
});

tMcMonitor = createBusType('', {
    'Mode', 'McUInt8_T', 1, '兼容eSmStates的诊断映射，独立核心仅使用算法相关状态码';
    'FaultBits', 'McUInt16_T', 1, '锁存故障位图';
    'Tick', 'McUInt32_T', 1, '电流环累计采样计数';
    'SpeedRequest', 'ValueType: AngularSpeedRadPerSec_V', 1, '限幅后的目标电角速度';
    'Omega', 'ValueType: AngularSpeedRadPerSec_V', 1, '控制使用的电角速度';
    'Theta', 'ValueType: AngleRad_V', 1, '控制使用的电角度';
    'Current', 'McSingle_T', 3, '三相电流，A';
    'CurrentDq', 'McSingle_T', 2, 'dq电流，A';
    'ReferenceDq', 'McSingle_T', 2, 'dq目标电流，A';
    'Voltage', 'McSingle_T', 2, '本拍调制命令alpha/beta电压（非实际反馈），单位V';
    'Duty', 'McSingle_T', 3, '归一化三相占空比';
    'GateEnable', 'ValueType: LogicBool_V', 1, '独立功率级使能';
    'ObserverReady', 'ValueType: LogicBool_V', 1, '观测器置信度通过';
    'FluxMagnitude', 'ValueType: Flux_Wb_V', 1, '观测磁链幅值';
    'PositionMode', 'McUInt8_T', 1, '0无感、1位置传感器';
    'CoreMode', 'McUInt8_T', 1, '核心算法状态，0/2禁用、3故障、6–15算法阶段';
    'ApplicationMode', 'McUInt8_T', 1, '整机状态0–5；独立核心为255（不适用）';
    'CalibrationDone', 'ValueType: LogicBool_V', 1, '整机校准完成；独立核心为false（不适用）';
    'CalibrationCount', 'McUInt16_T', 1, '整机稳定校准采样数；独立核心为0';
    'StopComplete', 'ValueType: LogicBool_V', 1, '核心已停止且门极关闭';
});

tDataDualU16 = createBusType('双路 uint16 数据包', {
    'D1', 'McUInt16_T', 1, 'tDataDualU16 member 1';
    'D2', 'McUInt16_T', 1, 'tDataDualU16 member 2';
});

tDataQuadU16 = createBusType('四路 uint16 数据包', {
    'D1', 'McUInt16_T', 1, 'tDataQuadU16 member 1';
    'D2', 'McUInt16_T', 1, 'tDataQuadU16 member 2';
    'D3', 'McUInt16_T', 1, 'tDataQuadU16 member 3';
    'D4', 'McUInt16_T', 1, 'tDataQuadU16 member 4';
});

tDataPentaU16 = createBusType('五路 uint16 数据包', {
    'D1', 'McUInt16_T', 1, 'tDataPentaU16 member 1';
    'D2', 'McUInt16_T', 1, 'tDataPentaU16 member 2';
    'D3', 'McUInt16_T', 1, 'tDataPentaU16 member 3';
    'D4', 'McUInt16_T', 1, 'tDataPentaU16 member 4';
    'D5', 'McUInt16_T', 1, 'tDataPentaU16 member 5';
});

tDataHexaU16 = createBusType('六路 uint16 数据包', {
    'D1', 'McUInt16_T', 1, 'tDataHexaU16 member 1';
    'D2', 'McUInt16_T', 1, 'tDataHexaU16 member 2';
    'D3', 'McUInt16_T', 1, 'tDataHexaU16 member 3';
    'D4', 'McUInt16_T', 1, 'tDataHexaU16 member 4';
    'D5', 'McUInt16_T', 1, 'tDataHexaU16 member 5';
    'D6', 'McUInt16_T', 1, 'tDataHexaU16 member 6';
});

tDataQuadF32 = createBusType('四路浮点数据包', {
    'D1', 'McSingle_T', 1, 'tDataQuadF32 member 1';
    'D2', 'McSingle_T', 1, 'tDataQuadF32 member 2';
    'D3', 'McSingle_T', 1, 'tDataQuadF32 member 3';
    'D4', 'McSingle_T', 1, 'tDataQuadF32 member 4';
});

tDataPentaF32 = createBusType('五路浮点数据包', {
    'D1', 'McSingle_T', 1, 'tDataPentaF32 member 1';
    'D2', 'McSingle_T', 1, 'tDataPentaF32 member 2';
    'D3', 'McSingle_T', 1, 'tDataPentaF32 member 3';
    'D4', 'McSingle_T', 1, 'tDataPentaF32 member 4';
    'D5', 'McSingle_T', 1, 'tDataPentaF32 member 5';
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
