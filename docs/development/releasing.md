# Release 打包与发布

发布应让用户能够下载、校验、解压并按文档使用，同时让维护者能追溯到固定提交。
发布包的内容由 `tools/release/manifest.json` 逐文件批准，版本、依赖矩阵由
`tools/release/release.json` 管理，用户可见的变更由 `tools/release/notes.md` 维护。
这些文件需要随实现一起审阅；新增文件不会自动进入发布包。

## 交付物与许可边界

| 交付物 | 内容 |
| --- | --- |
| `AMBD-MC-<version>.zip` | `ambd_mc.m`、`private/`、活动模型与字典、参数与场景、两种 HSP 目标配置、自有板级源码、工具、测试源码及公开 Markdown 文档 |
| `RELEASE_NOTES.md` | 变化、迁移方法、依赖、已知限制、对应源提交和固定版本下载链接；包内也有一份 |
| `release-metadata.json` | 版本、拟发布 tag、源提交及其 UTC 日期、依赖和包内交付文件的 SHA256；元数据自身不递归列入清单 |
| `SHA256SUMS` | 上述三个附件的 SHA256，用于核对下载内容完整性 |
| 包内 `THIRD_PARTY_NOTICES.md` | 每个组件的来源、许可证、修改状态及许可/来源记录路径 |

ZIP 保留原相对目录，包含 `docs/McStruct.md`、`docs/BldcStruct.md` 和类型生成工具。
GitHub 源码浏览链接在包内 Markdown 中固定到源提交；在线手册仍可能展示最新版本，
使用旧版本应优先阅读随包文档。普通初始化与主机场景不需要 Git；发布、Agent 环境等
维护者流程仍需对应 tag 的 Git 检出。包内脚本包含维护工具不表示已安装它们依赖的产品。

项目自有文件保留 MIT 许可；S32K144/S32K344 配置分别保留 Apache-2.0
许可和来源/修改记录。详见[许可范围](../project/license.md)。
禁止分发 `legacy/`、厂商 RTD/SDK 实现、工具安装包、生成固件/代码、缓存、
内部记录及本机敏感配置。打包工具也会拒绝受限目录下 Git blob 的原样改名副本，
但这不能代替对修改过的衍生内容和新组件的人工许可审阅。

MATLAB/Simulink、HSP、工具箱、编译器及目标工具链由用户自行安装，
版本与适用工作流见[环境要求](../manual/index.md)。原始运行证据、审核记录只保存在本机
`.agent-env/`，不上传公开 Actions artifact 或 Release。

## 版本与内容维护

