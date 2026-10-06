# BLDC implementation sequence

Baseline 2026-10-06. The system/architecture contracts gate integration.
Detailed tracked steps and commit checkpoints are in
[the work plan](../../../superpowers/plans/2026-10-06-bldc-framework-sil.md).

1. Verify base branch, official tools, eligibility and protected-source inventory;
   freeze units, bipolar PWM, sampled-terminal timing, Hall/sector map and state API.
2. Write failing leaf/controller tests; implement original six-step algorithms,
   feedback, PI control, state management and fault containment; run focused tests.
3. Independently implement/verify phase plant with diode continuity and a native
   MathWorks oracle. It may proceed separately after the phase/parameter contract.
4. Generate unique Markdown-backed buses; build transactional initializer and
   dictionary tests. Compile bus interfaces before model wiring.
5. Build/read/check the framework, codegen wrappers, Hall/sensorless top models
   through official tools. Keep generated artifacts below `.agent-env`.
6. Execute Normal physical profiles, actual SIL, same-input replay, negative
   acceptance tests and PMSM regression; save reports and measured tolerances.
7. Audit requirements/verification/reproducibility, commit each verified stage,
   and deliver the exact commands, report links, limitations and local history.
