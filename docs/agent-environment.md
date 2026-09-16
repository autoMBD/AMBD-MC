# MathWorks Agent 环境

本项目使用 MathWorks 官方 MATLAB MCP Server、MATLAB Agentic Toolkit 和 Simulink Agentic Toolkit。Simulink 工具通过官方 `tools/tools.json` 扩展同一个 MCP Server；项目只提供依赖管理、启动入口和验收客户端。关联 [issue #10](https://github.com/autoMBD/AMBD-MC/issues/10)。

本次实测结果见 [验收记录](agent-environment-validation.md)。

## 快速开始

要求 Windows x64、PowerShell 7、Python 3.11+、Codex，以及已激活的 MATLAB R2023a+ / Simulink。当前实际验证版本为 MATLAB R2026a、Python 3.14.6。MCP 本身支持更早的 MATLAB，但组合环境按 Simulink Toolkit 的最低要求检查。选择的部分 skills 还依赖额外产品；安装 skill 不代表对应产品已安装或有许可。

在仓库根目录执行（MATLAB 路径按本机修改）：

```powershell
pwsh -NoProfile -File tools/agent/agent-env.ps1 Bootstrap -MatlabRoot 'D:/SoftwareSpace/MATLAB/R2026a'
pwsh -NoProfile -File tools/agent/agent-env.ps1 Doctor
```

也可指定 `MATLAB_ROOT` 环境变量，或让脚本从 PATH / Program Files 中发现 MATLAB。后续 Sync 未指定 MATLAB 路径或会话模式时，沿用上次激活的设置。`-Python` 选择 Python 可执行文件。所有路径以参数数组传递，支持空格；机器路径仅存于忽略的本地文件。基础设施也可直接通过 `python tools/agent/agent_env.py <Action> --help` 使用。

Bootstrap 会下载并验证锁定文件，创建候选环境，通过真实 MCP 执行计算、静态检查、单元测试和临时模型仿真，然后注册 `.codex/config.toml` 的 `ambd_matlab` 与 `.agents/skills/ambd-mathworks`。**重启 Codex task 后才能加载新 MCP 和 skills**。项目必须受 Codex 信任，否则项目 MCP 配置可能不会生效。

当前默认选取 52 个官方 skills，覆盖 MATLAB 编程、测试、控制系统、代码生成，以及 Simulink 建模、仿真、验证和代码生成。完整选择位于锁文件 `skill_groups`，每个 skill 连同 `manifest.yaml`、引用及资源一起同步。Smoke 根据 manifest、MATLAB 版本、已安装产品、工具和其他 skill 依赖生成 `skill_eligibility`；Doctor 展示最近一次报告，Agent 指南要求筛选 `ELIGIBLE` 技能使用，跳过 `UNAVAILABLE` / `UNKNOWN` 项。注册目录保留选定分组的完整内容，避免每台机器的产品差异改写官方包。`ELIGIBLE` 也不代表本次运行一定能签出许可证。

Codex 会递归发现项目 skill 目录中的 `SKILL.md`；可在新 task 中检查 skill 列表，再调用 `detect_matlab_toolboxes` 或 `model_overview` 验证加载。

## 版本来源与安装方式

| 组件 | 当前锁定版本 | 官方来源 |
|---|---|---|
| MATLAB MCP Server + MATLABMCPServerToolbox | v0.13.0 | [matlab/matlab-mcp-server](https://github.com/matlab/matlab-mcp-server) |
| MATLAB Agentic Toolkit | MATK-2026.09.a | [matlab/matlab-agentic-toolkit](https://github.com/matlab/matlab-agentic-toolkit) |
| Simulink Agentic Toolkit + installer | SATK-2026.09.b | [matlab/simulink-agentic-toolkit](https://github.com/matlab/simulink-agentic-toolkit) |

`tools/agent/official.lock.json` 记录官方仓库、release tag、不可变 commit、下载 URL、SHA-256、文件长度、skill 分组、工具/skill 内容摘要和实测版本。Release 二进制使用 GitHub 发布资产摘要；按 commit 下载的源码 ZIP 在解析新版本时计算摘要。首次接受更新仍需审阅官方来源和变更，摘要用于后续复现与完整性验证。没有默认跟随 `main` 的依赖。

优先评估了官方 `setupAgenticToolkit` 安装入口及 Offline / InstallRoot / Scope 参数。实测当前 installer 即使指定项目范围和 InstallRoot，MCP 可执行文件与 MATLAB addon 仍涉及用户级安装位置，不能提供本项目需要的独立切换和回滚。因此自动流程采用官方文档支持的手动配置方式：从校验后的发布包解压到项目版本目录，使用官方可执行文件、toolbox 的 `fsroot` 和 `satk_initialize(MCPServerPath=...)`。不修改或重写任何官方实现，也不调用全局 `savepath`。

官方 installer 随 bundle 缓存，便于需要用户级安装时使用。官方直接管理的环境可用 `setupAgenticToolkit("update")` 更新，再执行 `satk_initialize` 并重启 agent；**不要用这一命令更新本项目管理的锁定环境**。具体参数以所锁版本 [官方配置文档](https://github.com/matlab/simulink-agentic-toolkit/blob/main/Configuration_and_Troubleshooting.md) 为准。

## 更新、同步和回滚

```powershell
# 查询最新版并生成 update-report.json 与 candidate.lock.json，不激活候选、不启动 MATLAB
pwsh -NoProfile -File tools/agent/agent-env.ps1 CheckUpdates

# 按当前锁文件重新安装/同步；依赖版本保持锁定，每次切换前真实验收
pwsh -NoProfile -File tools/agent/agent-env.ps1 Sync -MatlabRoot 'D:/SoftwareSpace/MATLAB/R2026a'

# 明确升级到本次查询到的最新 release，验收后切换并更新仓库锁文件
pwsh -NoProfile -File tools/agent/agent-env.ps1 Sync -Latest -MatlabRoot 'D:/SoftwareSpace/MATLAB/R2026a'

# 或固定使用已审阅的候选文件，避免再次查询时上游又发布了版本
pwsh -NoProfile -File tools/agent/agent-env.ps1 Sync -LockFile .agent-env/candidate.lock.json -MatlabRoot 'D:/SoftwareSpace/MATLAB/R2026a'

# 重新验收并切回上一个可用环境，之后重启 Codex task
pwsh -NoProfile -File tools/agent/agent-env.ps1 Rollback
```

报告比较 release 版本，以及所选 skills 的新增/删除/内容变化和 Simulink 工具定义变化。MCP 二进制版本变化时，静态检查明确标记内置工具 schema 尚待验证，Sync 中的真实 `tools/list` 会记录全部工具摘要，并在 `.agent-env/runtime-update-report.json` 比较完整工具清单及实际 skill 变化；缺少旧实测基线会明确标记。CI 不执行下载的工具。官方删除已选分组、文件名变化或校验失败时会停止并保留当前环境，需审查锁文件/适配代码后重试。

每个 bundle 保留其锁文件和完整文件清单。候选验证失败不会修改活动配置。成功后保留前一个环境；Rollback 恢复活动指针和 skills，并保留后来新增的其他 MCP 设置。Rollback 不修改 Git 中的锁文件：要让团队一起回退，提交相应旧版本的锁文件。修改 skill 分组也会产生独立环境版本，可以使用相同流程验证和回滚。`Sync -Latest` 完成后应审查并提交锁文件 diff。

`CheckUpdates` 有更新时下载官方资产到缓存用于静态比较，**不改变活动环境**；没有更新时只查询 release API。可以用 `-Output` 指定报告位置。GitHub Actions 在每周一 UTC 03:00（北京时间 11:00）、手动触发及环境工具相关 PR 上检查；发现变化或手动运行时上传报告与候选锁文件 artifact，没有变化的定期检查不生成重复 artifact。权限为 `contents: read`，不会安装 MATLAB、申请许可证或自动更新开发机。可从仓库 Actions 的 **MathWorks upstream releases** 工作流下载结果。

## 离线与会话

首次在线安装或 CheckUpdates 后，将 `.agent-env/cache` 和对应锁文件传到离线机器，然后运行：

```powershell
pwsh -NoProfile -File tools/agent/agent-env.ps1 Bootstrap -Offline -Cache 'D:/agent-cache' -MatlabRoot 'D:/MATLAB/R2026a'
```

缓存按 SHA-256 命名，离线安装仍校验长度与哈希；缺失或损坏会明确报错，不下载替代版本。损坏缓存不会被静默覆盖，可移走报告中对应文件后在线重试。下载失败不会留下被当作成功资产的文件。官方源码、二进制、报告和运行输出都留在 `.agent-env/`，不提交到 Git。

默认 `-Session new` 使用独立、无桌面的 MATLAB，会运行 bundle 的 `startup/startup.m`，注册官方工具并将模型缓存/代码输出设置到 `.agent-env/`。不会修改个人 startup 文件。`Smoke` 始终使用独立会话，服务退出后由官方 MCP 回收该会话。

需要连接已打开的 MATLAB 时，可 Sync 时传 `-Session existing`，随后在目标 MATLAB 手动 `run('<Doctor 显示的 active.bundle>/startup/startup.m')`，再重启 Codex。该脚本调用官方 `shareMATLABSession`；不会替你退出现有会话。官方 existing 模式与 `matlab-root`、`initial-working-folder`、`matlab-display-mode` 互斥，入口会自动省略这三个参数；连接的是最近执行共享命令的会话。`auto` 由官方 MCP 自行选择现有或新会话，现有会话仍需先初始化正确的 bundle。多项目并用时建议 `new`，避免连接到加载了其他版本 toolkit 的现有会话。

## 验收与诊断

```powershell
pwsh -NoProfile -File tools/agent/agent-env.ps1 Doctor
pwsh -NoProfile -File tools/agent/agent-env.ps1 Smoke
python -m unittest discover -s tests/agent -v
python tools/test_check_spdx.py
```

Doctor 只检查 Python、MATLAB 路径、WINDIR、锁文件、bundle 完整性、配置和 skills 归属。Smoke 通过真正的 MCP 协议验证：

1. MCP 初始化、完整工具清单，以及计算/模型检查所需工具存在。额外连接同一测试 MATLAB 的 existing 会话，核对 PID 与仓库工作目录，再断开共享客户端并确认原会话可继续使用。
2. MATLAB 运算，官方工具路径属于锁定 bundle，静态分析及 3 项 MATLAB 单元测试。
3. 创建临时 Constant(2) → Triple 子系统（Gain=3）→ Output 模型，实际仿真结果为 6；通过官方工具读取模型结构、求解器参数和仿真诊断。有 Simulink Test 时，按照官方 `testing-simulink-models` skill 执行 Gherkin 行为测试，分别验证 draft 和完整编译模式。
4. 使用官方 `model_scan` 搜索仓库保存模型中的 PWM 项，并直接解析保存 XML 中的根级结构与块数，确认检查没有写回模型或执行回调。
5. 记录 MATLAB/toolbox 版本与 Simulink、Stateflow、Simscape、Simulink Test、Simulink Coder、Embedded Coder 的安装/许可矩阵；NXP MBDT 单独探测。额外许可证不决定基础仿真是否可用，未执行的代码生成等能力只报告安装/许可检测，不声称运行验证。

报告在 `.agent-env/reports/<环境 ID>-<运行 ID>/smoke.json`。退出码 0 表示该命令成功，1 表示错误（参数错误由 argparse 返回 2）。失败保留报告和候选文件以便诊断。运行时间取决于 MATLAB 冷启动，可用 `-Timeout` 调整单次 MCP 请求上限。

从 main 建立此分支时，`mc-models/` 没有 `.slx` 模型，`tools/generate_data_type_from_md.m` 也尚未合入。这两项报告为 **SKIP**；历史模型只做保存文件搜索。基础环境 PASS 不意味着电机控制模型、NXP 编译或产品行为已经验证。合入相应项目文件后，可在独立输出目录运行类型生成验收，并单独报告项目数据问题。

| 现象 | 处理 |
|---|---|
| 无法找到 MATLAB | 提供安装根目录，不含 `bin`；检查 Python 和 PowerShell 版本 |
| MATLAB 最小命令出现 `File system inconsistency` | 在正常终端执行同一最小命令，区分执行沙箱与 MATLAB 安装问题；本机普通执行已通过，受限执行失败，不应据此重装 MATLAB |
| MCP 初始化失败 | 查看 `.agent-env/logs/`，确认 MATLAB root、日志目录可写；保留 WINDIR / SystemRoot / TEMP / TMP |
| 工具存在但报 Undefined function | 执行对应 bundle 的 startup，检查 `which('satk_initialize')` 与 `which('shareMATLABSession')` 是否指向同一环境 |
| Simulink / 可选 toolbox 报许可错误 | 根据报告核对已安装产品和可用许可证；NXP MBDT 不由此脚本安装，`which` 探测不到也可能需要按 NXP 文档初始化 |
| skills 链接创建失败 | 脚本自动复制完整官方 skills，不要求开启 Windows Developer Mode；更新前检查本地改动，防止覆盖 |
| 同名配置或 skills 已存在 | 脚本拒绝覆盖用户文件；将自定义内容保存在独立名称，再重试 |

官方服务的日志目录还可能包含临时会话连接文件及证书；不要整体上传 `.agent-env/logs/`。分享诊断时只提取需要的错误文本，并检查模型路径等内容。项目不会将日志、凭据或 license 文件提交到 Git。

## 恢复、清理与自定义

`.agent-env/operation.lock` 记录进行中切换的 PID。进程异常退出时先确认该 PID 已结束，再移走陈旧锁。若存在 `activation-journal.json`，运行 `Recover` 恢复切换前配置；若中断后有人编辑了相关配置或 skills，恢复会停止，先保存这些改动再处理。旧 skill 注册通过重命名保存在 `.agent-env/registrations/`，切换期间不递归删除活动目录，恢复时也保留替换下来的内容。恢复后运行 Doctor / Smoke；确认不再需要恢复记录后可随项目缓存统一清理这些备份。

配置仅管理带 `BEGIN/END AMBD-MC MANAGED MCP` 标记的块，其他配置保持原样。自定义项目规则写入根目录 `AGENTS.md`；自定义 skills 放在 `.agents/skills/` 的其他目录，避免直接改写托管目录。托管目录内容发生变化时停止切换并提示保存，不能用同步覆盖本地修改。

停用环境时，先关闭连接本项目的 Codex task，再删除 `.codex/config.toml` 中上述托管块，以及 `.agents/skills/ambd-mathworks` 注册入口，最后删除本项目 `.agent-env/`。先用 `Get-Item` 判断 skill 入口是否为链接：链接只删除入口，不递归删除其目标；复制目录才递归移除。每次删除前核对完整路径属于本项目。保留个人配置、其他 MCP 和其他 skills。自动流程不修改全局 MATLAB path 或用户级 Codex 配置，无需全局卸载。

## 官方资料

- [MathWorks Agentic AI](https://www.mathworks.com/products/matlab/agentic-ai.html)
- [MATLAB MCP Server 安装、参数及故障处理](https://github.com/matlab/matlab-mcp-server)
- [Simulink Toolkit 手动配置与 MATLAB 初始化](https://github.com/matlab/simulink-agentic-toolkit#manual-setup)
- [Codex MCP 配置](https://developers.openai.com/codex/mcp) / [Codex skills 发现规则](https://developers.openai.com/codex/skills)
