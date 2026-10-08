<a id="pmsm-framework-architecture"></a>

# PMSM 控制框架架构

本文定义公开的架构与接口契约。

保留现有命名框架模块，并使其具备可执行逻辑。控制函数采用适用于 Embedded Coder 的自主 MATLAB 实现，由 MATLAB Function 模块调用。显式状态保存在具有确定类型的 Unit Delay 中，使复位、调度、Normal 执行和生成 C 代码共享同一个状态转移函数。未执行的 Stateflow 草图由显式且经过测试的状态转移实现替代；状态名称/编码仍遵守 McStruct 枚举契约，避免保留图上可见但不执行的重复逻辑。

<a id="module-order-and-state"></a>

## 模块顺序与状态

| 模块 | 职责 | 直接馈通 | 速率 |
|---|---|---|---|
| McKernel | 初始化状态、接收快速节拍、派生慢速节拍、维护有界计数器 | 是 | 选定的 Ts |
| McTuning | 仅在未使能时校验并锁存调参 | 是 | 快速 |
| McEventHub | 捕获已使能的命令与请求电角速度 | 是 | 快速 |
| McFault | ADC/母线/输入校验、立即跳闸、需显式复位的故障锁存 | 是 | 快速，独立于驱动使能 |
| McStateMachine | 复位/初始化/空闲/就绪/对齐/开环/跟踪/运行/停止/故障转移 | 是 | 已接受的快速节拍 |
| McDataFlow | 采集、位置/速度估算、电流/速度控制、电压限幅与调制 | 是 | 快速；速度 PI 每 SpeedDivider 个节拍执行一次 |
| McDebug | 生成占空比计数、门极使能及具有确定类型的遥测/快照 | 是 | 快速 |
| 运行时存储 | 上一周期完整控制器状态 | 否 | 快速；按文档进行零值/类型初始化 |

控制器内部唯一的反馈经过运行时存储。被控对象使用显式命令延迟和独立物理状态，不向控制器内部反馈真值。快速节拍暂停时控制积分器保持，但故障输入仍强制关闭门极。

McDrivingEvent 接收快速节拍，McCtrlEvent 捕获命令/速度变化。McTimerEvent 是保留的兼容输入，在此同步主机契约中预留。慢速节拍仅由已接受的快速节拍计数派生，独立定时事件不能引发额外 PI 积分。模型采样时间与 McControl_Params.Ts 必须一致：主机/S32K344 基线为 62.5 us，S32K144 为 125 us；速度分频分别为 16 或 8，以保持 1 ms 周期。改变此时序契约须同步模型配置，并重新验证整个层级。

<a id="external-ports"></a>

## 外部端口

保留现有概念端口：Ia、Ib、Ic（uint16 偏移二进制 ADC）；McControl（0=复位/未使能，1=运行，2=受控停止）；FaultEvent；McCtrlEvent；McDrivingEvent；McTimerEvent；McTuningPort（tMcTuning）。增加 SpeedReq（single，电角速度 rad/s）、DcBusVoltage（single，V）、RotorAngle（single，电角度 rad）。RotorAngle 仅在显式选择的有感模式中参与控制；未使能采样可初始化其他情况下不用的位置历史。无感观测器函数不含角度/被控对象真值参数，测试要求无感输出不受位置输入影响。

最后两个输入是 AppliedVoltageAlpha 和 AppliedVoltageBeta（single，V），封装为 tMcInput.AppliedVoltage，描述产生当前电流样本的区间内实际施加的电压。主机适配器根据延迟且量化的 PWM 计数、延迟后的门极状态及该区间直流母线电压重建此反馈。观测器必须使用该反馈，不能使用自身未量化的请求电压。回放须使用与电流记录对应的实际施加电压输入；将新生成的电压命令与固定的历史电流组合，会造成实验不一致。

输出为 DutyA/B/C（uint16 定时器计数）、DebugPort（tMcDebug）、GateEnable（boolean）和 Monitor（具有确定类型的遥测）。归一化占空比等于 counts/PwmPeriod。门极禁用在逆变器边界覆盖占空比；禁用时数值占空比居中为 0.5，不代表允许桥臂通电。

HSP 应用边界负责 ADC 对齐/标定、RTD 占空比缩放、相空闲状态及门极命令、母线测量和事件驱动的单步调用。HSP 0.1.0 配置显式选择的 S32K144 或 S32K344 目标。链接的 McControllerLibrary 子系统在各组件间共享控制器，主机测试框架引用这些组件进行 Normal/SIL/PIL。

HSP 还需根据该采样区间实际装载的 PWM 值（或经过独立验证的电压测量）提供实际施加电压反馈，包含门极状态及相关逆变器补偿。被拒绝、限幅或延迟的占空比命令不能当作已经施加。非有限电压反馈会锁存输入故障 fault16。

<a id="control-law"></a>

## 控制律

