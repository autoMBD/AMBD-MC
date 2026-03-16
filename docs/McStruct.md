# McStruct 数据结构参考手册

> 源文件：`mc-models/pmsm/commom/McStruct.m`
>
> 本文档汇总了 PMSM 电机控制系统中使用的全部 Simulink Bus 和 Enum 定义，按功能模块分类整理。
>
> 自 `v1.1` 起，本文档同时作为 `tools/generate_data_type_from_md.m` 的输入源，除保留原始 `Bus/Enum` 数据外，还补充了按 skill 要求整理的 `NumericType / AliasType / ValueType / Bus` 分层定义。

---

## 类型系统架构摘要

按照 `simulink data type system design` 的要求，本文档将 PMSM 控制数据定义整理为如下四层：

| 层级 | 对象 | 作用 | 本文档中的来源 |
|------|------|------|----------------|
| 物理语义层 | `Simulink.ValueType` | 表达单位、物理意义、范围约束 | 本文“规范化数据类型清单” |
| 数值表示层 | `Simulink.NumericType` | 表达位宽、符号位、缩放和原始编码 | 本文“规范化数据类型清单” |
| 代码兼容层 | `Simulink.AliasType` | 提供稳定的代码类型名，避免模型直接依赖内建类型 | 本文“规范化数据类型清单” |
| 复合接口层 | `Simulink.Bus` / `Enum` | 描述控制接口、状态结构和复合数据对象 | 本文第 `1` 至 `10` 章 |

### 设计约束

1. 原始 `Bus/Enum` 数据保持不删改，继续作为结构定义的事实来源。
2. 所有共享基础类型统一收敛到脚本生成的类型层，不在模型里零散定义。
3. 物理量优先绑定到 `ValueType`，纯实现载体或泛型容器使用 `AliasType` 或 `NumericType`。
4. 命名约定采用：
   `*_T` 表示数值或代码类型，`*_V` 表示物理值类型，`*_Bus` 继续由现有 `t*` 结构承载。
5. `tData*` 泛型容器保留原始数据内容，但在规范中仅作为复用型 `Bus`，不替代具名物理接口。

### 生成脚本输出约定

`tools/generate_data_type_from_md.m` 解析本文后，会在目标目录下生成一个汇总脚本：

| 输出文件 | 说明 |
|----------|------|
| `mc_data_types.m` | 统一创建 `NumericType`、`AliasType`、`ValueType`、`Enum` 与 `Bus` |

默认输出路径建议为：`mc-models/pmsm/data`

## 规范化数据类型清单

下述三张表为新增的规范化类型层定义，保留原始数据内容不变，同时为脚本生成提供稳定输入。

### NumericType 清单

<!-- MC_TYPE_TABLE:NUMERIC -->
| Name | Signed | WordLength | FractionLength | Slope | Bias | Description |
|------|--------|------------|----------------|-------|------|-------------|
| McU8Raw_T | false | 8 | 0 | 1 | 0 | 8 位无符号原始编码，适用于数字量与轻量状态载体 |
| McU16Raw_T | false | 16 | 0 | 1 | 0 | 16 位无符号原始编码，适用于 ADC/PWM/调参原始量 |
| McS8Idx_T | true | 8 | 0 | 1 | 0 | 8 位有符号索引或编号量 |
| McU32Cnt_T | false | 32 | 0 | 1 | 0 | 32 位无符号计数、频率或时间基准载体 |

### AliasType 清单

<!-- MC_TYPE_TABLE:ALIAS -->
| Name | BaseType | HeaderFile | Description |
|------|----------|------------|-------------|
| McBool_T | boolean |  | 逻辑开关与使能标志 |
| McUInt8_T | uint8 |  | 通用 8 位无符号代码类型 |
| McInt8_T | int8 |  | 通用 8 位有符号代码类型 |
| McUInt16_T | uint16 |  | 通用 16 位无符号代码类型 |
| McUInt32_T | uint32 |  | 通用 32 位无符号代码类型 |
| McSingle_T | single |  | 通用 32 位浮点代码类型 |

### ValueType 清单

