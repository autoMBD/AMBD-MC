# 项目变更记录

本页按仓库提交日期记录已落地的变化，不为没有发布依据的功能编造版本号。
完整记录见 [Git 历史](https://github.com/autoMBD/AMBD-MC/commits/main/)。

| 日期 | 变化 | 依据 |
| --- | --- | --- |
| 2026-10-07 | 活动模型迁移至 autoMBD HSP S32K344；增加 MCSPTE1AK344 采样与受门控输出；历史截图留在归档目录 | [HSP 迁移](https://github.com/autoMBD/AMBD-MC/commit/c709951)、[板级集成](https://github.com/autoMBD/AMBD-MC/commit/cba0757)、[截图归档](https://github.com/autoMBD/AMBD-MC/commit/6afefcb) |
| 2026-10-07 | 项目自有源文件许可头与模型注释统一 | [提交记录](https://github.com/autoMBD/AMBD-MC/commit/f711723) |
| 2026-10-06 | 完成 BLDC Hall／实测端电压无感框架、独立对象及 SIL 验证流程 | [实现](https://github.com/autoMBD/AMBD-MC/commit/c9139b1) |
| 2026-10-06 | 更新 PMSM 可执行框架、类型初始化与 SIL 验证 | [提交记录](https://github.com/autoMBD/AMBD-MC/commit/ac4ef18) |
| 2026-09-11 | 引入锁定版本的官方 MathWorks Agent 环境、验收与更新流程 | [提交记录](https://github.com/autoMBD/AMBD-MC/commit/5966c19) |
| 2026-03-17 | 建立并整理 Markdown 类型定义及生成工作流 | [提交记录](https://github.com/autoMBD/AMBD-MC/commit/c7dafa4)、[类型整理](https://github.com/autoMBD/AMBD-MC/commit/dede73c) |

## 文档整理

Issue #6 将早期模板替换为当前项目手册，整理导航、设计参考和发布检查。
文档组织和维护规则见[文档维护](../development/documentation.md)。
运行报告与任务记录只保存在本机 `.agent-env/`。文档构建不代表执行过模型或硬件测试。
