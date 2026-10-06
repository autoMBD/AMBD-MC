# PMSM Host Plant: System and Architecture

Updated 2026-10-06. Purpose: repeatable software control and generated-C verification, not power-electronics/hardware qualification.

The host plant is independent of controller state and runs double-precision dq electrical dynamics plus mechanical speed/electrical angle. Its four states are id, iq, mechanical rad/s and electrical rad. Inputs are normalized duty, independent gate-enable, measured DC voltage and signed external load torque; outputs are phase-current ADC counts and optional encoder angle, with speed/current/angle truth on separate logging channels. Sensorless control cannot receive truth through its observer interface.

Use the Rs/Ld/Lq/flux/pole-pair/J/B values inherited from this repository's FOC_Config, documented in the controller system specification. No hardware identification claim is made. The average inverter applies Vdc*(duty-mean(duty)); gate-off approximates winding decay and mechanical coast. Body diodes, deadtime, switching ripple, thermal behavior and DC-link regeneration are outside this software-validation plant. An active external load can back-drive a gate-disabled motor; stop tests specify whether load is removed or retained.

Dynamics follow the MathWorks Interior PMSM dq/mechanical equations: https://www.mathworks.com/help/autoblks/ref/interiorpmsm.html . RK4 with four substeps per controller interval integrates the physical states. An explicit Unit Delay in the harness means each interval uses the previous command. The observer uses that same reconstructed applied voltage. Physical states use double; sensor adapters quantize to uint16 at 1000counts/A and offset32768; controller values use single.

Normal and SIL use exactly the same plant and scenarios. This isolates differences in generated controller code. Separate analytic plant checks and comparison with the official PMSM plant are required to avoid treating two identical wrong loops as validation.
