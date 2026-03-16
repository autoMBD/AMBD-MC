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
% Date:        2026-03-17
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

LogicBool_V = createValueType('McBool_T', '', 0, 1, '通用逻辑量');
HallLevel_V = createValueType('McUInt8_T', '', 0, 1, '霍尔数字量采样');
ResolverLevel_V = createValueType('McUInt8_T', '', 0, 1, '旋变数字接口电平');
EncoderLevel_V = createValueType('McUInt8_T', '', 0, 1, '编码器数字接口电平');
AdcCurrentRaw_V = createValueType('McUInt16_T', '', 0, 65535, '电流 ADC 原始采样值');
AdcVoltageRaw_V = createValueType('McUInt16_T', '', 0, 65535, '电压 ADC 原始采样值');
AdcBemfRaw_V = createValueType('McUInt16_T', '', 0, 65535, '反电动势 ADC 原始采样值');
DutyCount_V = createValueType('McUInt16_T', '', 0, 65535, 'PWM 占空比计数值');
DutyRatio_V = createValueType('McSingle_T', '1', 0, 1, '归一化占空比');
AngleRad_V = createValueType('McSingle_T', 'rad', [], [], '角度量');
AngularSpeedRadPerSec_V = createValueType('McSingle_T', 'rad/s', [], [], '角速度量');
SpeedRpm_V = createValueType('McSingle_T', 'rpm', 0, [], '机械转速');
Current_A_V = createValueType('McSingle_T', 'A', [], [], '电流物理量');
Voltage_V = createValueType('McSingle_T', 'V', 0, [], '电压物理量');
Time_S_V = createValueType('McSingle_T', 's', 0, [], '时间量');
Freq_Hz_V = createValueType('McUInt32_T', 'Hz', 0, [], '频率配置量');
Gain_V = createValueType('McSingle_T', '1', [], [], '无量纲增益或系数');
Count_V = createValueType('McUInt32_T', '', 0, [], '计数量');
MotorIndex_V = createValueType('McInt8_T', '', -128, 127, '电机编号或实例索引');
PolePairCount_V = createValueType('McUInt8_T', '', 0, 255, '极对数');
Inductance_H_V = createValueType('McSingle_T', 'H', 0, [], '电感量');
Resistance_Ohm_V = createValueType('McSingle_T', 'Ohm', 0, [], '电阻量');
Flux_Wb_V = createValueType('McSingle_T', 'Wb', 0, [], '磁链量');
Inertia_KgM2_V = createValueType('McSingle_T', 'kg*m^2', 0, [], '转动惯量');
Torque_Nm_V = createValueType('McSingle_T', 'N*m', [], [], '转矩量');
TorquePerAmp_NmPerA_V = createValueType('McSingle_T', 'N*m/A', [], [], '转矩常数');
BemfConst_VsPerRad_V = createValueType('McSingle_T', 'V*s/rad', [], [], '反电动势常数');

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
    'HA', 'McUInt8_T', 1, 'A 相霍尔信号';
    'HB', 'McUInt8_T', 1, 'B 相霍尔信号';
    'HC', 'McUInt8_T', 1, 'C 相霍尔信号';
});

tSnrResolver = createBusType('旋变传感器信号，用于高精度转子位置检测。', {
    'A', 'McUInt8_T', 1, 'A 路信号';
    'B', 'McUInt8_T', 1, 'B 路信号';
    'C', 'McUInt8_T', 1, 'C 路信号';
});

tSnrEncoder = createBusType('编码器传感器信号，用于增量式位置检测。', {
    'A', 'McUInt8_T', 1, 'A 路信号';
    'B', 'McUInt8_T', 1, 'B 路信号';
    'C', 'McUInt8_T', 1, 'C 路（Index）信号';
});

tSnrBemf = createBusType('反电动势（Back-EMF）检测信号，用于无传感器位置估算。', {
    'BemfA', 'McUInt16_T', 1, 'A 相反电动势 ADC 采样值';
    'BemfB', 'McUInt16_T', 1, 'B 相反电动势 ADC 采样值';
    'BemfC', 'McUInt16_T', 1, 'C 相反电动势 ADC 采样值';
});

tSnrVot = createBusType('三相电压采样信号。', {
    'Va', 'McUInt16_T', 1, 'A 相电压 ADC 采样值';
    'Vb', 'McUInt16_T', 1, 'B 相电压 ADC 采样值';
    'Vc', 'McUInt16_T', 1, 'C 相电压 ADC 采样值';
});

