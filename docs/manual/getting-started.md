# 快速开始

本页从当前仓库的活动模型运行一个主机场景，并检查结果。
先按[工作流与环境要求](index.md)准备 MATLAB/Simulink、所需产品和
autoMBD HSP 0.1.0。参考环境为 Windows + MATLAB R2026a；Python 不能替代 MATLAB。

## 获取项目

```powershell
git clone https://github.com/autoMBD/AMBD-MC.git
cd AMBD-MC
```

在 MATLAB 中将当前目录切换到仓库根目录。活动模型位于
`mc-models/pmsm/` 和 `mc-models/bldc/`。

## 统一 MATLAB 入口 {#matlab}

根目录的 `ambd_mc.m` 是公共操作入口。无参数调用或 `ambd_mc("help")`
显示帮助；操作命令必须显式指定家族，不再默认初始化全部模型。

| 调用 | 行为与返回值 |
|---|---|
| `info = ambd_mc("setup","pmsm")` | 返回 PMSM 初始化信息；通过 `info.DictionaryConnection` 保持字典连接 |
| `info = ambd_mc("setup","bldc")` | 返回 BLDC 初始化信息及字典连接 |
| `info = ambd_mc("setup","all")` | 返回 `Root`、`Family`、`HspVersion`，以及 `info.Bldc` 和 `info.Pmsm` 两组初始化信息 |
| `stage = ambd_mc("stage","bldc",settingsFile)` | 为单个家族建立独立工作副本；PMSM 同样支持。返回 `Stage`、`Models`、HSP 元数据以及 `Bldc` 或 `Pmsm` 初始化信息 |

`setup` 支持以下名称-值选项，也接受 `'Name',value` 语法：

- `SyncDictionary=false`：默认只验证类型，保留标定；显式 `true` 同步类型并重置框架默认标定，拒绝未保存的字典修改。必须传逻辑标量。
- `Dictionary=""`：默认选择该家族源字典。可为单个家族指定其他字典；同步写入仍受源字典／`.agent-env/` 边界约束。`all` 不接受非空 `Dictionary`，分别初始化各家族以指定不同字典。
- `OutputDirectory=""`：默认写入 `.agent-env/i/<实例 ID>/pmsm/` 或同实例的 `bldc/`。显式目录必须在 `.agent-env/` 内，托管实例对其持有排他锁；`all` 在指定目录下按 `bldc/` 和 `pmsm/` 分开保存生成物。

托管 MCP 实例禁止同步源字典或写入其他实例目录；使用 `stage` 或独立 `Dictionary` 副本进行修改。交互式 MATLAB 的源字典同步仍需自行保证独占。模式与生命周期见[会话隔离说明](../development/agent-environment.md#离线与会话)。托管 MATLAB 的当前目录是实例 `work/`，以 `fileparts(which('ambd_mc'))` 定位仓库，避免依赖 `pwd`。

命令和家族使用表中的小写全名，选项使用完整名称。未知命令、非法家族、
缺失参数或非法选项会给出 `ambd:*` 错误。`stage` 只接受家族和本机 JSON
配置路径，不接受 `setup` 选项；具体保护和目标构建步骤见
[HSP 指南](../hardware/hsp-s32k344.md)。相对路径以 MATLAB 当前目录解析。

升级已有脚本时，将原家族初始化调用替换为对应的 `ambd_mc("setup",...)`；
单家族返回字段不变。原 HSP 单家族初始化的聚合字段现为直接返回，
例如改为读取 `info.DictionaryConnection`；`all` 和 stage 保持聚合字段。
四个旧根目录操作函数已移除；未来操作通过此入口的子命令扩展。

## 运行第一个场景

选择一种电机执行即可。

PMSM 有感基线：

```matlab
info = ambd_mc("setup","pmsm");
result = mc_run_host_case('FOC_PIL_Algth_top','sensored_steps','Normal');
```

BLDC Hall 基线：

```matlab
info = ambd_mc("setup","bldc");
result = bldc_run_host_case("hall_steps","Normal");
```

入口会选择场景顶层、模式、参数和输入，通过 `Simulink.SimulationInput`
临时应用，不保存场景覆盖。模型文件名不自动切换控制模式。

初始化会检查类型、连接字典并保留已有标定。保留返回的 `info`，
维持字典连接生命周期。普通启动无需重建模型或使用 `SyncDictionary=true`；
类型同步和默认标定重置见 [PMSM](pmsm.md)／[BLDC](bldc.md) 手册。

## 检查结果与日志

```matlab
assert(result.Passed, '场景未通过验收');
disp(result.TraceFile);
saved = load(result.TraceFile);
disp(fieldnames(saved));
disp(saved.assessment);
```

成功时 `result.Passed` 为真。MAT 文件包含 `trace`、`scenario`、
`metadata` 和 `assessment`，分别记录信号、场景、执行信息和物理判据。
文件保存在本机 `.agent-env/` 内，不是网站下载附件。

错误或缺少依赖时先查看诊断；初始化成功不等于仿真通过，也不要用扩大容差掩盖失败。

## 继续使用

- [场景示例](examples.md)：有感、Hall、无感及 SIL 调用。
- [验证与复现](verification.md)：完整矩阵、局部调试及证据判读。
- [框架与数据流](../specs/architecture.md)：算法、对象与硬件边界。
- [HSP 指南](../hardware/hsp-s32k344.md)：目标构建与实际 PIL。
- [常见问题](faq.md)：环境、字典和模式排查。

首次主机仿真无需接入功率板。目标固件、PIL 和带电机调试遵循其各自指南。
