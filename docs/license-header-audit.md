# Issue #12 许可头盘点与验收

基线：最新 `origin/main` 的 `0749a75181c618da072633373a5d87ff8d669caa`。
本次从该提交创建 `codex/12-uniform-file-headers`，没有导入其他分支。
实际主分支已包含 PMSM、BLDC 源码及 16 个模型；环境文档早期“无模型”的记录不适用于本次盘点。

## 规范与元数据来源

- 原样纳入本地 `common-uniform-file-header` 的 3 个文件，未修改技能正文。
- 根 `LICENSE` 仍为 MIT。按技能“已有项目有效样式优先”规则，使用
  `tools/export_sldd_to_m.m` 的双语正文（包括弯引号），提取为
  `tools/license-header-template.txt`；只将年份/权利人变为模板参数。
- 模板明确要求保留 `IN NO EVENT SHALLTHE AUTHORS`，因此该拼写是已知模板约定。
  `THE SOFTWAREISPROVIDED`、`APARTICULAR` 等损坏拼接均修复为所选模板正文。
- 已有作者、版权年份、Date、Version 原样保留；作者仅为 autoMBD 时补入项目已知邮箱。
  原来只有 SPDX 的文件，Date 取 Git 首次引入日期，版权沿用原声明或该日期年份，
  Version 缺失时沿用项目初始版本 `0.1.0`，不冒充今日新建文件。
- 模型旧注释无 Date/Version 字段：Date 取 Git 首次引入日期，Version 同上。
  模型自身自动递增修订号与许可头版本字段独立，保存造成的修订号变化属正常序列化。
- MATLAB 函数/类帮助与 `%#codegen` 留在原位置；只移除原来散落的短许可声明。
  PowerShell `#requires` 位于完整注释后、参数绑定前，仍保持其指令语义。
  检查器支持 Python shebang/编码行、PowerShell 前置 `#requires`。

## 检查方式及边界

`python tools/test_check_spdx.py` 检查 Git 跟踪的项目自有 `.m/.py/.ps1/.c/.h/.cpp`，
逐行匹配双语正文、分隔线、空行、字段对齐、Description 续行，校验文件名、日期、
版本、作者邮箱、占位符及重复声明。声明检查区分 Python 字符串、C 字符串与块注释、
PowerShell here-string/块注释以及 MATLAB 块注释。

`--models` 独立读取 SLX ZIP 内保存的根级注释，要求恰有一个完整许可注释。
这不是模型编译或仿真测试。`.mdl/.mlx` 预留为独立格式验证路径并报告 SKIP；本基线没有
纳入范围的这两类文件。非 Git 目录或空检查范围失败，不回退扫描缓存和用户未跟踪文件。
CI 同时运行完整头/保存模型检查与检查器回归测试。Git 路径输出显式按 UTF-8 解码；
Windows CP1252 默认环境导致的中文路径解码错误已通过实际 CI 定位，并用包含中文
仓库目录和文件名的回归测试复现后修复。

## 实际测试

| 检查 | 实际结果 |
|---|---|
| 旧检查器回归复现 | 初始 14 项中 12 项按预期失败，证明原检查器漏检 |
| `python -m unittest discover -s tests/headers -v` | 29 项通过；涵盖源文件、排除规则、模型根级/子系统/重复/损坏注释 |
| `python tools/test_check_spdx.py` | 126 个文本文件通过；模型路径明确 SKIP，由下一项覆盖 |
| `python tools/test_check_spdx.py --models` | 126 个文本文件及 16 个保存模型注释通过 |
| `python -m unittest discover -s tests/agent -v` | 36 项通过；更新一项旧许可范围用例，使其构建真实 Git 索引 |
| `python -m unittest discover -s tests/bldc -v` | 19 项 Python 测试通过 |
| PowerShell Parser | 通过 |
| `git diff --cached --check`（排除原样导入的技能目录） | 通过；全量检查在用户原始 `reference.md` 中报告 21 处行尾空格，按保留要求未改写 |
| 源码行为对比 | 89 个 MATLAB、3 个 C、1 个 H、1 个 PowerShell 的非许可内容保持；25 个 Python AST 等价。检查器逻辑和对应范围测试是预期变化 |
| 原有本地技能 | 3 文件 SHA-256 与开始时一致 |
| 排除文件 | 与基线比较，除工作区换行表示外无变化 |

## 模型保存与回读

