# MCSPTE1AK344 板级集成

本配置面向 S32K344EVB-T172、DEVKIT-MOTORGD 和套件 Sunrise 电机，使用
autoMBD HSP 0.1.0 的外部 EB 工程、NXP RTD 7.0.1 和 FreeRTOS 运行框架。
硬件映射依据 NXP 的 [套件指南](https://www.nxp.com/document/guide/getting-started-with-the-mcspte1ak344-development-kit%3AGS-MCSPTE1AK344)、
[AN13884（套件文档入口，下载需 NXP 账户）](https://www.nxp.com/design/design-center/development-boards-and-designs/MCSPTE1AK344)、官方 BLDC
六步换相示例及 [GD3000 数据手册入口](https://www.nxp.com/products/GD3000)。
NXP 驱动、参考应用和工具均由本机安装提供，不随本项目分发。

## 采样与驱动

| 信号 | 配置与处理 |
|---|---|
| BLDC 母线电流 | ADC0 P0，14 bit，50 A 满量程，启动零点校准 |
| PMSM B 相电流 | ADC0 P2，14 bit，62.5 A 满量程，反相放大器极性 |
| PMSM A 相电流 | ADC1 P1，同步采样；C 相由 `-Ia-Ib` 重建 |
| 母线电压 | ADC0 P1，45 V 满量程 |
| BLDC 悬空相电压 | ADC1 P1/P3/P2 对应 A/B/C，相切换后选择正确通道 |
| Hall | A/B/C 对应 PTA19/20/21；板端顺序转换为控制器定义的 Hall 编码 |
| 相 PWM | eMIOS0 CH1/2/3，CH22 时基，160 MHz、10,000 ticks，16 kHz |
| ADC 触发 | eMIOS0 CH4 flag 直接触发 BCTU；BLDC 在有效脉冲中心，PMSM 在低侧零矢量区 |
| 栅极输出 | PWM 经 TRGMUX 路由到 LCU0 六路互补输出；高侧为低有效；上升沿滤波 96 ticks，即 600 ns 死区 |
| GD3000 | GPIO CS 的 SPI 读写、模式和屏蔽寄存器读回、INT 中断及逐帧电平检查 |

BLDC 与 PMSM 的电流/电压通道共用套件引脚。按官方对应应用设置功率板跳线，
不可混用两种跳线布局。采样驱动检查每个 FIFO 字的 ADC、通道、触发标签及
数据范围；帧数或标签不符会触发板级故障。1024 个有效、居中的无输出采样
完成电流零点校准。输入电流统一换算成模型的 32768 零点、1000 counts/A。

BLDC 参数 `CurrentSenseMode=1` 明确表示 DC 分流；`Current` 三相量保持零，
`PhaseCurrentsValid=false`，控制与保护使用独立的 `DcCurrent` 和有效标志。
悬空相退磁通过消隐时间、脱离电源轨及连续有效样本判断，不能从 DC 电流
推断悬空相电流。无感启动的相位追赶不增加过零计数；首个真实括住的过零
建立时间锚点，其周期在第二个相邻过零前是暂定值。进入 Run 仍要求六次
按方向相邻的真实过零、周期合理性以及跟踪时间。

## PWM 提交与互锁

`BLDC_Ctrl_MBD` 和 `FOC_Ctrl_MBD` 的 C Function 输出适配调用
`Ambd_KitCommit`。它只排队经过检查的命令；采样回调通过 RTD 官方
`Emios_Pwm_Ip_UpdateUCRegA/B` 更新三相缓冲，并同步放行比较器传输。
启动时检查 MCAL logical ID 到 eMIOS CH1–3 的映射、周期、模式和极性。
映射不符时拒绝启动，HSP 故障码为 74。

完整提交必须在 1600 CPU cycles（10 µs）内完成且不能跨重载。迟到时不发布
已提交计划并关闭输出。BLDC 换相先关闭六路输出，等待缓冲生效后只启用
导通两相；LCU 同时关闭悬空相高、低侧，不能用单路 PWM idle 代替高阻。
PMSM 的电压反馈使用上一采样区间计划，补偿电流方向对应的死区电压。

初始化在 ADC 触发启动前执行 32 个强制故障输入步以预热，随后重新初始化
模型状态和根输入。此过程不打开功率输出，也不替代正常状态转换的实时性测试。
ADC 进入 CTU 控制时会重新初始化共享 BCTU，因此驱动在这一步之后再次关闭
触发。PWM 先运行两个周期以锁存初始比较值，清除 CH4 标志并确认 FIFO 为空后，
才启用采样，避免 PMSM 的默认半周期脉冲与新前沿位置形成短首帧。FIFO 非空时
拒绝启动，HSP 故障码为 75。

## 参数与命令

`hsp_stage` 在独立字典中选用 `ambd.kit_parameters`：两对极、相电阻
0.192 Ω、PMSM Ld/Lq 为 96/107 µH、磁链 0.005872 Wb。这些是初始工程标定。
BLDC 默认 Hall、DC 分流，开环启动电流 1 A；PMSM 默认无感观测器，根输入
`RotorAngle` 不提供虚构位置。无感 BLDC 可显式设 `PositionMode=1`。
BLDC 和 PMSM 的 `PositionMode` 编码不同，见主集成说明。
PMSM 有感组件通过仿真／PIL 的外部 `RotorAngle` 输入验证；当前套件原生
应用仅配置无感 FOC，板级适配不提供有感位置接口。

目标命令为 `Ambd_KitControl` 和 `Ambd_KitSpeedRequest`，后者单位为电角速度
rad/s；零命令为停止。`Ambd_OutputsArmed` 默认 false。GD3000 读回失败、
INT 故障、电流未校准、采样失效或算法故障都会阻止功率输出。
板级故障保持锁存，排除故障后重新启动固件；算法故障沿用停止命令和安全复位流程。
连接功率板后的调试应先核对跳线、原始采样、零点和母线电压，再验证实际
六路栅极极性、死区与悬空相关断，之后才进行有电机输出的测试。

本机设置中的 `boardDiagnostics=true` 仅用于未接驱动板时测量同一 PWM
提交路径。该路径要求 GD3000 未就绪、EN 低且 LCU OUTEN 为零。它不会打开
栅极，也不能证明正常驱动状态的最坏执行时间。普通部署不启用该选项。

## 验证边界

板级 C 测试覆盖 ADC 标签与标度、桥臂映射、GD3000 事务失败、校准、INT
边沿/电平互锁、迟到提交及错误 PWM 映射。套件参考仿真包含量化和提交延迟；
BLDC 使用开关电气对象，PMSM 使用平均电压对象。Normal/SIL/PIL 检查控制器
数值，控制板诊断另外测量中断与提交时序。

GD3000 板和电机未连接时，真实采样标定、栅极波形、带载闭环、功率故障及
正常运行各分支最坏执行时间均为未验证。实际结果见当次验证报告，不以
PIL 或故障状态的连续运行替代这些项目。
