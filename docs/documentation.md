# 文档维护与发布

## 内容来源与维护责任

当前仓库没有找到独立的项目手册原稿（盘点基线：`f63d80d`）。
本次以两类电机 README、现有规格、源码入口和历史验收记录组织项目手册，
不等待未知原稿，不创建空章节。

| 原始内容 | 处理结果 | 当前维护位置 |
| --- | --- | --- |
| 首页、快速开始、架构模板 | 替换为当前项目介绍、运行入口和模型关系；保留 URL | [首页](index.md)、[快速开始](getting-started.md)、[架构](architecture.md) |
| 基础／高级教程、示例模板 | 替换为已存在场景、日志读取及验证流程 | [基础教程](tutorials/tutorial-quick.md)、[验证教程](tutorials/tutorial-advanced.md)、[示例](examples/example.md) |
| FAQ、更新日志模板 | 移除虚构接口和版本，按实际入口与提交重写 | [FAQ](faq.md)、[变更记录](changelog.md) |
| 许可、贡献模板 | 对齐仓库声明；贡献流程引用单一仓库来源 | [许可](doc-lic.md)、[贡献](doc-contributing.md) |
| 两类电机完整 README | 正文迁入手册；原 README 保留初始化入口和链接 | [PMSM](manual/pmsm.md)、[BLDC](manual/bldc.md) |
| 2 份类型参考 | 保留路径、解析标记与表格；修正旧入口描述 | [McStruct](McStruct.md)、[BldcStruct](BldcStruct.md) |
| 3 份环境／硬件指南 | 纳入导航，修复源码链接 | [Agent](agent-environment.md)、[HSP](hsp-s32k344.md)、[套件](mcspte1ak344.md) |
| 15 份算法／对象规格 | 全部纳入设计参考；修复过时范围和引用 | 导航“设计参考”下的 4 组规格 |
| 8 份运行报告／技术决策及环境验收 | 保留历史结果，标明基线；移除无效工件下载链接 | [验证索引](validation/index.md) |
| 2 个 JSON | 保留可公开配置示例和验证证据，不包含实际机器配置 | [环境示例](hsp-environment.example.json)、[证据](validation/2026-10-07-hsp-s32k344.json) |
| 开发计划与许可头审计 | 保留 Git 历史资料，在构建层排除，不进入站点或搜索 | 仓库 `docs/superpowers/`、`docs/license-header-audit.md` |

适用版本由各指南前提和报告日期声明。没有迁入的独立手册来源；
早期不适用的模板正文已替换，不再作为归档内容发布。
未来新增手册材料时，先更新此表，记录其来源、适用版本和采用/排除结果。

## 本地构建

只构建文档不需要 MATLAB。在仓库根目录创建专用 Python 环境：

```powershell
python -m venv .agent-env/docs/venv
# 标准 Windows Python；其他平台使用该环境的 bin/python
.agent-env/docs/venv/Scripts/python.exe -m pip install -r requirements-docs.txt
.agent-env/docs/venv/Scripts/python.exe -m unittest discover -s tests/docs -v
.agent-env/docs/venv/Scripts/python.exe -m mkdocs build --strict
.agent-env/docs/venv/Scripts/python.exe tools/docs/check_site.py .agent-env/docs/site --external
.agent-env/docs/venv/Scripts/python.exe -m mkdocs serve
```

预览地址为 `http://127.0.0.1:8000/AMBD-MC/`。
构建输出、虚拟环境和缓存保留在忽略目录；不要提交生成的 HTML。

## 发布范围与检查

`mkdocs.yml` 是导航和发布范围的唯一配置来源。
使用 `exclude_docs` 排除开发计划和许可头审计，仅从 `nav` 删除不会停止发布。
新公开页面必须有导航入口。十篇旧页面保留原地址并提供真实内容，不另造空重定向页。

PR 与 main 使用相同锁定依赖，执行严格构建和生成站点检查。
检查覆盖本地页面、资源、锚点、搜索、sitemap 及禁止发布的路径；
外链 HTTP 错误也会阻止 CI。确需例外时在
[外链例外文件](https://github.com/autoMBD/AMBD-MC/blob/main/tools/docs/link-exceptions.json)
记录精确 URL、允许的失败状态和原因，不能用通配域名或忽略所有错误。
正常检查仍访问例外链接，返回其他错误码时失败。当前精确例外为 MathWorks 的
HTTP 403，以及已在浏览器逐项确认存在但脚本返回 HTTP 404 的三个 NXP 页面；
修改这些引用时重新进行人工核对。仓库自身的 main 分支源码链接按本次检出的
文件验证，以支持 PR 中尚未进入 main 的新文件；其他外链执行 HTTP GET。

只有推送 main 才部署 GitHub Pages；PR 上传同一构建工件供审阅。
合并后的工作流检查实际部署站点的首页、搜索和 sitemap；
PR 阶段不宣称生产网站已更新。

## 链接与工程契约

- 站内使用 Markdown 相对链接；仓库源码使用 GitHub 链接。
- 本机工件使用带说明的代码路径，不制造不存在的下载地址。
- 不发布 `legacy/`、本机配置、原始运行目录或二进制。
- `McStruct.md` 与 `BldcStruct.md` 同时是类型生成输入。移动路径或修改解析标记、
  表格时必须同步调用方并执行工程验证；仅修正说明文字仍应检查机器可读区域未变。
- 文档构建与链接测试只证明文档质量，不代表模型、算法或硬件重新验收。
