# BLDC staged verification plan

Baseline 2026-10-06. Each gate must execute through the pinned official MCP.
Sources and models are hashed before/after acceptance; generated binaries and
signals remain below `.agent-env`. Missing execution evidence is not PASS.

| Gate | Oracle / concrete cases | Requirements |
|---|---|---|
| Types | Fresh/second initialization, Markdown/dictionary equality, preserved calibration/unowned entries, dirty/foreign dictionary refusal and rollback | B1 |
| Leaf algorithms | Six Hall codes and both directions, exact complementary count sum, invalid sector disable, angle boundaries, conditional-integration saturation and recovery | B3,B4,B6 |
| Feedback | Signed adjacent Hall timing, illegal jumps, stall, wrap-safe tick counts; terminal-only six-sector ZC ramps, wrong slope, blanking, duplicate rejection, 30° delay and timeout | B4,B5 |
| Lifecycle | Reset/idle/alignment/open/acquire/track/run/stop/fault paths, stop at each startup bridge, reversal guard, disabled fast tick, slow divider, finite recovery | B2,B3,B5 |
| Plant | Analytic RL/coast, KCL, torque/power identity, continuity through commutation, freewheel/all-off topology, signed terminal crossing, step-halving, independent native comparison | B7 |
| Integrated Normal | Hall and sensorless top models, physical metrics independent of agreement | B2,B4–B7 |
| Host generated C | Independent ERT build and both real SIL wrappers, compile log/EXE fingerprints, full same-input replay and closed-loop comparison | B8 |
| Regression/delivery | Full PMSM `validate_sil.py`, protected-file hashes, source/license/path checks and three completion audits | B9,B10 |

## Scenario matrix

Scenario functions define exact intervals and assertion windows before evaluating
results. Nominal initial speed is zero. Use distinct ±100/±200 electrical rad/s
profiles, 12 V bus, and 0/0.005/0.01 Nm signed load within the current envelope.
All scenarios include t=0 and a complete fixed grid; no interpolation or time shift
is allowed to hide controller differences.

1. Hall positive speed steps and Hall negative speed steps.
2. Hall low-speed startup, zero request and reversal through a verified stop.
3. Hall load disturbance and 10–14 V bus variation.
4. Hall stop/restart and stop during alignment.
5. Invalid Hall 0/7, illegal jump, stuck Hall under active drive; each must cause
   its specified fault and stay latched until safe reset.
6. External fault recovery, under/overvoltage, overcurrent and nonfinite inputs.
7. Current saturation with a deliberately infeasible load, then load removal;
   require actual limiting dwell and recovery, not merely bounded current.
8. Sensorless positive/negative startup and sustained controlled commutation.
9. Sensorless stop/restart, reversal, and stop during acquisition/transfer.
10. Sensorless low forced speed then a feasible closed-loop request; low stage
    must be labelled open-loop and the high stage must qualify actual ZC control.
11. Sensorless lost/invalid terminal sample stream; time-bounded fault and disable.
12. Separate plant R/L/Ke/inertia variation (bounded ±10% initially), nonzero
    starting angle and finite measurement perturbation, with unchanged controller.

Physical bounds and replay tolerances are fixed in the system specification.
Each scenario produces traces, per-assertion measured values and limits, mode and
fault paths, current/speed peaks, and a comparison plot. Both mode settings and
real SIL start/stop execution evidence must be recorded.

## Acceptance-checker negative tests

Reject truncated final interval, missing samples, nonfinite values, wrong state,
missing closed-loop qualification, wrong/late gate disable, spurious fault,
unbounded reference, a false saturation claim, changed phase mask and changed PWM
counts. A plot or two passing physical loops cannot substitute for replay.

## Regression policy

Observe failing tests before new implementations and fixes. For a code change,
run its focused tests and affected integration gate, then run the full final
matrix once source is frozen. Re-run only when further changes or unresolved
failures justify it. Claims refer to the final source fingerprints.
