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
# Description: Build and execute an independent Simscape BLDC + six-switch bridge
#              oracle.
# =================================================================================

"""Build and execute an independent Simscape BLDC + six-switch bridge oracle.

Run from any directory: python tools/bldc/validate_plant_reference.py
All structural operations use the pinned official model_edit tool in a new
owned MATLAB session. Models, traces, transcripts and hashes stay ignored.
"""
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import shutil
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS = ROOT / '.agent-env/bldc-plant'
MODEL = 'bldc_native_reference'
SOURCE_FILES = [ROOT / 'mc-models/bldc/algo/+bldc' / name for name in
                ('trapezoid.m', 'hall_signal.m', 'phase_network.m',
                 'plant_step.m', 'plant_measure.m')]
SOURCE_FILES += [ROOT / 'tests/bldc/bldcPlantTest.m', Path(__file__).resolve()]
SOURCE_FILES += [ROOT / 'tests/bldc/test_plant_reference_runner.py']
SOURCE_FILES += sorted((ROOT / 'tests/bldc/helpers').glob('*plant*.m'))


def source_hashes():
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in SOURCE_FILES}


def build_operations():
    operations = []

    def add(kind, name, **params):
        operations.append(dict(op='add_block', type=kind, name=name, ref=name,
                               params=params))

    def wire(source, destination, physical=True):
        arrow = '<->' if physical else '->'
        operations.append(dict(op='connect', target=f'#{source} {arrow} #{destination}'))

    add('BLDC', 'NativeBLDC', port_option='ee.enum.threePhasePort.expanded',
        rotor_param='ee.enum.pmsm.backemf.tabulatedbackemf',
        back_emf_tab='[0 .78104522 .78104522 -.78104522 -.78104522 0]',
        rotor_angle_tab='[0 30 150 210 330 360]/2', rotor_angle_tab_unit='deg',
        w_meas='100', w_meas_unit='rad/s', nPolePairs='2',
        Rs='.56', Ld='.0004', Lq='.0004', L0='.0004', J='1.2e-5', lam='.0005',
        angular_position='theta0/2', angular_position_unit='rad',
        angular_position_specify='on', angular_position_priority='High',
        angular_velocity='shaftSpeed', angular_velocity_unit='rad/s',
        angular_velocity_specify='on', angular_velocity_priority='High',
        i_d='0', i_d_specify='on', i_d_priority='High',
        i_q='0', i_q_specify='on', i_q_priority='High')
    add('Solver Configuration', 'Solver', UseLocalSolver='on',
        LocalSolverChoice='NE_BACKWARD_EULER_ADVANCER',
        LocalSolverSampleTime='nativeStep', DoDC='off')
    add('Electrical Reference', 'Ground')
    add('Mechanical Rotational Reference', 'MechanicalGround')
    add('Ideal Angular Velocity Source', 'Shaft')
    add('DC Voltage Source', 'Bus', v0='12')
    add('Constant', 'Speed', Value='shaftSpeed')
    add('Simulink-PS Converter', 'SpeedConvert', Unit='rad/s')
    wire('Bus.RConn1', 'Ground.LConn1')
    wire('Solver.RConn1', 'Ground.LConn1')
    wire('NativeBLDC.RConn2', 'MechanicalGround.LConn1')
    wire('Shaft.RConn2', 'MechanicalGround.LConn1')
    wire('NativeBLDC.RConn1', 'Shaft.LConn1')
    wire('SpeedConvert.RConn1', 'Shaft.RConn1')
    wire('Speed.y1', 'SpeedConvert.u1', False)
    for index, phase in enumerate('ABC', 1):
        for leg in ('High', 'Low'):
            ref = leg + phase
            # Verified local library path avoids the Simulink Switch name collision.
            add('fl_lib/Electrical/Electrical Elements/Switch', ref,
                R_closed='1e-4', G_open='1e-8')
            add('fl_lib/Electrical/Electrical Elements/Diode', 'Diode' + ref,
                Vf='1e-4', Ron='1e-4', Goff='1e-8')
            add('FromWorkspace', 'Command' + ref, VariableName='gate' + ref,
                Interpolate='off', OutputAfterFinalValue='Holding final value')
            add('Simulink-PS Converter', 'Convert' + ref)
            wire('Command' + ref + '.y1', 'Convert' + ref + '.u1', False)
            wire('Convert' + ref + '.RConn1', ref + '.RConn1')
        sensor = 'Current' + phase
        add('Current Sensor', sensor)
        add('PS-Simulink Converter', sensor + 'Convert')
        add('ToWorkspace', 'Log' + sensor, VariableName='current' + phase,
            SaveFormat='Timeseries')
        wire(sensor + '.RConn1', sensor + 'Convert.LConn1')
        wire(sensor + 'Convert.y1', 'Log' + sensor + '.u1', False)
        wire(sensor + '.RConn2', f'NativeBLDC.LConn{index}')
        wire('High' + phase + '.LConn1', 'Bus.LConn1')
        wire('High' + phase + '.RConn2', sensor + '.LConn1')
        wire('Low' + phase + '.LConn1', sensor + '.LConn1')
        wire('Low' + phase + '.RConn2', 'Ground.LConn1')
        wire('DiodeHigh' + phase + '.LConn1', sensor + '.LConn1')
        wire('DiodeHigh' + phase + '.RConn1', 'Bus.LConn1')
        wire('DiodeLow' + phase + '.LConn1', 'Ground.LConn1')
        wire('DiodeLow' + phase + '.RConn1', sensor + '.LConn1')
        for kind in ('Phase', 'Terminal'):
            name = kind + 'Voltage' + phase
            add('Voltage Sensor', name)
            add('PS-Simulink Converter', name + 'Convert')
            variable = kind.lower() + 'Voltage' + phase
            if kind == 'Phase' and phase == 'A':
                variable = 'phaseVoltage'
            add('ToWorkspace', 'Log' + name, VariableName=variable, SaveFormat='Timeseries')
            wire(name + '.LConn1', f'NativeBLDC.LConn{index}')
            wire(name + '.RConn2', 'NativeBLDC.LConn4' if kind == 'Phase' else 'Ground.LConn1')
            wire(name + '.RConn1', name + 'Convert.LConn1')
            wire(name + 'Convert.y1', 'Log' + name + '.u1', False)
    operations.append(dict(op='configure', target='config:' + MODEL, params={
        'SolverType': 'Fixed-step', 'Solver': 'FixedStepDiscrete', 'FixedStep': 'nativeStep',
        'RelTol': '1e-7', 'AbsTol': '1e-9', 'StopTime': 'stopTime',
        'ReturnWorkspaceOutputs': 'on', 'SimscapeLogType': 'all',
        'MaxConsecutiveMinStep': '5'}))
    return operations


