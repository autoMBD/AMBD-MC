# 文档维护与发布

## 公开文档的职责

| 目录 | 内容 | 维护原则 |
| --- | --- | --- |
| `manual/` | 环境、入门、两类电机使用、场景、验证方法和 FAQ | 通用流程集中维护，家族手册只补充差异 |
| `hardware/` | HSP 构建/PIL、MCSPTE1AK344 板级接口、环境配置示例 | 硬件要求与主机仿真分开 |
| `specs/` | 总体架构、算法和对象的系统/接口契约 | 描述当前设计，不记录任务执行过程 |
| `development/` | Agent 环境和文档维护指南 | 提供可复用方法，不发布本机验收材料 |
| `project/` | 许可、贡献、项目变更 | 引用仓库权威来源，避免多份规则失配 |

根目录只保留首页和 `McStruct.md`、`BldcStruct.md`。
这两份文件是类型生成器输入，路径、解析标记和表格格式属于工程契约。
仅整理文字时也要核对机器可读区域未变；移动或修改类型结构需要同步调用方和工程验证。

仓库 README 负责入口导航，完整手册在本站维护。
快速开始只维护首次运行和日志读取；场景表、验证命令和硬件步骤各有独立页面。
新内容应先归入已有章节，避免复制一份稍有不同的操作说明。
尚无真实内容的章节留在本地任务清单，不创建公开占位页。

## 内部文件只保存在本地

后续任务的开发计划、测试执行计划、验收记录、实验日志、审查结果、
许可头审计、运行指纹和原始附件一律放入已忽略的 `.agent-env/`：

- `.agent-env/plans/`：任务与实施计划。
- `.agent-env/reports/`：验收和测试运行记录；既有工具可继续使用其家族子目录。
- `.agent-env/audits/`：审查、盘点和审计材料。
- `.agent-env/internal-docs/`：从旧目录迁出的本地归档。

这些材料不能提交 Git，也不能通过 GitHub 源文件链接、站点导航、搜索索引、
重定向或构建工件重新公开。公开文档只保留用户需要的使用方法、设计契约和适用限制。
规则同样适用于技能默认要求生成的计划或报告，项目规则优先于技能默认保存路径。

`.gitignore` 和仓库检查共同防止内部路径再次进入提交：
即使强制添加被忽略文件，CI 也会拒绝识别到的内部文档。
检查规则不能替代内容审阅；不要通过更名绕过内部资料边界。

## 本地构建

只构建文档不需要 MATLAB。在仓库根目录使用 Python 3.11+：

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
输出和虚拟环境均位于忽略目录；生成的 HTML 不提交 Git。

## 发布与链接检查

`mkdocs.yml` 维护导航、公开旧地址的重定向和防御性构建排除规则。
移动公开页面时更新正文引用并配置旧地址跳转；内部资料的旧地址不保留跳转。

PR 与 main 使用锁定依赖，执行仓库文件边界、严格构建、生成站点检查和外链检查。
页面、资源、锚点、搜索与 sitemap 必须一致；重定向页不进入搜索及 sitemap。
只有 main 推送才部署，部署后比对首页、搜索和 sitemap 与受检工件。

站内链接使用相对路径，源码链接指向 GitHub；源码链接按当前检出检查，
以支持 PR 中尚未进入 main 的文件。内部工件不做下载链接。
厂商 HTTP 访问例外必须在
[精确外链例外配置](https://github.com/autoMBD/AMBD-MC/blob/main/tools/docs/link-exceptions.json)
注明 URL、状态码及人工核对原因；其他状态或网络错误仍失败。

文档检查只证明文档质量，不表示重新执行了模型、算法或硬件验收。
