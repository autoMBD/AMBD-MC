# BLDC data structure reference

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 autoMBD.

This document is the canonical BLDC type source. Generate with
`tools/generate_data_type_from_md.m` and use `bldc_initialize` to collect the
result in function scope. The initializer renames the generator output to
`bldc_data_types.m`; BLDC never imports PMSM types or its dictionary.

All physical values use SI units and single precision. Vector fields are
fixed column vectors. Mode, event, counter and PWM fields use integer or
logical storage. Runtime.Parameters contains the complete parameter bus.
Normal startup verifies type equality and preserves calibration values.
Explicit `SyncDictionary=true` resets only BLDC-owned types and parameters.

## Primitive and physical types

<!-- MC_TYPE_TABLE:NUMERIC -->
| Name | Signed | WordLength | FractionLength | Slope | Bias | Description |
|---|---|---|---|---|---|---|
| BldcRaw16_T | false | 16 | 0 | 1 | 0 | Unsigned raw 16-bit representation |

<!-- MC_TYPE_TABLE:ALIAS -->
| Name | BaseType | HeaderFile | Description |
|---|---|---|---|
| BldcSingle_T | single | | BLDC single storage |
| BldcUInt8_T | uint8 | | BLDC uint8 storage |
| BldcInt8_T | int8 | | BLDC int8 storage |
| BldcUInt16_T | uint16 | | BLDC uint16 storage |
| BldcUInt32_T | uint32 | | BLDC uint32 storage |
| BldcInt32_T | int32 | | BLDC int32 storage |
| BldcBool_T | boolean | | BLDC logical storage |

<!-- MC_TYPE_TABLE:VALUE -->
| Name | DataType | Unit | Min | Max | Description |
|---|---|---|---|---|---|
| BldcTime_V | BldcSingle_T | s | 0 | | Time in seconds |
| BldcVoltage_V | BldcSingle_T | V | | | Measured voltage |
| BldcCurrent_V | BldcSingle_T | A | | | Phase current |

## Interface buses

### tBldcParams

Fixed-size BLDC params interface.

| 字段 | 类型 | 说明 |
|---|---|---|
| Ts | BldcTime_V | Ts |
| SpeedDivider | BldcUInt16_T | SpeedDivider |
| AdcOffset | BldcSingle_T | AdcOffset |
| AdcCountsPerAmp | BldcSingle_T | AdcCountsPerAmp |
| PwmPeriod | BldcUInt16_T | PwmPeriod |
| Rs | BldcSingle_T | Rs |
| Ls | BldcSingle_T | Ls |
| Ke | BldcSingle_T | Ke |
| PolePairs | BldcUInt8_T | PolePairs |
| Inertia | BldcSingle_T | Inertia |
| Friction | BldcSingle_T | Friction |
| PlantSubsteps | BldcUInt16_T | PlantSubsteps |
| NominalVdc | BldcVoltage_V | NominalVdc |
| VdcMin | BldcVoltage_V | VdcMin |
| VdcMax | BldcVoltage_V | VdcMax |
| CurrentLimit | BldcSingle_T | CurrentLimit |
| TripCurrent | BldcSingle_T | TripCurrent |
| SpeedLimit | BldcSingle_T | SpeedLimit |
| MaxModulation | BldcSingle_T | MaxModulation |
| KpCurrent | BldcSingle_T | KpCurrent |
| KiCurrent | BldcSingle_T | KiCurrent |
| KpSpeed | BldcSingle_T | KpSpeed |
| KiSpeed | BldcSingle_T | KiSpeed |
| SpeedSlew | BldcSingle_T | SpeedSlew |
| CurrentSlew | BldcSingle_T | CurrentSlew |
| AlignTime | BldcSingle_T | AlignTime |
| AlignCurrent | BldcSingle_T | AlignCurrent |
| OpenCurrent | BldcSingle_T | OpenCurrent |
| OpenAccel | BldcSingle_T | OpenAccel |
| OpenSpeed | BldcSingle_T | OpenSpeed |
| TrackingTime | BldcSingle_T | TrackingTime |
| TrackingTimeout | BldcSingle_T | Maximum tracking qualification duration |
| StartTimeout | BldcSingle_T | StartTimeout |
| StopSpeed | BldcSingle_T | StopSpeed |
| StopTimeout | BldcSingle_T | StopTimeout |
| StopCoastTime | BldcSingle_T | StopCoastTime |
| HallTimeout | BldcSingle_T | HallTimeout |
| HallStartTimeout | BldcSingle_T | HallStartTimeout |
| HallStallCurrent | BldcSingle_T | HallStallCurrent |
| SpeedFilterAlpha | BldcSingle_T | SpeedFilterAlpha |
| HallGainSpeed | BldcSingle_T | Electrical request in rad/s at full Hall speed-loop gains |
| HallMinGainScale | BldcSingle_T | Minimum Hall proportional gain scale; integral uses its square |
| ZcBlankTicks | BldcUInt16_T | ZcBlankTicks |
| ZcHysteresis | BldcSingle_T | ZcHysteresis |
| FloatCurrentLimit | BldcSingle_T | FloatCurrentLimit |
| ZcMinTicks | BldcUInt32_T | ZcMinTicks |
| ZcMaxTicks | BldcUInt32_T | ZcMaxTicks |
| ZcRequired | BldcUInt16_T | ZcRequired |
| ZcTimeoutFactor | BldcSingle_T | ZcTimeoutFactor |
| ZcMinSpeed | BldcSingle_T | ZcMinSpeed |
| AcquireSpacing | BldcUInt16_T | AcquireSpacing |
| AcquireMinVoltage | BldcSingle_T | AcquireMinVoltage |
| AcquireTimeout | BldcSingle_T | AcquireTimeout |
| LowSpeedThreshold | BldcSingle_T | LowSpeedThreshold |
| PositionMode | BldcUInt8_T | 0 Hall; 1 terminal-voltage sensorless |
| CurrentSenseMode | BldcUInt8_T | 0 three phase sensors; 1 valid-window DC-link shunt |
| MinModulation | BldcSingle_T | Minimum energized duty in DC-link mode |
| DemagBlankFraction | BldcSingle_T | Commutation-period fraction excluded after switching |
| DemagRailMargin | BldcSingle_T | Floating terminal must leave both clamp rails by this voltage |
| DemagReleaseTicks | BldcUInt16_T | Consecutive unclamped samples required before ZC arming |
| ActuationDelayTicks | BldcUInt16_T | Compensated output activation delay for DC-link commutation |

