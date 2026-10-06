# BLDC framework architecture

Status: interface baseline, 2026-10-06. Implements B1–B10 in the system spec.

## Composition and execution order

Use package `+bldc`, unique `tBldc*` buses and `BldcData.sldd`. No `+mc` or PMSM
dictionary modification is required. `BLDCFramework` stores one explicit runtime
bus in Unit Delay and orders McTuning → McKernel → McEventHub → McFault →
McStateMachine → McDataFlow → McDebug. Every component accepts `(u,s,p)` and
returns next state; monitor/output generation has no hidden state. Disarmed
calibration latching precedes acquisition so ADC conversion, feedback, protection
and regulation all use one coherent calibration set in each frame. McKernel
advances the divide-by-16 scheduler; TimerEvent permits the due slow update.

`BLDC_Ctrl_MBD` and `BLDC_Ctrl_CodeModel` are ERT host wrappers. Hall and
sensorless wrapper/top pairs in `platform/pil` reference the same core with
separate SimulationInput parameter overrides. The plant resides outside the SIL
controller. Its truth outputs never enter the sensorless or Hall speed regulator.
Hall signals are the only plant-position-derived sensor input, permitted only
in Hall mode. An ignored replay wrapper drives the same controller with captured
ADC, Hall, terminal voltage, bus, command and applied-interval metadata.

## Phase, Hall and commutation convention

`theta_e=p*theta_m`. Define periodic f(theta): linear -1→+1 on [-30°,30°],
+1 on [30°,150°], linear +1→-1 on [150°,210°], -1 on [210°,330°].
The motor's phase shapes are f(theta), f(theta−120°), f(theta+120°).
Sector is `floor(mod(theta_e−pi/6,2*pi)/(pi/3))+1`.

| Sector | Hall code | Positive source | Positive sink | Floating phase | Expected BEMF crossing slope |
|---:|---:|---|---|---|---|
| 1 | 5 | A | B | C | falling |
| 2 | 4 | A | C | B | rising |
| 3 | 6 | B | C | A | falling |
| 4 | 2 | B | A | C | rising |
| 5 | 3 | C | A | B | falling |
| 6 | 1 | C | B | A | rising |

Negative motoring torque swaps source/sink for the same rotor sector; negative
rotation visits sectors in reverse order. Raw Hall code is never a sector index.
At negative speed the BEMF sign and motion reverse together, so the measured
crossing-time slope in this table is unchanged. Alignment uses A+ B−, whose
stable equilibrium is theta_e=150°; forced positive/negative startup begins in
sector 3/2 respectively with the selected source/sink orientation.

## Actuator and sample-time contract

Use bipolar complementary PWM of the two active legs. Modulation m in [0,1]
requests source pole Vdc*(1+m)/2 and sink pole Vdc*(1−m)/2; the other leg is
high impedance. Quantize the source high-side duty to q counts, set sink to
65535−q exactly. Each enabled leg's low-side PWM is its complement; deadtime
is an adapter responsibility, not simultaneous high/low switch conduction.
An inactive leg has PhaseEnable=false and both switches off. Global disable
overrides all outputs. This explicitly differs from conventional high-side-only
six-step PWM; HSP must preserve the documented modulation interpretation.

Output commands are delayed one fast tick before the plant. At sample k the
controller receives current and terminal voltages from the actual preceding
actuation interval, plus AppliedSector/AppliedDirection. ZC detection uses that
recorded sector, never the newly requested one. Logs include initial state at
t=0 and exactly one sample per Ts. Replay reuses these actual inputs with no
reconstruction from its own evolving output.

## Feedback and PI control

Hall feedback timestamps adjacent transitions and estimates signed electrical
speed as (pi/3)/elapsed time; filtered estimate decays/invalidates when no edge
arrives. Illegal code/transition faults are mode-specific. Startup, stalled motor
and running-edge timeout have separate guards; a static valid Hall at rest is
not immediately faulty.

