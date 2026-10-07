# PMSM 框架与 PC SIL 最终验收

验收日期：2026-10-06。结论：本次约定的五个里程碑及 R1–R8 全部通过。
实现保留在当前分支 `8-update-pmsm-models` 的工作区，未创建提交、未推送远程。

## 最终运行与证据

最终完整运行：`20261005T224813Z-3da48fe6`，北京时间 06:48–07:09。
环境为 MATLAB/Simulink R2026a、Embedded Coder、Windows 主机、MinGW64 C 14.2.0；
通过项目锁定的官方 MATLAB MCP 新会话执行。

- [完整汇总 JSON](../../.agent-env/pmsm/validation/20261005T224813Z-3da48fe6/summary.json)：
  `Passed=true`、`CompleteMatrix=true`、`SourcesUnchanged=true`。
- 87/87 MATLAB 单元测试通过：算法 19、运行时 36、初始化 15、对象 5、验收器 12；
  无失败、无未完成测试。
- 13 个场景各运行独立 Normal 与真实 SIL 闭环，共 26 次物理行为验收全部通过。
  两个 `platform/pil` 顶层模型均实际执行了生成 C 的主机 SIL。
- 13 次同输入 Normal/SIL 成对回放全部通过，累计 865,613 个采样点。
  录制 Normal 与回放 Normal 对齐检查全部逐位通过；回放 Normal 与 SIL
  全部受检输出逐位一致，PWM 不同计数总数为 0。
- 13 组独立闭环比较全部通过；速度、电流、占空比最大差异均为 0，
  gate、状态及故障输出一致。
- `FOC_Ctrl_CodeModel` 独立 ERT 构建通过，见
  [构建日志](../../.agent-env/pmsm/validation/20261005T224813Z-3da48fe6/standalone-codegen.log)。
  汇总记录生成的控制器 C、独立主机 EXE、两个 SIL EXE 的路径、大小和 SHA-256。
  验收结束后重新计算源文件与五项构建产物指纹，全部一致。

上述二进制、日志、MAT 信号、图和完整 JSON 位于忽略目录 `.agent-env/`，
不会随 Git 发布。本文保存结果摘要；清理该目录后可按下方命令重新生成证据。
历史失败报告保留用于追溯，不属于最终验收结果。

## 需求与里程碑对应

| 需求 | 已交付实现 | 实际验收 |
|---|---|---|
| R1 类型、字典、入口 | Markdown 类型源、生成脚本、字典、`pmsm_setup` 和幂等初始化；正常启动保留标定 | 15 项初始化测试、全新 MCP 会话运行、模型编译通过 |
| R2 框架分工 | McKernel / McTuning / McEventHub / McFault / McStateMachine / McDataFlow / McDebug 实际执行 | 官方模型检查、7 个生产模型编译、接口和依赖扫描通过 |
| R3 时序与故障优先级 | 16 kHz 快环、1 kHz 速度环、显式状态、故障锁存与安全复位 | 运行时测试、外部/母线故障及恢复闭环通过 |
| R4 完整运行周期 | 对齐、I/f 启动、观测器资格确认、角度混合、闭环、停止/反转/重启 | 正反转、100 rad/s、TRACKING 中停止、低速转闭环等场景通过 |
| R5 控制与观测算法 | 采样换算、坐标变换、抗饱和 PI、限流、SVPWM、磁链观测器 | 解析算法测试；实际施加电压反馈及非法反馈回归测试通过 |
| R6 物理行为 | 独立 PMSM 平均值对象、明确 PWM/采样延时、真值仅用于日志/有感基线 | 26 次闭环验收及 5 个官方对象参考比较通过 |
| R7 代码与模型一致性 | 两个主机 SIL 封装、同输入回放、独立闭环比较、独立 ERT 构建 | 87 测试、13 场景、13 回放全部通过，最终严格逐位一致 |
| R8 平台边界 | 该次主机执行链独立于硬件工具；记录采样/电压反馈/PWM/gate 接口 | 活跃模型无硬件依赖；195 项受保护文件指纹保持不变 |

五个里程碑分别为：类型与初始化、控制算法、框架集成、独立主机对象和平台、
可复现验收与交付。详见[完成清单](../superpowers/plans/2026-10-06-pmsm-framework-sil.md)。
状态转换由显式 MATLAB 函数实现并置于对应模型模块内，沿用 `eSmStates` 编号。

## 场景结果

表中峰值取 SIL 实际日志；电流是三相瞬时绝对值的最大值，速度是电角速度
绝对值的最大值。每行 Normal、SIL 物理验收、闭环比较和严格逐位回放均通过。

