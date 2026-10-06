# PMSM Host Plant: Implementation and Validation

Updated 2026-10-06.

1. Implement the original mc.plant_step dq/mechanical derivative and RK4 integrator, then mc.plant_measure for current transforms and ADC quantization.
2. Validate unenergized equilibrium, coast exponential J/B, current RL exponential L/R, positive-q torque direction, and signed load acceleration independently of controller code. Tests are in test_mc_plant.m.
3. Compare the gate-enabled averaged plant against the official Interior PMSM block using the same physical parameters and prescribed voltage/load, including nonzero initial angle and both torque directions. Use bounded differences consistent with numerical integration/measurement sampling; report sample interval and measured errors.
4. Connect the complete controller in the existing platform/pil top models, log plant truth separately, and test closed-loop feasibility before SIL.
5. Repeat representative nominal and disturbed cases with half the plant integration step; require steady speed/current conclusions unchanged and quantify trajectory difference.

Artifacts, temporary comparison models and traces belong to .agent-env. No NXP/HSP model internals are copied and no hardware calls are used.
