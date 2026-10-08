# 框架与数据流

PMSM 和 BLDC 各有独立的算法包、类型源、数据字典与主机电机对象，
通过共享算法库连接到主机验证模型和 S32K144 / S32K344 目标组件。

## 执行链

每个快环步以类型化输入、上一状态和参数计算下一状态与输出。
状态通过显式 Unit Delay 保存。通用主机与 S32K344 快环为 16 kHz；
S32K144 套件配置为 8 kHz。端口与状态延迟继承顶层步长，速度环分频分别为
16 与 8，均保持 1 kHz。目标时基与控制参数 Ts 必须一致。

| 模块 | 职责 |
| --- | --- |
| McTuning | 停机状态下锁存一致的标定参数 |
| McKernel | 采样、单位换算和快慢环调度 |
| McEventHub | 命令与定时事件 |
| McFault | 输入、运行和外部故障检测与锁存 |
| McStateMachine | 复位、启动、运行、停止及故障生命周期 |
| McDataFlow | 按状态执行电流／速度调节、观测或换相 |
| McDebug | 输出监控、状态与调试信息 |

具体执行顺序和接口以
[PMSM 架构规格](algorithms/pmsm-framework/pmsm-framework-architecture.md)、
[BLDC 架构规格](algorithms/bldc-framework/bldc-framework-architecture.md) 为准。

## 主机闭环与目标边界

```text
场景命令/扰动 → 控制组件 → PWM/gate/相使能 → 独立逆变器与电机对象
                    ↑                         ↓
                    └── ADC/Hall/端电压适配 ──┘
                              │
                        日志与独立验收

目标：ADC（BCTU 或 PDB）/Hall → 板级适配 → 同一控制算法 → PWM 提交/互锁 → 功率级
```

主机对象的转角、速度和反电势真值用于独立验收；无感控制器不读取这些真值。
PMSM 有感基线可接收位置输入，BLDC Hall 模式使用 Hall 信号。
实际施加电压或换相区间须与采样对齐，不能用尚未施加的命令替代测量反馈。

| 层 | PMSM | BLDC |
| --- | --- | --- |
| 算法包 | `+mc` | `+bldc` |
| 类型字典 | `McData.sldd` | `BldcData.sldd` |
| 共享库 | `McControllerLibrary` | `BldcControllerLibrary` |
| 框架 | `MotorFramework` | `BLDCFramework` |
| 主机对象 | dq 平均值模型 | 相域梯形反电势及续流网络 |

两类电机共用 HSP/板级基础设施，各自保留算法和标定。

## 类型与标定

[PMSM 类型源](../McStruct.md)和 [BLDC 类型源](../BldcStruct.md)由
[类型生成器](https://github.com/autoMBD/AMBD-MC/blob/main/tools/generate_data_type_from_md.m)
读取。初始化检查生成类型与字典是否一致；正常启动保留已有标定。
控制器参数与对象参数分开，场景使用临时覆盖实现失配、扰动和故障测试。

## 验证层次

Normal 检查模型行为；SIL 执行主机生成 C；同输入重放比较模型与代码；
PIL 在目标处理器执行生成代码。独立闭环与同输入重放解决不同问题，
两者均不能替代实机采样、功率级与实时性测试。

模型角色和目标部署见 [HSP 目标指南](../hardware/hsp-targets.md)，
各验证层级和结果判读见[验证指南](../manual/verification.md)。
