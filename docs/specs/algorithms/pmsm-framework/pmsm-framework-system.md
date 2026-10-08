# PMSM Framework System Specification

Public system requirements and interface contract.


## Objectives and acceptance

- R1: A clean MATLAB session can initialize the current framework by one repository-relative entry point. Markdown remains the type source; the generated script and McData.sldd agree; parameters and enums resolve without manual workspace manipulation.
- R2: Preserve the MotorFramework decomposition: McKernel, McEventHub, McStateMachine, McDataFlow, McFault, McTuning and McDebug. The shared McControllerLibrary supplies the executable algorithm to HSP components.
- R3: Deterministic fast control at the selected target period (62.5 us host/S32K344; 125 us S32K144), 1 ms speed regulation. Explicit initialization and reset; no hidden dependence on previous runs. Command/fault inputs have defined priorities. Fault disable occurs within one fast sample, stays latched until an explicit safe reset, and does not auto-restart.
- R4: Run alignment, open-loop start, observer tracking, closed-loop run, controlled stop, and fault/recovery. Sensored control supplies an independently testable baseline; sensorless mode must operate from measured current and applied voltage, without plant truth feedback. Unsupported operating-point requests must result in a declared fallback or fault.
- R5: Implement ADC conversion, amplitude-invariant Clarke/Park/inverse Park, d/q PI regulation with voltage-vector saturation and anti-windup, speed PI with current limiting and anti-windup, centered SVPWM, observer and handover. Disabled inverter commands must be deterministic; gate enable is separate from numerical duty.
- R6: Nominal host scenarios at 12 V: positive and negative speed commands in the feasible range, start/stop/restart, load disturbances, current saturation and recovery, bus voltage limits, injected fault and reset. Steady speed error <=5% (or 5 rad/s electrical near zero), overshoot <=20% at feasible unsaturated points, finite states and bounded duty [0,1], current within configured trip envelope. Numeric tolerances are engineering acceptance targets for the virtual plant, not physical motor measurements.
- R7: Both platform/pil top models execute a closed-loop Normal baseline and actual software-in-the-loop generated C on the host. Compare the same controller and inputs; verify mode is SIL and evidence of host compilation/executable exists. Integer status, fault, timing and gate outputs match exactly in open-loop replay; single outputs satisfy absolute 1e-4 plus relative 1e-4. Continuous duty has a tighter absolute 1e-6 bound. PWM counts may differ by at most one count only when both outputs exactly requantize from their own single duty and every mismatch straddles the same half-count boundary. Preserve and report strict bitwise comparison separately. Closed-loop traces must meet physical acceptance independently, with separate drift tolerances justified by quantization.
- R8: autoMBD HSP 0.1.0 owns explicitly selected S32K144/S32K344 target configuration, RTD API binding and PIL. Host harnesses remain Normal/SIL references. Source models contain portable settings; local tools, isolated build copies and generated artifacts remain below .agent-env.

## Interface baseline

Retain the framework's logical boundary: phase current acquisition, McControl, fault/command/driving/timer indications, tuning, three duties and diagnostics. The boundary includes requested electrical speed, DC bus measurement and optional electrical rotor position inputs. Use rad and electrical rad/s inside control; pole pairs convert mechanical plant values only at the adapter. Current ADC is offset binary uint16; physical signals and controller state are single. Commands, state codes and faults use defined integer/enum types. Raw PWM counts and normalized duties have explicit scaling, never implicit casts.

Scheduling is synchronous and deterministic on the host. An HSP sampling event calls the same controller step. Slow-rate execution uses an integer fast-tick divider; no wall-clock timing or continuous controller state. Feedback uses the previous applied voltage for the estimator and a unit delay at the inverter/plant boundary.

AppliedVoltageAlpha/Beta are explicit single-precision voltage feedback ports. The adapter reconstructs them from actual delayed PWM counts and gate state with the interval's DC bus, aligned to current acquisition. Own unquantized command voltage is not a substitute for this input. Nonfinite applied-voltage feedback is an input fault.

## Operating domain

Use the motor constants declared in mc.defaults as initial virtual-plant parameters: Rs=0.56 ohm, Ld=375 uH, Lq=435 uH, flux=0.0039052261 Wb, pole pairs=2, J=1.2e-5 kg m^2, B=0.0005 N m s/rad. These are inherited simulation parameters, not reidentified hardware values. Calibrations and tested speed/load bounds are versioned and reported.

## References

MathWorks Interior PMSM documentation provides dq equations, mechanical dynamics, amplitude-invariant transforms and pole-pair conventions: https://www.mathworks.com/help/autoblks/ref/interiorpmsm.html . HSP 0.1.0 provides target configuration, native API blocks and ordinary Model block SIL/PIL. Shared controller libraries keep the algorithm independent of peripheral initialization.
