# PMSM Framework Architecture

Public architecture and interface contract.

The existing named framework modules are retained and made executable. Control functions are original MATLAB implementations suitable for Embedded Coder, called from MATLAB Function blocks. Their explicit state is held by a typed Unit Delay, so reset, scheduling, Normal execution and generated C share one transition function. Inactive draft Stateflow diagrams are replaced by an explicit, tested state-transition implementation; state names/codes retain the McStruct enumeration contract. This avoids retaining visually present but nonexecuting duplicate logic.

## Module order and state

| Module | Responsibility | Direct feedthrough | Rate |
|---|---|---|---|
| McKernel | Initialize state, accept fast tick, derive slow tick, maintain bounded counters | Yes | 62.5 us |
| McTuning | Validate and latch tuning only while disarmed | Yes | fast |
| McEventHub | Capture enabled command and requested electrical speed | Yes | fast |
| McFault | ADC/bus/input validation, immediate trip, explicit-reset latch | Yes | fast, independent of driving enable |
| McStateMachine | Reset/init/idle/ready/align/open-loop/tracking/run/stop/fault transitions | Yes | accepted fast ticks |
| McDataFlow | Acquisition, position/speed estimation, current/speed control, voltage limiting and modulation | Yes | fast; speed PI every 16 ticks |
| McDebug | Produce duty counts, gate enable and typed telemetry/snapshots | Yes | fast |
| Runtime memory | Previous complete controller state | No | fast; documented zero/typed initialization |

The only feedback in the controller runs through runtime memory. The plant uses an explicit command delay, separate physical states and no controller-internal truth feedback. A fast-tick pause holds control integrators, but fault inputs still force the gate off.

McDrivingEvent accepts a fast tick; McCtrlEvent captures command/speed changes.
McTimerEvent is a retained compatibility input, reserved in this synchronous
host contract. Slow ticks derive exclusively from the accepted fast-tick count,
so an independent timer indication cannot cause extra PI integrations. Model
sample time and McControl_Params.Ts are both 62.5 us; changing that timing contract
requires updating the model configuration and revalidating the entire hierarchy.

## External ports

Existing conceptual ports are retained: Ia, Ib, Ic (uint16 offset-binary ADC); McControl (0=reset/disarmed, 1=run, 2=controlled stop); FaultEvent; McCtrlEvent; McDrivingEvent; McTimerEvent; McTuningPort (tMcTuning). Add SpeedReq (single electrical rad/s), DcBusVoltage (single V), RotorAngle (single electrical rad). RotorAngle affects control only in explicitly selected sensored mode; a disarmed sample may initialize the otherwise-unused position history. The sensorless observer function has no angle/plant-truth argument, and tests require sensorless outputs to be independent of the position input.

The final two inputs are AppliedVoltageAlpha and AppliedVoltageBeta (single V), packed as tMcInput.AppliedVoltage. They describe the voltage applied during the interval producing the current sample. The host adapter reconstructs it from the delayed, quantized PWM counts, delayed gate and the interval's DC bus voltage. The observer must use this feedback, never its own unquantized requested voltage. Replay records the same applied-voltage inputs as the current recording; feeding a newly generated voltage command against frozen recorded currents creates an inconsistent experiment.

Outputs are DutyA/B/C (uint16 timer counts), DebugPort (tMcDebug), GateEnable (boolean) and Monitor (typed telemetry). Normalized duty equals counts/PwmPeriod. A disabled gate overrides duties at the inverter boundary; disabled numerical duties are centered at 0.5, not interpreted as permission to energize a bridge.

The HSP application boundary owns ADC alignment/calibration, RTD duty scaling, phase idle and gate commands, measured DC bus and event-driven step invocation. HSP 0.1.0 configures the S32K344 target. Linked McControllerLibrary subsystems share the controller across components; host harnesses reference those components for Normal/SIL/PIL.

HSP also supplies applied-voltage feedback from the PWM values actually loaded for that acquisition interval (or an independently validated voltage measurement), including gate state and relevant inverter compensation. A rejected, limited or delayed duty command must not be reported as if it was applied. Invalid nonfinite voltage feedback latches input fault16.

## Control law

Use amplitude-invariant Clarke/Park with phase A aligned to the d axis at electrical angle zero. Positive iq creates positive torque for positive pole pairs/flux. Electrical speed is polePairs times mechanical rad/s. dq current PI uses Rs/L pole cancellation at a 500 Hz design bandwidth, SI integral gains multiplied once by Ts, dq cross-coupling feedforward, circular voltage limiting (0.9*Vdc/sqrt(3)) and conditional anti-windup. Speed PI is designed for a critically damped 8 Hz nominal loop using the inherited inertia/friction/torque constant, and clamps iq at 6 A. Defaults are versioned in mc.defaults; changes require behavioral revalidation.

