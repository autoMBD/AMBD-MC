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
# File:        validate_plant_reference.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-06
# Version:     0.1.0
# Description: Compare the original host plant with the official continuous PMSM block.
# =================================================================================

"""Compare the original host plant with the official continuous PMSM block.

Run: python tools/pmsm/validate_plant_reference.py
Uses a fresh owned official MCP session from the active locked environment.
All generated models, caches and reports remain below .agent-env.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS = ROOT / '.agent-env/pmsm-plant-validation'
MODEL = 'pmsm_native_reference'
REFERENCE = 'autolibpmsminterior/Interior PMSM'
SOURCE_FILES = [ROOT / 'mc-models/pmsm/algo/+mc' / name for name in
                ('plant_step.m', 'plant_measure.m', 'defaults.m')]


def source_hashes():
    return {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in SOURCE_FILES}


def build_operations():
    """Return original test-harness operations; never edit the library block."""
    operations = [dict(
        op='add_block', type=REFERENCE, name='NativePMSM', ref='motor', params={
            'port_config': 'Torque', 'sim_type': 'Continuous',
            'P': 'double(p.PolePairs)', 'Rs': 'double(p.Rs)',
            'Ldq': 'double([p.Ld p.Lq])', 'lambda_pm': 'double(p.Flux)',
            'mechanical': '[double(p.Inertia) double(p.Friction) 0]',
            'idq0': 'transpose(x0(1:2))',
            'theta_init': 'x0(4)/double(p.PolePairs)', 'omega_init': 'x0(3)'})]
    for name, ref, value in [('PhaseVoltage', 'v', 'phaseVoltage'),
                             ('LoadTorque', 'load', 'loadTorque')]:
        operations.append(dict(op='add_block', type='Constant', name=name,
                               ref=ref, params={'Value': value}))
    operations.append(dict(op='add_block', type='BusSelector', name='MotorSignals',
                           ref='bus', params={'OutputSignals': 'IdSync,IqSync,MtrPos'}))
    for name, ref, variable in [('Currents', 'curr', 'currents'), ('Speed', 'speed', 'speed'),
                                ('Id', 'id', 'id'), ('Iq', 'iq', 'iq'),
                                ('Position', 'pos', 'position')]:
        operations.append(dict(op='add_block', type='ToWorkspace', name=name, ref=ref,
                               params={'VariableName': variable, 'SaveFormat': 'Timeseries'}))
    for source, target in [('load.y1', 'motor.u1'), ('v.y1', 'motor.u2'),
                           ('motor.y1', 'bus.u1'), ('motor.y2', 'curr.u1'),
                           ('motor.y3', 'speed.u1'), ('bus.y1', 'id.u1'),
                           ('bus.y2', 'iq.u1'), ('bus.y3', 'pos.u1')]:
        operations.append(dict(op='connect', target=f'#{source} -> #{target}'))
    operations.append(dict(op='configure', target=f'config:{MODEL}', params={
        'SolverType': 'Fixed-step', 'Solver': 'ode4',
        'FixedStep': '1/16000/16', 'StopTime': '0.1'}))
    return operations


def main():
    sys.path.insert(0, str(ROOT / 'tools/agent'))
    import configuration
    import environment
    from mcp_client import Client

    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    transcript = []

    def call(client, name, **arguments):
        if name == "evaluate_matlab_code":
            arguments.setdefault("project_path", client.project_path)
        result = client.call(name, arguments)
        transcript.append(dict(name=name, arguments=arguments, result=result))
        (ARTIFACTS / 'reproduction-transcript.json').write_text(
            json.dumps(transcript, indent=2, ensure_ascii=False), encoding='utf-8')
        output = '\n'.join(item.get('text', '') for item in result.get('content', []))
        print(f'{name}: {output[:100]}', flush=True)
        return output

    candidate = configuration.read_state(ROOT)['active']
    command, env = environment.runtime(candidate, session='new')
    before = source_hashes()
    with Client(command, cwd=ROOT, env=env, timeout=600) as client:
        client.initialize()
        gate = call(client, 'evaluate_matlab_code',
                    code='disp(jsonencode(library.settingsLookup()));')
        if '"gatePass":true' not in gate:
            raise RuntimeError('Custom library prerequisites are not satisfied.')
        call(client, 'evaluate_matlab_code', code=(
            f"load_system('autolibpmsminterior'); "
            f"disp(jsonencode(get_param('{REFERENCE}','DialogParameters'))); "
            f"new_system('{MODEL}'); open_system('{MODEL}'); "
            f"save_system('{MODEL}',fullfile(pwd,'.agent-env',"
            f"'pmsm-plant-validation','{MODEL}.slx'));"))
        call(client, 'model_read', model=MODEL, scope='root', depth='0')
        edited = call(client, 'model_edit', model=MODEL, scope='root', layout_mode='full',
                      operations=json.dumps(build_operations(), separators=(',', ':')))
        # Read/check immediately even when the edit tool reports partial success.
        call(client, 'model_read', model=MODEL, scope='root', depth='0')
        checked = call(client, 'model_check', model=MODEL, scope='root', checks='["all"]')
        if 'status: ok' not in edited or 'status: healthy' not in checked:
            raise RuntimeError('The reference harness did not build cleanly.')
        result = call(client, 'evaluate_matlab_code', code=(
            "addpath(fullfile(pwd,'tests','pmsm','helpers')); "
            "clear compare_plant_reference; rehash; "
            "report=compare_plant_reference(); assert(report.pass); "
            "disp('NATIVE_REFERENCE_VALIDATION_PASS');"))
        if 'NATIVE_REFERENCE_VALIDATION_PASS' not in result:
            raise RuntimeError(result)
    after = source_hashes()
    if before != after:
        raise RuntimeError('Plant source changed during validation; rerun with stable sources.')
    (ARTIFACTS / 'source-hashes.json').write_text(json.dumps(after, indent=2), encoding='utf-8')
    report = json.loads((ARTIFACTS / 'results.json').read_text(encoding='utf-8'))
    if not report['pass']:
        raise RuntimeError('Official PMSM comparison failed.')
    print(f"PASS: {len(report['cases'])} cases; results at {ARTIFACTS / 'results.json'}")


if __name__ == '__main__':
    main()
