# BLDC 六步控制与 S32K344 HSP

框架提供 Hall 六步控制和基于实测端电压的无感六步控制，使用独立的
梯形反电势电机及带续流二极管的逆变器对象。控制器保存显式状态，
目标组件使用 autoMBD HSP 0.1.0、S32K344 外部 EB 工程和 RTD API。
[目标配置、代码生成与 PIL](../hardware/hsp-s32k344.md)使用独立工作副本。

## 启动与仿真

在仓库根目录使用 `bldc_setup` 初始化。首次运行及日志读取见
[快速开始](getting-started.md)，Hall 和无感调用见[场景示例](examples.md)。

`bldc_run_host_case` 自动选择对应顶层，并通过 `Simulink.SimulationInput`
临时设置控制模式、独立对象参数、初态和输入波形。它不保存这些覆盖。
SIL 在 Windows 主机运行实际生成 C，不连接芯片。

两组顶层共用完整控制器，模式由 `BldcControl_Params.PositionMode` 选择：
0 为 Hall，1 为无感。保存字典的默认模式为 Hall；顶层文件名不隐式切换
标定。使用上述入口运行无感场景，可保证模式和初态与记录一致。

正常 `bldc_setup` 验证类型并保留标定。修改类型或明确重置默认标定时使用：

```matlab
info = bldc_setup(SyncDictionary=true);
```

同步只更新 BLDC 拥有的条目，保留无关字典数据；未保存、带引用或不属于
允许目录的字典会被拒绝。保留 `info`，以维持字典连接生命周期。

## 模型和数据

| 文件/数据 | 用途 |
|---|---|
| `algo/BldcControllerLibrary.slx`、`BLDCFramework.slx` | 调参锁存、采样/时基、事件、故障、状态机、调制和诊断 |
| `platform/pil/BLDC_PIL_Hall_model.slx`、`BLDC_PIL_Sensorless_model.slx` | 共享控制算法的 HSP 组件 |
| `platform/pil/BLDC_PIL_Hall_top.slx`、`BLDC_PIL_Sensorless_top.slx` | 控制器、独立对象、测量适配、真值和完整输入日志 |
| `platform/codegen/BLDC_Ctrl_CodeModel.slx`、`BLDC_Ctrl_MBD.slx` | HSP C 代码入口；`BLDC_Ctrl_MBD` 含 RTD PWM/DIO 输出 |
| `BldcControl_Params` | 控制器标定；仅在停机状态锁存 |
| `BldcPlant_Params` | 独立对象参数，可用于失配验证 |
| `BldcRuntime_Init`、`BldcInput_Default` | 类型化初态和输入默认值 |

[BldcStruct.md](../BldcStruct.md) 是独立类型源。`bldc_initialize` 复用
本项目 Markdown 生成器，使用唯一的 `Bldc*`/`tBldc*` 名称及 `BldcData.sldd`。
每次正式场景都从当前场景标定重建控制器初态。顶层 `InitialPlantState`
接受 `[ia;ib;ic;theta_e;omega_m]`，首个 t=0 输出不提前积分。

## 接口与物理含义

- 快环 16 kHz，速度环 1 kHz；内部速度和请求为**电角速度 rad/s**。
- Hall 低速区按边沿信息量降低速度环增益；默认在 80 电 rad/s 恢复完整
  增益，比例项按速度缩放，积分项按其平方缩放。参数均可标定。
- 电流输入为 `uint16[3]`，默认零点 32768、1000 count/A；Hall 为编码值，
  其序列 `[5,4,6,2,3,1]` 对应六个物理扇区，数值本身不是扇区编号。
- `TerminalVoltage[3]` 是相对 DC 负端的实测相端电压；`AppliedSector`、
  `AppliedDirection` 描述产生这一组测量的上一实际驱动区间。
- `Control=0/1/2` 分别为安全复位、运行、受控停止。故障优先且锁存；
  复位时仍存在的外部故障或无效 Hall 不会被清除。
- 输出 `DutyA/B/C` 是高侧 PWM 计数，周期 65535。两个有效桥臂采用双极性
  互补 PWM，源/汇计数和严格等于周期。`PhaseEnable=false` 表示该相两管
  全关；`GateEnable=false` 全局关断。实际低侧互补、死区和两管关断由功率板
  适配落实；单路 PWM idle 不能单独代表桥臂高阻。
- 无感启动先对齐、强制换相，再短暂全关断测量相位。测量种子只安排临时
  换相；必须继续采集真实浮相过零才能宣告闭环就绪。详见
  [反馈与接管架构](../specs/algorithms/bldc-framework/bldc-framework-architecture.md)。
- 默认低于 75 电 rad/s 的无感请求采用明确的强制换相状态，不声明无感
  闭环性能。停止先降低电流，再全关断滑行；重新反向驱动前完成停止守卫。

虚拟电机参数为 12 V、2 对极、每相 R=0.56 Ω、L=0.4 mH、
相反电势峰值/机械速度系数 Ke=0.0078104522 V/(rad/s)、
J=1.2e-5 kg m²、B=0.0005 N m s/rad。参考电流限制 6 A、过流阈值 10 A，
速度请求限制 ±250 电 rad/s。这些是声明的仿真假设，完整标定见
[defaults.m](https://github.com/autoMBD/AMBD-MC/blob/main/mc-models/bldc/algo/+bldc/defaults.m)。

## 验证与复现

通用命令、完整矩阵与局部调试规则见[验证指南](verification.md)。
BLDC 独立参考包含 Simscape BLDC、六开关与续流二极管，检查浮相端电压、
过零、续流释放、电流/转矩以及平均对象与开关纹波的关系。
场景入口见[场景示例](examples.md)，判据见
[BLDC 系统规格](../specs/algorithms/bldc-framework/bldc-framework-system.md)。

完整矩阵和所有门槛通过才构成完整 SIL 验收；SIL 生成的 C 与主机 EXE
证据不能替代独立目标构建。目标构建及模型重建统一见
[HSP 指南](../hardware/hsp-s32k344.md)。普通验证无需重建生产模型。

## 适用范围与 HSP 边界

Hall 和无感回路不读取电机的角度、速度或内部反电势真值；真值仅用于
独立物理验收。无感依赖真实悬空相和采样/驱动区间对齐，HSP 适配需要保持
这一含义以及 ADC 标度、互补 PWM、相关闭和 gate 的语义。

平均对象保留电流连续性、二极管续流和浮相端电压，开关纹波在独立原生
参考中单独验证。这些仿真方法不替代死区、MOSFET 损耗、ADC 硬件时序、MCU
最坏执行时间和实机保护验证。板级配置、显式 Runtime 源码和端口标度见 HSP 集成说明。归档文件位于 `legacy/`。