最新 Smoke 将 `building-simulink-models` 标为 ELIGIBLE；本次官方 MCP 实际返回
MATLAB R2026a、Simulink 许可可用。先通过 `model_overview` 检查 16 个模型，再用
`Simulink.Annotation` 更新根级纯文本注释。14 个原先没有许可注释，2 个已有富文本
许可注释含损坏正文，更新原对象，保留所有其他注释。

每个模型保存、关闭并重新打开后，核对文件路径、完整文本、根级位置及唯一性。
许可注释使用 Consolas 10，放在原图上方并留 80 单位间距；检查注释边界与原有块/注释
无重叠，另渲染 BLDCFramework 与 FOC_Sub_CoreAlgoithm 检查可读性。

`FOC_Sub_CoreAlgoithm` 和 `FOC_Sub_StateMch` 原文件为 R2025b；通过官方
`save_system(..., 'ExportToVersion', 'R2025b')` 保留其可读取格式，不手工编辑 ZIP/XML。
保存伴随默认参数序列化、库版本记录、Stateflow 内部 SID、图窗/缩略图及修订号变化。
曾被保存流程自动规范化的 `MotorFramework` HDLSubsystem 已恢复为原值。

对每个基线文件和修改后的文件，分别按绝对路径在同一 R2026a 会话中打开，对比可读取的
标量/文本配置参数、块类型、全部可读取标量/文本 DialogParameters，以及按块名归一化的
端口连接（分支目标按块名和端口号成对排序，消除保存造成的枚举顺序差异）。下表均一致；这验证当前运行环境下的结构/配置保持，不宣称跨版本仿真等价。
Stateflow 保存 XML 的可执行内容另行比较，只有空视图节点等非行为记录发生变化。

一次额外编译校验和探测在未加载控制器校准工作区的 BLDCFramework/McDebug 输出类型
推断处失败，未计为通过，也未据此修改模型算法。完整仿真、SIL/PIL、硬件代码生成均
**SKIP**（本次许可注释任务未执行）。真实环境管理 Smoke **SKIP**（初始化与工具注册未变）。
所有临时脚本、原始模型备份、运行 JSON 和 PNG 留在忽略的 `.agent-env/issue-12/`。

| 模型 | 注释整改 | 配置参数数 | 块数 | 保存回读 / 布局 / 配置与连接 |
|---|---|---:|---:|---|
| `mc-models/bldc/algo/BLDCFramework.slx` | 补充 | 614 | 131 | PASS |
| `mc-models/bldc/platform/codegen/BLDC_Ctrl_CodeModel.slx` | 补充 | 614 | 21 | PASS |
| `mc-models/bldc/platform/codegen/BLDC_Ctrl_MBD.slx` | 补充 | 614 | 21 | PASS |
| `mc-models/bldc/platform/pil/BLDC_PIL_Hall_model.slx` | 补充 | 614 | 21 | PASS |
| `mc-models/bldc/platform/pil/BLDC_PIL_Hall_top.slx` | 补充 | 614 | 92 | PASS |
| `mc-models/bldc/platform/pil/BLDC_PIL_Sensorless_model.slx` | 补充 | 614 | 21 | PASS |
| `mc-models/bldc/platform/pil/BLDC_PIL_Sensorless_top.slx` | 补充 | 614 | 92 | PASS |
| `mc-models/pmsm/algo/FOC_Sub_CoreAlgoithm.slx` | 修复已有 | 577 | 140 | PASS |
| `mc-models/pmsm/algo/FOC_Sub_StateMch.slx` | 修复已有 | 626 | 253 | PASS |
| `mc-models/pmsm/algo/MotorFramework.slx` | 补充 | 614 | 131 | PASS |
| `mc-models/pmsm/platform/codegen/FOC_Ctrl_CodeModel.slx` | 补充 | 614 | 21 | PASS |
| `mc-models/pmsm/platform/codegen/FOC_Ctrl_MBD.slx` | 补充 | 614 | 21 | PASS |
| `mc-models/pmsm/platform/pil/FOC_PIL_Algth_model.slx` | 补充 | 614 | 21 | PASS |
| `mc-models/pmsm/platform/pil/FOC_PIL_Algth_top.slx` | 补充 | 614 | 50 | PASS |
| `mc-models/pmsm/platform/pil/FOC_PIL_StateMch_model.slx` | 补充 | 614 | 21 | PASS |
| `mc-models/pmsm/platform/pil/FOC_PIL_StateMch_top.slx` | 补充 | 614 | 50 | PASS |

