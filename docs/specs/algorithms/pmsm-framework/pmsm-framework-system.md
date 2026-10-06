# PMSM Framework System Specification

Status: implementation baseline; 2026-10-06. Owner: autoMBD / 小T.

User authorization: autonomously finish the existing framework and all milestones on the current branch, with PC SIL in platform/pil; no chip download and no remote submission. The HSP and NXP reference repositories are read-only conceptual references; no copied implementation. All active development is MBDT-independent and prepares for future autoMBD HSP integration. legacy is untouched.

## Objectives and acceptance

- R1: A clean MATLAB session can initialize the current framework by one repository-relative entry point. Markdown remains the type source; the generated script and McData.sldd agree; parameters and enums resolve without manual workspace manipulation.
- R2: Preserve the MotorFramework decomposition: McKernel, McEventHub, McStateMachine, McDataFlow, McFault, McTuning and McDebug. Replace inactive placeholder algorithms with executing components. No commented production logic or MBDT references in active models.
- R3: Deterministic 62.5 us fast control, 1 ms speed regulation. Explicit initialization and reset; no hidden dependence on previous runs. Command/fault inputs have defined priorities. Fault disable occurs within one fast sample, stays latched until an explicit safe reset, and does not auto-restart.
- R4: Run alignment, open-loop start, observer tracking, closed-loop run, controlled stop, and fault/recovery. Sensored control supplies an independently testable baseline; sensorless mode must operate from measured current and applied voltage, without plant truth feedback. Unsupported operating-point requests must result in a declared fallback or fault.
- R5: Implement ADC conversion, amplitude-invariant Clarke/Park/inverse Park, d/q PI regulation with voltage-vector saturation and anti-windup, speed PI with current limiting and anti-windup, centered SVPWM, observer and handover. Disabled inverter commands must be deterministic; gate enable is separate from numerical duty.
- R6: Nominal host scenarios at 12 V: positive and negative speed commands in the feasible range, start/stop/restart, load disturbances, current saturation and recovery, bus voltage limits, injected fault and reset. Steady speed error <=5% (or 5 rad/s electrical near zero), overshoot <=20% at feasible unsaturated points, finite states and bounded duty [0,1], current within configured trip envelope. Numeric tolerances are engineering acceptance targets for the virtual plant, not physical motor measurements.
- R7: Both platform/pil top models execute a closed-loop Normal baseline and actual software-in-the-loop generated C on the host. Compare the same controller and inputs; verify mode is SIL and evidence of host compilation/executable exists. Integer status, fault, timing and gate outputs match exactly in open-loop replay; single outputs satisfy absolute 1e-4 plus relative 1e-4. Continuous duty has a tighter absolute 1e-6 bound. PWM counts may differ by at most one count only when both outputs exactly requantize from their own single duty and every mismatch straddles the same half-count boundary. Preserve and report strict bitwise comparison separately; see the numerical-equivalence decision record. Closed-loop traces must meet physical acceptance independently, with separate drift tolerances justified by quantization.
- R8: Host build scripts must not call deployment, serial, debugger or flashing APIs. Host initialization is independent of SDK, HSP checkout, NXP MBDT, and board configuration. Generated artifacts belong to .agent-env. Future HSP maps the documented sensor/command/timebase/gate/duty interface; no HSP implementation is imported.

## Interface baseline

Retain the framework's logical boundary: phase current acquisition, McControl, fault/command/driving/timer indications, tuning, three duties and diagnostics. Add the missing requested electrical speed, DC bus measurement and optional electrical rotor position inputs explicitly. Use rad and electrical rad/s inside control; pole pairs convert mechanical plant values only at the adapter. Current ADC is offset binary uint16; physical signals and controller state are single. Commands, state codes and faults use defined integer/enum types. Raw PWM counts and normalized duties have explicit scaling, never implicit casts.

Scheduling is synchronous and deterministic on the host. An eventual HSP sampling event calls the same controller step. Slow-rate execution uses an integer fast-tick divider; no wall-clock timing or continuous controller state. Feedback uses the previous applied voltage for the estimator and a unit delay at the inverter/plant boundary.

AppliedVoltageAlpha/Beta are explicit single-precision voltage feedback ports. The adapter reconstructs them from actual delayed PWM counts and gate state with the interval's DC bus, aligned to current acquisition. Own unquantized command voltage is not a substitute for this input. Nonfinite applied-voltage feedback is an input fault.

## Operating domain

Use the motor constants already present in this repository's FOC_Config as initial virtual-plant parameters: Rs=0.56 ohm, Ld=375 uH, Lq=435 uH, flux=0.0039052261 Wb, pole pairs=2, J=1.2e-5 kg m^2, B=0.0005 N m s/rad. These are inherited simulation parameters, not reidentified hardware values. Calibrations and tested speed/load bounds are versioned and reported.

## Research notes

MathWorks Interior PMSM documentation provides dq equations, mechanical dynamics, amplitude-invariant transforms and pole-pair conventions: https://www.mathworks.com/help/autoblks/ref/interiorpmsm.html . Local R2026a APIs must be verified before new API use. HSP documentation supports a pure algorithm/host harness boundary and ordinary Model block SIL; no HSP code is copied. NXP references are inspected only for architectural conventions.
