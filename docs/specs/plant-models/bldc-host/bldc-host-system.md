# BLDC host plant system specification

The original five-state phase-domain plant supports PC Normal/SIL control
validation. It is a virtual motor, not an identified hardware model. Existing
PMSM and legacy models are excluded from all edits.

Commands u are three uint16 high-side counts, three Boolean phase enables and
a Boolean gate enable. Disturbances w are bus voltage (V) and resisting shaft
load (N m). Measurements y are uint16 current ADC counts, uint8 Hall code and
single terminal voltages. Truth z is single current, electrical angle and
electrical speed; truth must never enter either controller speed regulator.

The interface ticks at 62.5 us. The plant state is double [ia ib ic theta_e
omega_m]'. Initial phase currents must sum to zero. Physical parameters are
phase resistance 0.56 ohm, phase inductance 0.4 mH, phase peak BEMF coefficient
0.0078104522 V/(rad/s mechanical), two pole pairs, inertia 1.2e-5 kg m² and
viscous friction 0.0005 N m s/rad. Nominal bus is 12 V; intended bus range is
8–16 V. The plant supports signed motion, regeneration, commutation and all-off
diode decay without discontinuously clearing winding current.

Evidence is analytic RL/coast dynamics, electromagnetic power conservation,
current conservation, time-step convergence and independent MathWorks Simscape
BLDC/inverter comparisons. Dead time, switching losses, thermal saturation and
hardware ADC aperture effects are outside this average inverter's fidelity.
