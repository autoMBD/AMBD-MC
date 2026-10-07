# PMSM Normal/SIL numerical-equivalence decision

> 历史验证记录：结果仅适用于本文所列日期、运行编号和源码基线，不表示当前修改已重新验收。验证层级与本地证据说明见[验证索引](index.md)。


Date: 2026-10-06. Applies to the host verification configuration, PWM period65535, single-precision controller and the documented scenarios. This is an explicit engineering update to the initial acceptance proposal, made under the user's authorization to resolve unspecified technical choices autonomously.

## Evidence before the decision

The first fixed-input replay used the initial strict requirement: every integer output, including PWM timer counts, identical. It FAILED that strict comparison. The original report is retained in `.agent-env/pmsm/replay/sensored_steps/initial-result.json`.

The recorded closed-loop Normal output and reconstructed-input replay Normal output matched bit for bit for all48,001samples, proving recording/time alignment. Replay Normal versus actual SIL had exact state, fault, tick, gate, observer-ready, position-mode and debug values. All floating fields met abs1e-4+rel1e-4. The only strict mismatch was800 of144,003phase PWM elements, each exactly1count apart.

Independent inspection of the saved HDF5 traces established:

- Both complete PWM arrays equal the specified quantizer applied to their respective logged single-precision duty arrays.
- Every mismatch is an adjacent integer pair straddling the same half-count threshold; zero exceptions.
- Maximum continuous duty difference:4.172325134277344e-7.
- Maximum scaled difference before rounding:0.02734375counts.
- Example at0.3260625s, phaseB:32642.500 and32642.498046875 correctly round to32643 and32642.

Raw classification is retained in `quantization-classification-independent.json` and the800-row `pwm-mismatch-classification.csv` beside the replay report. Generated controller arithmetic was not changed to force a passing comparison.

## Accepted rule

1. State, fault, tick, gate, observer-ready, position mode and debug integer/boolean outputs remain exact.
2. Floating values retain abs1e-4+rel1e-4; continuous duty uses the tighter absolute1e-6 bound.
3. PWM may differ by at most1timer count only if both full arrays exactly match their own quantization, and every mismatch is an adjacent pair on the same half-count boundary. A difference without that proof fails.
4. Report strict bitwise equality separately. A quantization-aware pass must never be described as bit-identical output.
5. Closed-loop physical behavior is checked independently for Normal and SIL; replay equivalence does not replace tracking, current, fault or lifecycle tests.

At the configured65535count period, one count is1/65535 normalized duty (about0.00153%). At12V it corresponds to approximately0.183mV of pole voltage. This explains why a finite-precision difference smaller than one continuous-duty tolerance can produce adjacent discrete codes. These limits are specific to this host configuration; a future HSP timer resolution/compiler requires fresh verification.

MathWorks documents configurable numerical tolerances for [back-to-back testing](https://www.mathworks.com/help/sltest/ug/back-to-back-equivalence-testing.html) and [simulation-data comparisons](https://www.mathworks.com/help/simulink/ug/compare-simulation-data.html). Those references justify tolerance-based numerical comparison generally; the concrete PWM rule above is this project's measured, independently checked engineering decision.

## Subsequent implementation corrections

The initial evidence above predates the explicit applied-voltage feedback and
[portable math evaluation](2026-10-06-pmsm-math-precision.md) corrections. The
acceptance rule remains unchanged, but each final report recomputes strict
bitwise equality for the current implementation. Historical mismatch counts
must not be presented as final-run results.
