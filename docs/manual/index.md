# 使用手册与环境要求

本手册以当前仓库的活动模型、初始化入口和已记录验证为依据。
首次使用从[快速开始](../getting-started.md)进入，随后按电机类型阅读
[PMSM](pmsm.md) 或 [BLDC](bldc.md)。

## 选择工作流

| 工作流 | 前提与范围 |
| --- | --- |
| 文档浏览／构建 | 浏览器；本地构建使用 Python 和锁定的文档依赖，不需要 MATLAB |
| 主机 Normal | MATLAB/Simulink、已启用的 autoMBD HSP 0.1.0；不需要连接目标板 |
| 主机 SIL | 上述环境及 MATLAB Coder、Simulink Coder、Embedded Coder 和可用的主机 C 编译器 |
| 独立对象参考 | BLDC 使用 Simscape/Simscape Electrical；PMSM 使用提供 `autolibpmsminterior/Interior PMSM` 的产品安装，执行前确认该参考块可用 |
| Python 验证编排 | 配置项目锁定的[官方 MCP 环境](../agent-environment.md)，逐项检查所需产品及许可证 |
| S32K344 目标构建 | HSP 0.1.0、RTD 7.0.1、EB tresos 30、NXP GCC 10.2、FreeRTOS 11.1.0 |
| 实际 PIL | 目标构建环境、S32K344 控制板、PEmicro 探针及确认的 UART 配置 |
| 带电机实验 | 额外需要正确连接及标定的驱动板、电机、采样和保护；按[板级说明](../mcspte1ak344.md)逐项验证 |

报告中的参考环境为 Windows、MATLAB/Simulink R2026a。
Agent 环境的最低版本要求不等于电机模型已在该最低版本验收。
产品安装和技能可用性也不等于本次许可证可成功签出。

autoMBD HSP 由外部安装提供。活动模型的 `hsp_setup` 会核对已启用的
0.1.0 版本；缺少它时先完成 HSP 安装与初始化，不应绕过检查打开目标模型。
芯片工具、本机路径、串口与探针设置见 [HSP 指南](../hsp-s32k344.md)。

## 学习与使用路径

1. [基础教程](../tutorials/tutorial-quick.md)：初始化、场景执行、读取 MAT 验收。
2. [场景示例](../examples/example.md)：有感、Hall、无感和 SIL 调用。
3. [框架架构](../architecture.md)：算法、对象和硬件边界。
4. [PMSM 类型](../McStruct.md)、[BLDC 类型](../BldcStruct.md)：接口与生成源。
5. [完整验证流程](../tutorials/tutorial-advanced.md)：参考对象、场景矩阵和重放。
6. [HSP 构建/PIL](../hsp-s32k344.md)、[板级集成](../mcspte1ak344.md)：目标工作副本与实机边界。

## 参数与数据的维护

控制器与对象参数分别维护。普通初始化保留字典标定；显式同步会重建本框架
拥有的类型与默认参数。修改类型源前先阅读对应电机手册，避免将排版调整变成
工程输入变更。两类电机的 `PositionMode` 编码不同，不能互相套用。

完整运行证据见[验证索引](../validation/index.md)；资料来源和手册整理范围见
[文档维护清单](../documentation.md)。
