# AMBD-MC / autoMBD Motor Control

Model-based motor control development. The PMSM and BLDC frameworks include
typed initialization, Normal/SIL simulation, and autoMBD HSP 0.1.0 workflows
for NXP S32K344 code generation and processor-in-the-loop (PIL).

- [PMSM setup and validation](mc-models/pmsm/README.md)
- [BLDC Hall/sensorless six-step setup and validation](mc-models/bldc/README.md)
- [S32K344 HSP configuration, build and PIL](docs/hardware/hsp-s32k344.md)
- [Validation workflows and result interpretation](docs/manual/verification.md)

## Agent development environment

Windows + MATLAB/Simulink + Codex: see [MathWorks agent environment](docs/development/agent-environment.md)
for reproducible setup, official MCP/skills, update checks and rollback.

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

