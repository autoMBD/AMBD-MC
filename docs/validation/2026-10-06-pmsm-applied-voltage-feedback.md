# Applied-voltage feedback for the PMSM observer

Date: 2026-10-06. This is a causal interface correction; replay tolerances are unchanged.

The first complete sensorless Normal/SIL fixed-input replay failed materially.
Both paths entered TRACKING at 1.3405 s, but their magnetic-flux estimates then
diverged. SIL lost observer qualification at 1.4396875 s and took a different
state transition on the next tick. Duty error ultimately reached 0.88. This
failure is distinct from an adjacent PWM count crossing a rounding boundary.
The initial failed report is retained under `.agent-env/pmsm/replay/sensorless_forward/`.

The observer integrated its own prior unquantized command voltage. During a
current recording replay, that command can differ from the voltage that produced
the recorded currents. The angle/controller/voltage feedback then closes an
internal loop without the corresponding physical current response.

An isolated experiment copied only this repository's function into an ignored
experiment directory. It changed only the observer voltage source and perturbed
one flux state at entry to TRACKING. A 64-ULP seed (2.98e-8 Wb) with own-command
voltage grew to 0.0191 Wb and changed the lifecycle. With recorded actual PWM
voltage, the flux difference decayed to zero and no mode or qualification
difference occurred. Frozen-time finite-difference Jacobians at 1.38 s gave a
dominant eigenvalue near 1.03 for own-command feedback across three step sizes.
These are diagnostic results for the recorded trajectory, not a global stability
proof or hardware measurement. Artifacts are in `.agent-env/pmsm/replay-experiment/`.

The controller now accepts AppliedVoltageAlpha/Beta, packed as
`tMcInput.AppliedVoltage`. The host adapter reconstructs the stationary voltage
from actual delayed PWM counts, delayed gate state and the DC bus used for that
plant interval. Gate-off feedback is zero under the declared average-inverter
abstraction. Replay uses those same recorded inputs, alongside the recorded
currents. The monitor still exposes the newly requested modulation voltage.

Regression tests require the observer result to follow applied feedback even
when its prior command-voltage state differs, and require nonfinite feedback to
disable the gate through input fault16. Both tests failed before the correction.
Model integration, closed-loop physical acceptance and same-input actual SIL
replay must all be rerun after this interface change; the isolated experiment
alone does not satisfy acceptance.

The [final full acceptance run](2026-10-06-pmsm-sil-acceptance.md) completed
these integration gates for all 13 scenarios; every same-input actual SIL
comparison passed strict bitwise equality after the subsequent math fix.

For future HSP integration, supply feedback for the actual PWM interval aligned
with ADC acquisition. Account for any rejected/limited command and relevant
inverter compensation. Neither rotor truth nor an independently recomputed
controller command may stand in for applied-voltage feedback.
