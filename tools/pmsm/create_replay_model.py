# SPDX-License-Identifier: MIT
"""Create only the ignored PMSM replay harness; leave production models alone.

Run from the repository root: python tools/pmsm/create_replay_model.py
The pinned official MCP performs all block edits. A fresh checkout needs
pmsm_setup-compatible saved production models and the canonical dictionary.
"""
from __future__ import annotations

import sys

from build_models import ARTIFACTS, ROOT, Builder, quote


def create_replay(call, force=False):
    path=ARTIFACTS/'FOC_SIL_Replay.slx'
    if path.exists() and not force:
        print(f'Replay harness already exists: {path}')
        return
    builder=Builder(call)
    builder.seq=500
    gate=builder.matlab('disp(jsonencode(library.settingsLookup()));')
    if not ('"found":false' in gate or '"gatePass":true' in gate):
        raise RuntimeError(gate)
    result=builder.matlab(
        f'addpath({quote(ROOT)});'
        f'info=pmsm_setup(OutputDirectory={quote(ARTIFACTS/"replay-build")});'
        "assert(~bdIsLoaded('FOC_SIL_Replay'),'mc:ReplayAlreadyLoaded',"
        "'Refusing to replace an unsaved loaded replay harness.');"
        "open_system('FOC_PIL_StateMch_top');disp('REPLAY SETUP PASS');")
    if 'REPLAY SETUP PASS' not in result:
        raise RuntimeError(result)
    builder.read('FOC_PIL_StateMch_top')
    # A new model has factory settings, while the saved controller uses ERT
    # host settings. Compile only after copying the compatible configuration.
    builder.wrapper('FOC_SIL_Replay',ARTIFACTS,'FOC_PIL_StateMch_model',compile_model=False)
    # Harness configuration copies the compatible saved host configuration.
    # This neither configures nor saves any production model.
    result=builder.matlab(
        "replayConfig=copy(getActiveConfigSet('FOC_PIL_StateMch_top'));"
        "replayConfig.Name='HostReplayConfiguration';"
        "attachConfigSet('FOC_SIL_Replay',replayConfig,true);"
        "setActiveConfigSet('FOC_SIL_Replay',replayConfig.Name);"
        "set_param('FOC_SIL_Replay','SimulationCommand','update');"
        f"save_system('FOC_SIL_Replay',{quote(path)});"
        "disp('REPLAY BUILD PASS');")
    if 'REPLAY BUILD PASS' not in result:
        raise RuntimeError(result)
    builder.read('FOC_SIL_Replay')
    builder.check('FOC_SIL_Replay')


if __name__=='__main__':
    sys.path.insert(0,str(ROOT/'tools/agent'))
    import configuration
    import environment
    from mcp_client import Client
    command,env=environment.runtime(configuration.read_state(ROOT)['active'],session='new')
    with Client(command,cwd=ROOT,env=env,timeout=900) as client:
        client.initialize()
        create_replay(client.call, force=True)
