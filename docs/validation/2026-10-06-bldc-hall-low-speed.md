# BLDC Hall low-speed gain scheduling

> 历史验证记录：结果仅适用于本文所列日期、运行编号和源码基线，不表示当前修改已重新验收。验证层级与本地证据说明见[验证索引](index.md)。


Date: 2026-10-06. The complete preliminary Normal matrix
`20261006T041159Z-0232c41c` passed 32 of 33 cases. The sole failed case was
`hall_low_speed`: its 20 electrical rad/s request produced sustained speed
oscillation, approximately 5.4–38.9 rad/s late in the trace. The steady error,
ripple and directional overshoot gates all rejected it.

At this operating point, six Hall edges per electrical turn provide about
19.1 speed observations per second. The nominal 8-Hz speed-loop natural frequency
was too aggressive for that delayed, intermittent speed measurement. The trace
showed estimated speed lagging actual acceleration/deceleration while the PI
alternately raised current and saturated at zero. This was a control failure,
not a tolerance or Simulink transport issue.

A controlled isolated run changed only the Hall speed PI gains to Kp*0.25 and
Ki*0.0625. It reduced late mean absolute error to approximately 0.017 rad/s and
peak-to-peak ripple to 0.147 rad/s. The implementation therefore schedules Hall
gains by `scale=clamp(abs(request)/HallGainSpeed,HallMinGainScale,1)`:
Kp is multiplied by scale, Ki by scale squared. Defaults are 80 electrical rad/s
and minimum scale 0.2. This gives approximately 2-Hz natural frequency at the
20-rad/s test point. The current-unit integral state remains continuous, and the
existing fast-rate current slew limiter bounds request transitions.

Sensorless gains are unchanged. Above 80 electrical rad/s Hall gains are also
unchanged. Parameters are defined in the canonical type source and validated
on initialization. New leaf tests check low-speed scheduling, signed requests
and unchanged sensorless behavior. The actual `hall_low_speed` Normal model
rerun passed all original gates with 64,001 samples and 1.517 A peak current.
The final matrix also includes a 20→100→20 Hall speed-range case to exercise
gain transitions; complete SIL and replay evidence remain independent gates.

All original failed traces and the controlled experiment remain under
`.agent-env/bldc/validation/20261006T041159Z-0232c41c` and
`.agent-env/bldc-development`. No physical acceptance threshold was changed.