<!-- MC_TYPE_TABLE:VALUE -->
| Name | DataType | Unit | Min | Max | Description |
|------|----------|------|-----|-----|-------------|
| LogicBool_V | McBool_T |  | 0 | 1 | 通用逻辑量 |
| HallLevel_V | McUInt8_T |  | 0 | 1 | 霍尔数字量采样 |
| ResolverLevel_V | McUInt8_T |  | 0 | 1 | 旋变数字接口电平 |
| EncoderLevel_V | McUInt8_T |  | 0 | 1 | 编码器数字接口电平 |
| AdcCurrentRaw_V | McUInt16_T |  | 0 | 65535 | 电流 ADC 原始采样值 |
| AdcVoltageRaw_V | McUInt16_T |  | 0 | 65535 | 电压 ADC 原始采样值 |
| AdcBemfRaw_V | McUInt16_T |  | 0 | 65535 | 反电动势 ADC 原始采样值 |
| DutyCount_V | McUInt16_T |  | 0 | 65535 | PWM 占空比计数值 |
| DutyRatio_V | McSingle_T | 1 | 0 | 1 | 归一化占空比 |
| AngleRad_V | McSingle_T | rad |  |  | 角度量 |
| AngularSpeedRadPerSec_V | McSingle_T | rad/s |  |  | 角速度量 |
| SpeedRpm_V | McSingle_T | rpm | 0 |  | 机械转速 |
| Current_A_V | McSingle_T | A |  |  | 电流物理量 |
| Voltage_V | McSingle_T | V | 0 |  | 电压物理量 |
| Time_S_V | McSingle_T | s | 0 |  | 时间量 |
| Freq_Hz_V | McUInt32_T | Hz | 0 |  | 频率配置量 |
| Gain_V | McSingle_T | 1 |  |  | 无量纲增益或系数 |
| Count_V | McUInt32_T |  | 0 |  | 计数量 |
| MotorIndex_V | McInt8_T |  | -128 | 127 | 电机编号或实例索引 |
| PolePairCount_V | McUInt8_T |  | 0 | 255 | 极对数 |
| Inductance_H_V | McSingle_T | H | 0 |  | 电感量 |
| Resistance_Ohm_V | McSingle_T | Ohm | 0 |  | 电阻量 |
| Flux_Wb_V | McSingle_T | Wb | 0 |  | 磁链量 |
| Inertia_KgM2_V | McSingle_T | kg*m^2 | 0 |  | 转动惯量 |
| Torque_Nm_V | McSingle_T | N*m |  |  | 转矩量 |
| TorquePerAmp_NmPerA_V | McSingle_T | N*m/A |  |  | 转矩常数 |
| BemfConst_VsPerRad_V | McSingle_T | V*s/rad |  |  | 反电动势常数 |

### 生成与映射说明

1. 生成脚本优先从上述三张清单创建共享类型层。
2. 原文第 `1` 至 `10` 章中的 `Bus/Enum` 仍作为结构与枚举的事实来源。
3. 对于能明确识别物理意义的字段，生成脚本会优先将 `BusElement.DataType` 绑定到对应 `ValueType`。
4. 对于 `tDataDualF32`、`tDataTriU16` 这类泛型容器，生成脚本保留其通用属性，字段仍使用代码兼容层类型。

## 修改日志

| 日期 | 作者 | 版本 | 变更说明 |
|------|------|------|----------|
| 2026-03-17 | GPT-5.4 / autoMBD | v1.2 | 合并 Markdown 生成入口，统一使用 `tools/generate_data_type_from_md.m` |
| 2026-03-17 | GPT-5.4 / autoMBD | v1.1 | 按强类型分层规则补充 NumericType/AliasType/ValueType 规范，新增 Markdown 解析与生成约定 |
| 2026-03-16 | autoMBD | v1.0 | 初始版本，定义了适用于PMSM的 Bus/Enum 定义 |

---

## 目录