### tBldcInput

Fixed-size BLDC input interface.

| 字段 | 类型 | 说明 |
|---|---|---|
| CurrentRaw | BldcUInt16_T[3] | Phase ADC encodings; DC-link mode uses element 1 only |
| Hall | BldcUInt8_T | Hall |
| TerminalVoltage | BldcSingle_T[3] | Three phase terminal voltages; DC-link mode qualifies the applied floating phase only |
| Control | BldcUInt8_T | Control |
| Fault | BldcBool_T | Fault |
| CommandEvent | BldcBool_T | CommandEvent |
| DrivingEvent | BldcBool_T | DrivingEvent |
| TimerEvent | BldcBool_T | TimerEvent |
| SpeedReq | BldcSingle_T | SpeedReq |
| Vdc | BldcVoltage_V | Vdc |
| AppliedSector | BldcUInt8_T | AppliedSector |
| AppliedDirection | BldcInt8_T | AppliedDirection |
| VoltageValid | BldcBool_T | VoltageValid |

### tBldcRuntime

Fixed-size BLDC runtime interface.

| 字段 | 类型 | 说明 |
|---|---|---|
| Parameters | tBldcParams | Complete independent controller calibration |
| Mode | BldcUInt8_T | Mode |
| PreviousMode | BldcUInt8_T | PreviousMode |
| ModeTicks | BldcUInt32_T | ModeTicks |
| Tick | BldcUInt32_T | Tick |
| SlowCounter | BldcUInt16_T | SlowCounter |
| FastTick | BldcBool_T | FastTick |
| SpeedTick | BldcBool_T | SpeedTick |
| Command | BldcUInt8_T | Command |
| SpeedRequest | BldcSingle_T | SpeedRequest |
| SpeedRamped | BldcSingle_T | SpeedRamped |
| CoastTicks | BldcUInt32_T | CoastTicks |
| Direction | BldcInt8_T | Direction |
| OutputDirection | BldcInt8_T | OutputDirection |
| Sector | BldcUInt8_T | Sector |
| GateEnable | BldcBool_T | GateEnable |
| PhaseEnable | BldcBool_T[3] | PhaseEnable |
| DutyCounts | BldcUInt16_T[3] | DutyCounts |
| Modulation | BldcSingle_T | Modulation |
| Current | BldcSingle_T[3] | Three phase currents in A |
| CurrentRef | BldcCurrent_V | CurrentRef |
| CurrentDemand | BldcCurrent_V | Saturated speed-loop current demand before slew |
| CurrentMeasured | BldcCurrent_V | CurrentMeasured |
| CurrentIntegrator | BldcSingle_T | CurrentIntegrator |
| SpeedIntegrator | BldcSingle_T | SpeedIntegrator |
| SpeedEstimate | BldcSingle_T | SpeedEstimate |
| ControlSpeed | BldcSingle_T | ControlSpeed |
| RawSpeed | BldcSingle_T | RawSpeed |
| HallLast | BldcUInt8_T | HallLast |
| HallSector | BldcUInt8_T | HallSector |
| HallAge | BldcUInt32_T | HallAge |
| HallValid | BldcBool_T | HallValid |
| HallDirection | BldcInt8_T | HallDirection |
| FeedbackReady | BldcBool_T | FeedbackReady |
| OmegaOpen | BldcSingle_T | OmegaOpen |
| ThetaOpen | BldcSingle_T | ThetaOpen |
| AppliedLastSector | BldcUInt8_T | AppliedLastSector |
| AppliedAge | BldcUInt32_T | AppliedAge |
| ZcAge | BldcUInt32_T | ZcAge |
| ZcPeriod | BldcSingle_T | ZcPeriod |
| ZcCount | BldcUInt16_T | ZcCount |
| ZcFound | BldcBool_T | ZcFound |
| ZcArmed | BldcBool_T | ZcArmed |
| ZcValue | BldcSingle_T | ZcValue |
| ZcCountdown | BldcInt32_T | ZcCountdown |
| ZcNextSector | BldcUInt8_T | ZcNextSector |
| AcquireStage | BldcUInt8_T | AcquireStage |
| AcquireTheta | BldcSingle_T | AcquireTheta |
| AcquireAge | BldcUInt32_T | AcquireAge |
| AcquisitionReady | BldcBool_T | Terminal voltage coast acquisition qualified |
| SensorFault | BldcUInt16_T | SensorFault |
| ActiveFaults | BldcUInt16_T | ActiveFaults |
| FaultBits | BldcUInt16_T | FaultBits |
| PhaseCurrentsValid | BldcBool_T | True only for actual phase-current sensing |
| DcCurrent | BldcCurrent_V | Last valid DC-link current; not a three-phase reconstruction |
| DcCurrentValid | BldcBool_T | Current frame sampled in a qualified conduction window |
| ZcUnclampedCount | BldcUInt16_T | Consecutive floating-voltage rail-release observations |

