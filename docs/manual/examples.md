# 场景示例

以下入口均在仓库根目录的 MATLAB 会话执行。环境要求见
[使用手册](index.md)。模式由场景显式设置，不由文件名隐式决定。

| 目的 | 初始化 | 运行命令 |
| --- | --- | --- |
| PMSM 有感基线 | `info = ambd_mc("setup","pmsm");` | `result = mc_run_host_case('FOC_PIL_Algth_top','sensored_steps','Normal');` |
| PMSM 无感启动 | `info = ambd_mc("setup","pmsm");` | `result = mc_run_host_case('FOC_PIL_StateMch_top','sensorless_forward','Normal');` |
| BLDC Hall 阶跃 | `info = ambd_mc("setup","bldc");` | `result = bldc_run_host_case("hall_steps","Normal");` |
| BLDC 无感启动 | `info = ambd_mc("setup","bldc");` | `result = bldc_run_host_case("sensorless_forward","Normal");` |

SIL 使用同一入口，将最后一个执行模式参数换为 `'SIL'` 或 `"SIL"`，
并准备主机编译器与代码生成产品。SIL 不连接目标芯片。

## 预期结果

`result.Passed` 为真，`result.TraceFile` 给出 MAT 记录位置。
场景检查电流、速度、有限值、状态路径与故障响应等条件；
`load(result.TraceFile)` 可读取信号和验收结构。
结果位于 `.agent-env/`，不随站点公开。

## 更多场景与完整验收

场景定义以源码为准：
[PMSM 场景](https://github.com/autoMBD/AMBD-MC/blob/main/mc-models/pmsm/platform/pil/mc_host_scenario.m)、
[BLDC 场景](https://github.com/autoMBD/AMBD-MC/blob/main/mc-models/bldc/platform/pil/bldc_host_scenario.m)。
它们覆盖反转、停止/重启、负载与母线变化、故障恢复及参数失配等情况。

不要把几个示例当作完整验收；完整矩阵和同输入重放见
[验证教程](verification.md)。