def write_json_atomic(path, payload):
    temporary = path.with_name(f'.{path.name}.{uuid.uuid4().hex}.tmp')
    try:
        temporary.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding='utf-8')
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def initialize_attempt(attempt):
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    previous = [ARTIFACTS / name for name in
                ('results.json', 'native-results.json', 'source-hashes.json',
                 'reproduction-transcript.json', MODEL + '.slx')]
    previous += list(ARTIFACTS.glob('*.mat'))
    if any(path.exists() for path in previous):
        archive = ARTIFACTS / 'history' / attempt
        archive.mkdir(parents=True)
        for path in previous:
            if path.exists():
                shutil.copy2(path, archive / path.name)
    write_json_atomic(ARTIFACTS / 'results.json',
                      {'pass': False, 'status': 'RUNNING', 'attempt': attempt})
    (ARTIFACTS / 'source-hashes.json').unlink(missing_ok=True)
    (ARTIFACTS / 'native-results.json').unlink(missing_ok=True)


def execute_native(attempt):
    sys.path.insert(0, str(ROOT / 'tools/agent'))
    import configuration
    import environment
    from mcp_client import Client

    smoke = max((ROOT / '.agent-env/reports').rglob('smoke.json'), key=lambda p: p.stat().st_mtime)
    eligibility = json.loads(smoke.read_text(encoding='utf-8'))['skill_eligibility']
    for skill in ('building-simulink-models', 'matlab-run-tests'):
        if eligibility[skill]['status'] != 'ELIGIBLE':
            raise RuntimeError(f'{skill} unavailable: {eligibility[skill]}')
    transcript = []

    def call(client, name, **arguments):
        result = client.call(name, arguments)
        transcript.append(dict(name=name, arguments=arguments, result=result))
        (ARTIFACTS / 'reproduction-transcript.json').write_text(
            json.dumps(transcript, indent=2, ensure_ascii=False), encoding='utf-8')
        output = '\n'.join(item.get('text', '') for item in result.get('content', []))
        print(f'{name}: {output[:100]}', flush=True)
        return output

    command, env = environment.runtime(configuration.read_state(ROOT)['active'], session='new')
    before = source_hashes()
    with Client(command, cwd=ROOT, env=env, timeout=600) as client:
        client.initialize()
        gate = call(client, 'evaluate_matlab_code', code='disp(jsonencode(library.settingsLookup()));')
        if '"gatePass":true' not in gate:
            raise RuntimeError('Custom library prerequisites are not satisfied.')
        call(client, 'evaluate_matlab_code', code=(
            "load_system('ee_lib'); load_system('fl_lib'); "
            "disp(get_param('ee_lib/Electromechanical/Permanent Magnet/BLDC','rotor_param')); "
            "disp(find_system('fl_lib','LookUnderMasks','all','FollowLinks','on','Name','Switch')); "
            f"new_system('{MODEL}'); open_system('{MODEL}'); "
            f"save_system('{MODEL}',fullfile(pwd,'.agent-env','bldc-plant','{MODEL}.slx'));"))
        call(client, 'model_read', model=MODEL, scope='root', depth='0')
        edited = call(client, 'model_edit', model=MODEL, scope='root', layout_mode='full',
                      operations=json.dumps(build_operations(), separators=(',', ':')))
        call(client, 'model_read', model=MODEL, scope='root', depth='0')
        checked = call(client, 'model_check', model=MODEL, scope='root', checks='["all"]')
        if 'status: ok' not in edited or 'status: healthy' not in checked:
            raise RuntimeError('Native reference topology did not build cleanly.')
        verified = call(client, 'evaluate_matlab_code', code=(
            "addpath(fullfile(pwd,'tests','bldc','helpers')); "
            f"save_system('{MODEL}'); "
            "unit=runtests(fullfile(pwd,'tests','bldc','bldcPlantTest.m')); assert(all([unit.Passed])); "
            f"report=compare_plant_reference('{attempt}'); assert(report.pass); "
            "disp('BLDC_NATIVE_REFERENCE_PASS');"))
        if 'BLDC_NATIVE_REFERENCE_PASS' not in verified:
            raise RuntimeError(verified[-3000:])
    native_bytes = (ARTIFACTS / 'native-results.json').read_bytes()
    native = json.loads(native_bytes)
    if native.get('attempt') != attempt:
        raise RuntimeError('Native provisional report does not belong to this attempt.')
    if native.get('status') != 'PROVISIONAL' or native.get('pass') is not True:
        raise RuntimeError('Native provisional validation did not pass.')
    return before, native, hashlib.sha256(native_bytes).hexdigest()


