# =================================================================================
# The MIT License
# MIT许可证
#
# <https://opensource.org/license/mit>
#
# SPDX short identifier / SPDX 短标识符：MIT
#
# Copyright (c) 2026 autoMBD
# 版权所有 (c) 2026 autoMBD
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the “Software”),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
# 特此向获得本软件及相关文档（合称“本软件”）副本的任何人免费授予不受限制地利用本软
# 件的许可，包括而不限于：使用、复制、修改、合并、发布、分发、分许可和/或销售本软
# 件副本，并允许本软件的接收者也获得前述许可，但须遵守以下条件：
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
# 以上版权声明及本许可声明应包含在本软件的所有副本或主要部分中。
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALLTHE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# 本软件系“按原样”提供，不包含任何形式的明示或默示保证，包括但不限于适销性、特定
# 目的适用性及不侵权的保证。在任何情况下，无论是在合同、侵权或其他案件中，作者或版
# 权持有人均不对因本软件、或因本软件的使用或其他利用而引起的、引发的或与之相关的任
# 何权利主张、损害赔偿或其他责任承担责任。
# =================================================================================
# Project:     autoMBD Motor Control <https://github.com/autoMBD/AMBD-MC>
# File:        create_replay_model.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-06
# Version:     0.1.0
# Description: Create the ignored BLDC SIL replay harness with matching host
#              configuration.
# =================================================================================

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
    result=builder.matlab(f'addpath({quote(ROOT)});info=ambd_mc("setup","bldc");'+
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
