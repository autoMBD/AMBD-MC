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
stage = ambd_mc("stage","bldc",fullfile(pwd,'.agent-env','hsp','s32k144.json'));
slbuild('BLDC_Ctrl_MBD');
```

`setup` 初始化共用算法、字典和 HSP；`stage` 才选择目标。每次暂存创建新的
`.agent-env/t/` 子目录，复制对应 EB 工程和源模型，使用包含目标名称的字典，
返回 `stage.Target`。源模型保持默认 S32K344 的便携设置，不写入机器路径。共享控制器的端口与
状态延迟继承顶层离散步长，由所选目标设为 62.5 µs 或 125 µs。
切换目标前关闭上一工作副本的同名模型，保留需要的标定；脏模型、脏字典和
其他位置的同名模型均阻止暂存。

每个工作副本都将 `AmbdOutputsArmed` 设为 false。普通构建仅产生目标 ELF；
实际下载/PIL 需要明确设置 `deployment.targetConnected=true` 和探针身份。

## 逐模型范围

以下模型均复用同一份算法，不为 S32K144 复制控制器。

| 模型 | 角色与验证 |
|---|---|
| `BldcControllerLibrary`、`McControllerLibrary` | 共享库；随各目标组件编译，另有算法单元测试 |
| `BLDCFramework`、`MotorFramework` | 目标框架；代码生成、原生构建、基础 PIL |
| `BLDC_Ctrl_CodeModel`、`FOC_Ctrl_CodeModel` | C 接口；原生构建、基础及运行状态 PIL |
| `BLDC_Ctrl_MBD`、`FOC_Ctrl_MBD` | 原生板级应用；原厂 API 集成构建、基础 PIL、控制板诊断 |
| `BLDC_PIL_Hall_model`、`BLDC_PIL_Sensorless_model` | BLDC 控制组件；基础和运行状态 PIL |
| `FOC_PIL_Algth_model`、`FOC_PIL_StateMch_model` | PMSM 控制组件；基础和运行状态 PIL |
| `BLDC_PIL_Hall_top`、`BLDC_PIL_Sensorless_top` | 主机对象与 Normal/SIL 顶层 |
| `FOC_PIL_Algth_top`、`FOC_PIL_StateMch_top` | 主机对象与 Normal/SIL 顶层 |

这是适用范围，不能作为测试通过记录。BLDC 支持 Hall / 无感算法；PMSM
有感组件使用外部位置输入，套件原生应用选择无感 FOC。当前板级驱动不提供
PMSM 编码器位置接口，不声明有感原生实机支持。

## 统一验证入口

同一控制板的验证入口应顺序执行，探针和 UART 只能由一个进程占用。
在启动验证的 PowerShell 中分配独立临时目录，可避免与已打开的 MATLAB
会话共享 Simulink 临时缓存；变量仅影响当前 PowerShell 及其新建子进程：

```powershell
$matlabTemp = Join-Path $PWD ('.agent-env/tmp/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $matlabTemp | Out-Null
$env:TEMP = $matlabTemp
$env:TMP = $matlabTemp
```

需要并行运行独立主机验证时，各 MATLAB 实例还必须有独立的生成/缓存目录。
共享临时缓存可能触发字典“已在磁盘改变”等一致性错误，详见
[MathWorks 多实例说明](https://www.mathworks.com/matlabcentral/answers/1728440-running-simulink-on-multiple-matlab-instances-concurrently-on-machine-crashes-in-sldd-dmr-sdi-jen)。

```powershell
python -m unittest discover -s tests/hsp -v
python tools/hsp/validate_target.py --settings .agent-env/hsp/s32k144.json
python tools/validate_kit.py --target s32k144
python tools/validate_kit.py --reference-report .agent-env/kit-validation/<run>/summary.json --settings .agent-env/hsp/s32k144.json
```

基础入口遍历 10 个目标组件，执行真实构建与 PIL；`--model` / `--family`
用于局部诊断。报告记录所选目标，不能将 S32K344 结果计入 S32K144。
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
