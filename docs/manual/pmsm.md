# PMSM 控制与 S32K344 HSP

控制器采用显式状态、类型化接口和 Simulink 平均值逆变器 + PMSM 电机模块。共享
`McControllerLibrary/FocCore` 连接到独立算法和整机管理组件，支持 Normal/SIL 对照和
S32K344 PIL。[目标配置、代码生成与 PIL](../hardware/hsp-s32k344.md)
基于 autoMBD HSP 0.1.0，使用独立工作副本。

## 启动与参数

在仓库根目录使用 `ambd_mc("setup","pmsm")` 初始化。首次运行及日志读取见
[快速开始](getting-started.md)，有感和无感调用见[场景示例](examples.md)。

入口设置相对路径，校验 Markdown 类型与保存的数据字典，读取已有标定，
将缓存、生成代码和报告放在 `.agent-env/` 下。保留返回的 `info`，以维持
字典枚举的生命周期。目标组件需要已启用的 autoMBD HSP 0.1.0。

仅在主动修改 `docs/McStruct.md` 或默认参数、需要重置字典时执行
`info = ambd_mc("setup","pmsm",SyncDictionary=true)`。同步重建本框架拥有的类型和默认
参数，拒绝有未保存修改的字典。正常启动不重置已有标定。

上述源字典同步用于独占的交互式 MATLAB。托管 MCP 实例默认只读源码，
同步时必须显式选择当前实例或独占输出目录中的字典副本；详见
[快速开始](getting-started.md)及[会话隔离](../development/agent-environment.md#离线与会话)。

| 数据 | 用途 |
|---|---|
| `McControl_Params` | 当前控制器标定 |
| `McPlant_Params` | 独立对象参数 |
| `McRuntime_Init`、`McCoreRuntime_Init` | 整机及独立核心初态 |
| `McInput_Default`、`McCoreInput_Default` | 原始采样及物理量输入默认值 |
| `tMcDrive_Param` | 电机参数描述结构；控制器使用 `McControl_Params` 标定 |

场景通过 `Simulink.SimulationInput` 临时覆盖参数和运行模式，不保存覆盖。
`legacy/` 保持原样，遵循其独立许可。

## 模型与控制约定

| 模型 | 职责 |
|---|---|
| `algo/McControllerLibrary.slx`、`MotorFramework.slx` | 共享 FocCore、独立核心封装与整机管理封装；MotorFramework 引用整机封装 |
| `platform/pil/FOC_PIL_Algth_model.slx` | 独立 FOC 核心：物理电流输入、归一化占空比输出 |
| `platform/pil/FOC_PIL_StateMch_model.slx` | 整机校准/启停/故障管理，内部复用同一 FOC 核心 |
| `platform/pil/FOC_PIL_Algth_top.slx`、`FOC_PIL_StateMch_top.slx` | 各自组件、接口适配、共享 AveragePlant 和实际输入/真值日志 |
| `platform/codegen/FOC_Ctrl_CodeModel.slx`、`FOC_Ctrl_MBD.slx` | HSP C 代码入口；`FOC_Ctrl_MBD` 含 RTD PWM/DIO 输出 |

- 快环 16 kHz（62.5 µs），速度环 1 kHz。角度为电角度 rad，速度为电角速度
  rad/s；对象日志的 `OmegaTruth` 也转换为电角速度。
- 整机接口电流 ADC 为 `uint16`，名义零点 32768，默认 1000 count/A；PWM 周期 65535。
  独立核心接口使用 single 安培和归一化占空比；gate enable 与三相占空比分开输出。
- 命令 `0` 为安全复位，`1` 为运行，`2` 为受控停止。故障优先并锁存，
  故障消失后必须收到安全复位才清除。
- 默认 `PositionMode=0`：对齐、I/f 启动、观测器资格确认、角度混合、闭环。
  观测器使用电流和电压，不使用对象转角真值。模式 `1` 提供有感控制基线。
- 低于可靠启动范围（默认约 75 电 rad/s）的请求保持 I/f，不宣称无感闭环。
  启动/停止超时及非有限数值有明确故障处理。
- 默认 12 V、2 对极、6 A 电流参考限幅、10 A 过流阈值、250 电 rad/s
  速度请求限幅。完整参数见 `mc.defaults`。

状态沿用 `eSmStates` 的 0–15 编号，转换由显式 MATLAB 函数实现，在模型中
保留独立模块。故障位：外部 1、过流 2、欠压 4、过压 8、非法输入 16、
ADC 到轨 32、启动超时 64、停止超时 128、非法状态 256、数值故障 512、校准失败 1024。

整机组件默认先采集64个稳定零偏样本，校准完成前门极保持禁用；独立核心
使用已处理的安培电流，不执行该校准。整机和核心分别报告状态，详见
[架构与校准契约](../specs/algorithms/pmsm-framework/pmsm-framework-architecture.md#lifecycle)。

## 验证与复现

通用命令、完整矩阵与局部调试规则见[验证指南](verification.md)。
PMSM 参考对象采用 MathWorks Interior PMSM，矩阵覆盖有感与无感、反转、
停止/重启、负载及母线变化、故障恢复、饱和恢复和对象参数偏差。
具体场景调用见[场景示例](examples.md)。

两个顶层共享可见的 `AveragePlant` 库子系统；禁用施加零相电压，属于电气制动，
不模拟硬件高阻滑行。对象连接、控制周期和电压反馈对齐见
[主机对象时序](../specs/algorithms/pmsm-framework/pmsm-framework-architecture.md#native-host-plant)。

同输入回放直接使用实际控制器输入总线，分别检查状态、故障、时序、gate、浮点与 PWM 量化。
数值契约见[PMSM 系统规格](../specs/algorithms/pmsm-framework/pmsm-framework-system.md)，
数学精度与施加电压的设计约定见[架构规格](../specs/algorithms/pmsm-framework/pmsm-framework-architecture.md)。

普通验证无需重建生产模型。需要重建时按[HSP 指南](../hardware/hsp-s32k344.md#模型重建)执行。

## HSP 迁移边界与验证范围

HSP 应用边界负责采样、时基、命令、故障、PWM 装载和 gate 控制。
它必须统一电/机械角度、ADC/PWM 标度、采样与电压施加延时；控制器不直接
访问板级 API。详见 [架构规格](../specs/algorithms/pmsm-framework/pmsm-framework-architecture.md)。
两层控制器的 `AppliedVoltageAlpha/Beta` 输入为与电流采样对齐的实际施加
电压；独立核心还带有 `Disable` 输入。主机从实际逆变器输出记录区间电压，HSP 需提供相同
物理含义的反馈，不能用尚未施加的命令电压代替。
S32K344 外部工程、Runtime 和目标 API 适配见 HSP 集成说明。

平均值逆变器不模拟开关纹波、死区、二极管续流或硬件故障延迟；gate 关闭
采用上述零相电压制动边界。SIL 不能替代 MCU 时序、ADC 同步、保护电路
和实机验证。
