# HSP 目标选择与模型矩阵

BLDC、PMSM 共用控制算法库和活动模型，通过本机 JSON 的 `target` 选择芯片。
未指定时沿用 `s32k344`。硬件差异集中在
[目标配置](https://github.com/autoMBD/AMBD-MC/blob/main/mc-models/hsp/targets.json)、
各自的外部 EB 工程与板级驱动中；不使用 `legacy/` 或 MBDT。

| 项目 | `s32k344` | `s32k144` |
|---|---|---|
| 套件 | MCSPTE1AK344 | MCSPTE1AK144 / S32K144EVB-Q100 |
| HSP 目标 | `nxp.s32k3.s32k344-custom` | `nxp.s32k1.s32k144-custom` |
| CPU / 原厂驱动 | Cortex-M7 / RTD 7.0.1 | Cortex-M4F / RTD 3.0.0 QLP06 |
| 配置工具 | EB tresos 30 | EB tresos 29 |
| 电机时基 | 160 MHz eMIOS | 80 MHz FTM3 |
| 采样周期 / ADC | 62.5 µs / 14 bit | 125 µs / 12 bit |
| PIL UART | LPUART6，PTA15 RX / PTA16 TX | LPUART1，PTC6 RX / PTC7 TX |
| 指南 | [构建与 PIL](hsp-s32k344.md) / [板级配置](mcspte1ak344.md) | [MCSPTE1AK144](mcspte1ak144.md) |

两者依赖已启用的 autoMBD HSP 0.1.0、MATLAB/Simulink、Embedded Coder、
NXP GCC 10.2 和 FreeRTOS 11.1.0。S32K144 HSP 安装需包含 `s32k144-custom`
目标和版本 2 的 `s32k144-motor` 模板；本仓库配置来源记录在相应配置目录中。
模板原型仅含内部 ADC / 软件触发；套件的 FTM/PDB、引脚和驱动由本项目扩展。

## 工作副本

从对应环境示例创建独立本机文件：

- [S32K344 示例](hsp-environment.example.json) → `.agent-env/hsp/s32k344.json`
- [S32K144 示例](hsp-s32k144-environment.example.json) → `.agent-env/hsp/s32k144.json`

填写实际工具路径、探针及串口。`target` 与 `device.partNumber` 不一致会报错。
串口号和探针序列号属于本机配置，不能据此推断芯片型号。

```matlab
info = ambd_mc("setup","all");
repo = fileparts(which('ambd_mc'));
stage = ambd_mc("stage","bldc",fullfile(repo,'.agent-env','hsp','s32k144.json'));
slbuild('BLDC_Ctrl_MBD');
```

`setup` 初始化共用算法、字典和 HSP；`stage` 才选择目标。每次暂存创建新的
`.agent-env/i/<实例 ID>/t/` 子目录，复制对应 EB 工程和源模型，使用包含目标名称的字典，
返回 `stage.Target`。源模型保持默认 S32K344 的便携设置，不写入机器路径。共享控制器的端口与
状态延迟继承顶层离散步长，由所选目标设为 62.5 µs 或 125 µs。
切换目标前关闭上一工作副本的同名模型，保留需要的标定；脏模型、脏字典和
其他位置的同名模型均阻止暂存。

每个工作副本都将 `AmbdOutputsArmed` 设为 false。普通构建仅产生目标 ELF；
实际下载/PIL 需要明确设置 `deployment.targetConnected=true` 和探针身份。

## 模式隔离与构建身份

应用模型通过 `autombd.hsp.model.configureNativeCode` 的 `application` 模式登记
`KitPowerStage`：板级头文件和 `Ambd_KitCommit` 仅进入 application 生成分支，
Normal/SIL/PIL 使用显式占位。安装的 HSP 必须同时提供此入口和公开
`adapters/common/tools/verify_build_receipt.py` 校验器；仅版本号相同不足以确认接口可用。
还必须包含 [HSP Issue #14](https://github.com/autoMBD/autombd-hsp/issues/14) 中
callback-task 保留故障回调的隔离 PIL 支持；先更新 HSP，再使用本项目的迁移模型。

板级源码、包含目录、宏和编译选项登记在 `runtime.lifecyclePlan.resources`，
PIL 使用独立的 `runtime.pilIsolationPlan`。PIL 初始化仅配置时钟、UART、关闭状态的
门驱动复位/使能引脚，并停用应用 IRQ 和定时器；不启动 PWM、ADC、采样、预热或遥测。
配置中仍引用的板级回调由 HSP 根据显式声明生成调用即失败的替身，并记录声明来源。

`stage` 复制模型、字典和 EB 配置，板级 C 源码仍按项目路径参与构建，并非完整的源码快照。
`validate_target.py` 从实际 MATLAB 会话取得 HSP 路径，使用公开回执校验器核对预期
模型、目标、工程目录、ELF 路径和当前 SHA256；校验失败直接终止。回执校验本身不证明
下载或运行成功。每次验证创建独立 stage，并检查源文件与本机配置在运行期间没有变化。

K344 的 `Ambd_KitFaultIrq` 是专用于故障引脚的 ICU 上升沿通知。通知本身代表已确认的
边沿：即使回调执行时 GPIO 已回落，也必须锁存故障并禁止输出。不能把它当作任意 GPIO
轮询函数调用。K144 仍检查专用 PORT pending 位或当前故障电平。故障锁存之后，已排队或
重复提交的旧输出不得重新使能；重新初始化不是通用 Rearm。

原生 callback-task 时序保持不变：模型提交仅更新 pending，下一次采样 ISR 才写入
PWM 缓冲；软件 active 的周期推进不等同于外设装载确认。原生区间电压/扇区解释、
32 次安全输入预热、板级故障锁存与遥测协议仍由本项目负责，不声明为通用 HSP I/O
事务或通用 Rearm 的等价实现。

## 逐模型范围

以下模型均复用同一份算法，不为 S32K144 复制控制器。

| 模型 | 角色与验证 |
|---|---|
| `BldcControllerLibrary`、`McControllerLibrary` | 共享库；随各目标组件编译，另有算法单元测试 |
| `BLDCFramework`、`MotorFramework` | 目标框架；代码生成、原生构建、基础 PIL |
| `BLDC_Ctrl_CodeModel`、`FOC_Ctrl_CodeModel` | C 接口；原生构建、基础及运行状态 PIL |
| `BLDC_Ctrl_MBD`、`FOC_Ctrl_MBD` | 原生板级应用；原厂 API 集成构建、基础 PIL、控制板诊断 |
| `BLDC_PIL_Hall_model`、`BLDC_PIL_Sensorless_model` | BLDC 控制组件；基础和运行状态 PIL |
| `FOC_PIL_Algth_model` | 独立 FOC 核心，安培输入、归一化占空比输出；基础和运行状态 PIL |
| `FOC_PIL_StateMch_model` | 原始 ADC/PWM 接口，增加整机校准/状态管理；基础和运行状态 PIL |
| `BLDC_PIL_Hall_top`、`BLDC_PIL_Sensorless_top` | 主机对象与 Normal/SIL 顶层 |
| `FOC_PIL_Algth_top`、`FOC_PIL_StateMch_top` | 主机对象与 Normal/SIL 顶层 |

这是适用范围，不能作为测试通过记录。BLDC 支持 Hall / 无感算法；PMSM
有感组件使用外部位置输入，套件原生应用选择无感 FOC。当前板级驱动不提供
PMSM 编码器位置接口，不声明有感原生实机支持。

## 统一验证入口

同一控制板的验证入口应顺序执行，探针和 UART 只能由一个进程占用。
项目 MCP 的 `new`/`auto` 入口自动隔离 TEMP/TMP、工作目录和后续初始化生成物，无需逐次手动设置临时环境变量。`stage` 的类型脚本、EB 工作区和 cache/codegen 全部位于当前实例的暂存目录。`setup` 默认只读源字典；托管实例需要同步类型或修改标定时，使用自己的工作副本，不能同步源字典或其他实例的目录。

多实例目录所有权、`existing` 的边界和退出保留策略见
[会话隔离说明](../development/agent-environment.md#离线与会话)。
[并发回归](../manual/verification.md#多实例隔离回归)只运行 HSP 初始化及主机仿真，
不并发访问探针、UART 或控制板。

```powershell
python -m unittest discover -s tests/hsp -v
python tools/hsp/validate_target.py --settings .agent-env/hsp/s32k144.json
python tools/validate_kit.py --target s32k144
python tools/validate_kit.py --reference-report .agent-env/kit-validation/<run>/summary.json --settings .agent-env/hsp/s32k144.json
```

基础入口遍历 10 个目标组件，执行真实构建与 PIL；`--model` / `--family`
用于局部诊断。报告记录所选目标，不能将 S32K344 结果计入 S32K144。
基础 PIL 夹具使用所选目标的原生快环周期，并同步速度环分频：K144 为
125 µs / 8，K344 为 62.5 µs / 16，两者均保持 1 ms 速度环。
套件电气参考使用所选 ADC 和 PWM 分辨率；回放拒绝不同目标的参考记录。
运行状态回放使用录波原始时间网格与原参数，报告分别保留原生周期和回放周期；
16 kHz 通用录波的处理器数值比较不替代 8 kHz 套件参考或实时执行预算。
运行状态矩阵、1,024 个有效 Run 样本及全部根输出精确比较，见
[S32K344 指南的公共验证流程](hsp-s32k344.md#验证与证据)和
[验证与复现](../manual/verification.md)。

所有原始证据、源码/输入/ELF 指纹及报告只保存在忽略的 `.agent-env/`。
套件矩阵在每个案例的 `download-evidence/` 中保存下载回执、ELF 和烧录镜像，
并在矩阵摘要的 `DownloadEvidence` 中记录路径和哈希。后续案例重建同一模型时，
这些快照保持独立；矩阵结束前再次校验全部快照。
PIL 证明处理器数值行为；控制板无输出诊断、实际栅极波形和功率级闭环分别验收。
缺少功率板、电机、负载或测量条件的必需项目标记 SKIP，并保持套件验收未完成。
