# Agent 环境验收记录（2026-09-11）

关联 [#10](https://github.com/autoMBD/AMBD-MC/issues/10)。实现分支 `codex/10-mathworks-agent-env` 从 main `094313534a69c77e32eedb500beae02fcaefdf59` 创建。

验证环境：Windows 11 x64、PowerShell 7、Python 3.14.6、MATLAB R2026a（26.1.0.3203278）、Codex Desktop/CLI 0.150.1。官方版本及 SHA-256 见 [official.lock.json](../tools/agent/official.lock.json)。

| 检查 | 实际结果 |
|---|---|
| Python 管理器测试 | 35 项通过；包含失败保留、用户配置变动、中断恢复、Windows 进程树回收及启动器真实 stdio 转发 |
| 许可证头、Python/PowerShell/工作流语法 | 本地检查通过 |
| 全新项目 bundle 的 Bootstrap | 离线缓存校验、真实 MCP 验收、项目配置和 skills 注册通过 |
| 重复同步 | 没有重复 MCP 注册或重复 skills |
| Codex 配置发现 | 新启动的正常用户配置服务识别 `ambd_matlab`，保留原有 `node_repl`；项目配置层未被禁用 |
| Codex skills 发现 | 新配置服务实际发现 52 个项目官方 skills，未报告解析错误 |
| Codex 实际启动入口 | 读取生成的配置命令，经过 Python Serve → 官方 MCP → MATLAB 完成真实计算；Windows 标准流转发回归通过 |
| MATLAB MCP | v0.13.0，14 个工具；计算、代码分析及 3 项 MATLAB 单元测试通过 |
| new / existing 会话 | 共享客户端连接到同一测试 MATLAB PID；仓库工作目录核对通过，断开共享客户端后原会话继续使用 |
| Simulink 最小模型 | Constant(2) 经 Triple 子系统（Gain=3）输出 6，实际仿真断言通过 |
| Simulink 模型工具 | overview、read、参数查询及诊断读取通过；诊断工具返回 0 条记录，仿真成功以实际执行及输出断言为依据 |
| Simulink Test | 依照官方 `testing-simulink-models` skill，draft 和完整编译各运行 1 个场景、1 项评估，均通过 |
| 仓库模型结构 | 保存的 BLDC 模型含 9 个根级块、295 个保存块；直接解析 XML 并经官方 model_scan 搜索，原文件 SHA-256 不变 |
| 当前 mc-models / 类型生成器 | SKIP：main 尚无活动 `.slx` 模型和 `tools/generate_data_type_from_md.m`；没有合入其他分支或修改 legacy |
| skills 能力筛选 | 51 项满足所检查的 manifest 条件；AI 部署 skill 因缺少 PyTorch/LiteRT 支持包标为不可用；NXP MBDT 未探测到 |
| 更新检测 | 已锁版本与当日最新官方 release 一致，版本差异为空 |
| 候选切换 / 回滚 | 使用缓存增加 1 个 settings skill，52 → 53；报告正确列出新增 skill，随后验收并回滚到原 52 个 |
| 更新失败保护 | Gherkin 参数校验失败时没有切换活动环境；修正测试调用后，完整验收通过 |

默认 bundle ID 为 `f0fc9ceaf4302854`；分组切换演练的候选 ID 为 `79da5b0b5784b97c`。当日没有更新的上游 release，因此切换演练使用 skill 分组变化，不代表测试过尚未发布的版本。

真实 MCP 运行报告保存在本机忽略目录 `.agent-env/reports/`，包含逐工具结果、工具摘要、能力矩阵和项目检查；最新完整验收记录为 `f0fc9ceaf4302854-4a5a71b59249/smoke.json`。版本锁保存运行版本及工具摘要。缓存、证书、连接信息和机器配置不纳入提交。

安装器兼容性探测曾安装用户级 MATLAB MCP Server Toolbox 和用户级 MCP 可执行文件。实测其共享目录行为后，项目采用官方制品的独立目录方案；后续 Bootstrap/Sync/Rollback 直接使用锁定 bundle 中的可执行文件和 toolbox 路径，实际 `which` 检查也确认了这一点。

本记录验证 Agent 环境，不代表电机算法、代码生成、目标板或 PIL/HIL 已验收。当前已打开的 Codex task 不会热加载新增工具，需要重启或新开 task；项目配置与 skills 的发现已通过独立配置服务验证。