| 场景 | 采样点 | 峰值电流 A | 峰值电速度 rad/s | 结果 |
|---|---:|---:|---:|---|
| 有感阶跃 `sensored_steps` | 48,001 | 4.3612 | 200.3163 | PASS |
| 无感正转 `sensorless_forward` | 52,801 | 4.9676 | 200.0437 | PASS |
| 无感反转 `sensorless_reverse` | 52,801 | 4.9674 | 200.0477 | PASS |
| 无感 100 rad/s `sensorless_100` | 48,001 | 3.5002 | 103.6161 | PASS |
| 负载/母线变化 `load_voltage` | 64,001 | 4.9676 | 200.0437 | PASS |
| 运行反转 `reversal` | 104,001 | 4.9676 | 200.0437 | PASS |
| 停止重启 `stop_restart` | 64,001 | 3.2959 | 150.3169 | PASS |
| 混合阶段停止 `stop_mid_tracking` | 48,001 | 4.0464 | 132.2370 | PASS |
| 故障恢复 `fault_recovery` | 88,001 | 4.9681 | 200.0469 | PASS |
| 母线故障 `bus_fault` | 56,001 | 3.2959 | 150.3169 | PASS |
| 饱和恢复 `saturation_recovery` | 64,001 | 6.0002 | 255.0142 | PASS |
| 对象参数偏差 `parameter_variation` | 64,001 | 5.1189 | 201.4743 | PASS |
| 低速转闭环 `low_speed_transition` | 112,001 | 3.5009 | 103.6106 | PASS |

饱和场景确实进入 6 A 参考限幅并在卸载后退出饱和；负载期间无法维持
250 rad/s 属于设定的饱和工况，验收要求最终恢复。6 A 是电流参考限幅，
测得相电流峰值 6.0002 A 不应误写为参考越限或 10 A 过流保护失效。
所有场景均检查完整时间区间、采样网格、有限值、状态路径、gate、故障和
各自的稳态/超调窗口，具体值见汇总中每个 `Assessment.Checks`。

已目视复核[反转](../../.agent-env/pmsm/validation/20261005T224813Z-3da48fe6/comparison/reversal/closed-loop.png)、
[故障恢复](../../.agent-env/pmsm/validation/20261005T224813Z-3da48fe6/comparison/fault_recovery/closed-loop.png)、
[饱和恢复](../../.agent-env/pmsm/validation/20261005T224813Z-3da48fe6/comparison/saturation_recovery/closed-loop.png)
及[低速转闭环](../../.agent-env/pmsm/validation/20261005T224813Z-3da48fe6/comparison/low_speed_transition/closed-loop.png)波形。

## 对象独立校验与数值问题闭环

原创对象与 MathWorks Interior PMSM 连续模型的 5 个案例全部通过：零平衡、
正反向空载、正反向带载及非零初态。另进行积分步长减半比较。
最大相电流误差约 2.384e-7 A，最大机械速度误差约 1.884e-6 rad/s，
均低于预设门槛。见[对象校验结果](../../.agent-env/pmsm-plant-validation/results.json)。
该证据对应的对象源文件哈希与最终实现一致。此参考比较仅覆盖 gate 开启的
平均电压模型；gate 关闭的衰减/滑行近似由单独单元测试验证。

开发阶段的两项实质性回放失败均完成因果定位和修复：

1. [实际施加电压反馈](2026-10-06-pmsm-applied-voltage-feedback.md)：
   观测器改用与电流采样对齐的实际 PWM 电压，增加末尾两个输入
   `AppliedVoltageAlpha/Beta`；不使用尚未施加的自身命令电压。
2. [数学函数求值精度](2026-10-06-pmsm-math-precision.md)：
   用受控实验定位 Normal 与生成 C 的数学库舍入差异；选定超越函数以 double
   中间求值后显式转回原精度，状态和接口仍为 single。

最终运行沿用已记录的[数值验收规则](2026-10-06-pmsm-numerical-equivalence.md)，
没有为这两项失败继续放宽门槛；实际结果严格逐位一致，不依赖允许的量化误差。
这只是当前工具链与已测输入域的实测结论，不构成所有输入或所有编译器的等价证明。

## 三轮完成审计

1. 功能完整性：逐项对应 R1–R8；复核 7 个模型引用、显式状态及反馈链。
   核心加四个封装为 14 输入/6 输出，两个闭环顶层为 5 输入/6 输出。
   复核停止方向边界、TRACKING 停止、离线标定生效及观测器电压因果关系。
2. 验证可信度：复核 87 项测试、26 次物理验收、13 次回放、13 次闭环比较，
   检查真实 SIL 执行日志、生成 C 和 EXE；验收器包含错误状态、伪造 PWM
   相邻计数、缺失时间证据及未进入饱和的负向测试。
3. 可复现与范围：全新会话重建回放 harness 并完整验收；检查源文件/产物哈希、
   相对路径入口、源码许可、环境 Doctor 和环境回归测试；确认 legacy 与所检查
   的外部参考文件共 195 项未变化。本任务未执行远程提交、硬件下载或调试器调用。

## 复现和后续边界

从仓库根目录执行：

```powershell
python tools/pmsm/validate_plant_reference.py
python tools/pmsm/validate_sil.py
```

MATLAB 交互入口与接口约定见 [PMSM 使用说明](../../mc-models/pmsm/README.md)。
`build_models.py` 用于需要时重建生产模型；普通验收不修改生产模型。

当前交付为 PC SIL。低于约 75 电 rad/s 的请求采用已声明的 I/f 回退，
不宣称低速无感闭环。平均值对象不覆盖开关纹波、死区、二极管续流和硬件
故障延迟；双精度数学求值的 MCU 成本尚未测量。未来 HSP 适配、芯片时序、
ADC/PWM 同步和实机保护需要单独验证。旧 `FOC_Sub_*`、`FOC_Config.m` 及
`legacy/` 不属于当前执行链；HSP 和 NXP 实现未导入或复制。