def main():
    attempt = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    try:
        # Invalidate prior acceptance before imports, Smoke lookup, or runtime setup.
        initialize_attempt(attempt)
        before, native, native_digest = execute_native(attempt)
        verified_sources = source_hashes()
        if before != verified_sources:
            raise RuntimeError('Plant source changed during validation; rerun with stable sources.')
        hashes = dict(verified_sources)
        hashes['native_model_sha256'] = hashlib.sha256(
            (ARTIFACTS / (MODEL + '.slx')).read_bytes()).hexdigest()
        hash_path = ARTIFACTS / 'source-hashes.json'
        write_json_atomic(hash_path, hashes)
        if source_hashes() != verified_sources:
            raise RuntimeError('Plant source changed during hash publication; rerun with stable sources.')
        final = dict(native)
        final.update(status='PASS', sourceHashesFile='source-hashes.json',
                     sourceHashesSha256=hashlib.sha256(hash_path.read_bytes()).hexdigest(),
                     nativeResultsFile='native-results.json', nativeResultsSha256=native_digest)
        print(f'Publishing verified native reference report: {ARTIFACTS / "results.json"}')
        # This is the sole authoritative PASS publication, after every gate.
        write_json_atomic(ARTIFACTS / 'results.json', final)
    except BaseException as error:
        try:
            (ARTIFACTS / 'source-hashes.json').unlink(missing_ok=True)
        finally:
            write_json_atomic(ARTIFACTS / 'results.json', {
                'pass': False, 'status': 'FAILED', 'attempt': attempt,
                'failure': {'type': type(error).__name__, 'message': str(error)}})
        raise


if __name__ == '__main__':
    main()
