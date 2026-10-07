# AMBD-MC 电机控制

AMBD-MC（autoMBD Motor Control）使用 MATLAB/Simulink 开发电机控制框架，包含
PMSM 矢量控制（FOC）和 BLDC Hall／无感六步控制。项目提供类型化接口、
独立主机电机对象、Normal/SIL 验证及基于 autoMBD HSP 0.1.0 的 S32K344 集成。

## 从这里开始

1. [准备环境并运行第一个场景](getting-started.md)。
2. 选择 [PMSM 手册](manual/pmsm.md) 或 [BLDC 手册](manual/bldc.md)。
3. 了解 [框架与数据流](architecture.md)，按 [场景示例](examples/example.md) 查看结果。
4. 需要目标代码或处理器验证时，阅读 [S32K344 HSP 指南](hsp-s32k344.md) 和
   [MCSPTE1AK344 板级集成](mcspte1ak344.md)。

## 当前能力与边界

| 工作流 | 内容 | 阅读入口 |
| --- | --- | --- |
| 主机控制仿真 | PMSM 有感／无感、BLDC Hall／无感；独立电机对象 | [使用手册](manual/index.md) |
| 软件验证 | 单元测试、Normal/SIL 闭环、同输入重放、原生对象参考比较 | [验证记录](validation/index.md) |
| S32K344 集成 | HSP 目标构建、PIL、板级 ADC/PWM 与门控适配 | [目标指南](hsp-s32k344.md) |
| 类型与接口 | Markdown 类型源、生成脚本、独立数据字典 | [PMSM 类型](McStruct.md)、[BLDC 类型](BldcStruct.md) |

已归档结果只适用于报告所列基线。2026-10-07 的验证包括实际 S32K344 PIL 和
控制板诊断；当次未连接 GD3000 驱动板及电机，带载闭环、真实栅极波形和正常运行
最坏执行时间等仍为未验证。详见[报告及限制](validation/2026-10-07-hsp-s32k344.md)。

## 项目资料

- [常见问题](faq.md)与[实际变更记录](changelog.md)
- [开发贡献](doc-contributing.md)与[文档维护](documentation.md)
- [许可与第三方范围](doc-lic.md)
- [GitHub 仓库](https://github.com/autoMBD/AMBD-MC)
