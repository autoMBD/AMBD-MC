# PMSM Framework Test Plan

Updated 2026-10-06. Derived from requirements R1-R8 in the system specification.

| Requirement | Test and oracle | Acceptance |
|---|---|---|
| R1 | Temporary dictionary from Markdown; typed motor/enum defaults; second initialization; drift and dirty-user-data tests | No missing types; exact type equivalence; no repeated save; preserve unowned values |
| R3 | Explicit tick pause/divider; reset; 16-state lifecycle; fault on current/voltage/input; reset while fault persists | No control advance without driving tick; speed loop exactly once per16ticks; gate false within one sample; latch clears only on safe reset |
| R4 | Sensored start; sensorless positive/negative startup; confidence loss; stop/reversal/restart | All specified transitions exercised, no truth input in sensorless estimator, finite estimates, declared fallback/timeout |
| R5 | Analytic balanced Clarke, round-trip Park, q-axis polarity, PWM voltage reconstruction, saturated PI/recovery, observer rotating-flux oracle | Transform error <2e-6; bounded modulation/voltage; no outward windup; observer synthetic angle error <0.06 rad and speed error <4 rad/s |
| R6 | Closed-loop profiles through platform top models: speed step/ramp, load step, bus variation, restart/reversal, faults | Feasible steady error <=5% or5electrical rad/s; overshoot<=20%; bounded current/duty; all states finite |
| R7 | Normal and host SIL from the same controller and input recording; both platform/pil top models | Actual SIL mode and host executable/build evidence; integer statuses exact; float replay abs1e-4+rel1e-4; continuous duty abs1e-6; PWM adjacency/half-boundary/requantization proof with max1count; strict bitwise result retained; both closed loops meet R6 independently |
| R8 | Scan active model saved XML, sources and callbacks; inspect protected-source hashes; output paths | No active MBDT dependency or hardware invocation; external references/legacy unchanged; all binaries/evidence confined to .agent-env |

Tests run first against missing implementations to establish failure, then through official MATLAB MCP. Closed-loop tuning does not loosen acceptance after observing failures; any changed operating domain or tolerance needs an explicit engineering rationale in the report. Model agreement alone is insufficient: plant open-loop physics checks and controller behavioral checks are independent gates.

The closed-loop comparison additionally bounds maximum Normal/SIL drift at
1 electrical rad/s, 0.1 A phase current and 0.01 normalized duty, with identical
fault bits. These are conservative behavioral discrepancy budgets: respectively
one fifth of the minimum steady-speed tolerance, one percent of the nominal
current trip and one percent modulation. Quantization perturbations propagate
through independently evolving plants, so these bounds are separate from the
much tighter same-input replay tolerances. Gate and mode mismatch sample counts
are reported; fault latency, disable windows and lifecycle requirements remain
mandatory independently for both runs. The limits are declared before evaluating
the revised applied-voltage interface.

Overshoot is checked separately for each commanded direction and speed window,
including 100 rad/s before the sensored 200-rad/s step and the -150-rad/s reversal.
The saturation scenario must spend at least 0.1 s above 99% of the 6-A reference
limit during the load interval, never exceed that limit, and recover below 95%
in its final steady window. Negative tests reject missing timing evidence,
forged adjacent PWM counts, changed states and missed current saturation.
