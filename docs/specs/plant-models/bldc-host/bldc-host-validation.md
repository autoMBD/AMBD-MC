# BLDC host plant validation record

> 历史验证记录：结果仅适用于本文所列日期、运行编号和源码基线，不表示当前修改已重新验收。验证层级与本地证据说明见[验证索引](../../../validation/index.md)。


Validated on 2026-10-06 with MATLAB R2026a through a new, owned session of
the project's pinned official MCP server. No hardware callbacks, legacy
models or PMSM sources were used or modified.

Reproduce from the repository with:

```powershell
python -m unittest discover -s tests/bldc -p test_plant_reference_runner.py -v
python tools/bldc/validate_plant_reference.py
```

The script checks latest Smoke eligibility, checks library settings, builds
the native reference exclusively through `model_edit`, then requires
`model_read` and a healthy `model_check`. It runs twenty-eight MATLAB unit tests
and nine native-reference cases. The final source set, test helpers,
reproduction script and generated native model have recorded SHA-256 hashes. All generated artifacts
remain under `.agent-env/bldc-plant`.
The ten Python publisher tests use mocked MCP responses in isolated
temporary directories. They qualify report integrity, not motor physics.
All five core plant sources remain identical to the original reviewed
baseline.
The final frozen-source reproduction exited 0: 28 MATLAB tests and all nine
native cases passed. All 15 source/model hashes and both report-binding
digests were independently checked against disk after publication.

| Native case | Maximum comparison error | Limit |
|---|---:|---:|
| Open circuit, forward | 1.25111e-6 V | 1e-4 V |
| Open circuit, reverse | 1.25111e-6 V | 1e-4 V |
| Locked rotor | 0.00242458 A | 0.01 A |
| Commutation | 0.0198757 A | 0.03 A |
| All gates off after excitation | 0.0211324 A | 0.03 A |
| Bipolar PWM, settled interval mean | 0.00166514 A | 0.1 A |
| Forward driven terminal case, current | 0.0179563 A | 0.03 A |
| Reverse driven terminal case, current | 0.0167665 A | 0.03 A |
| 32 kHz bipolar PWM, settled interval mean | 0.000777511 A | 0.1 A |

The PWM instantaneous deviation is separately recorded as 0.172901 A;
an average inverter is not expected to reproduce switching ripple.
Native maximum KCL residual is 8.89e-16 A and electromagnetic torque error
against independently interpolated phase shapes is below 1.17e-14 N m.

The added driven terminal cases excite C, disable its switches at 1 ms and
hold A/B active through the expected 3 ms crossing. They check upper-diode
release during forward rotation and lower-diode release during reverse
rotation. The guard windows and limits were written into the test plan
before evaluating these native traces. All three absolute terminal voltages
agree within 0.924 mV in the qualified windows, below the 5 mV limit.

| Driven terminal result | Forward | Reverse |
|---|---:|---:|
| Qualified clamped / released samples | 8 / 39 | 6 / 41 |
| Released C terminal-voltage error | 0.268 mV | 0.348 mV |
| Native C clamp error from its rail | 0.669 mV | 0.567 mV |
| Host crossing time | 3.000000 ms | 3.000000 ms |
| Native crossing time | 2.999869 ms | 2.999857 ms |
| Native crossing slope | -298.282 V/s | -298.278 V/s |
| Theoretical crossing slope | -298.337 V/s | -298.337 V/s |
| Host sampled current release | 1.625000 ms | 1.500000 ms |
| Native current release | 1.571250 ms | 1.462500 ms |
| Release-time difference | 53.75 us | 37.50 us |

Native and host voltage-release detection agrees with each corresponding
current-release detection. The release budget is 63.75 us, comprising one
62.5 us acquisition period plus two native integration steps. Current-based
qualification masks are saved; the event-time checks cover the transition
between clamped and floating windows. Negative fixtures reject voltage bias,
reversed slope, delayed or jointly delayed crossings, delayed release and
empty usable windows. Their missing-helper RED and subsequent GREEN records
are `res-057.json` and `res-058.json`.

The settled mean per-cycle current ripple decreases from 0.351223 A at
16 kHz to 0.175666 A at 32 kHz, a ratio of 0.500155 within the predeclared
[0.4,0.6] interval. Both carrier cases retain their 0.1 A mean-error limit.
This demonstrates ripple convergence without assuming mean error must
decrease when numerical or finite-switch-loss error dominates it.

Unit tests cover the phase/Hall convention, analytic locked-rotor RL and
viscous coast, current continuity, ideal-diode release at zero, all-off
passive energy, overspeed rectification, current conservation, all twelve
signed sector torque responses in the actual mechanical state, ADC
saturation/types and terminal crossing slopes in both directions. Plant
integration errors against an 80-substep calculation decrease from about
0.0061 to 0.0026 when increasing ten substeps to twenty. The all-off energy
increments in the tested trace are negative; no current reset is used.

The native bridge uses explicit finite switch/diode parameters documented
in the test plan. Its initial dq currents are constrained to zero. The
open-circuit oracle includes the finite-leakage RL initial boundary layer
and compares native BEMF separately, including the t=0 sample. Ground-referred
common mode of an entirely open ideal bridge is not uniquely determined;
the open case compares winding voltage relative to neutral.

Failed exploratory runs are retained: missing-function RED in
`res-003.json`, first GREEN in `res-004.json`, native initialization and
near-ideal conditioning diagnostics in later numbered transcripts. Native
local backward Euler integration resolved the stiff switching case without
changing comparison limits. The clean reproduction reports only Simscape
converter library-instance parameter-override notices during first compile;
it has no solver convergence warning or failed physical comparison.

Evidence files are `reproduction-transcript.json`, `results.json`,
`source-hashes.json`, `bldc_native_reference.slx`, and one MAT trace per case.
The original reviewed six-case evidence is preserved in
`baseline-reviewed-20261006`; reproduction also archives preceding artifacts
under `history` before invalidating the current PASS marker and starting a
new run.

Acceptance-integrity regressions reproduced and fixed two defects: a
provisional physical pass could previously precede source verification, and
NaN currents could disappear from voltage qualification masks. The Python
suite now verifies failure handling for prerequisite/import/eligibility
failures, missing or foreign-attempt provisional results, source changes
during simulation and hash writing, hash-write failure, and summary-output
failure. Its successful path asserts that bound hashes exist before PASS
publication. RED is retained in `runner-red.txt` and
`runner-publication-red.txt`; GREEN is `runner-green.txt`.

MATLAB RED `res-064.json` includes the exact masked-NaN regression and other
malformed full-trace cases; GREEN `res-065.json` contains 28 passing tests.
Full finite, real, dimension and time-grid checks now precede all masks.
The authoritative `results.json` remains non-PASS during an attempt;
MATLAB's separate `native-results.json` is explicitly PROVISIONAL and tied
to the attempt ID. Final PASS is published atomically only after source
stability and hash publication checks. The final report binds both evidence
files by SHA-256. On failure, current hashes are removed and the report is
FAILED; prior reports remain in history.

A real run also exercised source-change rejection: its nine native cases
passed provisionally, but a later publisher/test edit changed the source
set, so the authoritative report became FAILED and current hashes were
removed. `publication-source-change-snapshot.json` preserves that outcome.
The subsequent frozen-source run passed and published a matching attempt ID
and checksums. This directly verifies that physical success alone cannot
publish overall PASS.
This acceptance qualifies the virtual host plant within the declared model
domain; controller scenario acceptance and actual PC SIL are separate steps.
