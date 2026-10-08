<a id="bldc-data-structure-reference"></a>

# BLDC 数据结构参考手册

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 autoMBD.

本文是 BLDC 类型定义的权威来源。使用 `tools/generate_data_type_from_md.m` 生成类型，由 `bldc_initialize` 在函数作用域内收集结果。初始化器将生成器输出重命名为 `bldc_data_types.m`；BLDC 不导入 PMSM 类型或其字典。

所有物理量使用 SI 单位和单精度。向量字段为固定尺寸列向量，模式、事件、计数器及 PWM 字段采用整数或逻辑类型存储。Runtime.Parameters 包含完整参数总线。普通启动校验类型一致性并保留标定值；显式 `SyncDictionary=true` 仅重置 BLDC 自有类型和参数。

<a id="primitive-and-physical-types"></a>

## 基础与物理量类型

<!-- MC_TYPE_TABLE:NUMERIC -->
| Name | Signed | WordLength | FractionLength | Slope | Bias | Description |
|---|---|---|---|---|---|---|
| BldcRaw16_T | false | 16 | 0 | 1 | 0 | 无符号 16 位原始表示 |

<!-- MC_TYPE_TABLE:ALIAS -->
| Name | BaseType | HeaderFile | Description |
|---|---|---|---|
| BldcSingle_T | single | | BLDC 单精度存储 |
| BldcUInt8_T | uint8 | | BLDC 无符号 8 位存储 |
| BldcInt8_T | int8 | | BLDC 有符号 8 位存储 |
| BldcUInt16_T | uint16 | | BLDC 无符号 16 位存储 |
| BldcUInt32_T | uint32 | | BLDC 无符号 32 位存储 |
| BldcInt32_T | int32 | | BLDC 有符号 32 位存储 |
| BldcBool_T | boolean | | BLDC 逻辑存储 |

<!-- MC_TYPE_TABLE:VALUE -->
| Name | DataType | Unit | Min | Max | Description |
|---|---|---|---|---|---|
| BldcTime_V | BldcSingle_T | s | 0 | | 以秒为单位的时间 |
| BldcVoltage_V | BldcSingle_T | V | | | 测量电压 |
| BldcCurrent_V | BldcSingle_T | A | | | 相电流 |

<a id="interface-buses"></a>

## 接口总线

### tBldcParams

固定尺寸的 BLDC 参数接口。