The speed request is slew-limited. All PI integrators reset while disarmed/faulted; the speed integral is seeded from measured q current at observer handover to avoid a discontinuity. Saturation can never increase integral in the outward direction. Centered modulation subtracts (max(vabc)+min(vabc))/2 before normalizing to duty.

McTuning is disabled by default. When TuningEnable is true, complete valid gain
and startup groups latch only in RESET/IDLE. uint16 SpdKp, SpdKi, IdKp and IqKp
encode 1000 times their SI gain; IdKi and IqKi encode SI integral gain directly.
AlignCurrent is in mA, AlignTime in ms, OpenLoopAccel in electrical rad/s², and
TrackingGain encodes observer bandwidth in s⁻¹. Zero or out-of-range groups are
ignored; tuning while armed cannot change active gains. The full control
parameter structure remains the higher-resolution offline calibration interface.
With online tuning disabled, disarmed ticks seed gains and startup settings from
McControl_Params, so an old saved McRuntime_Init cannot mask edited calibrations.

Sensorless operation estimates active rotor flux by integrating applied stationary voltage minus Rs*current, with a bounded flux-magnitude correction. The Lq current term is removed; the expected active flux accounts for Ld-Lq and estimated d current. Angle comes from atan2, speed from wrapped angle difference with a low-pass filter. Alignment supplies the initial angle; no rotor truth is used after alignment. Observer confidence requires sufficient speed and a plausible flux magnitude for a dwell time. I/f startup ramps signed electrical frequency; handover blends angle over 0.2 s. Loss of confidence invokes a documented low-speed fallback or a latched timeout fault instead of silently trusting invalid estimates.

## Lifecycle

Codes retain eSmStates: 0 RESET, 1 INIT, 2 IDLE, 3 FAULT, 4 READY, 5 READY_2_ALIGN, 6 ALIGN, 7 ALIGN_2_OPEN_IF, 8 OPEN_IF, 9 OPEN_IF_2_TRACKING, 10 TRACKING_2_OPEN_IF, 11 TRACKING, 12 TRACKING_2_RUN, 13 RUN_2_TRACKING, 14 RUN, 15 STOP.

Fault has priority over reset, stop, start and ordinary progression. Reset clears a latch only when the active fault source is absent; a subsequent explicit run command is needed. Stop and direction reversal ramp speed down before a new alignment/start. Positive and negative sensorless startup are both acceptance scenarios. The default domain is a single PMSM; optional enum values for other motors/sensors remain type definitions, not claims of implemented control algorithms.

The zero-speed deadband is inclusive: requests with absolute value at most
1 electrical rad/s remain disarmed or initiate a controlled stop. Direction
capture and reverse-start handling only apply outside that deadband.

## References

- PMSM dq dynamics and amplitude conventions: https://www.mathworks.com/help/autoblks/ref/interiorpmsm.html
- Flux estimation principles: https://www.mathworks.com/help/mcb/ref/fluxobserver.html
- MATLAB Function script API: https://www.mathworks.com/help/simulink/slref/simulink.matlabfunctionconfiguration.html
- Actual host SIL semantics: https://www.mathworks.com/help/ecoder/ug/software-and-processor-in-the-loop-sil-and-pil-simulation.html

## Low-speed and numerical equivalence policy

Below 75 electrical rad/s (1.25*ObserverMinSpeed), sensorless operation is explicitly I/f fallback; it is not claimed to be observable closed-loop control. Entering the closed-loop-eligible speed domain starts a new acquisition timeout. Stopping from I/f, or losing observer qualification while stopping, preserves the last applied control frame and ramps frequency/current down; it never switches to an unqualified angle. Numerical-state failure latches fault512 and forces finite centered duty with gate disabled in the same step.

In this low-speed domain, I/f current scales with absolute requested frequency
relative to OpenLoopSpeed while retaining CurrentSlew. Scaling the request limits low-speed acceleration without using rotor
truth or changing the full-speed startup path. This remains open-loop operation,
not a guarantee of load rejection at unobservable speeds.

The exact replay comparison distinguishes deterministic integer status/gate from float-derived PWM quantization. Acceptance limits are defined in the [system specification](pmsm-framework-system.md).

State and interfaces use single precision. Selected trigonometric, angle and
square-root evaluations use double intermediates and explicitly round back,
avoiding amplified library-rounding discrepancies in recorded-input replay.
Target execution time for these intermediate evaluations must be assessed separately from numerical agreement.
