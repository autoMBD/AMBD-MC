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

## 运行第一个场景

选择一种电机执行即可。

PMSM 有感基线：

```matlab
info = pmsm_setup;
result = mc_run_host_case('FOC_PIL_Algth_top','sensored_steps','Normal');
```

BLDC Hall 基线：

```matlab
info = bldc_setup;
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
