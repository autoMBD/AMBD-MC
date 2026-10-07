# 验证与复现

面向已运行过主机场景的开发者。Python 验证入口需要
[锁定的 Agent 环境](../agent-environment.md)，会创建独立的官方 MCP 会话。

## 独立对象参考与完整 SIL

在仓库根目录执行：

```powershell
python tools/pmsm/validate_plant_reference.py
python tools/pmsm/validate_sil.py
python tools/bldc/validate_plant_reference.py
python tools/bldc/validate_sil.py
```

对象参考检查物理实现及数值收敛；SIL 验收运行单元测试、
独立 Normal/SIL 闭环、同输入重放和代码生成检查。
每次完整验收建立新的报告目录，记录执行环境与源码指纹。

## 局部排查

```powershell
python tools/pmsm/validate_sil.py --scenario sensorless_forward
python tools/bldc/validate_sil.py --scenario hall_steps
```

局部运行标记 `CompleteMatrix=false`，不能替代完整验收。
BLDC 还支持 `--normal-only --collect-failures` 收集物理场景问题；
此结果也不构成完整 SIL 验收。

## 判断结果

- 完整运行同时检查 `Passed`、`CompleteMatrix` 和源码未变化门槛。
- 独立闭环验证控制行为；同输入重放验证模型与代码数值关系。
- 查看精确比较与浮点容差的独立记录，不把“曲线接近”当作逐位一致。
- 工具未安装、许可证不可用、输入缺失与算法失败分开诊断；
  缺少任务输入标记 SKIP，不记为 PASS。

[PMSM 数值决策](../validation/2026-10-06-pmsm-numerical-equivalence.md)
与 [BLDC 完整验收](../validation/2026-10-06-bldc-sil-acceptance.md)
保留历史判据和结果；当前运行仍需生成自己的证据。

## 目标处理器与功率板

主机通过后按 [HSP 指南](../hsp-s32k344.md) 准备独立工作副本、外部工具链及
明确的探针/UART 配置，再进行目标构建和 PIL。PIL 比较处理器代码数值，
并不证明真实电流标定、栅极波形或带载闭环。板级工作见
[MCSPTE1AK344 指南](../mcspte1ak344.md)。
