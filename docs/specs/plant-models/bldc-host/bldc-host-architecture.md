# BLDC host plant architecture

The motor uses three equal RL windings with an isolated star neutral:
L di/dt = v - vn - R i - e, sum(i)=0. The periodic phase shape is linear
-1 to +1 over -30 to 30 electrical degrees, +1 through 150, linear to -1
through 210, then -1 through 330. Other phases are shifted -120 and +120.
BEMF is Ke omega_m f and torque is Ke dot(f,i), so electrical conversion
power equals torque times mechanical speed. Mechanical dynamics are
J domega/dt = torque - load - B omega; dtheta_e/dt = polePairs omega.

Enabled poles reconstruct bus*counts/period. Disabled poles are genuinely
floating at zero current, lower-diode clamped at positive current and
upper-diode clamped at negative current. The neutral is solved from the
conducting subset; zero-current poles join it only when their candidate
floating voltage exceeds the rails. With no conducting winding the neutral
is centered in the feasible floating interval. Excess BEMF span initiates
rectification through the extreme phase pair.

When all phases carry zero current and all switches are off, ideal topology
does not uniquely determine ground-referenced common mode. The midpoint
choice makes reporting deterministic and does not change winding voltage or
current dynamics. A native bridge with finite off-state leakage fixes a
different common mode; the open-circuit oracle therefore compares winding
voltages relative to neutral. During normal two-leg conduction the active
poles fix neutral, and the floating terminal crossing is directly comparable.

Each substep freezes BEMF and integrates each RL branch exponentially.
An inactive diode reaching zero current ends that segment exactly; topology
is then resolved again. This preserves current continuity and avoids applying
a conducting diode past its zero-current event. Torque uses interval-average
current; mechanical friction is integrated exponentially. Sensors share the
same topology solution and quantize only at the boundary.

Hall sector = floor(mod(theta_e-pi/6,2pi)/(pi/3))+1, with codes
[5 4 6 2 3 1]. VoltageValid belongs to the external acquisition interface;
the plant does not use hidden rotor information to qualify samples.
