# MCSPTE1AK144 集成

本配置面向 S32K144EVB-Q100、DEVKIT-MOTORGD 和 Sunrise 42BLY3A78-24110
电机，使用 autoMBD HSP 0.1.0、RTD 3.0.0 QLP06、EB tresos 29 和 Cortex-M4F
FreeRTOS 端口。目标选择和共用验证入口见 [HSP 目标指南](hsp-targets.md)。

**当前功率级功能仍需完整套件验收。** 控制板可独立执行 PIL 和关闭输出的
诊断；驱动板缺失时 GD3000 资格失败，不能据此宣称 BLDC/PMSM 实机运行。

## 工具与构建

安装并启用 HSP 0.1.0 的 S32K1 适配器，填写
[S32K144 环境示例](hsp-s32k144-environment.example.json)。SDK 根目录为
含 `sdk_manifest.xml`、`RTD/`、`FreeRTOS/` 的 S32K1 平台安装目录；不要填
S32K3 RTD 路径。PIL 使用 OpenSDA、LPUART1、115200 baud、8-N-1。
可用 PEmicro `pegdbserver_console -showhardware` 核对探针身份。

```matlab
stage = ambd_mc("stage","pmsm",fullfile(pwd,'.agent-env','hsp','s32k144.json'));
slbuild('FOC_Ctrl_MBD');
```

实际生成输入是工作副本的 `configuration/S32K144`。源 EB 工程来自 HSP 的
Apache-2.0 模板，项目配置脚本为 `tools/hsp/configure_s32k144.py`；原厂驱动实现、
编译器、EB 插件、生成 C 和 ELF 都不随仓库分发。

## PMSM 模型层级与周期

K1 与 K3 使用同一份 `McControllerLibrary` 和 PMSM 活动模型；选择
`s32k144` 会把工作副本绑定到 K1 配置，不另复制一套控制算法。
`FOC_PIL_Algth_model` 独立运行 FOC 核心，使用安培电流和归一化占空比；
`FOC_PIL_StateMch_model`、`MotorFramework` 和 C 应用入口执行整机校准与状态管理，
内部调用同一个核心。

K1 的快环为 125 µs，速度环分频为 8，保持 1 ms 周期。暂存分别设置
`McCoreRuntime_Init` 和包含核心状态的 `McRuntime_Init`；基础 PIL 夹具也使用
目标周期和对应分频。主机 16 kHz 记录的运行窗口回放仍按原录波周期执行，
不能作为 K1 原生 8 kHz 实时性验收。

板级 12 bit ADC 经驱动换算为安培；独立核心直接接收该物理量，整机接口则由
桥接层重新编码为零点 32768、1000 count/A 的 `uint16` 采样值。不要把板级
12 bit 原始计数直接送入整机模型。完整分层与校准规则见
[PMSM 架构](../specs/algorithms/pmsm-framework/pmsm-framework-architecture.md)。

## 下载与调试

先在本机 JSON 中核对 `deployment.probeSerial`、`deployment.interface` 和
`deployment.executable`，将 `deployment.targetConnected` 设为 true，再创建
工作副本。HSP Config 的 **Build and deploy** 会构建、下载并复位运行；等价操作为：

```matlab
cfg = autombd.hsp.config.read('FOC_Ctrl_MBD');
cfg.buildAction = 'Build and deploy';
autombd.hsp.config.write('FOC_Ctrl_MBD',cfg);
autombd.hsp.config.apply('FOC_Ctrl_MBD');
slbuild('FOC_Ctrl_MBD');
```

下载回执位于该工作副本的 `build/FOC_Ctrl_MBD/application/download-result.json`，
原生 ELF 位于 `build/FOC_Ctrl_MBD/project/build/FOC_Ctrl_MBD.elf`。
回执证明下载命令完成，仍需复位后读取控制板状态才能确认启动。
PIL 入口自动下载独立的测试固件；结束后若需运行原生应用，应重新下载应用 ELF。

用 S32DS/PEmicro 打开对应 ELF 调试时，先退出占用探针的 PIL，并关闭占用
串口的终端。控制板诊断重点检查 `Ambd_Kit` 的 `driver_ready`、`calibrated`、
`faults`、`late_updates`，以及 EN、RESET 和 FTM3 `OUTMASK`。驱动板缺席时
GD3000 资格失败和故障锁存是预期行为；不得绕过互锁以使诊断显示“运行”。

## 接线与跳线

