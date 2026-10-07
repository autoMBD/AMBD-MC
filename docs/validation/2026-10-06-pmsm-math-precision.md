# Portable evaluation of PMSM transcendental functions

> 历史验证记录：结果仅适用于本文所列日期、运行编号和源码基线，不表示当前修改已重新验收。验证层级与本地证据说明见[验证索引](index.md)。


Date: 2026-10-06. Controller state, calibrations and signal interfaces remain
single precision. Selected transcendental functions evaluate in double before
rounding back to the input precision. No acceptance tolerance is changed.

## Reproduced failure

After the applied-voltage interface correction, actual sensorless Normal and
SIL closed loops both passed. Fixed-input replay had exact lifecycle, fault,
tick, gate and observer qualification outputs, but failed numerical acceptance:
maximum duty difference was 0.0035324 (232 PWM counts). A small speed/reference
difference accumulated through the current PI under fixed recorded currents.
The report is retained in `.agent-env/pmsm-applied-feedback-forward/Replay/`.

## Causal isolation

The unchanged generated C was compiled with a small independent host driver.
Its complete 52,801-sample, 36-column output matched the actual SIL recording
bit for bit, validating the diagnostic driver and input serialization.

Normal MATLAB Function execution used LLVM code calling MathWorks
`muSingleScalarCos`, `Sin`, `Atan2` and `Sqrt`; ERT C called the host C library's
single-precision functions. The inspected LLVM operations had no fast-math,
contract or FMA flags. The following experiments preserved generated source
hashes and changed only the selected math implementation:

| Experiment | Result |
|---|---|
| Original generated C and host library | Exactly reproduces actual SIL, including the failure |
| C math calls routed to the Normal single-precision math library | Exactly reproduces all recorded Normal outputs |
| Double evaluation on the C side alone | Still differs from the old Normal implementation |
| Double evaluation followed by original-precision rounding on both sides | All 52,801 × 36 outputs bitwise equal; zero differing elements |

Artifacts, compilation logs, source hashes and comparison scripts are in
`.agent-env/pmsm-math-probe/`. The last result is an isolated algorithm experiment;
full Simulink Normal and actual SIL must also pass after integration.

Final integration evidence is now available in the
[full acceptance report](2026-10-06-pmsm-sil-acceptance.md): all 13 actual
Normal/SIL replay pairs pass strict bitwise comparison, including PWM counts.

## Implementation choice

Use double evaluation for `sin`/`cos` in Park, inverse Park and observer
initialization; for `sin`/`cos`/`atan2`/`sqrt` in the flux observer; and for the
current controller's vector-magnitude `sqrt`. Explicitly cast the result back
to its original precision. Existing double constants and host-plant arithmetic
are unchanged. This improves rounding consistency across math libraries without
coarsening outputs, resetting integrators during comparison, or feeding rotor
truth into the sensorless controller.

The production code uses standard C math, not MathWorks runtime-library calls.
No state or bus is widened. This choice does introduce double transcendental
evaluation cost; execution time on a future MCU/HSP target is not established by
PC SIL and must be measured during that target's integration.

MathWorks identifies math-library implementations, algorithm sensitivity and
open/closed-loop behavior as possible sources of model/code differences, and
recommends locating the differing computations. See
[Numerical consistency of model and generated code](https://www.mathworks.com/help/rtw/ug/numerical-consistency-of-model-and-generated-code-simulation-results.html).
The causal conclusion above comes from this project's controlled experiment.
