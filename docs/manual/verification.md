# 验证与复现

本页说明如何运行验证及解读结果，不发布项目内部的任务计划、验收记录或审计附件。
Python 入口需要[项目锁定的官方 MCP 环境](../development/agent-environment.md)，
并使用独立会话；各产品和硬件前提见[环境要求](index.md)。

## 主机验证入口

在仓库根目录执行所需家族的命令：

| 目的 | PMSM | BLDC |
| --- | --- | --- |
| 独立对象参考 | `python tools/pmsm/validate_plant_reference.py` | `python tools/bldc/validate_plant_reference.py` |
| 完整 Normal/SIL 矩阵与重放 | `python tools/pmsm/validate_sil.py` | `python tools/bldc/validate_sil.py` |
| 仅排查一个场景 | `python tools/pmsm/validate_sil.py --scenario sensorless_forward` | `python tools/bldc/validate_sil.py --scenario hall_steps` |

BLDC 的 `validate_sil.py` 会先核对本地原生对象参考证据，包括局部场景和
`--normal-only` 运行。首次执行前先运行 `validate_plant_reference.py`；相关源码
变化导致参考证据过期时也需重新生成，不能跳过该依赖。

PMSM 对象参考使用 MathWorks Interior PMSM；BLDC 使用独立 Simscape BLDC、
六开关及续流二极管，检查物理方程、端电压和积分步长等性质。
完整 SIL 入口执行组件测试、模型接口/对象时序测试、独立闭环和同输入重放，并收集主机生成 C 与 EXE 证据。

PMSM 的两个顶层直接使用平均值逆变器和 Interior PMSM。独立对象参考入口
额外比较保留的数值参考实现，不是主机顶层的运行前提。核心层使用安培/归一化
占空比接口，整机层使用 ADC/PWM 计数接口，回放分别引用对应组件。实际输入
总线与事件随 trace 保存，不从对象真值重建。

PMSM 可附加 `--model FOC_PIL_Algth_top` 或 `--model FOC_PIL_StateMch_top`
选择层级；该选项和 `--scenario` 都只构成局部验证。完整报告按
`closed-loop/<模型名>/<场景>/<模式>`、`replay/<模型名>/<场景>` 区分，
同名场景在两个层级上运行时不会覆盖。

`--scenario` 仅用于局部排查，报告标记 `CompleteMatrix=false`。
BLDC 的 `--normal-only --collect-failures` 用于收集 Normal 物理场景问题，
也不构成完整 SIL 验收。

## 多实例隔离回归

使用已通过 Bootstrap/Sync 的锁定环境，在仓库根目录执行：

```powershell
python tools/agent/concurrent_smoke.py --instances 2 --cycles 2
python tools/agent/concurrent_smoke.py --instances 3 --cycles 2
```

`--instances` 可设为任意大于等于 2 的整数，`--cycles` 控制重复创建／回收次数；
`--timeout` 为单次 MCP 请求上限（默认 1800 秒）。每个周期同时保留 N 个真实 MATLAB，
校验不同 PID、实际 `tempdir`、工作目录和初始化后的生成目录。每个实例运行
完整 `tests/hsp`、两家族 `setup`、S32K144/S32K344 暂存测试，以及 BLDC `hall_steps`
和 PMSM `sensored_steps` 的 Normal 闭环；验证源文件与不可变 bundle 保持原样。
还验证显式输出目录排他锁、existing 同 PID 附着／断开、失败退出、执行中超时取消，
以及其余实例和运行前已有 MATLAB 进程的存活。进程回收后产物保留。

摘要和原始输出保存在 `.agent-env/reports/concurrent-<运行 ID>/`；
实例数据保存在各自的 `.agent-env/i/<实例 ID>/`。成功要求所有测试 Passed，
且没有 Failed/Incomplete。资源不足、许可证、目录冲突、传输和工作负载错误分别记录；
失败不会以保存重试、覆盖字典或禁用一致性检查来消除。
这只是并发隔离验收，不替代完整电机控制场景矩阵、目标代码生成或 PIL。
硬件访问在此入口中为 SKIP，探针和串口仍必须独占。

## 结果分层

| 层次 | 检查对象 | 不能替代 |
| --- | --- | --- |
| 单元／对象参考 | 算法局部行为、物理方程与独立参考 | 完整控制闭环 |
| Normal/SIL 闭环 | 模型和主机生成 C 的独立控制行为 | 同输入数值比较 |
| 同输入重放 | 相同输入下状态、时序、整数和浮点输出 | 两个闭环各自的物理表现 |
| 目标 PIL | 实际处理器执行生成代码与数值比较 | 连续实时电机试验 |
| 控制板诊断 | 当次板级采样、提交和故障路径时序 | 正常运行 WCET、功率级和带载闭环 |

检查 `Passed`、`CompleteMatrix`、源码未变化门槛及具体失败项，
不能只看脚本退出或曲线外观。整数状态、故障与 gate 的精确比较，
以及浮点容差、PWM 量化和严格逐位比较分别保留。
具体数值契约见 [PMSM 系统规格](../specs/algorithms/pmsm-framework/pmsm-framework-system.md)
和 [BLDC 系统规格](../specs/algorithms/bldc-framework/bldc-framework-system.md)。

## 本地证据

每次运行的编号、源码指纹、环境、报告与原始信号保存在本机 `.agent-env/`。
它们只证明对应受检输入和代码基线，不是当前工作区的自动通过证明。
原始工件清理后，重新运行会生成新的证据，不能声称恢复了相同历史结果。

工具未安装、许可证不可用、输入缺失与算法失败分开诊断。
缺少输入或硬件的项目标记 SKIP／未验证，不计为 PASS。
开发计划、验收记录、实验过程与审计文件的保存规则见[文档维护](../development/documentation.md)。

## 目标构建与板级验证

目标选择与实际 PIL 的入口见 [HSP 目标指南](../hardware/hsp-targets.md)，
详细公共验证流程见 [S32K344 HSP 指南](../hardware/hsp-s32k344.md)。
S32K144 使用独立本机设置及 12 位 ADC 的套件参考；不同目标的证据不能混用。
配置独立工作副本、外部工具链及明确的探针/UART 后再执行目标验证。
采样标定、栅极波形、带载闭环和正常运行时序按
[MCSPTE1AK344 板级说明](../hardware/mcspte1ak344.md)或
[MCSPTE1AK144 板级说明](../hardware/mcspte1ak144.md)单独验证。
