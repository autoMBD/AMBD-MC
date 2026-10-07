# 基础教程：运行并检查一个场景

先完成[快速开始](../getting-started.md)。以下以 BLDC Hall 为例，
所有命令在仓库根目录的 MATLAB 会话中运行。

## 1. 初始化

```matlab
info = bldc_setup;
```

入口检查类型并连接 BLDC 字典。保留 `info`，
不要为普通仿真重建模型或同步默认标定。

## 2. 运行场景

```matlab
result = bldc_run_host_case("hall_steps","Normal");
assert(result.Passed, 'Hall 场景未通过验收');
```

入口选择场景所需顶层、控制模式、参数和输入，
并通过 `Simulink.SimulationInput` 临时应用。仅打开一个带有
`Sensorless` 名字的模型，不会自动切换其参数。

## 3. 查看日志

```matlab
disp(result);
saved = load(result.TraceFile);
disp(fieldnames(saved));
disp(saved.assessment);
```

MAT 文件包含 `trace`、`scenario`、`metadata` 和 `assessment`，
分别记录信号、场景、执行信息和物理验收。文件位于 `.agent-env/`。
验收失败应查看具体检查和诊断，不应通过扩大容差将失败变为通过。

## 4. 扩展到无感或 SIL

```matlab
result = bldc_run_host_case("sensorless_forward","Normal");
```

确认主机编译器和代码生成产品可用后，可将执行模式改为 `"SIL"`。
单个场景通过不等于完整矩阵通过；完整流程见
[验证与复现教程](tutorial-advanced.md)和 [BLDC 手册](../manual/bldc.md)。