| 字段 | 类型 | 说明 |
|---|---|---|
| Ts | BldcTime_V | 快速采样周期 |
| SpeedDivider | BldcUInt16_T | 速度环分频系数 |
| AdcOffset | BldcSingle_T | ADC 零点偏移 |
| AdcCountsPerAmp | BldcSingle_T | 每安培对应的 ADC 计数 |
| PwmPeriod | BldcUInt16_T | PWM 周期计数 |
| Rs | BldcSingle_T | 相电阻 |
| Ls | BldcSingle_T | 相电感 |
| Ke | BldcSingle_T | 反电动势系数 |
| PolePairs | BldcUInt8_T | 极对数 |
| Inertia | BldcSingle_T | 转动惯量 |
| Friction | BldcSingle_T | 黏性摩擦系数 |
| PlantSubsteps | BldcUInt16_T | 被控对象积分子步数 |
| NominalVdc | BldcVoltage_V | 标称直流母线电压 |
| VdcMin | BldcVoltage_V | 母线欠压阈值 |
| VdcMax | BldcVoltage_V | 母线过压阈值 |
| CurrentLimit | BldcSingle_T | 电流参考限值 |
| TripCurrent | BldcSingle_T | 过流跳闸阈值 |
| SpeedLimit | BldcSingle_T | 速度请求限值 |
| MaxModulation | BldcSingle_T | 最大调制度 |
| KpCurrent | BldcSingle_T | 电流环比例增益 |
| KiCurrent | BldcSingle_T | 电流环积分增益 |
| KpSpeed | BldcSingle_T | 速度环比例增益 |
| KiSpeed | BldcSingle_T | 速度环积分增益 |
| SpeedSlew | BldcSingle_T | 速度请求变化率限值 |
| CurrentSlew | BldcSingle_T | 电流参考变化率限值 |
| AlignTime | BldcSingle_T | 对齐持续时间 |
| AlignCurrent | BldcSingle_T | 对齐电流 |
| OpenCurrent | BldcSingle_T | 开环启动电流 |
| OpenAccel | BldcSingle_T | 开环电角加速度 |
| OpenSpeed | BldcSingle_T | 开环目标电角速度 |
| TrackingTime | BldcSingle_T | 跟踪确认时间 |
| TrackingTimeout | BldcSingle_T | 跟踪有效性确认的最大持续时间 |
| StartTimeout | BldcSingle_T | 启动超时时间 |
| StopSpeed | BldcSingle_T | 停止速度阈值 |
| StopTimeout | BldcSingle_T | 停止超时时间 |
| StopCoastTime | BldcSingle_T | 停止滑行时间 |
| HallTimeout | BldcSingle_T | 霍尔运行边沿超时时间 |
| HallStartTimeout | BldcSingle_T | 霍尔启动超时时间 |
| HallStallCurrent | BldcSingle_T | 霍尔堵转检测电流阈值 |
| SpeedFilterAlpha | BldcSingle_T | 速度滤波系数 |
| HallGainSpeed | BldcSingle_T | 采用完整霍尔速度环增益时的请求电角速度，单位 rad/s |
| HallMinGainScale | BldcSingle_T | 霍尔比例增益的最小缩放比例；积分增益使用其平方 |
| ZcBlankTicks | BldcUInt16_T | 过零检测消隐节拍数 |
| ZcHysteresis | BldcSingle_T | 过零检测滞环电压 |
| FloatCurrentLimit | BldcSingle_T | 悬浮相电流限值 |
| ZcMinTicks | BldcUInt32_T | 有效过零间隔的最小节拍数 |
| ZcMaxTicks | BldcUInt32_T | 有效过零间隔的最大节拍数 |
| ZcRequired | BldcUInt16_T | 闭环就绪所需有效过零次数 |
| ZcTimeoutFactor | BldcSingle_T | 过零超时系数 |
| ZcMinSpeed | BldcSingle_T | 过零反馈的最低有效电角速度 |
| AcquireSpacing | BldcUInt16_T | 捕获快照间隔节拍数 |
| AcquireMinVoltage | BldcSingle_T | 捕获所需最小电压跨度 |
| AcquireTimeout | BldcSingle_T | 捕获超时时间 |
| LowSpeedThreshold | BldcSingle_T | 低速回退阈值 |
| PositionMode | BldcUInt8_T | 0 霍尔；1 端电压无感 |
| CurrentSenseMode | BldcUInt8_T | 0 三相电流传感器；1 有效采样窗口内的直流母线分流 |
| MinModulation | BldcSingle_T | 直流母线采样模式下通电占空比下限 |
| DemagBlankFraction | BldcSingle_T | 换相后排除的区间占换相周期的比例 |
| DemagRailMargin | BldcSingle_T | 悬浮端脱离上下钳位电源轨所需的电压裕量 |
| DemagReleaseTicks | BldcUInt16_T | 使能过零检测前所需连续未钳位样本数 |
| ActuationDelayTicks | BldcUInt16_T | 直流母线采样换相所补偿的输出生效延迟 |

### tBldcInput

固定尺寸的 BLDC 输入接口。

| 字段 | 类型 | 说明 |
|---|---|---|
| CurrentRaw | BldcUInt16_T[3] | 相电流 ADC 编码；直流母线模式仅使用第 1 个元素 |
| Hall | BldcUInt8_T | 霍尔编码 |
| TerminalVoltage | BldcSingle_T[3] | 三相端电压；直流母线模式仅校验实际悬浮相 |
| Control | BldcUInt8_T | 控制命令 |
| Fault | BldcBool_T | 外部故障输入 |
| CommandEvent | BldcBool_T | 命令事件 |
| DrivingEvent | BldcBool_T | 驱动节拍事件 |
| TimerEvent | BldcBool_T | 定时事件 |
| SpeedReq | BldcSingle_T | 请求电角速度 |
| Vdc | BldcVoltage_V | 直流母线电压 |
| AppliedSector | BldcUInt8_T | 采样区间实际生效的扇区 |
| AppliedDirection | BldcInt8_T | 采样区间实际生效的方向 |
| VoltageValid | BldcBool_T | 端电压采样有效标志 |