tSnrCur = createBusType('三相电流采样信号。', {
    'Ia', 'McUInt16_T', 1, 'A 相电流 ADC 采样值';
    'Ib', 'McUInt16_T', 1, 'B 相电流 ADC 采样值';
    'Ic', 'McUInt16_T', 1, 'C 相电流 ADC 采样值';
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
    'AH', 'McUInt16_T', 1, 'A 相上桥臂占空比';
    'AL', 'McUInt16_T', 1, 'A 相下桥臂占空比';
    'BH', 'McUInt16_T', 1, 'B 相上桥臂占空比';
    'BL', 'McUInt16_T', 1, 'B 相下桥臂占空比';
    'CH', 'McUInt16_T', 1, 'C 相上桥臂占空比';
    'CL', 'McUInt16_T', 1, 'C 相下桥臂占空比';
});

tMcActuator = createBusType('执行器顶层结构，包含执行器状态和 PWM 占空比。', {
    'ActrState', 'McUInt8_T', 1, '执行器工作状态';
    'PwmDuty', 'Bus: tActrDuty', 1, 'PWM 占空比输出';
});

tAlgoPI = createBusType('标准 PI 控制器参数结构。', {
    'Kp', 'McSingle_T', 1, '比例增益';
    'Ki', 'McSingle_T', 1, '积分增益';
    'Ts', 'Time_S_V', 1, '采样周期（秒）';
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
    'AngleElc', 'AngleRad_V', 1, '电角度（rad）';
    'WElc', 'McSingle_T', 1, '电角速度（rad/s）';
    'WReqElc', 'McSingle_T', 1, '目标电角速度（rad/s）';
    'DcBusCurRaw', 'AdcCurrentRaw_V', 1, '母线电流 ADC 原始值';
    'DcBusCurFlt', 'Current_A_V', 1, '母线电流滤波值（A）';
    'DcBusVotRaw', 'AdcVoltageRaw_V', 1, '母线电压 ADC 原始值';
    'DcBusVotFlt', 'Voltage_V', 1, '母线电压滤波值（V）';
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
    'DebugEn', 'LogicBool_V', 1, '调试使能开关';
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
    'MotorNum', 'MotorIndex_V', 1, '电机编号';
    'TuningEn', 'McBool_T', 1, '在线调参使能';
    'DebugEn', 'McBool_T', 1, '调试使能';
    'SampleRate', 'McUInt32_T', 1, '采样频率（Hz）';
    'PwmFreq', 'McUInt32_T', 1, 'PWM 开关频率（Hz）';
    'PosAlgo', 'Enum: ePosAlgo', 1, '位置估算算法选择';
});

tMotorPara = createBusType('电机物理参数，用于 FOC 算法计算。', {
    'NomVoltage', 'Voltage_V', 1, '额定电压（V）';
    'NomCurrent', 'Current_A_V', 1, '额定电流（A）';
    'NornSpd', 'SpeedRpm_V', 1, '额定转速（RPM）';
    'PolePairNum', 'PolePairCount_V', 1, '极对数';
    'Ld', 'McSingle_T', 1, 'd 轴电感（H）';
    'Lq', 'McSingle_T', 1, 'q 轴电感（H）';
    'Rs', 'Resistance_Ohm_V', 1, '定子电阻（Ω）';
    'Bemf', 'BemfConst_VsPerRad_V', 1, '反电动势常数';
    'Flux', 'Flux_Wb_V', 1, '永磁磁链（Wb）';
    'RotorInertia', 'Inertia_KgM2_V', 1, '转子转动惯量（kg·m²）';
    'Kt', 'TorquePerAmp_NmPerA_V', 1, '转矩常数（N·m/A）';
    'Ke', 'BemfConst_VsPerRad_V', 1, '反电动势常数（V·s/rad）';
    'Fdamp', 'McSingle_T', 1, '阻尼系数';
});

tMcDrive = createBusType('电机控制驱动顶层结构，聚合了配置、状态机、调参、电机参数等所有子模块。', {
    'BasicCnt', 'Count_V', 1, '基础计数器（系统 tick）';
    'McCtrl', 'Enum: eMcCtrl', 1, '电机控制状态（启动/退出）';
    'McType', 'Bus: tMcType', 1, '电机控制类型配置';
    'StateMachine', 'Bus: tMcStateMachine', 1, '状态机';
    'DebugInfo', 'Bus: tMcDebug', 1, '调试信息';
    'Tunning', 'Bus: tMcTuning', 1, '在线调参参数';
    'McCfg', 'Bus: tMcCfg', 1, '系统配置';
    'MotorPara', 'Bus: tMotorPara', 1, '电机物理参数';
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
