# 快速开始

本页从当前仓库的活动模型运行一个主机场景。先阅读
[工作流与环境要求](manual/index.md)，确认 MATLAB/Simulink、所需产品和
autoMBD HSP 0.1.0 已可用。当前参考验证环境是 Windows + MATLAB R2026a；
仅安装 Python 无法执行电机模型。

## 获取项目

```powershell
git clone https://github.com/autoMBD/AMBD-MC.git
cd AMBD-MC
```

在 MATLAB 中将当前目录切换到仓库根目录。活动模型位于
`mc-models/pmsm/` 和 `mc-models/bldc/`；无需打开历史归档模型。

## 初始化并运行

PMSM 有感基线：

```matlab
info = pmsm_setup;
result = mc_run_host_case('FOC_PIL_Algth_top','sensored_steps','Normal');
disp(result.Passed);
disp(result.TraceFile);
```

BLDC Hall 基线：

```matlab
info = bldc_setup;
result = bldc_run_host_case("hall_steps","Normal");
disp(result.Passed);
disp(result.TraceFile);
```

成功时 `result.Passed` 为真，`TraceFile` 指向本次运行的 MAT 日志。
普通场景输出位于忽略的 `.agent-env/` 下。错误或缺少依赖时先查看诊断，
不要把“已初始化”当成“仿真通过”。

初始化校验类型和字典并保留已有标定。保留返回的 `info`，
维持字典连接生命周期。不要在普通启动时使用 `SyncDictionary=true`；
它用于明确更新类型或重置默认标定，见两类电机手册。

## 下一步

- [基础教程](tutorials/tutorial-quick.md)：从初始化、运行到读取记录。
- [场景示例](examples/example.md)：Hall、有感、无感及 SIL 入口。
- [验证流程](tutorials/tutorial-advanced.md)：完整矩阵与局部调试。
- [Agent 环境](agent-environment.md)：使用 Python 验证脚本前配置锁定的官方 MCP。
- [HSP 指南](hsp-s32k344.md)：目标构建及实际 PIL 的额外前提。

首次主机仿真无需接入功率板。目标固件、PIL 和带电机调试分别遵循其对应指南，
不能把主机场景通过理解为实机验收通过。
