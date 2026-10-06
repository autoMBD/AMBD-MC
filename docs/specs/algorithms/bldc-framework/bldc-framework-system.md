# BLDC framework system specification

Status: implementation baseline, 2026-10-06. Owner: autoMBD / 小T.

## Objective and existing baseline

Complete the BLDC counterpart of the PMSM framework milestones: typed data and
initialization, executing control components, integrated models, a independently
validated host motor/inverter, and actual generated-C PC SIL with reproducible
acceptance. The existing BLDC model implements Hall-related logic with S32K/MBDT
dependencies. Its saved XML was inspected without executing board callbacks.

Development branch: `codex/bldc-models`, created from `8-update-pmsm-models` at
`ac4ef18` (completed PMSM work). The user-named `820f966` is its direct ancestor.
Use local commits at verified milestones; do not push or run hardware tools.
Keep legacy and external HSP/NXP references unchanged; author original control
and plant implementations. Existing project utilities may be reused.

BLDC models reside under `mc-models/bldc`; the user-mentioned
`mc-models/pmsm/platform/pil` remains part of final regression acceptance.

## Requirements

| ID | Requirement and observable completion evidence |
|---|---|
| B1 | A repository-relative `bldc_setup` initializes types, persistent dictionary and calibrations in a fresh session, repeatedly without destructive reset; Markdown and generated types agree. |
| B2 | `BLDCFramework` preserves McKernel, McTuning, McEventHub, McFault, McStateMachine, McDataFlow and McDebug responsibilities; all components execute and contain no active MBDT/board dependency. |
| B3 | Explicit single-precision controller state at 16 kHz; integer divide-by-16 speed loop at 1 kHz; fault/reset priority and disabled outputs deterministic even without a driving tick. |
| B4 | Hall six-step uses measured Hall edges for sector/direction/speed, including invalid codes, illegal transitions and timeout diagnostics. Sensorless control uses sampled terminal voltages, currents and the actual prior commutation state, without rotor speed/angle or internal BEMF truth. |
| B5 | Alignment, forced-current startup, qualified zero crossing, 30-degree delayed commutation, closed-loop run, controlled stop, reversal/restart, protection, explicit safe reset and declared low-speed behavior are exercised. Loss of qualified feedback cannot silently sustain uncontrolled drive. |
| B6 | Anti-windup speed PI and current PI regulate positive motoring current in the selected direction; bounded current reference and bipolar modulation; complementary active legs and one floating leg. Every run checks no simultaneous physical high/low gate command, current envelope, finite outputs and safe fault disable. |
| B7 | Independent phase-domain trapezoidal motor/inverter validation includes RL and coast analytic oracles, torque/power consistency, Kirchhoff current conservation, commutation continuity, diode/float terminal behavior, integration-step convergence and a MathWorks native physical comparison. |
| B8 | Hall and sensorless host top models run Normal and actual ERT C SIL. Record exact input replay, source/harness hashes, compiler and executed EXE evidence. Both loops pass physical criteria independently. |
| B9 | Full scenario matrix covers signed speed, load/bus disturbance, stop/restart, reversal, startup/transition stop, current saturation/recovery, invalid Hall/stall, external/bus/overcurrent faults, sensorless acquisition/loss and parameter variation. Negative tests prove the acceptance checks reject invalid traces. |
| B10 | Fresh-session scripts reproduce results below `.agent-env`; existing PMSM full SIL matrix remains passing and its model/source hashes unchanged. Final requirement audit, three completion reviews and staged local commits are mandatory. |

## Quantitative acceptance

- Feasible steady operating points: electrical-speed mean error no greater than
  max(5 rad/s, 5% of requested magnitude), ripple peak-to-peak no greater than
  15% of request or 10 rad/s; directional overshoot at most 20% after acquisition.
  Startup alignment is evaluated separately from commanded steady-speed windows.
- Current reference at most 6 A; measured phase-current envelope below 9.9 A in
  ordinary scenarios, and 10 A trip faults disable by the next fast sample.
  Fault injection may intentionally exceed the envelope only in its declared window.
