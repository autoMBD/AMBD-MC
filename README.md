# AMBD-MC / autoMBD Motor Control

**使用 MATLAB/Simulink 学习与开发电机控制，从主机仿真走向 NXP S32K144 / S32K344 集成。**
AMBD-MC（autoMBD Motor Control）是 autoMBD 的基于模型设计（Model-Based Design，MBD）
电机控制项目，面向希望学习、验证和改进电机控制算法、类型化接口及嵌入式代码生成的开发者。

[在线文档](https://autombd.github.io/AMBD-MC/) ·
[版本下载](https://github.com/autoMBD/AMBD-MC/releases) ·
[快速开始](docs/manual/getting-started.md) ·
[参与贡献](.github/CONTRIBUTING.md) ·
[问题反馈](https://github.com/autoMBD/AMBD-MC/issues)

## 项目提供什么

| 方向 | 项目内容 | 阅读入口 |
| --- | --- | --- |
| PMSM | 永磁同步电机矢量控制（FOC），包含有感与无感场景 | [PMSM 手册](docs/manual/pmsm.md) |
| BLDC | 无刷直流电机 Hall／无感六步控制 | [BLDC 手册](docs/manual/bldc.md) |
| 主机验证 | 独立电机对象、Normal 仿真、软件在环（SIL）及同输入重放 | [验证流程](docs/manual/verification.md) |
| 嵌入式集成 | 基于 autoMBD HSP 0.1.0 的 S32K144 / S32K344 代码生成与处理器在环（PIL）流程 | [目标选择](docs/hardware/hsp-targets.md) |

控制算法、电机对象与硬件适配各有独立职责，详见[框架与数据流](docs/specs/architecture.md)。
主机仿真、SIL 和 PIL 分别验证不同层面的行为；实际带电机运行仍需完成
[板级验证](docs/hardware/mcspte1ak344.md#验证边界)。

## 开始前需要准备什么

模型参考环境为 **Windows + MATLAB/Simulink R2026a**。按你的目标准备对应环境：

| 目标 | 环境要求 |
| --- | --- |
| 阅读或贡献文档 | 浏览器；本地构建使用 Python 3.11+ 和[版本锁定的文档依赖](docs/development/documentation.md) |
| 运行首个主机 Normal 场景 | MATLAB/Simulink，以及已安装并启用的 **autoMBD HSP 0.1.0**；无需连接目标板 |
| 运行 SIL | 主机环境，以及 MATLAB Coder、Simulink Coder、Embedded Coder 和受支持的主机 C 编译器 |
| 构建 S32K144 / S32K344 目标代码或运行 PIL | [目标工具链与本机配置](docs/hardware/hsp-targets.md)；实际 PIL 还需要控制板、PEmicro 探针和 UART 连接 |

完整工作流及独立对象参考所需的额外产品见[环境要求](docs/manual/index.md)。
HSP 由外部安装提供，初始化时会检查版本；请在运行 `setup` 前完成安装与启用，
克隆本仓库不会自动安装 HSP。

## 运行第一个主机场景

也可从 [GitHub Releases](https://github.com/autoMBD/AMBD-MC/releases) 下载带
`SHA256SUMS` 的 `AMBD-MC-<version>.zip` 发布附件，校验后解压并进入包根目录。
预发布版会标注 Pre-release；没有独立附件的历史发布不代表已通过当前打包检查。
包内提供模型、源码、使用文档和许可材料，MATLAB/HSP/目标工具链需要另行安装。
下载与校验方法见[快速开始](docs/manual/getting-started.md)，维护者见[发布指南](docs/development/releasing.md)。

在终端中克隆仓库：

```powershell
git clone https://github.com/autoMBD/AMBD-MC.git
cd AMBD-MC
```

在 MATLAB 中将当前文件夹切换到仓库根目录。准备好上述主机环境后，
运行 PMSM 有感基线场景：

```matlab
info = ambd_mc("setup","pmsm");
result = mc_run_host_case('FOC_PIL_Algth_top','sensored_steps','Normal');
```

也可以选择 BLDC Hall 基线场景：

```matlab
info = ambd_mc("setup","bldc");
result = bldc_run_host_case("hall_steps","Normal");
```

完成任一场景后，检查结果并查看日志保存路径：

```matlab
assert(result.Passed, '场景未通过验收');
disp(result.TraceFile);
```

`result.Passed` 为真表示场景通过验收。轨迹 MAT 文件保存在本机的 `.agent-env/`
目录中，该目录已被 Git 忽略。使用模型期间请保留 `info`，以维持数据字典连接。
普通初始化保留已保存的标定，首次运行无需重建模型或重置默认参数。

[快速开始](docs/manual/getting-started.md)介绍日志内容和初始化选项。
使用 `ambd_mc("help")` 查看命令帮助；环境或字典问题可参考[常见问题](docs/manual/faq.md)。
需要目标构建时，先完成主机验证，再按[独立工作副本流程](docs/hardware/hsp-s32k344.md)操作。

## 仓库导航

| 路径 | 用途 |
| --- | --- |
| [`ambd_mc.m`](ambd_mc.m) | 统一 MATLAB 入口：初始化、帮助和目标独立工作副本 |
| [`mc-models/pmsm/`](mc-models/pmsm/) | PMSM 模型、算法、参数和主机场景 |
| [`mc-models/bldc/`](mc-models/bldc/) | BLDC 模型、算法、参数和主机场景 |
| [`mc-models/hsp/`](mc-models/hsp/) | 双目标集成、板级适配与活动模型清单 |
| [`docs/`](docs/) | 使用手册、硬件指南、设计规格和项目规则 |
| [`tools/`](tools/) 与 [`tests/`](tests/) | 生成器、验证工具和自动化测试 |

进一步使用可参考[场景示例](docs/manual/examples.md)、
[PMSM 接口类型](docs/McStruct.md)和 [BLDC 接口类型](docs/BldcStruct.md)。
如需在 Windows 下配合 Codex 开发，可按
[MathWorks Agent 环境指南](docs/development/agent-environment.md)
配置可复现环境、官方 MCP 与技能，并了解更新检查和回滚方法。

## 参与贡献

欢迎改进文档、提交可复现的问题报告，或参与电机控制算法与模型开发。
你可以从[现有 Issue](https://github.com/autoMBD/AMBD-MC/issues) 入手，
也可以新建 Issue 说明问题和预期行为。提交前请阅读
[贡献指南](.github/CONTRIBUTING.md)和[行为准则](.github/CODE_OF_CONDUCT.md)。

请在功能分支开发，向 `main` 提交 PR，并说明关联 Issue、改动范围、实际测试结果和
文档同步情况。纯文档贡献按[文档检查流程](docs/development/documentation.md)验证，
无需 MATLAB；模型改动按[模型验证流程](docs/manual/verification.md)验证。

## 许可说明

请阅读 [LICENSE](LICENSE) 和[第三方许可范围](docs/project/license.md)，并遵守以下许可例外。

NOTICE

This project follows the MIT License, except for the following files:

- `mc-models/hsp/config/S32K344/` and `mc-models/hsp/config/S32K144/` retain autoMBD HSP Apache-2.0 licenses and provenance. NXP RTD implementations remain external.

- **All files under the `legacy` directory do not follow the MIT License**
- **All files under the `legacy` directory are owned by the autoMBD author <email: tkung.lqk@foxmail.com>**
- **All files under the `legacy` directory are not allowed to be modified, merged, published, distributed, sublicensed, and/or sold; for learning purposes only**
- **All files under the `legacy` directory are historical development artifacts, kept to maintain project continuity, but will be removed in the future**

特别提示

本项目遵循MIT许可，但以下文件除外：

- `mc-models/hsp/config/S32K344/`、`mc-models/hsp/config/S32K144/` 保留 autoMBD HSP 的 Apache-2.0 许可与来源记录；NXP RTD 驱动实现由外部安装提供。

- **`legacy`目录下所有文件不遵循MIT许可**
- **`legacy`目录下所有文件所有权利归autoMBD作者<邮箱tkung.lqk@foxmail.com>所有**
- **`legacy`目录下所有文件不允许任何修改、合并、发布、分发、分许可和/或销售本软件副本，仅供学习使用**
- **`legacy`目录下所有文件为历史开发遗留，保留的目的是维持项目的延续性，但将会在未来被移除**

