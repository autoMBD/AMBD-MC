# AMBD-MC 电机控制

AMBD-MC（autoMBD Motor Control）使用 MATLAB/Simulink 开发电机控制框架，包含
PMSM 矢量控制（FOC）和 BLDC Hall／无感六步控制。项目提供类型化接口、
独立主机电机对象、Normal/SIL 验证及基于 autoMBD HSP 0.1.0 的 S32K344 集成。

## 从这里开始

首次接触项目可先阅读
[仓库 README](https://github.com/autoMBD/AMBD-MC/blob/main/README.md)，了解项目内容、
目录与参与方式。只阅读或改进文档不需要 MATLAB；运行模型前先按
[环境与工作流](manual/index.md)准备依赖，再选择下面的路径。

1. [准备环境并运行第一个场景](manual/getting-started.md)。
2. 选择 [PMSM 手册](manual/pmsm.md) 或 [BLDC 手册](manual/bldc.md)。
3. 了解 [框架与数据流](specs/architecture.md)，按 [场景示例](manual/examples.md) 查看结果。
4. 需要目标代码或处理器验证时，阅读 [S32K344 HSP 指南](hardware/hsp-s32k344.md) 和
   [MCSPTE1AK344 板级集成](hardware/mcspte1ak344.md)。

## 当前能力与边界

| 工作流 | 内容 | 阅读入口 |
| --- | --- | --- |
| 主机控制仿真 | PMSM 有感／无感、BLDC Hall／无感；独立电机对象 | [使用手册](manual/index.md) |
| 软件验证 | 单元测试、Normal/SIL 闭环、同输入重放、原生对象参考比较 | [验证方法](manual/verification.md) |
| S32K344 集成 | HSP 目标构建、PIL、板级 ADC/PWM 与门控适配 | [目标指南](hardware/hsp-s32k344.md) |
| 类型与接口 | Markdown 类型源、生成脚本、独立数据字典 | [PMSM 类型](McStruct.md)、[BLDC 类型](BldcStruct.md) |

主机仿真、SIL、PIL 和控制板诊断各有适用范围，不能互相替代。
真实采样标定、栅极波形、带载闭环和正常运行最坏执行时间需要单独的硬件验证，
详见[板级验证边界](hardware/mcspte1ak344.md#验证边界)。

## 项目资料

欢迎从文档改进、问题复现或算法与模型贡献开始。浏览
[GitHub Issues](https://github.com/autoMBD/AMBD-MC/issues) 选择问题，按
[贡献指南](project/contributing.md)提交改动，并说明实际验证结果。

- [常见问题](manual/faq.md)与[实际变更记录](project/changelog.md)
- [开发贡献](project/contributing.md)与[文档维护](development/documentation.md)
- [许可与第三方范围](project/license.md)
- [GitHub 仓库](https://github.com/autoMBD/AMBD-MC)
