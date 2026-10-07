# AMBD-MC / autoMBD Motor Control

**Learn and develop motor control with MATLAB/Simulink, from host simulation to
NXP S32K344 integration.** AMBD-MC is autoMBD's Model-Based Design (MBD) project
for developers exploring motor-control algorithms, typed interfaces and embedded
code generation.

[Documentation / 中文文档](https://autombd.github.io/AMBD-MC/) ·
[Getting started / 快速开始](docs/manual/getting-started.md) ·
[Contributing / 参与贡献](.github/CONTRIBUTING.md) ·
[Issues](https://github.com/autoMBD/AMBD-MC/issues)

## What you can explore

| Area | Included in the project | Guide |
| --- | --- | --- |
| PMSM | Permanent-magnet synchronous motor field-oriented control (FOC), with sensored and sensorless scenarios | [PMSM manual](docs/manual/pmsm.md) |
| BLDC | Brushless DC motor Hall and sensorless six-step control | [BLDC manual](docs/manual/bldc.md) |
| Host verification | Independent motor plant models, Normal simulation, software-in-the-loop (SIL) and input replay | [Verification workflows](docs/manual/verification.md) |
| Embedded integration | autoMBD HSP 0.1.0 workflows for S32K344 code generation and processor-in-the-loop (PIL) | [HSP guide](docs/hardware/hsp-s32k344.md) |

Control algorithms, motor plants and hardware adapters have separate roles;
see the [architecture guide](docs/specs/architecture.md). Host simulation, SIL
and PIL provide different evidence. Real motor operation still requires
[board-level validation](docs/hardware/mcspte1ak344.md#验证边界).

## Before you start

The reference model environment is **Windows + MATLAB/Simulink R2026a**.
Choose the requirements for your workflow:

| Goal | Requirements |
| --- | --- |
| Read or contribute documentation | A browser; local site builds use Python 3.11+ and the [pinned documentation environment](docs/development/documentation.md) |
| Run a first host Normal scenario | MATLAB/Simulink and an installed, enabled **autoMBD HSP 0.1.0**; no target board is needed |
| Run SIL | The host environment plus MATLAB Coder, Simulink Coder, Embedded Coder and a supported host C compiler |
| Build for S32K344 or run PIL | The [target toolchain and local settings](docs/hardware/hsp-s32k344.md); actual PIL also needs the board, PEmicro probe and UART connection |

See [environment requirements](docs/manual/index.md) for the full workflow
matrix, including additional products for independent plant references.
HSP is provided by an external installation and is checked during initialization.
Prepare it before running `setup`; cloning this repository does not install it.

## Run your first host scenario

Clone the repository in a terminal:

```powershell
git clone https://github.com/autoMBD/AMBD-MC.git
cd AMBD-MC
```

In MATLAB, set the current folder to the cloned repository root. With the host
requirements above ready, run the PMSM sensored baseline:

```matlab
info = ambd_mc("setup","pmsm");
result = mc_run_host_case('FOC_PIL_Algth_top','sensored_steps','Normal');
```

Alternatively, start with the BLDC Hall baseline:

```matlab
info = ambd_mc("setup","bldc");
result = bldc_run_host_case("hall_steps","Normal");
```

After either scenario, check the outcome and locate the saved trace:

```matlab
assert(result.Passed, 'Scenario did not pass acceptance checks');
disp(result.TraceFile);
```

Success means `result.Passed` is true. The trace MAT file is saved under the
local, ignored `.agent-env/` directory. Keep `info` alive while using models:
it owns the data dictionary connections. Normal setup preserves saved
calibrations; a first run does not require rebuilding models or resetting defaults.

The [quick-start guide](docs/manual/getting-started.md) explains trace contents
and setup options. Use `ambd_mc("help")` for command help, or the
[FAQ](docs/manual/faq.md) to diagnose environment and dictionary errors.
For target builds, follow the [isolated staging workflow](docs/hardware/hsp-s32k344.md)
after host verification.

## Find your way around

| Path | Purpose |
| --- | --- |
| [`ambd_mc.m`](ambd_mc.m) | Public MATLAB entrypoint for setup, help and isolated target staging |
| [`mc-models/pmsm/`](mc-models/pmsm/) | PMSM models, algorithms, parameters and host scenarios |
| [`mc-models/bldc/`](mc-models/bldc/) | BLDC models, algorithms, parameters and host scenarios |
| [`mc-models/hsp/`](mc-models/hsp/) | Shared S32K344 integration and the active model manifest |
| [`docs/`](docs/) | User manuals, hardware guides, specifications and project policies |
| [`tools/`](tools/) and [`tests/`](tests/) | Generators, verification tools and automated tests |

Continue with [scenario examples](docs/manual/examples.md),
[PMSM interface types](docs/McStruct.md) or [BLDC interface types](docs/BldcStruct.md).
For optional Windows + Codex integration, the
[MathWorks agent environment guide](docs/development/agent-environment.md)
covers reproducible setup, official MCP/skills, update checks and rollback.

## Contribute

Documentation improvements, reproducible bug reports and motor-control
contributions are welcome. Start with an
[existing issue](https://github.com/autoMBD/AMBD-MC/issues) or open one describing
the problem and expected behavior, then follow the
[contribution guide](.github/CONTRIBUTING.md) and [code of conduct](.github/CODE_OF_CONDUCT.md).

Develop on a feature branch and submit a PR to `main` with the related issue,
scope, actual test results and documentation updates. For documentation-only
contributions, use the [documentation checks](docs/development/documentation.md);
MATLAB is not required. Model changes use the
[model verification workflows](docs/manual/verification.md).

## License / 许可

See [LICENSE](LICENSE) and the [third-party scope](docs/project/license.md).
The existing exceptions below apply.

NOTICE

This project follows the MIT License, except for the following files:

- `mc-models/hsp/config/S32K344/` retain autoMBD HSP Apache-2.0 licenses and provenance. NXP RTD implementations remain external.

- **All files under the `legacy` directory do not follow the MIT License**
- **All files under the `legacy` directory are owned by the autoMBD author <email: tkung.lqk@foxmail.com>**
- **All files under the `legacy` directory are not allowed to be modified, merged, published, distributed, sublicensed, and/or sold; for learning purposes only**
- **All files under the `legacy` directory are historical development artifacts, kept to maintain project continuity, but will be removed in the future**

特别提示

本项目遵循MIT许可，但以下文件除外：

- `mc-models/hsp/config/S32K344/` 保留 autoMBD HSP 的 Apache-2.0 许可与来源记录；NXP RTD 驱动实现由外部安装提供。

- **`legacy`目录下所有文件不遵循MIT许可**
- **`legacy`目录下所有文件所有权利归autoMBD作者<邮箱tkung.lqk@foxmail.com>所有**
- **`legacy`目录下所有文件不允许任何修改、合并、发布、分发、分许可和/或销售本软件副本，仅供学习使用**
- **`legacy`目录下所有文件为历史开发遗留，保留的目的是维持项目的延续性，但将会在未来被移除**