- Voltage bounds 8–16 V, nominal 12 V; invalid/nonfinite measured inputs fault.
  Invalid Hall codes 0/7 and nonadjacent sector changes fault in Hall mode.
- Stops/reversals must reach the declared idle/coast criterion within 1.5 s;
  no opposite drive while prior-direction speed remains above the stop threshold.
  A low sensorless request is declared forced-commutation operation; it is never
  reported as observed closed-loop regulation. A lost ZC sequence while closed-loop
  drives safely to fault/disable, with an explicit timeout and no auto-restart.
- Replay: status, fault, sector, masks, timing, integer diagnostics and PWM counts
  exact; floating outputs abs 1e-5 + rel 1e-5. Record strict bitwise equality also.
  No post-result tolerance relaxation without a documented physical rationale.
- Independent closed-loop Normal/SIL drift limits: 1 electrical rad/s speed,
  0.1 A phase current and 1e-3 modulation; faults/masks/gate exact. These budgets
  are smaller than the physical performance allowance and do not replace it.

## External boundary

All inputs/outputs execute at 62.5 us. Electrical angle increases in the declared
A-B-C forward direction; electrical speed equals pole pairs times mechanical speed.

| Input | Type / units | Meaning |
|---|---|---|
| CurrentRaw | uint16[3], ADC counts | Phase currents into motor; offset 32768, 1000 count/A |
| Hall | uint8 | Encoded Hall signals, LUT specified in architecture; ignored in sensorless mode |
| TerminalVoltage | single[3], V | Sampled terminal voltages relative to DC negative, aligned with current |
| Control | uint8 | 0 safe reset, 1 run, 2 controlled stop |
| Fault | boolean | External protection request |
| CommandEvent, DrivingEvent, TimerEvent | boolean each | Synchronous command latch, fast tick and timing event |
| SpeedReq | single, electrical rad/s | Signed request, clamp to ±250 |
| Vdc | single, V | DC bus measurement for the sampled interval |
| AppliedSector | uint8 | Sector active during the measured interval, 0 if disabled |
| AppliedDirection | int8 | Source/sink orientation during the measured interval, ±1 |
| VoltageValid | boolean | Whether terminal voltage is a usable aligned acquisition |

| Output | Type | Meaning |
|---|---|---|
| DutyA, DutyB, DutyC | uint16 each | High-side timer counts, period 65535 |
| PhaseEnable | boolean[3] | Enabled leg uses complementary high/low PWM; false means both switches off |
| GateEnable | boolean | Global enable; false overrides all phases |
| Debug | typed bus | Versioned fixed-size diagnostics |
| Monitor | typed bus | State, faults, feedback, requests, PI/commutation/timing diagnostics |

Controller defaults use Hall mode (`PositionMode=0`); sensorless mode is 1.
Mode choice and startup/gain calibrations are latched only while disarmed.
Plant parameters are separate from controller calibrations for mismatch testing.

## Operating domain and exclusions

Virtual motor parameters come from this repository's PMSM baseline for controlled
comparison: phase R=0.56 ohm, nonsalient phase L=0.4 mH, pole pairs=2,
flux constant=0.0039052261 Wb, J=1.2e-5 kg m², B=0.0005 N m s/rad.
These are declared simulation assumptions, not measured BLDC identification.
The phase BEMF coefficient per mechanical speed is p*flux, torque is its dot
product with normalized trapezoid and phase currents. Target is host Windows x64
ERT C. MCU WCET, deadtime compensation, ADC hardware timing and physical motor
validation require later HSP integration and are outside this PC-only request.

## Research notes

MathWorks documents terminal-voltage ZC detection, alignment/open-loop acquisition,
demagnetization blanking and 30-degree commutation delay in
[Sensorless Six-Step Commutation](https://www.mathworks.com/help/mcb/ref/sensorlesssixstepcommutation.html).
The controller here is independently authored, not a copied example. The
[BLDC physical block](https://www.mathworks.com/help/sps/ref/bldc.html) supplies an
independent oracle for three-phase trapezoidal flux dynamics. Local R2026a API and
parameter behavior must be inspected before building that reference harness.
