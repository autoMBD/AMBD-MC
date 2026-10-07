# PMSM 控制与 S32K344 HSP

控制器采用显式状态、类型化接口和独立 PMSM 平均值对象。共享
`McControllerLibrary` 连接到各 HSP 组件，支持 Normal/SIL 对照和
S32K344 PIL。[目标配置、代码生成与 PIL](../hsp-s32k344.md)
基于 autoMBD HSP 0.1.0，使用独立工作副本。

## 启动与参数

在仓库根目录启动 MATLAB：

```matlab
info = pmsm_setup;
open_system('FOC_PIL_StateMch_top');
```

入口设置相对路径，校验 Markdown 类型与保存的数据字典，读取已有标定，
将缓存、生成代码和报告放在 `.agent-env/` 下。保留返回的 `info`，以维持
字典枚举的生命周期。目标组件需要已启用的 autoMBD HSP 0.1.0。

仅在主动修改 `docs/McStruct.md` 或默认参数、需要重置字典时执行
`info = pmsm_setup(SyncDictionary=true)`。同步重建本框架拥有的类型和默认
参数，拒绝有未保存修改的字典。正常启动不重置已有标定。

| 数据 | 用途 |
|---|---|
| `McControl_Params` | 当前控制器标定 |
| `McPlant_Params` | 独立对象参数 |
| `McRuntime_Init` | 控制器初态 |
| `McInput_Default` | 类型化输入默认值 |
| `tMcDrive_Param` | 电机参数描述结构；控制器使用 `McControl_Params` 标定 |

场景通过 `Simulink.SimulationInput` 临时覆盖参数和运行模式，不保存覆盖。
`legacy/` 保持原样，遵循其独立许可。

## 模型与控制约定

| 模型 | 职责 |
|---|---|
| `algo/McControllerLibrary.slx`、`MotorFramework.slx` | McKernel、McTuning、McEventHub、McFault、McStateMachine、McDataFlow、McDebug 执行链 |
| `platform/pil/FOC_PIL_Algth_model.slx`、`FOC_PIL_StateMch_model.slx` | 共享完整控制算法的 HSP 组件 |
| `platform/pil/FOC_PIL_Algth_top.slx`、`FOC_PIL_StateMch_top.slx` | 控制器、ADC/PWM 适配、独立对象和真值日志 |
| `platform/codegen/FOC_Ctrl_CodeModel.slx`、`FOC_Ctrl_MBD.slx` | HSP C 代码入口；`FOC_Ctrl_MBD` 含 RTD PWM/DIO 输出 |

- 快环 16 kHz（62.5 µs），速度环 1 kHz。角度为电角度 rad，速度为电角速度
  rad/s；对象日志的 `OmegaTruth` 也转换为电角速度。
- 电流 ADC 为 `uint16`，零点 32768，默认 1000 count/A；PWM 周期 65535。
  gate enable 与三相占空比分开输出。
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
ADC 到轨 32、启动超时 64、停止超时 128、非法状态 256、数值故障 512。

## 验证与复现

2026-10-06 完整验收：87 项单元测试、13 个场景的 Normal/SIL 闭环及同输入回放
全部通过，最终受检回放输出逐位一致。详见
[2026-10-06 验收报告](../validation/2026-10-06-pmsm-sil-acceptance.md)。
后续 HSP 迁移及主机回归见 [2026-10-07 报告](../validation/2026-10-07-hsp-s32k344.md)。

先按 [代理环境说明](../agent-environment.md) 配置锁定的官方 MCP，
然后从仓库根目录执行：

```powershell
python tools/pmsm/validate_plant_reference.py
python tools/pmsm/validate_sil.py
```

第一条与 MathWorks Interior PMSM 连续对象比较并检查积分步长收敛。
第二条使用新的官方 MCP 会话运行单元测试、闭环 Normal/SIL 场景矩阵和
同输入回放。每次创建独立报告目录；所有门槛通过且验证期间源文件哈希
不变，汇总才通过。用 `--scenario sensorless_forward` 可选择场景，这种
运行标记 `CompleteMatrix=false`，不替代完整验收。

MATLAB 内可直接执行：

```matlab
info = pmsm_setup;
result = mc_run_host_case('FOC_PIL_StateMch_top', ...
    'sensorless_forward','SIL');
```

矩阵覆盖有感阶跃、无感正反转、100 rad/s、负载/母线变化、反转、停止/重启、
TRACKING 中停止、故障恢复、母线故障、饱和恢复、对象参数偏差及低速转闭环。
检查电流/速度边界、稳定误差、有限值、状态路径、gate、故障响应和锁存。

同输入回放要求状态、故障、时序和 gate 精确相同。浮点与 PWM 判据、严格
逐位结果和量化边界证明分开保留，见
[数值一致性决策](../validation/2026-10-06-pmsm-numerical-equivalence.md)。
两个独立闭环通过不能替代同输入回放的一致性检查。

控制器状态和接口为 single；三角函数、角度和部分平方根采用 double 中间
求值再舍入，减少数学库差异在积分环节的累积。证据与取舍见
[数学精度决策](../validation/2026-10-06-pmsm-math-precision.md)。

`python tools/hsp/build_models.py --family pmsm` 可重建生产模型，并在 `.agent-env/`
备份旧模型；普通验证不要求重建。

## HSP 迁移边界与验证范围

HSP 应用边界负责采样、时基、命令、故障、PWM 装载和 gate 控制。
它必须统一电/机械角度、ADC/PWM 标度、采样与电压施加延时；控制器不直接
访问板级 API。详见 [架构规格](../specs/algorithms/pmsm-framework/pmsm-framework-architecture.md)。
控制器末尾两个输入 `AppliedVoltageAlpha/Beta` 为与电流采样对齐的实际施加
电压，主机从延迟的 PWM 计数、gate 和该区间母线电压重建；HSP 需提供相同
物理含义的反馈，不能用尚未施加的命令电压代替。
S32K344 外部工程、Runtime 和目标 API 适配见 HSP 集成说明。

平均值逆变器不模拟开关纹波、死区、二极管续流或硬件故障延迟；gate 关闭
采用电流衰减/机械滑行近似。SIL 不能替代 MCU 时序、ADC 同步、保护电路
和实机验证。
