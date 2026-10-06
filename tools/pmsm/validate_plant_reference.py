# SPDX-License-Identifier: MIT
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
