# 常见问题

## 只安装 Python 就能运行模型吗？

不能。电机模型需要 MATLAB/Simulink 及对应产品，活动目标模型还使用 autoMBD
HSP 0.1.0。Python 用于环境管理和验证编排。各工作流前提见
[环境要求](manual/index.md)。

## 运行 Normal/SIL 是否需要连接电机？

主机闭环使用独立电机对象，不连接功率板。SIL 在主机执行生成 C。
实际 PIL 需要 S32K344、探针和 UART；功率板实验另有前提，
见 [HSP 指南](hsp-s32k344.md)。

## 字典类型不一致时怎么办？

确认从仓库根目录调用正确的 `pmsm_setup` 或 `bldc_setup`，
以及 MATLAB 路径没有指向旧副本。普通启动保留标定并报告类型差异。
明确需要同步当前类型和默认参数时才使用 `SyncDictionary=true`；
先处理未保存的字典修改。详见 [PMSM](manual/pmsm.md) 或
[BLDC](manual/bldc.md) 手册。

## 为什么打开无感模型后仍是另一种模式？

模型文件名不自动切换参数。BLDC 的 `PositionMode=0/1` 表示 Hall／无感，
PMSM 则表示无感／有感。使用[场景入口](examples/example.md)显式选择配置。

## 一个场景通过就算验收完成吗？

不算。局部运行标记 `CompleteMatrix=false`。
完整验收要求完整场景、独立闭环、同输入重放和相关门槛都通过；
缺少输入或未执行的项目不能记为 PASS。

## 旧报告里的 JSON 和图片在哪里？

报告保留当次结果及本地工件路径。原始日志、MAT 和图片在生成者的
`.agent-env/`，不提供失效下载链接。重新运行对应脚本可生成新的证据，
但新运行不能替代原报告的历史指纹。见[验证记录说明](validation/index.md)。

## MCP 安装成功但运行失败怎么办？

先运行 Agent 环境的 Doctor 检查配置，再按需运行 Smoke 验证真实执行。
区分传输、工具箱/许可和模型错误，见 [环境诊断](agent-environment.md)。
只编辑或构建本站文档不需要 MATLAB。

## 如何报告问题或贡献？

在 [GitHub Issues](https://github.com/autoMBD/AMBD-MC/issues) 提供模型/场景、
版本、命令、错误及脱敏摘要；贡献流程见[贡献指南](doc-contributing.md)。
许可范围见[许可说明](doc-lic.md)。
