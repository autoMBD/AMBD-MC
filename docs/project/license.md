# 许可与第三方范围

以仓库的 [LICENSE](https://github.com/autoMBD/AMBD-MC/blob/main/LICENSE)、
[README 声明](https://github.com/autoMBD/AMBD-MC/blob/main/README.md)
及各文件随附许可为准。

| 范围 | 项目中的声明 |
| --- | --- |
| 项目自有代码与文档 | 根 MIT License；保留版权与许可声明 |
| `mc-models/hsp/config/S32K344/` | 保留 autoMBD HSP 的 Apache-2.0 许可与来源记录 |
| `mc-models/hsp/config/S32K144/` | 同样保留 autoMBD HSP 的 Apache-2.0 许可与来源记录 |
| 外部 NXP RTD 实现、工具及参考应用 | 由本机外部安装提供，不随本项目分发 |
| `legacy/` 历史文件 | 不适用根 MIT；权利归 autoMBD 作者，仅供学习，不允许修改、合并、发布、分发、分许可或销售 |

第三方配置的 [许可原文](https://github.com/autoMBD/AMBD-MC/blob/main/mc-models/hsp/config/S32K344/LICENSE)
与 [来源记录](https://github.com/autoMBD/AMBD-MC/blob/main/mc-models/hsp/config/S32K344/provenance.json)
随源文件维护。本站不复制历史受限模型或图片，不重新解释或改变其许可。

S32K144 配置对应的[许可原文](https://github.com/autoMBD/AMBD-MC/blob/main/mc-models/hsp/config/S32K144/LICENSE)
和[来源记录](https://github.com/autoMBD/AMBD-MC/blob/main/mc-models/hsp/config/S32K144/provenance.json)
也必须随包保留；不能统一替换为根 MIT 许可。

Release 通过逐文件清单登记组件归属，随包生成 `THIRD_PARTY_NOTICES.md`，
保留许可原文、适用 NOTICE 及修改记录；默认排除历史受限文件、厂商实现和内部资料。
新增文件、依赖或衍生内容必须先审阅许可再列入清单。源码归档的排除规则只适用于包含
该规则的新提交，不追溯改变历史 tag。具体操作见[发布指南](../development/releasing.md)。