接线依据 [NXP 套件指南](https://www.nxp.com/document/guide/s32k144-motor-control-kit-guides%3AGS-MCSPTE1AK144)。
先断电，再按板上丝印和实际版本确认：

| 位置 | 设置 |
|---|---|
| 控制板 J104 | 2–3，MCU 复位 |
| 控制板 J107 | 仅 USB 控制板诊断用 2–3；完整套件由 12 V 供电时用 1–2 |
| 功率板 J9 / J10 / J11 | PMSM 两相采样用 1–2；BLDC 反电动势采样用 2–3 |
| 功率板 J8 | 按实际 Hall 传感器电压选择；原套件 5 V Hall 对应开路 |
| Sunrise 电机 A / B / C | 黄 / 绿 / 蓝；其他电机需重新确认相序与参数 |

两板通过套件内侧排针连接并共地。功率板的限流比较器、采样零点和母线分压
必须先实测标定，不能把软件默认保护阈值等同于实际硬件保护值。

## 信号映射

| 信号 | S32K144 配置 |
|---|---|
| 六路 PWM | FTM3 CH0–5，PTB8/9、PTB10/11、PTC10/11；偶数高侧低有效 |
| PWM 周期 / 死区 | 80 MHz、全周期 10,000 ticks、8 kHz；48 ticks = 600 ns 的配置值 |
| BLDC 母线电流 | ADC1 SE6 / PTD4，12 bit，50 A 全跨度，独立零点校准 |
| 母线电压 | ADC1 SE7 / PTB12，45 V 满量程 |
| BLDC 悬空相电压 | ADC0 SE4/5/2，PTB0 / PTB1 / PTA6，对应 A/B/C |
| PMSM A / B 电流 | ADC0 SE4 / PTB0、ADC1 SE15 / PTB1；反相放大器，62.5 A 全跨度；C 相重建 |
| Hall A / B / C | PTD11 / PTD10 / PTA1，转换到控制器 Hall 编码 |
| GD3000 | LPSPI0：PTB2 SCK、PTB3 SIN、PTB4 SOUT；PTB5 GPIO CS |
| GD3000 EN / RESET / INT | PTA2 / PTA3 / PTE10 |
| PIL 串口 | LPUART1：PTC6 RX、PTC7 TX，经 OpenSDA 到主机 |

ADC0/1 与 PDB0/1 通过原厂 RTD IP API 接入；FTM3 端点比较事件经 TRGMUX
驱动 PDB。启动时先屏蔽触发、关闭输出、完成 ADC 校准和缓冲准备，再稳定
PWM 时基后开放采样。ADC 完成标志与 PDB 序列错误共同判定帧有效性。
BLDC 的母线分流不会被伪造为三相电流；PMSM 的第三相由 `-Ia-Ib` 重建。

FTM 三相占空比经 `Ftm_Pwm_Ip_FastUpdatePwmDuty` 批量写入 CV 缓冲，
在 CNTMAX 装载；该 IP 接口接收半周期计数，不能直接传 Q15。
软件同步禁用计数器复位，输出屏蔽与占空比装载分别控制。BLDC 换相期间屏蔽整个桥，确认新计划
锁存后再使能对应两相；悬空相高低侧同时屏蔽。迟到、采样错误、GD3000 读回
失败和 INT 故障均关闭输出。实际极性、死区与高阻状态需要示波器确认，配置
值和 C 测试不能替代波形测量。

## 标定与运行边界

`ambd.kit_parameters(family,"s32k144")` 从独立目标记录读取 Sunrise 参数：
两对极、0.192 Ω、Ld/Lq 96/107 µH、磁链 0.005872 Wb。实际所接电机的型号
必须匹配；Linix 等其他电机不能沿用这组标定。S32K144 使用 125 µs 控制周期：62.5 µs 在启动控制步已超预算，
因此选择更大的执行窗口，并同步调整速度环分频和按时间定义的消隐阈值。
是否满足正常运行所有分支的执行预算，必须以对应固件的实测结果判断。

`Ambd_KitControl` 为命令，`Ambd_KitSpeedRequest` 单位为电角速度 rad/s。
`Ambd_OutputsArmed` 默认 false；驱动器资格、零点校准、算法 gate 和故障
状态共同决定输出。板级故障锁存后需排除原因并重新启动。

`boardDiagnostics=true` 用于驱动板未连接时的 PWM 提交路径测量，要求 EN
低、六路 FTM 输出全部屏蔽。串口诊断中相应硬件屏蔽字段是 FTM `OUTMASK`，
低六位应为 `0x3f`；它与 S32K344 的 LCU `OUTEN=0` 含义不同。
此模式的故障分支耗时不能作为正常运行 WCET。

验收按“处理器数值 / 控制板无输出 / 完整功率级”分别记录。完整套件仍需
完成零点与量程、栅极极性和死区、悬空相高阻、启停、正反转、速度变化、
带载闭环及故障关断。PMSM 有感 PIL 的位置来自录波输入，当前原生适配不
提供编码器接口。