Sensorless feedback subtracts half Vdc from the floating terminal voltage.
After demagnetization blanking and a near-zero floating current guard, require
the expected signed crossing with hysteresis. Reject implausible intervals and
duplicate crossings in one sector. Estimate the 60-degree period from valid
successive events; schedule the next sector after half that interval (30°).
At the target forced speed, briefly disable all gates, wait for measured current
decay, then acquire two fresh terminal-voltage snapshots. Their max/min/middle
ratios recover trapezoidal rotor phase without R/L/Ke or motor truth. Signed
phase change validates direction and seeds speed, sector and a provisional
commutation deadline. Reject negligible or rail-clamped voltage spans and frozen
or wrong-direction samples. This bounded acquisition interval is state 9.

The snapshot does not increment ZcCount or set FeedbackReady. In state 11, the
first real armed floating-phase crossing establishes the timestamp; the second
provides a complete 60-degree interval. Six qualified real crossings are required
before closed-loop readiness. Use the provisional period only until measured
periods exist. Invalid acquisition or lost crossings have explicit timeouts.
See the [acquisition decision](../../../validation/2026-10-06-bldc-acquisition.md).

The speed PI produces a nonnegative current magnitude in the selected direction,
with request slew limiting and conditional integration at the 6 A limit.
The current PI measures current into the selected source phase, regulates it
to the slew-limited reference, and produces m in [0,1]. Both integrators reset
when disabled/faulted and preload across startup/control transfer to prevent a
command step. A current reference of zero while spinning is regulated with its
required BEMF-balancing voltage; it is not interpreted as unconditional shorting.

## Lifecycle and priority

Retain numerical meaning of the PMSM framework's 0–15 lifecycle codes. Reset 0,
init 1, idle 2, fault 3, ready 4, ready-to-align 5, align 6, align-to-open 7,
forced startup 8, acquire bridge 9, fallback bridge 10, tracking 11, ready-to-run
12, feedback-loss bridge 13, run 14, stopping 15. All bridge states have defined
entry/exit behavior. Hall mode can enter run after alignment; sensorless proceeds
through startup/acquisition/tracking. Unsupported low speed remains explicitly
forced startup. On reversal, ramp current/request down and reach the stop guard
before selecting opposite direction and aligning again. After current demand
reaches zero and measured current decays, coast with all gates off for a
calibrated 0.25 s before idle. This avoids treating missing low-speed sensorless
edges as proof of standstill; the interval is justified by the declared virtual
J/B and verified against plant truth in acceptance. Stop commands preempt
every startup/bridge state. Persistent fault plus reset keeps the gate off.

Fault bits: external 1, overcurrent 2, undervoltage 4, overvoltage 8, invalid input
16, ADC rail 32, startup timeout 64, stop timeout 128, invalid state 256,
numeric failure 512, Hall invalid/sequence 1024, Hall stall 2048, ZC loss 4096.
Fault latch clears only on command 0 after the triggering condition is safe.

## Initialization and model APIs

`bldc_setup` resolves paths, verifies saved types and calibrations, and directs
generated files below `.agent-env/bldc`. Explicit `SyncDictionary=true` updates
owned types/defaults transactionally while preserving unrelated dictionary data.
Normal startup preserves existing calibration. Runtime state is rebuilt from
typed defaults each run. Dirty or foreign dictionary mutation is refused.

All structural model edits use official `model_edit`, followed by `model_read`
and `model_check`. `library.settingsLookup` found no custom library configuration.
The existing PMSM builder provides previously tested official-tool patterns;
document any narrow pinned-tool API limitation before using a metadata fallback.
ERT configuration must match throughout the model-reference hierarchy and actual
host code/executable evidence must be collected before claiming SIL.

## Technical choices and review boundaries

Controller values are single, time counters integer and all arrays fixed-size.
Selected math may evaluate in double then cast if causally justified by replay;
no output coarsening or reset introduced merely to hide differences. Separate
plant parameters permit R/L/flux/inertia/load perturbation without retuning the
controller. Physical-domain details and independent validation belong to the
BLDC host plant specification. Phase 0 review checks this contract before model
or controller integration; any change updates both sides and regression tests.