### tBldcRuntime

固定尺寸的 BLDC 运行时接口。

| 字段 | 类型 | 说明 |
|---|---|---|
| Parameters | tBldcParams | 完整且独立的控制器标定 |
| Mode | BldcUInt8_T | 当前模式 |
| PreviousMode | BldcUInt8_T | 上一模式 |
| ModeTicks | BldcUInt32_T | 当前模式持续节拍数 |
| Tick | BldcUInt32_T | 快速节拍计数 |
| SlowCounter | BldcUInt16_T | 慢速分频计数器 |
| FastTick | BldcBool_T | 快速更新标志 |
| SpeedTick | BldcBool_T | 速度环更新标志 |
| Command | BldcUInt8_T | 已锁存控制命令 |
| SpeedRequest | BldcSingle_T | 已锁存速度请求 |
| SpeedRamped | BldcSingle_T | 变化率限制后的速度请求 |
| CoastTicks | BldcUInt32_T | 滑行节拍计数 |
| Direction | BldcInt8_T | 控制方向 |
| OutputDirection | BldcInt8_T | 输出方向 |
| Sector | BldcUInt8_T | 换相扇区 |
| GateEnable | BldcBool_T | 全局门极使能 |
| PhaseEnable | BldcBool_T[3] | 各相桥臂使能 |
| DutyCounts | BldcUInt16_T[3] | 三相占空比计数 |
| Modulation | BldcSingle_T | 调制度 |
| Current | BldcSingle_T[3] | 三相电流，单位 A |
| CurrentRef | BldcCurrent_V | 电流参考 |
| CurrentDemand | BldcCurrent_V | 变化率限制前已限幅的速度环电流需求 |
| CurrentMeasured | BldcCurrent_V | 用于调节的测量电流 |
| CurrentIntegrator | BldcSingle_T | 电流环积分状态 |
| SpeedIntegrator | BldcSingle_T | 速度环积分状态 |
| SpeedEstimate | BldcSingle_T | 估算电角速度 |
| ControlSpeed | BldcSingle_T | 控制所用电角速度 |
| RawSpeed | BldcSingle_T | 未滤波电角速度 |
| HallLast | BldcUInt8_T | 上一霍尔编码 |
| HallSector | BldcUInt8_T | 霍尔扇区 |
| HallAge | BldcUInt32_T | 距上一霍尔边沿的节拍数 |
| HallValid | BldcBool_T | 霍尔反馈有效标志 |
| HallDirection | BldcInt8_T | 霍尔检测方向 |
| FeedbackReady | BldcBool_T | 反馈就绪标志 |
| OmegaOpen | BldcSingle_T | 开环电角速度 |
| ThetaOpen | BldcSingle_T | 开环电角度 |
| AppliedLastSector | BldcUInt8_T | 上一实际生效扇区 |
| AppliedAge | BldcUInt32_T | 当前实际生效扇区持续节拍数 |
| ZcAge | BldcUInt32_T | 距上一过零的节拍数 |
| ZcPeriod | BldcSingle_T | 估算的过零周期 |
| ZcCount | BldcUInt16_T | 有效过零计数 |
| ZcFound | BldcBool_T | 过零检测结果 |
| ZcArmed | BldcBool_T | 过零检测已使能标志 |
| ZcValue | BldcSingle_T | 过零检测电压值 |
| ZcCountdown | BldcInt32_T | 换相倒计时 |
| ZcNextSector | BldcUInt8_T | 下一换相扇区 |
| AcquireStage | BldcUInt8_T | 捕获阶段 |
| AcquireTheta | BldcSingle_T | 捕获电角度 |
| AcquireAge | BldcUInt32_T | 捕获阶段节拍计数 |
| AcquisitionReady | BldcBool_T | 滑行端电压捕获已通过有效性确认 |
| SensorFault | BldcUInt16_T | 传感器故障位 |
| ActiveFaults | BldcUInt16_T | 当前活动故障位 |
| FaultBits | BldcUInt16_T | 锁存故障位 |
| PhaseCurrentsValid | BldcBool_T | 仅在实际测量相电流时为 true |
| DcCurrent | BldcCurrent_V | 最近一次有效母线电流，不代表三相电流重建 |
| DcCurrentValid | BldcBool_T | 本帧电流在合格的导通窗口内采样 |
| ZcUnclampedCount | BldcUInt16_T | 连续观测到悬浮端电压脱离电源轨的次数 |