- [1. 传感器类（Sensor）](#1-传感器类sensor)
- [2. 执行器类（Actuator）](#2-执行器类actuator)
- [3. 算法类（Algorithm）](#3-算法类algorithm)
- [4. 数据流类（DataFlow）](#4-数据流类dataflow)
- [5. 状态机类（StateMachine）](#5-状态机类statemachine)
- [6. 故障与调试类（Fault & Debug）](#6-故障与调试类fault--debug)
- [7. 配置与参数类（Config & Parameter）](#7-配置与参数类config--parameter)
- [8. 顶层驱动结构（Drive）](#8-顶层驱动结构drive)
- [9. 通用数据容器（Generic Data）](#9-通用数据容器generic-data)
- [10. 枚举类型（Enum）](#10-枚举类型enum)

---

## 1. 传感器类（Sensor）

用于采集电机运行过程中的各种物理信号，包括位置传感器、电压和电流采样。

### tSnrHall

霍尔传感器信号，三路数字量输入，用于检测转子位置（60°分辨率）。

| 字段 | 类型 | 说明 |
|------|------|------|
| HA | uint8 | A 相霍尔信号 |
| HB | uint8 | B 相霍尔信号 |
| HC | uint8 | C 相霍尔信号 |

### tSnrResolver

旋变传感器信号，用于高精度转子位置检测。

| 字段 | 类型 | 说明 |
|------|------|------|
| A | uint8 | A 路信号 |
| B | uint8 | B 路信号 |
| C | uint8 | C 路信号 |

### tSnrEncoder

编码器传感器信号，用于增量式位置检测。

| 字段 | 类型 | 说明 |
|------|------|------|
| A | uint8 | A 路信号 |
| B | uint8 | B 路信号 |
| C | uint8 | C 路（Index）信号 |

### tSnrBemf

反电动势（Back-EMF）检测信号，用于无传感器位置估算。

| 字段 | 类型 | 说明 |
|------|------|------|
| BemfA | uint16 | A 相反电动势 ADC 采样值 |
| BemfB | uint16 | B 相反电动势 ADC 采样值 |
| BemfC | uint16 | C 相反电动势 ADC 采样值 |

### tSnrVot

三相电压采样信号。

| 字段 | 类型 | 说明 |
|------|------|------|
| Va | uint16 | A 相电压 ADC 采样值 |
| Vb | uint16 | B 相电压 ADC 采样值 |
| Vc | uint16 | C 相电压 ADC 采样值 |

### tSnrCur

三相电流采样信号。

| 字段 | 类型 | 说明 |
|------|------|------|
| Ia | uint16 | A 相电流 ADC 采样值 |
| Ib | uint16 | B 相电流 ADC 采样值 |
| Ic | uint16 | C 相电流 ADC 采样值 |

### tMcSensor

传感器聚合结构，汇集了所有传感器子模块的数据。

| 字段 | 类型 | 说明 |
|------|------|------|
| AdcI | tSnrCur | 三相电流 ADC 采样 |
| AdcV | tSnrVot | 三相电压 ADC 采样 |
| Bemf | tSnrBemf | 反电动势采样 |
| Hall | tSnrHall | 霍尔传感器信号 |
| Resolver | tSnrResolver | 旋变传感器信号 |
| Encoder | tSnrEncoder | 编码器信号 |

---

## 2. 执行器类（Actuator）

用于驱动逆变器桥臂的 PWM 输出控制。

### tActrDuty

三相六路 PWM 占空比，对应三相全桥逆变器的上下桥臂。

| 字段 | 类型 | 说明 |
|------|------|------|
| AH | uint16 | A 相上桥臂占空比 |
| AL | uint16 | A 相下桥臂占空比 |
| BH | uint16 | B 相上桥臂占空比 |
| BL | uint16 | B 相下桥臂占空比 |
| CH | uint16 | C 相上桥臂占空比 |
| CL | uint16 | C 相下桥臂占空比 |

### tMcActuator

执行器顶层结构，包含执行器状态和 PWM 占空比。

| 字段 | 类型 | 说明 |
|------|------|------|
| ActrState | uint8 | 执行器工作状态 |
| PwmDuty | tActrDuty | PWM 占空比输出 |

---

## 3. 算法类（Algorithm）

PI 调节器及算法模块参数。

### tAlgoPI

标准 PI 控制器参数结构。

| 字段 | 类型 | 说明 |
|------|------|------|
| Kp | single | 比例增益 |
| Ki | single | 积分增益 |
| Ts | single | 采样周期（秒） |
| Integral | single | 积分累积值 |

### tMcAlgorithm

电机控制算法集合，包含速度环和电流环 PI 控制器。

| 字段 | 类型 | 说明 |
|------|------|------|
| SpdPI | tAlgoPI | 速度环 PI 控制器 |
| IdPI | tAlgoPI | d 轴电流环 PI 控制器 |
| IqPI | tAlgoPI | q 轴电流环 PI 控制器 |

---

## 4. 数据流类（DataFlow）

电机控制核心数据流，涵盖从传感器采样到 PWM 输出全链路的中间变量。

### tMcDataFlow

| 字段 | 类型 | 说明 |
|------|------|------|
| AngleElc | single | 电角度（rad） |
| WElc | single | 电角速度（rad/s） |
| WReqElc | single | 目标电角速度（rad/s） |
| DcBusCurRaw | uint16 | 母线电流 ADC 原始值 |
| DcBusCurFlt | single | 母线电流滤波值（A） |
| DcBusVotRaw | uint16 | 母线电压 ADC 原始值 |
| DcBusVotFlt | single | 母线电压滤波值（V） |
| CurPhRaw | tDataTriU16 | 三相电流 ADC 原始值 |
| CurPhFlt | tDataTriF32 | 三相电流滤波值（A） |
| CurAlBeFlt | tDataDualF32 | αβ 坐标系电流（Clarke 变换后） |
| CurDqFlt | tDataDualF32 | dq 坐标系电流（Park 变换后） |
| CurDqReqFlt | tDataDualF32 | dq 轴目标电流 |
| VotDqFlt | tDataDualF32 | dq 轴输出电压 |
| VotAlBeFlt | tDataDualF32 | αβ 坐标系输出电压（反 Park 变换后） |
| VotPhFlt | tDataTriF32 | 三相输出电压（反 Clarke 变换后） |
| DutyTriFlt | tDataTriF32 | 三相占空比（浮点） |
| DutyHexaFlt | tDataHexaF32 | 六路占空比（浮点，含上下桥臂） |

---

## 5. 状态机类（StateMachine）

电机控制系统的运行状态管理。

### tMcStateMachine

| 字段 | 类型 | 说明 |
|------|------|------|
| State | eSmStates | 当前状态机状态 |
| Cmd | eSmCmd | 状态机控制指令 |
| Event | eSmEvent | 状态机触发事件 |

---

## 6. 故障与调试类（Fault & Debug）

### tMcFault

故障信息结构，按模块分类记录故障标志。

| 字段 | 类型 | 说明 |
|------|------|------|
| SnrFault | uint8 | 传感器故障标志 |
| AlgoFault | uint8 | 算法故障标志 |
| ActrFault | uint8 | 执行器故障标志 |
| HwFault | uint8 | 硬件故障标志 |

### tMcDebug

调试信息结构，用于运行时数据监控。

| 字段 | 类型 | 说明 |
|------|------|------|
| DebugEn | boolean | 调试使能开关 |
| DebugChannel | uint8 | 调试通道选择 |
| DebugData | uint8[8] | 调试数据缓冲区（8 字节） |

### tMcTuning

在线调参结构，用于运行时调整 PI 参数和启动参数。

| 字段 | 类型 | 说明 |
|------|------|------|
| SpdKp | uint16 | 速度环比例增益 |
| SpdKi | uint16 | 速度环积分增益 |
| IdKp | uint16 | d 轴电流环比例增益 |
| IdKi | uint16 | d 轴电流环积分增益 |
| IqKp | uint16 | q 轴电流环比例增益 |
| IqKi | uint16 | q 轴电流环积分增益 |
| AlignCurrent | uint16 | 对齐电流设定值 |
| AlignTime | uint16 | 对齐时间设定值 |
| OpenLoopAccel | uint16 | 开环加速度 |
| TrackingGain | uint16 | 跟踪增益 |

---

## 7. 配置与参数类（Config & Parameter）

### tMcType

电机控制类型配置，定义系统所用的电机类型、算法类型等。

| 字段 | 类型 | 说明 |
|------|------|------|
| MotorType | eMotorType | 电机类型（PMSM/BLDC/DCM） |
| AlgorithmType | uint8 | 控制算法类型 |
| SensorType | uint8 | 传感器类型 |
| ControlType | uint8 | 控制模式类型 |

### tMcCfg

电机控制系统配置参数。

| 字段 | 类型 | 说明 |
|------|------|------|
| MotorNum | int8 | 电机编号 |
| TuningEn | boolean | 在线调参使能 |
| DebugEn | boolean | 调试使能 |
| SampleRate | uint32 | 采样频率（Hz） |
| PwmFreq | uint32 | PWM 开关频率（Hz） |
| PosAlgo | ePosAlgo | 位置估算算法选择 |

### tMotorPara

电机物理参数，用于 FOC 算法计算。

| 字段 | 类型 | 说明 |
|------|------|------|
| NomVoltage | single | 额定电压（V） |
| NomCurrent | single | 额定电流（A） |
| NornSpd | single | 额定转速（RPM） |
| PolePairNum | uint8 | 极对数 |
| Ld | single | d 轴电感（H） |
| Lq | single | q 轴电感（H） |
| Rs | single | 定子电阻（Ω） |
| Bemf | single | 反电动势常数 |
| Flux | single | 永磁磁链（Wb） |
| RotorInertia | single | 转子转动惯量（kg·m²） |
| Kt | single | 转矩常数（N·m/A） |
| Ke | single | 反电动势常数（V·s/rad） |
| Fdamp | single | 阻尼系数 |

---

## 8. 顶层驱动结构（Drive）

### tMcDrive

电机控制驱动顶层结构，聚合了配置、状态机、调参、电机参数等所有子模块。

| 字段 | 类型 | 说明 |
|------|------|------|
| BasicCnt | uint32 | 基础计数器（系统 tick） |
| McCtrl | eMcCtrl | 电机控制状态（启动/退出） |
| McType | tMcType | 电机控制类型配置 |
| StateMachine | tMcStateMachine | 状态机 |
| DebugInfo | tMcDebug | 调试信息 |
| Tunning | tMcTuning | 在线调参参数 |
| McCfg | tMcCfg | 系统配置 |
| MotorPara | tMotorPara | 电机物理参数 |

---

## 9. 通用数据容器（Generic Data）

通用数据打包结构，用于在各模块间传递不同维度的数据。按数据类型分为 `uint16` 和 `single`（F32）两组。

### uint16 系列

| 结构体 | 字段数 | 字段名 | 说明 |
|--------|--------|--------|------|
| tDataDualU16 | 2 | D1, D2 | 双路 uint16 数据包 |
| tDataTriU16 | 3 | D1, D2, D3 | 三路 uint16 数据包 |
| tDataQuadU16 | 4 | D1 ~ D4 | 四路 uint16 数据包 |
| tDataPentaU16 | 5 | D1 ~ D5 | 五路 uint16 数据包 |
| tDataHexaU16 | 6 | D1 ~ D6 | 六路 uint16 数据包 |

### single（F32）系列

| 结构体 | 字段数 | 字段名 | 说明 |
|--------|--------|--------|------|
| tDataDualF32 | 2 | D1, D2 | 双路浮点数据包（如 αβ/dq 坐标对） |
| tDataTriF32 | 3 | D1, D2, D3 | 三路浮点数据包（如三相物理量） |
| tDataQuadF32 | 4 | D1 ~ D4 | 四路浮点数据包 |
| tDataPentaF32 | 5 | D1 ~ D5 | 五路浮点数据包 |
| tDataHexaF32 | 6 | D1 ~ D6 | 六路浮点数据包（如六路 PWM 占空比） |

---

## 10. 枚举类型（Enum）

### eMotorType

电机类型枚举，存储类型 `uint8`，默认值 `MC_MOTOR_NA`。

| 枚举值 | 数值 | 说明 |
|--------|------|------|
| MC_MOTOR_NA | 0 | 未定义 |
| MC_MOTOR_PMSM | 1 | 永磁同步电机 |
| MC_MOTOR_BLDC | 2 | 无刷直流电机 |
| MC_MOTOR_DCM | 3 | 有刷直流电机 |

### eSmCmd

状态机控制指令枚举，存储类型 `uint8`，默认值 `SmReset`。

| 枚举值 | 数值 | 说明 |
|--------|------|------|
| SmReset | 0 | 状态机复位 |
| FaultTrigger | 1 | 触发故障 |
| FaultClear | 2 | 清除故障 |
| AppOn | 3 | 应用开启 |
| AppOff | 4 | 应用关闭 |
| MotorRun | 5 | 电机运行 |
| MotorStop | 6 | 电机停止 |

### eSmEvent

状态机事件枚举，存储类型 `uint8`。

| 枚举值 | 数值 | 说明 |
|--------|------|------|
| EventNA | 0 | 无事件 |
| InitDone | 1 | 初始化完成 |
| FaultDetected | 2 | 检测到故障 |
| StopDone | 3 | 停机完成 |
| Shutdown | 4 | 系统关闭 |
| AlignDone | 5 | 转子对齐完成 |
| OpenIfDone | 6 | 开环 I/F 启动完成 |
| OpenVfDone | 7 | 开环 V/F 启动完成 |
| TrackingDone | 8 | 位置跟踪完成 |
| RunBackward | 9 | 反转运行 |
| TrackingBackward | 10 | 反向跟踪 |

### eSmStates

状态机状态枚举，存储类型 `uint8`。定义了电机从复位到闭环运行的完整状态流程。

| 枚举值 | 数值 | 说明 |
|--------|------|------|
| MC_STATE_RESET | 0 | 复位状态 |
| MC_STATE_INIT | 1 | 初始化状态 |
| MC_STATE_IDLE | 2 | 空闲状态 |
| MC_STATE_FAULT | 3 | 故障状态 |
| MC_STATE_READY | 4 | 就绪状态 |
| MC_STATE_READY_2_ALIGN | 5 | 就绪→对齐 过渡态 |
| MC_STATE_ALIGN | 6 | 转子对齐状态 |
| MC_STATE_ALIGN_2_OPEN_IF | 7 | 对齐→开环 I/F 过渡态 |
| MC_STATE_OPEN_IF | 8 | 开环 I/F 运行状态 |
| MC_STATE_OPEN_IF_2_TRACKING | 9 | 开环 I/F→跟踪 过渡态 |
| MC_STATE_TRACKING_2_OPEN_IF | 10 | 跟踪→开环 I/F 过渡态 |
| MC_STATE_TRACKING | 11 | 位置跟踪状态 |
| MC_STATE_TRACKING_2_RUN | 12 | 跟踪→闭环运行 过渡态 |
| MC_STATE_RUN_2_TRACKING | 13 | 闭环运行→跟踪 过渡态 |
| MC_STATE_RUN | 14 | 闭环运行状态 |
| MC_STATE_STOP | 15 | 停机状态 |

### eMcCtrl

电机控制启停枚举，存储类型 `uint8`，默认值 `McNotStart`。

| 枚举值 | 数值 | 说明 |
|--------|------|------|
| McNotStart | 0 | 未启动 |
| McStart | 1 | 启动 |
| McExit | 2 | 退出 |

### ePosAlgo

位置估算算法选择枚举，存储类型 `uint8`，默认值 `PosNA`。

| 枚举值 | 数值 | 说明 |
|--------|------|------|
| PosNA | 0 | 未选择 |
| PosEncoder | 1 | 编码器 |
| PosHall | 2 | 霍尔传感器 |
| PosResolver | 3 | 旋变传感器 |
| PosBemf | 4 | 反电动势过零检测 |
| PosHfi | 5 | 高频注入法（HFI） |
| PosFlux | 6 | 磁链观测器 |

---

## 结构体层次关系

```
tMcDrive (顶层驱动)
├── McCtrl        : eMcCtrl
├── McType        : tMcType
│   └── MotorType : eMotorType
├── StateMachine  : tMcStateMachine
│   ├── State     : eSmStates
│   ├── Cmd       : eSmCmd
│   └── Event     : eSmEvent
├── DebugInfo     : tMcDebug
├── Tunning       : tMcTuning
├── McCfg         : tMcCfg
│   └── PosAlgo   : ePosAlgo
└── MotorPara     : tMotorPara

tMcSensor (传感器聚合)
├── AdcI     : tSnrCur
├── AdcV     : tSnrVot
├── Bemf     : tSnrBemf
├── Hall     : tSnrHall
├── Resolver : tSnrResolver
└── Encoder  : tSnrEncoder

tMcActuator (执行器)
└── PwmDuty  : tActrDuty

tMcAlgorithm (算法)
├── SpdPI : tAlgoPI
├── IdPI  : tAlgoPI
└── IqPI  : tAlgoPI

tMcDataFlow (数据流)
├── CurPhRaw    : tDataTriU16
├── CurPhFlt    : tDataTriF32
├── CurAlBeFlt  : tDataDualF32
├── CurDqFlt    : tDataDualF32
├── CurDqReqFlt : tDataDualF32
├── VotDqFlt    : tDataDualF32
├── VotAlBeFlt  : tDataDualF32
├── VotPhFlt    : tDataTriF32
├── DutyTriFlt  : tDataTriF32
└── DutyHexaFlt : tDataHexaF32
```