采用 `vMAJOR.MINOR.PATCH` tag，配置文件的版本不带 `v`。修复递增 PATCH，
兼容功能递增 MINOR；1.0 后不兼容接口变化递增 MAJOR。0.x 阶段不兼容变化递增
MINOR，并明确迁移步骤。候选版本使用如 `0.2.0-rc.1` 并标记 Pre-release。
仓库中的候选版本配置不等于已公开发布，以 [GitHub Releases](https://github.com/autoMBD/AMBD-MC/releases) 为准。

新增/删除公开文件时同步清单中的精确路径及所属组件；新组件必须补齐许可原文、来源、
版本及修改说明，不得将第三方文件简单登记为项目 MIT。必要的上游 NOTICE 也列入组件材料。
未知许可证会阻止构建；扩展支持前需要审阅其分发条件和检查实现。

清单更新后，在仓库根目录生成 `.gitattributes`（PowerShell 7，UTF-8 无 BOM）：

```powershell
python tools/release/package.py --attributes-from tools/release/manifest.json |
  Set-Content -Encoding utf8NoBOM .gitattributes
```

此文件默认排除所有路径，只允许清单中的文件和父目录导出。它约束**新提交/新 tag**
的 GitHub Source code ZIP/TAR.GZ；不会修改历史 tag 的归档。历史 v0.1.0 的内容与
许可处理需单独决策，不改写历史、不将其默认源码归档宣传为本流程审核过的发布包。
仅靠 README 提醒用户不要下载源码归档不能代替排除规则。

## 本地生成与检查

需要 Python 3.11+ 和 Git 2.30+；无须 MATLAB、GitHub 凭据、联网或安装额外 Python 包。
提交清单、许可、文档及发布说明后，从固定提交或 tag 构建：

```powershell
python tools/release/package.py --version 0.2.0-rc.1 --ref HEAD --check
python tools/release/package.py --version 0.2.0-rc.1 --ref HEAD --output .agent-env/releases/candidate
python tools/release/package.py --ref HEAD --verify .agent-env/releases/candidate
```

版本参数可省略，默认读取所选提交的配置；传入时必须一致。`--ref` 在开始时解析为
固定 commit，文件来自 Git blobs，未提交/未跟踪的本地改动不会混入，也不会被覆盖。
从普通 commit 构建时元数据 tag 是计划使用的名字；只有发布命令会强制核对已有远端 tag。
工具按当前版本执行，使用不同历史版本时先检出相应 tag，避免检查规则与历史文件不匹配。

`--check` 不创建发布包、不改动工作区源码；许可校验会短暂使用并清理本机忽略目录。
输出目录必须尚不存在。失败输出保留以便本地诊断，不覆盖、不上传；修复后选择新的空目录。
ZIP 采用固定排序、时间戳、权限和无压缩存储，避免操作系统及压缩库版本差异；
相同提交和工具版本会得到相同内容。SLX/SLDD 本身已压缩，首期优先保证可复现性。

预检覆盖：清单完整性、许可材料、保存的模型许可注释、活动模型清单、Markdown 相对链接、
受限 blob 副本、路径越界、链接、大小写冲突及嵌套归档。它不执行模型回调，也不证明所有
运行依赖已可用；必须执行解压使用测试。最终 ZIP 会重新读取核对，下载资产则与源提交
重新生成的预期内容逐字节比较。

## 发布步骤

1. 维护者确定版本、功能范围，更新清单、配置、发布说明和相关用户文档。Release Notes
   说明新增/修复、用户影响、迁移、外部依赖及限制；自动 PR 清单只作为初稿。
2. 在 PR 上完成 Release package、基础 CI 和文档检查。另将候选 ZIP 解压到原仓库之外，
   用具备许可证的独立 MATLAB 会话运行两种电机的[快速开始](../manual/getting-started.md)。
   SIL、目标构建、PIL 按本版本声明支持的范围验证；缺少依赖或任务输入记为 SKIP，
   未满足的必要能力阻断发布或从发布声明中移除。
3. 固定源提交，创建对应版本 tag 并推送。`Release package` 工作流在 Windows/Linux
   上运行打包测试、许可和文档检查，在 Linux 上传四个公开分发附件。
   tag 推送只创建 **Draft**，自动下载附件和 GitHub 源码 ZIP/TAR.GZ 核对；不会自动公开。
4. 维护者确认运行结果和限制后公开 Draft；候选版标记 Pre-release，正式版使用 main
   中的提交。启用仓库 Immutable releases 后，应在公开之前准备好所有附件。
5. 从公开链接重新下载并校验，按包内快速开始复核；README 提供 Releases 入口，
   Release Notes 自动提供固定版本资产链接。

工作流合入默认分支后，也可从 Actions 手动运行，输入已有 tag、`draft`/`prerelease`/`release`
及运行审阅确认。后两种模式必须勾选确认；正式版本还检查提交属于 `origin/main`。
公开资格是维护者对本机测试的明确确认，CI 不会伪造 MATLAB 验收结果。

如不使用 Actions，可先构建包，再用已认证的 GitHub CLI 发布：

```powershell
python tools/release/publish.py --ref v0.2.0-rc.1 --assets .agent-env/releases/candidate --mode draft
```

公开新发布时可选 `--mode prerelease --runtime-reviewed` 或 `--mode release --runtime-reviewed`；
该命令始终先创建 Draft、验证 GitHub 下载，再公开。它不会创建 tag，也不会覆盖已有 Release。
对工作流已创建并验证过的 Draft，先下载所有附件到新的空目录，执行 `--verify`，并核对源归档：

```powershell
python tools/release/package.py --ref v0.2.0-rc.1 --verify .agent-env/releases/downloaded
python tools/release/package.py --ref v0.2.0-rc.1 --verify-source .agent-env/releases/source.zip
python tools/release/package.py --ref v0.2.0-rc.1 --verify-source .agent-env/releases/source.tar.gz
```

随后在 GitHub UI 检查预发布/正式发布标记并公开。公开后不替换附件、不移动 tag；
修复产生新版本。SHA256 只验证完整性；签名、构建证明、离线 HTML/PDF 可按需要后续增加。

## 检查失败与测试

出现缺失或未列出文件时审阅清单，不要改用全目录压缩；许可不明时保持 Draft。
GitHub 下载验证失败会保留 Draft；先调查原因，已存在的发布不会被工具隐式恢复或覆盖。
网络/API 错误不能视为校验通过。对于已经上传的 Draft，按上面的手动复核流程处理。

```powershell
python -m unittest discover -s tests/release -v
python tools/test_check_spdx.py --models
python -m unittest discover -s tests/headers -v
```

文档测试、严格构建与仓库/站点边界检查遵循[文档维护](documentation.md)。
发布检查只证明分发资产符合本项目的规则，不能替代第三方许可审阅或实际模型/硬件测试。

参考：[GitHub Release 管理](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)、
[Git archive 与导出属性](https://git-scm.com/docs/git-archive)。