### tBldcDebug

固定尺寸的 BLDC 调试接口。

| 字段 | 类型 | 说明 |
|---|---|---|
| Enabled | BldcBool_T | 调试使能 |
| Data | BldcSingle_T[16] | 16 个有序监视通道，见 bldc.monitor |

### tBldcMonitor

固定尺寸的 BLDC 监视接口。

| 字段 | 类型 | 说明 |
|---|---|---|
| Mode | BldcUInt8_T | 当前模式 |
| FaultBits | BldcUInt16_T | 锁存故障位 |
| Tick | BldcUInt32_T | 快速节拍计数 |
| Current | BldcSingle_T[3] | 三相电流，单位 A |
| CurrentReference | BldcCurrent_V | 电流参考 |
| CurrentDemand | BldcCurrent_V | 变化率限制前已限幅的速度环电流需求 |
| SpeedRequest | BldcSingle_T | 已锁存速度请求 |
| SpeedRamped | BldcSingle_T | 变化率限制后的速度请求 |
| SpeedEstimate | BldcSingle_T | 估算电角速度 |
| ControlSpeed | BldcSingle_T | 控制所用电角速度 |
| Sector | BldcUInt8_T | 换相扇区 |
| Direction | BldcInt8_T | 控制方向 |
| OutputDirection | BldcInt8_T | 输出方向 |
| Modulation | BldcSingle_T | 调制度 |
| GateEnable | BldcBool_T | 全局门极使能 |
| PhaseEnable | BldcBool_T[3] | 各相桥臂使能 |
| FeedbackReady | BldcBool_T | 反馈就绪标志 |
| ZcCount | BldcUInt16_T | 有效过零计数 |
| ZcPeriod | BldcSingle_T | 估算的过零周期 |
| ZcCountdown | BldcInt32_T | 换相倒计时 |
| AcquisitionReady | BldcBool_T | 滑行端电压捕获已通过有效性确认 |
| PositionMode | BldcUInt8_T | 0 霍尔；1 端电压无感 |
| VoltageResidual | BldcSingle_T | 端电压残差 |
| CurrentIntegrator | BldcSingle_T | 电流环积分状态 |
| SpeedIntegrator | BldcSingle_T | 速度环积分状态 |
| HallSector | BldcUInt8_T | 霍尔扇区 |
| HallValid | BldcBool_T | 霍尔反馈有效标志 |
| AppliedAge | BldcUInt32_T | 当前实际生效扇区持续节拍数 |
| CurrentMeasured | BldcCurrent_V | 用于调节的测量电流 |
| CurrentSenseMode | BldcUInt8_T | 0 相电流传感器；1 直流母线分流 |
| PhaseCurrentsValid | BldcBool_T | Current 向量有效标志 |
| DcCurrent | BldcCurrent_V | 最近一次有效母线电流 |
| DcCurrentValid | BldcBool_T | 本次母线电流采样有效标志 |


## 通用数据容器（Generic Data）

无需通用容器；固定尺寸向量在各总线上定义。

## 枚举类型（Enum）

总线字段保留整数存储；此枚举记录可选模式。

### eBldcPositionMode

BLDC 位置反馈选择。存储类型 `uint8`，默认值 `Hall`。

| 枚举值 | 数值 | 说明 |
|---|---|---|
| Hall | 0 | 霍尔边沿反馈 |
| Sensorless | 1 | 端电压过零反馈 |
