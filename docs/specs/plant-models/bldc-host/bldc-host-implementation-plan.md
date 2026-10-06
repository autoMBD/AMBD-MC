# BLDC host plant implementation plan

1. Freeze the interface and independent physical test expectations.
2. Run the class-based tests through an owned new official MCP session to
   capture RED before writing the five plant package functions.
3. Implement phase shape, Hall mapping, diode active-set network, exponential
   event integration and boundary measurements; obtain GREEN.
4. Inspect native Simscape BLDC parameters and conserving port topology using
   pinned tools. Construct the independent reference only with model_edit.
5. Compare open-circuit BEMF, locked-rotor RL, commutation, all-off and switched
   interval averages; retain reports and source hashes below .agent-env.
6. Supply the core API checkpoint for controller integration while completing
   independent native validation. Record limitations honestly.
