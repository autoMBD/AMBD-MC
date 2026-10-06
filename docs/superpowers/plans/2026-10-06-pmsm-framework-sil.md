# PMSM Framework Implementation Plan

> **For agentic workers:** Execute with subagent-driven-development for independent tasks, following test-driven-development and verification-before-completion. User authorizes autonomous implementation and saving local artifacts; no remote submission or hardware execution.

**Goal:** Complete the current PMSM framework and verify generated C in PC SIL through the platform/pil models.

**Architecture:** Retain MotorFramework module responsibilities and typed data structures; implement deterministic host-portable control functions and model-level orchestration. Separate controller, host plant, and future HSP I/O adapter. Keep all generated build/test artifacts in .agent-env.

**Tech Stack:** MATLAB/Simulink R2026a, Stateflow, Embedded Coder, Simulink Test, official pinned MCP, MinGW64 host compiler.

## Task 1: Types, dictionary and initialization

Files: docs/McStruct.md, tools/generate_data_type_from_md.m if necessary, mc-models/pmsm/data/mc_data_types.m, mc-models/pmsm/commom/McData.sldd, mc-models/pmsm/mc_initialize.m, tests/pmsm/test_mc_initialize.m.

- [x] Test clean-session initialization, dictionary/generated type equivalence, enum defaults, deterministic parameter initialization and repeated execution.
- [x] Implement an idempotent path-relative initializer and explicit dictionary synchronization; protect unrelated dictionary entries.
- [x] Run MATLAB unit tests through MCP, then check MotorFramework compilation.
- [x] Review specification compliance and code quality before integration.

## Task 2: Frozen controller contract and component algorithms

Files: algorithm system/architecture specs, mc-models/pmsm/algo/+mc/*.m, tests/pmsm/test_mc_algorithms.m.

- [x] Document port units, rates, current/duty conversion, fault priority, lifecycle transitions and parameter meanings.
- [x] Write analytic tests for transforms, PI saturation/reset/recovery, SVPWM, current calibration and observer synthetic trajectories; observe failures before implementation.
- [x] Implement original single-precision controller functions with explicit state and calibrations. No external reference project dependency.
- [x] Add startup/handover/stop/fault transition tests and test all named modes.

## Task 3: Integrate the existing framework

Files: mc-models/pmsm/algo/MotorFramework.slx and data schema extensions.

- [x] Inspect each scope with official model_read before model_edit. Preserve named architectural modules; replace inactive placeholder behavior.
- [x] Wire state, control, estimation, protection, tuning and diagnostics; explicitly order sampling and output updates.
- [x] Check connectivity/Stateflow lint, compilation and component behavioral tests. Save the completed model and dictionary.

## Task 4: Host plant and MBDT-independent platform

Files: mc-models/pmsm/platform/pil/FOC_PIL_Algth_model.slx, FOC_PIL_Algth_top.slx, FOC_PIL_StateMch_model.slx, FOC_PIL_StateMch_top.slx; platform/codegen models/configuration; host validation scripts.

- [x] Retain the existing platform model identities and implement explicit host adapters around the new framework. Remove active MBDT callback/target/library dependencies.
- [x] Integrate a physically validated PMSM plant/inverter with a documented voltage delay, input profiles and truth-only logging.
- [x] Run closed-loop Normal tests before SIL. Exercise positive/negative speed, load, voltage variation, stop/restart and faults.
- [x] Configure ERT C for PC execution and generate/compile host code under .agent-env. Execute SIL with ordinary Model blocks; never PIL/deploy.

## Task 5: Reproducible acceptance and delivery

Files: tests/pmsm, mc-models/pmsm/README.md, docs/specs and validation documentation.

- [x] Execute component tests, both host harnesses, deterministic Normal/SIL replay and closed-loop SIL scenarios.
- [x] Save signal traces, numeric comparisons, compiler/mode evidence and scenario-level acceptance metrics under .agent-env.
- [x] Verify all protected reference files and legacy are unchanged; verify no new remote operations or hardware calls occurred.
- [x] Review requirements against actual artifacts; resolve all material findings. Audit three times for omitted functionality, inadequate tests and reproducibility before completion.

No commits are required for execution; leave changes reviewable on the current branch.

Acceptance completed 2026-10-06. See [final evidence and three-pass audit](../../validation/2026-10-06-pmsm-sil-acceptance.md).