采用等幅值 Clarke/Park 变换，电角度为零时 A 相与 d 轴对齐。极对数和磁链为正时，正 iq 产生正转矩。电角速度等于 polePairs 乘机械角速度（rad/s）。dq 电流 PI 在 500 Hz 设计带宽下采用 Rs/L 极点抵消，SI 积分增益仅乘一次 Ts，并包含 dq 交叉耦合前馈、圆形电压限幅（0.9*Vdc/sqrt(3)）和条件积分抗饱和。速度 PI 使用沿用的惯量/摩擦/转矩常数，按标称 8 Hz 临界阻尼闭环设计，iq 限幅为 6 A。默认值在 mc.defaults 中维护版本，修改后须重新验证行为。

速度请求具有变化率限制。所有 PI 积分器在未使能/故障时复位；观测器控制权切换时，以测量 q 轴电流预置速度积分，避免不连续。饱和状态不得让积分继续向加深饱和的方向增长。居中调制先减去 (max(vabc)+min(vabc))/2，再归一化为占空比。

McTuning 默认禁用。TuningEnable 为 true 时，仅在 RESET/IDLE 锁存完整且有效的增益组和启动参数组。uint16 的 SpdKp、SpdKi、IdKp、IqKp 编码为 SI 增益的 1000 倍，IdKi、IqKi 直接编码 SI 积分增益。AlignCurrent 单位为 mA，AlignTime 为 ms，OpenLoopAccel 为电角加速度 rad/s²，TrackingGain 编码观测器带宽（s⁻¹）。零值或超范围参数组被忽略，使能期间调参不能改变活动增益。完整控制参数结构仍是更高分辨率的离线标定接口。禁用在线调参时，未使能节拍从 McControl_Params 预置增益和启动设置，避免旧的 McRuntime_Init 掩盖已修改的标定值。

无感运行通过积分“实际施加的静止坐标系电压减去 Rs*电流”估算转子有源磁链，并采用有界的磁链幅值修正。扣除 Lq 电流项，期望有源磁链考虑 Ld-Lq 及估算的 d 轴电流。角度由 atan2 得到，速度由回绕后的角度差经低通滤波得到。对齐提供初始角度，对齐之后不使用转子真值。观测器置信度要求速度足够高、磁链幅值合理并持续规定时间。I/f 启动按斜坡增加带符号的电角频率，控制权切换在 0.2 s 内混合角度。置信度丢失时进入文档定义的低速回退或锁存超时故障，不能继续静默信任无效估计值。

<a id="lifecycle"></a>

## 生命周期

状态码保留 eSmStates：0 RESET、1 INIT、2 IDLE、3 FAULT、4 READY、5 READY_2_ALIGN、6 ALIGN、7 ALIGN_2_OPEN_IF、8 OPEN_IF、9 OPEN_IF_2_TRACKING、10 TRACKING_2_OPEN_IF、11 TRACKING、12 TRACKING_2_RUN、13 RUN_2_TRACKING、14 RUN、15 STOP。

故障优先于复位、停止、启动和普通状态推进。仅在活动故障源消失后，复位才能清除锁存；之后还需要显式运行命令。停止及方向反转先按斜坡降速，再重新对齐/启动。正反向无感启动都属于验收场景。默认范围是单个 PMSM；其他电机/传感器的可选枚举值仅为类型定义，不代表已实现对应控制算法。

零速死区包含边界：请求绝对值不超过电角速度 1 rad/s 时保持未使能或启动受控停止。方向捕获和反向启动处理仅在死区之外生效。

<a id="references"></a>

## 参考资料

- [PMSM dq 动力学与幅值约定](https://www.mathworks.com/help/autoblks/ref/interiorpmsm.html)
- [磁链估算原理](https://www.mathworks.com/help/mcb/ref/fluxobserver.html)
- [MATLAB Function 脚本 API](https://www.mathworks.com/help/simulink/slref/simulink.matlabfunctionconfiguration.html)
- [主机 SIL 的实际执行语义](https://www.mathworks.com/help/ecoder/ug/software-and-processor-in-the-loop-sil-and-pil-simulation.html)

<a id="low-speed-and-numerical-equivalence-policy"></a>

## 低速与数值等价策略

低于电角速度 75 rad/s（1.25*ObserverMinSpeed）时，无感运行明确处于 I/f 回退，不声明为可观测的闭环控制。进入允许闭环的速度范围后启动新的捕获超时。从 I/f 停止，或停止期间观测器失去有效性时，保持最后实际使用的控制坐标系，按斜坡降低频率/电流；不得切到未经有效性确认的角度。数值状态故障锁存 fault512，并在同一步强制输出有限的居中占空比和禁用门极。

在此低速范围内，I/f 电流按请求频率绝对值相对于 OpenLoopSpeed 的比例缩放，同时保留 CurrentSlew。该缩放不使用转子真值，也不改变全速启动路径，用于限制低速加速。这仍是开环运行，不保证在不可观测速度下抑制负载扰动。

精确回放比较区分确定性的整数状态/门极信号与浮点派生的 PWM 量化结果。验收限值见[系统规格](pmsm-framework-system.md)。

状态和接口使用单精度。部分三角函数、角度和平方根计算采用 double 中间值，再显式舍入回 single，避免记录输入回放中库函数舍入差异被放大。此类中间计算的目标执行时间须单独评估，不能由数值一致性推断。
