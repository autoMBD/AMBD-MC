# BLDC terminal-voltage acquisition decision

Date: 2026-10-06. These are development experiments, not the final SIL result.

The first original six-step controller used 3.5 A forced startup followed by
armed floating-phase zero crossing. Its Hall path regulated 200 electrical rad/s,
but the sensorless path remained in forced startup at approximately 120 rad/s.
The recorded rotor phase led the forced commutation frame by about 55 degrees;
the relevant floating-phase crossing occurred before the new sector's usable
sampling window. Traces are under `.agent-env/bldc-development/`.

Independent integration of the trapezoidal torque gives the mean torque factor
`1-delta^2/7200` for phase lead delta in degrees, 0–60. At the nominal 120 electrical
rad/s, the necessary current is about 1.9205 A; a fixed 3.5 A predicts about
57 degrees phase lead, matching the observed failure. Reducing startup current
to 2 A passed nominal acquisition but failed with +10% plant Ke. Thus a nominal
tuning change alone did not establish the required parameter robustness.

The adopted acquisition stage briefly turns all gates off. It waits for measured
phase-current decay and rejects terminal voltages near a rail-clamped span. With
open windings, terminal voltages differ from their BEMF only by common mode.
Two fresh samples determine phase and speed without current differentiation,
R/L/Ke compensation, rotor truth, or a back-EMF output port from the plant.

For direction-normalized voltages, max/min phase identities identify the sector.
Let `r=(2*v_middle-v_max-v_min)/(v_max-v_min)`. Its exact electrical angle in
degrees is `[60-30r,120+30r,180-30r,240+30r,300-30r,360+30r]` for sectors 1–6.
The source/sink mapping is the same independently declared physical convention;
the angle computation does not invoke the plant implementation.

The seed initializes provisional commutation only. It cannot set FeedbackReady
or increase the real ZcCount. The first armed floating-phase event starts timing;
subsequent events establish the actual period. Closed-loop qualification requires
six genuine events. Residual current, frozen voltage, wrong direction, too-small
span and diode-clamped samples are rejected. The maximum acquisition interval
and later ZC-loss timeout cause safe disable when feedback cannot be established.

Unit tests cover both directions and all six sector voltage ratios, residual
current and unusable spans, fresh-sample speed and zero genuine-edge count after
seeding. Full model Normal/SIL and plant-parameter corners remain mandatory.
The average inverter uses complementary bipolar active legs and a physically
floating third leg; this method must not be transferred to an all-three-driven
average inverter.
