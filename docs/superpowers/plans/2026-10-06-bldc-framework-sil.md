# BLDC Framework Implementation Plan

> For agentic workers: use subagent-driven-development for independent plant,
> initialization and review tasks; use test-driven-development and
> verification-before-completion. The user authorizes autonomous execution and
> frequent local commits, with no remote submission or hardware execution.

**Goal:** Complete the BLDC framework milestones and prove actual PC SIL,
including regression through the existing PMSM platform/pil models.

**Architecture:** Typed explicit-state control, original Hall and terminal-voltage
sensorless six-step paths, two active complementary legs plus one floating leg,
independent phase-domain plant and HSP-ready I/O. Preserve the PMSM framework.

**Tech Stack:** R2026a, official pinned MATLAB/Simulink MCP, MATLAB unit tests,
Simulink model reference SIL, Embedded Coder, MinGW64 and Simscape reference.

## Task 1 — Interface and baseline

- [x] Verify clean current branch; create `codex/bldc-models` from `ac4ef18`,
  retaining the user-named ancestor `820f966` and completed PMSM implementation.
- [x] Inspect saved BLDC hardware dependencies and read PMSM framework topology
  through official tools; verify custom-library gate and latest Smoke eligibility.
- [x] Freeze algorithm system/architecture/test contracts, record physical review.
- [ ] Commit specification baseline after link and consistency review.

## Task 2 — Controller components

Files: `mc-models/bldc/algo/+bldc/*.m`, `tests/bldc/bldcAlgorithmsTest.m`,
`tests/bldc/bldcRuntimeTest.m`.

- [ ] Write Hall LUT, signed commutation and PI tests. For example, sector 1 at
  m=1 must output `[65535;0;0]`, enables `[true;true;false]`; reversing torque
  must swap active-leg counts, and invalid sector must disable all phases.
- [ ] Run the tests through MCP and record missing-behavior failures.
- [ ] Implement transforms/quantizer, defaults and explicit state; then Hall and
  ZC feedback with timestamp, blanking, slope and per-sector event guards.
- [ ] Test the 30° delay with synthetic 60° crossings every 160 samples: the
  next commutation is due 80 samples later; wrong slope/duplicates cannot qualify.
- [ ] Implement lifecycle and PI control; prove fault wins over run/reset when
  still active, stop preempts all bridges, gains latch only while disarmed.
- [ ] Run all component tests, review specification then code quality, commit.

## Task 3 — Plant and independent oracle

Files: `+bldc/plant_step.m`, `plant_measure.m`, `phase_network.m`, `trapezoid.m`,
`hall_signal.m`, `tests/bldc/bldcPlantTest.m`, native helper and validation script.

- [ ] Write plant specs and failing analytic/topology tests using the frozen
  phase, motor-constant and complementary PWM contract.
- [ ] Implement phase RL/mechanical equations, diode zero-current release and
  terminal measurements; never reset an outgoing phase current at commutation.
- [ ] Verify locked-rotor current versus V/(2R)*(1−exp(−Rt/L)), KCL and
  mechanical coast versus omega0*exp(−Bt/J); inspect sign and unit conventions.
- [ ] Build an independent native Simscape BLDC reference through official
  model tools; verify BEMF parameterization rather than assuming flux conventions.
- [ ] Run open circuit, driven/commutating and all-off cases plus step/PWM
  convergence checks; save plots and metrics; review and commit verified plant.

## Task 4 — Types and initializer

Files: `docs/BldcStruct.md`, `mc-models/bldc/data`, `commom/BldcData.sldd`,
`bldc_initialize.m`, root `bldc_setup.m`, `tests/bldc/bldcInitializeTest.m`.

- [ ] Define unique buses matching actual fixed-size state/input/monitor fields
  with units, default types and calibrations; use the existing Markdown parser.
- [ ] Write failing tests for fresh and repeated startup, drift rejection,
  calibration preservation, dirty/unowned dictionary guard and transaction rollback.
- [ ] Implement normal verification and explicit synchronization; preserve
  unrelated entries and keep generated type scripts/caches below `.agent-env`.
- [ ] Run tests and Code Analyzer, review schema and API, commit verified types.

## Task 5 — Models and Normal integration

Files: `tools/bldc/build_models.py`, `BLDCFramework.slx`, `platform/codegen`
wrappers, Hall and sensorless `platform/pil` wrappers/top models, host helpers.

- [ ] Back up the old BLDC hardware wrapper below `.agent-env`; build new model
  scopes with official model_edit; read/check each scope before saving.
- [ ] Wire explicit state delay, typed inputs, controller outputs and the
  one-interval delayed plant actuator/measurement metadata contract.
- [ ] Confirm no truth feedback into either speed regulator and no active
  board callbacks/library references; compile every production model.
- [ ] Run physical Normal scenario matrix and resolve control/plant failures
  with focused failing tests. Review model structure and commit integration.

## Task 6 — Actual SIL and delivery

Files: `tools/bldc/validate_sil.py`, replay/assessment helpers, README, report.

- [ ] Write acceptance-negative tests for missing samples, false saturation,
  wrong states/masks/PWM and late fault response; verify checker rejection.
- [ ] Configure matching ERT host options, build standalone C and both real
  SIL wrappers; collect compiler, source hashes and executed binary evidence.
- [ ] Run full Normal/SIL physical matrix, captured-input replay and plots;
  require all individual checks, full matrix and unchanged-source fingerprint.
- [ ] Run `python tools/pmsm/validate_sil.py` for the explicitly requested PMSM
  regression, verify protected hashes, `python tools/test_check_spdx.py` and
  `git diff --check`; no feature completion inferred from partial runs.
- [ ] Audit three times: missing functionality, inadequate evidence, then
  reproducibility/scope. Commit verified validation and document boundaries.
- [ ] Deliver final report, startup commands, local commit history and all
  unresolved limitations; close only this task's owned MATLAB sessions.