### tBldcDebug

Fixed-size BLDC debug interface.

| 字段 | 类型 | 说明 |
|---|---|---|
| Enabled | BldcBool_T | Enabled |
| Data | BldcSingle_T[16] | 16 ordered monitor channels; see bldc.monitor |

### tBldcMonitor

Fixed-size BLDC monitor interface.

| 字段 | 类型 | 说明 |
|---|---|---|
| Mode | BldcUInt8_T | Mode |
| FaultBits | BldcUInt16_T | FaultBits |
| Tick | BldcUInt32_T | Tick |
| Current | BldcSingle_T[3] | Three phase currents in A |
| CurrentReference | BldcCurrent_V | CurrentReference |
| CurrentDemand | BldcCurrent_V | Saturated speed-loop current demand before slew |
| SpeedRequest | BldcSingle_T | SpeedRequest |
| SpeedRamped | BldcSingle_T | SpeedRamped |
| SpeedEstimate | BldcSingle_T | SpeedEstimate |
| ControlSpeed | BldcSingle_T | ControlSpeed |
| Sector | BldcUInt8_T | Sector |
| Direction | BldcInt8_T | Direction |
| OutputDirection | BldcInt8_T | OutputDirection |
| Modulation | BldcSingle_T | Modulation |
| GateEnable | BldcBool_T | GateEnable |
| PhaseEnable | BldcBool_T[3] | PhaseEnable |
| FeedbackReady | BldcBool_T | FeedbackReady |
| ZcCount | BldcUInt16_T | ZcCount |
| ZcPeriod | BldcSingle_T | ZcPeriod |
| ZcCountdown | BldcInt32_T | ZcCountdown |
| AcquisitionReady | BldcBool_T | Terminal voltage coast acquisition qualified |
| PositionMode | BldcUInt8_T | 0 Hall; 1 terminal-voltage sensorless |
| VoltageResidual | BldcSingle_T | VoltageResidual |
| CurrentIntegrator | BldcSingle_T | CurrentIntegrator |
| SpeedIntegrator | BldcSingle_T | SpeedIntegrator |
| HallSector | BldcUInt8_T | HallSector |
| HallValid | BldcBool_T | HallValid |
| AppliedAge | BldcUInt32_T | AppliedAge |
| CurrentMeasured | BldcCurrent_V | CurrentMeasured |
| CurrentSenseMode | BldcUInt8_T | 0 phase sensors; 1 DC-link shunt |
| PhaseCurrentsValid | BldcBool_T | Validity of the Current vector |
| DcCurrent | BldcCurrent_V | Last valid DC-link current |
| DcCurrentValid | BldcBool_T | Validity of this DC-link sample |


## 通用数据容器（Generic Data）

No generic containers are needed; fixed vectors are defined on each bus.

## 枚举类型（Enum）

Bus fields retain integer storage. This enumeration documents the selection.

### eBldcPositionMode

BLDC position feedback selection. 存储类型 `uint8`，默认值 `Hall`。

| 枚举值 | 数值 | 说明 |
|---|---|---|
| Hall | 0 | Hall edge feedback |
| Sensorless | 1 | Terminal voltage zero crossing feedback |