## 文本文件清单

基线 125 个项目自有文本源码/脚本：120 个需更新，5 个已符合。
另新增 `tests/headers/test_headers.py`（2026-10-07，Version 0.1.0），带完整许可头。
下表“已符合”文件保持不动；检查器本身虽头部已符合，仍按 Issue 更新功能说明和验证逻辑。

| 文件 | 基线状态 | Date | 日期依据 | 结果 |
|---|---|---|---|---|
| `bldc_setup.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/coast_acquire.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/commutate.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/dataflow.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/default_input.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/defaults.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/event_hub.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/feedback.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/hall_decode.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/hall_signal.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/initial_state.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/kernel.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/monitor.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/phase_network.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/pi_step.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/plant_measure.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/plant_step.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/protection.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/sector.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/speed_gains.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/step.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/supervisor.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/trapezoid.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/tuning.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/algo/+bldc/voltage_angle.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/bldc_initialize.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/platform/pil/bldc_assess_host_trace.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/platform/pil/bldc_compare_host_cases.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/platform/pil/bldc_compare_outputs.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/platform/pil/bldc_host_scenario.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/platform/pil/bldc_measurement_adapter.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/platform/pil/bldc_read_trace.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/platform/pil/bldc_run_host_case.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/bldc/platform/pil/bldc_run_replay.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/acquire.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/applied_voltage.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/clarke.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/current_control.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/dataflow.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/default_input.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/defaults.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/event_hub.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/initial_state.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/invpark.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/kernel.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/monitor.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/observer_initial.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/observer_step.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/park.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/pi_step.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/plant_measure.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/plant_step.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/protection.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/step.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/supervisor.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/svpwm.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/tuning.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/algo/+mc/wrap_angle.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/commom/McStruct.m` | 已符合 | 2026-10-06 | 原头保留 | PASS |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/ISR.c` | 需更新 | 2026-01-27 | 原头保留 | PASS |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/MCU_Init.c` | 需更新 | 2026-01-27 | 原头保留 | PASS |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/MCU_Init.h` | 需更新 | 2026-01-27 | 原头保留 | PASS |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/main.c` | 需更新 | 2026-01-27 | 原头保留 | PASS |
| `mc-models/pmsm/mc_initialize.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/platform/codegen/FOC_Config.m` | 已符合 | 2026-01-27 | 原头保留 | PASS |
| `mc-models/pmsm/platform/pil/mc_assess_host_trace.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/platform/pil/mc_compare_host_cases.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/platform/pil/mc_compare_replay.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/platform/pil/mc_host_scenario.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/platform/pil/mc_read_host_trace.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/platform/pil/mc_run_host_case.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `mc-models/pmsm/platform/pil/mc_run_replay.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `pmsm_setup.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/agent/test_artifacts.py` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tests/agent/test_capabilities.py` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tests/agent/test_configuration.py` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tests/agent/test_diagnostics.py` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tests/agent/test_environment.py` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tests/agent/test_mcp_client.py` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tests/agent/test_smoke.py` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tests/bldc/bldcAcceptanceTest.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/bldc/bldcAlgorithmsTest.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/bldc/bldcInitializeTest.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/bldc/bldcMeasurementAdapterTest.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/bldc/bldcPlantTest.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/bldc/bldcRuntimeTest.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/bldc/bldcVoltageAcquisitionTest.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/bldc/helpers/compare_plant_reference.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/bldc/helpers/plant_parameters.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/bldc/helpers/plant_physical_checks.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/bldc/helpers/plant_terminal_acceptance.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/bldc/helpers/plant_terminal_fixture.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/bldc/helpers/plant_torque_checks.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/bldc/test_model_builder.py` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/bldc/test_plant_reference_runner.py` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/bldc/test_sil_publication.py` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/pmsm/helpers/compare_plant_reference.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/pmsm/test_mc_acceptance.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/pmsm/test_mc_algorithms.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/pmsm/test_mc_initialize.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/pmsm/test_mc_plant.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tests/pmsm/test_mc_runtime.m` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tools/agent/agent-env.ps1` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tools/agent/agent_env.py` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tools/agent/artifacts.py` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tools/agent/capabilities.py` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tools/agent/configuration.py` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tools/agent/environment.py` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tools/agent/matlab/ambd_probe.m` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tools/agent/matlab/ambd_smoke.m` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tools/agent/matlab/test_ambd_probe.m` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tools/agent/mcp_client.py` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tools/agent/process_tree.py` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tools/agent/smoke.py` | 需更新 | 2026-09-11 | Git 首次引入日期 | PASS |
| `tools/bldc/build_models.py` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tools/bldc/create_replay_model.py` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tools/bldc/validate_plant_reference.py` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tools/bldc/validate_sil.py` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tools/export_sldd_to_m.m` | 已符合 | 2026-03-16 | 原头保留 | PASS |
| `tools/generate_data_type_from_md.m` | 已符合 | 2026-03-17 | 原头保留 | PASS |
| `tools/pmsm/build_models.py` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tools/pmsm/create_replay_model.py` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tools/pmsm/validate_plant_reference.py` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tools/pmsm/validate_sil.py` | 需更新 | 2026-10-06 | Git 首次引入日期 | PASS |
| `tools/test_check_spdx.py` | 已符合 | 2026-03-16 | 原头保留 | PASS |

## 排除范围及原因

- 全部 `legacy/`：189 个已跟踪文件，单独许可限制，未编辑、加载、保存或再生成。
- `.agent-env/`、`.agents/skills/ambd-mathworks/`：官方工具包/技能、缓存、生成产物，保持上游声明；均为忽略目录。
- `.agents/skills/common-uniform-file-header/`：用户提供的技能资料，原样提交，不作为项目源码改写。
- `.mat/.sldd/.pmpx` 及 IDE 工程配置：非文本源码许可头对象，不插入文本；无改动。
- 其余配置文件（YAML/TOML/JSON/Markdown）不作为源程序头校验对象；本 PR 的 CI、模板、排除清单和说明是明确新增/更新的支持文件。

具体非 legacy 排除项如下（规则同时存于 `tools/license-header-exclusions.json`）：

| 文件 | 原因 |
|---|---|
| `mc-models/bldc/config/BLDC_Ctrl_MBD_DS/Project_Settings/Linker_Files/S32K144_64_flash.ld` | NXP/Freescale linker scripts with independent copyright. |
| `mc-models/bldc/config/BLDC_Ctrl_MBD_DS/Project_Settings/Linker_Files/S32K144_64_ram.ld` | NXP/Freescale linker scripts with independent copyright. |
| `mc-models/bldc/data/bldc_data_types.m` | Generated data-type artifact; maintained by generate_data_type_from_md.m. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Project_Settings/Linker_Files/S32K144_64_flash.ld` | NXP/Freescale linker scripts with independent copyright. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Project_Settings/Linker_Files/S32K144_64_ram.ld` | NXP/Freescale linker scripts with independent copyright. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Project_Settings/Startup_Code/startup_S32K144.S` | NXP generated startup code with independent copyright. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/GD3000/aml/common_aml.h` | NXP/Freescale independent copyright and license notices. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/GD3000/aml/gpio_aml.h` | NXP/Freescale independent copyright and license notices. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/GD3000/aml/readme.txt` | NXP/Freescale independent copyright and license notices. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/GD3000/aml/spi_aml/spi_aml.c` | NXP/Freescale independent copyright and license notices. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/GD3000/aml/spi_aml/spi_aml.h` | NXP/Freescale independent copyright and license notices. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/GD3000/aml/wait_aml/wait_aml.c` | NXP/Freescale independent copyright and license notices. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/GD3000/aml/wait_aml/wait_aml.h` | NXP/Freescale independent copyright and license notices. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/GD3000/gd3000_init.c` | NXP/Freescale independent copyright and license notices. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/GD3000/gd3000_init.h` | NXP/Freescale independent copyright and license notices. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/GD3000/tpp/tpp.c` | NXP/Freescale independent copyright and license notices. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/GD3000/tpp/tpp.h` | NXP/Freescale independent copyright and license notices. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/Sources/GD3000/tpp/tpp_mc33937.h` | NXP/Freescale independent copyright and license notices. |
| `mc-models/pmsm/config/FOC_Ctrl_MBD_Integration/include/freemaster_cfg.h` | NXP FreeMASTER configuration with independent copyright. |
| `mc-models/pmsm/data/mc_data_types.m` | Generated data-type artifact; maintained by generate_data_type_from_md.m. |
