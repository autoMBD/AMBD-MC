# SPDX-License-Identifier: MIT
"""Create the ignored BLDC SIL replay harness with matching host configuration."""
from __future__ import annotations
import sys
from build_models import ARTIFACTS,ROOT,Builder,quote

def create_replay(call,force=False):
    path=ARTIFACTS/'BLDC_SIL_Replay.slx'
    if path.exists() and not force:
        print(f'Replay harness already exists: {path}')
        return
    builder=Builder(call);builder.seq=500
    gate=builder.matlab('disp(jsonencode(library.settingsLookup()));')
    if not ('"found":false' in gate or '"gatePass":true' in gate):raise RuntimeError(gate)
    result=builder.matlab(f'addpath({quote(ROOT)});info=bldc_setup();'+
      "assert(~bdIsLoaded('BLDC_SIL_Replay'),'bldc:ReplayAlreadyLoaded','Refusing to replace a loaded replay harness.');"
      "open_system('BLDC_PIL_Sensorless_top');disp('REPLAY SETUP PASS');")
    if 'REPLAY SETUP PASS' not in result:raise RuntimeError(result)
    builder.read('BLDC_PIL_Sensorless_top')
    builder.wrapper('BLDC_SIL_Replay',ARTIFACTS,'BLDC_PIL_Sensorless_model',compile_model=False)
    # Copy the complete active ConfigSet before compiling. Individual option
    # copying misses host/codegen compatibility settings in referenced models.
    result=builder.matlab("replayConfig=copy(getActiveConfigSet('BLDC_PIL_Sensorless_top'));"
      "replayConfig.Name='HostReplayConfiguration';attachConfigSet('BLDC_SIL_Replay',replayConfig,true);"
      "setActiveConfigSet('BLDC_SIL_Replay',replayConfig.Name);"
      "set_param('BLDC_SIL_Replay','SimulationCommand','update');"
      f"save_system('BLDC_SIL_Replay',{quote(path)});disp('REPLAY BUILD PASS');")
    if 'REPLAY BUILD PASS' not in result:raise RuntimeError(result)
    builder.read('BLDC_SIL_Replay');builder.check('BLDC_SIL_Replay')

if __name__=='__main__':
    sys.path.insert(0,str(ROOT/'tools/agent'))
    import configuration,environment
    from mcp_client import Client
    command,env=environment.runtime(configuration.read_state(ROOT)['active'],session='new')
    with Client(command,cwd=ROOT,env=env,timeout=1200) as client:
        client.initialize();create_replay(client.call,force=True)
