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
# File:        validate_sil.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-06
# Version:     0.1.0
# Description: Run original BLDC physical scenarios and actual generated-C PC SIL.
# =================================================================================

"""Run original BLDC physical scenarios and actual generated-C PC SIL.

Default runs the entire matrix, component tests, standalone ERT build, independent
closed loops and exact recorded-input replay. Artifacts stay below .agent-env.
Run validate_plant_reference.py first to establish a current physical oracle.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
CASES = (
    'hall_steps', 'hall_negative_steps', 'hall_reverse', 'hall_low_speed', 'hall_speed_range',
    'hall_load_voltage', 'hall_negative_load_voltage', 'hall_stop_alignment', 'hall_zero_request',
    'hall_stop_restart', 'hall_reversal', 'hall_invalid_zero', 'hall_invalid_seven',
    'hall_jump', 'hall_stall', 'hall_bus_under', 'hall_bus_over', 'hall_overcurrent',
    'hall_adc_rail', 'hall_saturation_recovery', 'hall_parameters',
    'sensorless_forward', 'sensorless_reverse', 'sensorless_100', 'sensorless_minus_100',
    'sensorless_load_voltage', 'sensorless_negative_load_voltage', 'sensorless_stop_restart', 'sensorless_reversal',
    'sensorless_stop_open', 'sensorless_stop_acquisition', 'sensorless_stop_tracking',
    'sensorless_low_transition', 'sensorless_low_fallback', 'sensorless_external_recovery',
    'sensorless_voltage_loss', 'sensorless_voltage_freeze', 'sensorless_invalid_voltage',
    'sensorless_parameters_low_flux', 'sensorless_parameters_high_flux',
)


def quote(value):
    return "'" + str(value).replace('\\', '/').replace("'", "''") + "'"


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding='utf-8')
    # Windows readers may briefly deny rename/delete sharing. Preserve the old
    # complete report until atomic replacement succeeds; never truncate it.
    for attempt in range(6):
        try:
            temporary.replace(path)
            return
        except PermissionError as error:
            if getattr(error, 'winerror', None) not in (5, 32, 33) or attempt == 5:
                raise
            time.sleep(0.05 * 2 ** attempt)


def save_report(folder, summary, transcript):
    # A published PASS is the last write, after its complete transcript exists.
    write_json(folder / 'transcript.json', transcript)
    write_json(folder / 'summary.json', summary)


def source_hashes():
    paths = [ROOT / name for name in ('ambd_mc.m', 'docs/BldcStruct.md',
             'tools/generate_data_type_from_md.m', 'tools/pmsm/build_models.py')]
    paths.extend(sorted((ROOT / 'mc-models/+ambd_workflows').glob('*.m')))
    for folder in ('mc-models/bldc', 'tests/bldc', 'tools/bldc'):
        paths.extend(p for p in (ROOT / folder).rglob('*')
                     if p.suffix in ('.m', '.slx', '.sldd', '.py'))
    return {p.relative_to(ROOT).as_posix(): digest(p) for p in sorted(paths)}


def verify_native_reference():
    folder = ROOT / '.agent-env/bldc-plant'
    report = json.loads((folder / 'results.json').read_text(encoding='utf-8'))
    if report.get('pass') is not True or report.get('status') != 'PASS':
        raise RuntimeError('No passing BLDC native plant reference; run validate_plant_reference.py.')
    for name, key in [('source-hashes.json', 'sourceHashesSha256'),
                      ('native-results.json', 'nativeResultsSha256')]:
        if digest(folder / name) != report.get(key):
            raise RuntimeError(f'Unbound native evidence: {name}')
    hashes = json.loads((folder / 'source-hashes.json').read_text(encoding='utf-8'))
    for name, expected in hashes.items():
        path = folder / 'bldc_native_reference.slx' if name == 'native_model_sha256' else ROOT / name
        if digest(path) != expected:
            raise RuntimeError(f'Native evidence is stale: {name}; rerun the native reference.')
    native = json.loads((folder / 'native-results.json').read_text(encoding='utf-8'))
    if native.get('attempt') != report.get('attempt') or native.get('pass') is not True:
        raise RuntimeError('Native comparison attempt does not match final publication.')
    return dict(Passed=True, Attempt=report['attempt'], Cases=len(report['cases']),
                Report='.agent-env/bldc-plant/results.json', SHA256=digest(folder / 'results.json'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scenario', choices=CASES, action='append')
    parser.add_argument('--normal-only', action='store_true', help='Diagnostic physical matrix; not full SIL acceptance.')
    parser.add_argument('--collect-failures', action='store_true', help='Record unit failures and continue completed physical scenarios; acceptance still requires every gate.')
    args = parser.parse_args()
    cases = [name for name in CASES if not args.scenario or name in args.scenario]
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    folder = ROOT / '.agent-env/bldc/validation' / f'{stamp}-{uuid.uuid4().hex[:8]}'
    folder.mkdir(parents=True)
    build_folder = ROOT / '.agent-env/v' / ('b' + uuid.uuid4().hex[:8])
    build_folder.mkdir(parents=True)
    summary = dict(Passed=False, Status='RUNNING', CompleteMatrix=not args.scenario and not args.normal_only,
                   NormalOnly=args.normal_only, StartedUTC=stamp, SourceHashes=source_hashes(),
                   Cases=[], Comparisons=[], Replays=[])
    transcript = []

    def save():
        save_report(folder, summary, transcript)

    def evaluate(client, code, marker):
        response = client.call('evaluate_matlab_code', {'code': code, 'project_path': client.project_path})
        transcript.append(dict(Code=code, Response=response))
        save()
        output = '\n'.join(part.get('text', '') for part in response.get('content', []))
        if response.get('isError') or marker not in output.splitlines():
            raise RuntimeError(output or str(response))

    save()
    print(f'Reports: {folder}', flush=True)
    try:
        summary['NativeReference'] = verify_native_reference()
        tests = subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', 'tests/bldc',
                                '-p', 'test_*.py', '-v'], cwd=ROOT, capture_output=True, text=True)
        (folder / 'python-tests.log').write_text(tests.stdout + tests.stderr, encoding='utf-8')
        summary['PythonTests'] = dict(Passed=tests.returncode == 0, Log='python-tests.log')
        if tests.returncode:
            raise RuntimeError('Python validation infrastructure tests failed.')
        sys.path.insert(0, str(ROOT / 'tools/agent'))
        import configuration
        import environment
        from mcp_client import Client
        from create_replay_model import create_replay

        def new_client():
            command, env = environment.runtime(configuration.read_state(ROOT)['active'], session='new')
            return Client(command, cwd=ROOT, env=env, timeout=1200)

        with new_client() as client:
            client.initialize()
            unit_file = folder / 'unit-results.json'
            evaluate(client, "suite=testsuite(fullfile(pwd,'tests','bldc'),'IncludeSubfolders',false);"
                "results=run(suite);unit=struct('Total',numel(results),'Passed',sum([results.Passed]),"
                "'Failed',sum([results.Failed]),'Incomplete',sum([results.Incomplete]));"
                "unit.FailedNames={results([results.Failed]).Name};"
                f"fid=fopen({quote(unit_file)},'w');fprintf(fid,'%s',jsonencode(unit));fclose(fid);"
                "disp('BLDC_UNIT_RECORDED');", 'BLDC_UNIT_RECORDED')
            summary['UnitTests'] = json.loads(unit_file.read_text(encoding='utf-8'))
            unit_passed = summary['UnitTests']['Total'] > 0 and summary['UnitTests']['Passed'] == summary['UnitTests']['Total']
            print(f"UNIT_RESULTS {summary['UnitTests']['Passed']}/{summary['UnitTests']['Total']}", flush=True)
            if not unit_passed and not args.collect_failures:
                raise RuntimeError('One or more unit tests did not pass.')
        with new_client() as client:
            client.initialize()
            evaluate(client, f"addpath({quote(ROOT)});info=ambd_mc('setup','bldc');disp('BLDC_SETUP_PASS');", 'BLDC_SETUP_PASS')
            if not args.normal_only:
                compiler_file = folder / 'compiler.json'
                evaluate(client, "cc=mex.getCompilerConfigurations('C','Selected');assert(~isempty(cc));"
                    "compiler=struct('Name',string(cc(1).Name),'Version',string(cc(1).Version),'MATLAB',string(version));"
                    f"fid=fopen({quote(compiler_file)},'w');fprintf(fid,'%s',jsonencode(compiler));fclose(fid);"
                    "disp('BLDC_COMPILER_PASS');", 'BLDC_COMPILER_PASS')
                summary['Compiler'] = json.loads(compiler_file.read_text(encoding='utf-8'))
                create_replay(client.call, force=True)
                replay = ROOT / '.agent-env/bldc-models/BLDC_SIL_Replay.slx'
                replay_hash = digest(replay)
                summary['ReplayHarness'] = dict(Path=replay.relative_to(ROOT).as_posix(), SHA256=replay_hash, Rebuilt=True)
            for scenario in cases:
                physical_pass = True
                for mode in ('Normal',) if args.normal_only else ('Normal', 'SIL'):
                    destination = folder / 'closed-loop' / scenario / mode
                    evaluate(client, f"result=bldc_run_host_case({quote(scenario)},{quote(mode)},"
                        f"{quote(destination)},{quote(build_folder)});disp('BLDC_CASE_COMPLETED');", 'BLDC_CASE_COMPLETED')
                    result = json.loads((destination / 'result.json').read_text(encoding='utf-8'))
                    summary['Cases'].append(result);save()
                    physical_pass = physical_pass and result['Passed']
                    print(f"CASE_{'PASS' if result['Passed'] else 'FAIL'} {scenario} {mode}", flush=True)
                    if not result['Passed']:
                        failed = [c['Name'] for c in result['Assessment']['Checks'] if not c['Passed']]
                        print('Failed checks: ' + ', '.join(failed), flush=True)
                        if not args.collect_failures:
                            raise RuntimeError(f'Physical acceptance failed: {scenario}/{mode}: {failed}')
                if args.normal_only or not physical_pass:
                    continue
                normal_trace = folder / 'closed-loop' / scenario / 'Normal' / 'trace.mat'
                sil_trace = folder / 'closed-loop' / scenario / 'SIL' / 'trace.mat'
                destination = folder / 'comparison' / scenario
                evaluate(client, f"result=bldc_compare_host_cases({quote(normal_trace)},{quote(sil_trace)},{quote(destination)});"
                    "assert(result.Passed);disp('BLDC_COMPARISON_PASS');", 'BLDC_COMPARISON_PASS')
                summary['Comparisons'].append(json.loads((destination / 'result.json').read_text(encoding='utf-8')))
                destination = folder / 'replay' / scenario
                evaluate(client, f"result=bldc_run_replay({quote(normal_trace)},{quote(destination)},{quote(build_folder)});"
                    "assert(result.Passed);disp('BLDC_REPLAY_PASS');", 'BLDC_REPLAY_PASS')
                result = json.loads((destination / 'result.json').read_text(encoding='utf-8'))
                summary['Replays'].append(result);save()
                print(f"REPLAY_PASS {scenario} strict={result['StrictBitwisePassed']}", flush=True)
        summary['SourcesUnchanged'] = source_hashes() == summary['SourceHashes']
        if not summary['SourcesUnchanged']:
            raise RuntimeError('Sources changed during validation; repeat with stable sources.')
        summary['NativeReference'] = verify_native_reference()
        if not args.normal_only:
            if digest(replay) != replay_hash:
                raise RuntimeError('Replay harness changed during the run.')
            build = build_folder / 'codegen'
            executables = sorted(build.rglob('*.exe'))
            expected = {'BLDC_PIL_Sensorless_model'}
            expected.update('BLDC_PIL_Sensorless_model' if name.startswith('sensorless_')
                            else 'BLDC_PIL_Hall_model' for name in cases)
            if not expected.issubset({p.stem for p in executables}):
                raise RuntimeError('Required host executable evidence is missing.')
            sources = [path for name in sorted(expected) for path in build.rglob(name + '.c')]
            if not expected.issubset({p.stem for p in sources}) or any(p.stat().st_size == 0 for p in sources + executables):
                raise RuntimeError('Generated C or host binaries are missing/empty.')
            summary['BuildArtifacts'] = [dict(Path=p.relative_to(ROOT).as_posix(), Bytes=p.stat().st_size, SHA256=digest(p))
                                         for p in sources + executables]
        expected_cases = len(cases) * (1 if args.normal_only else 2)
        passed = len(summary['Cases']) == expected_cases and all(case['Passed'] for case in summary['Cases'])
        if not args.normal_only:
            passed = passed and len(summary['Comparisons']) == len(cases) and len(summary['Replays']) == len(cases)
        summary['ScenarioGatesPassed'] = passed
        if not passed or not unit_passed:
            raise RuntimeError('One or more required unit or scenario gates did not pass.')
        summary['FinishedUTC'] = datetime.now(timezone.utc).isoformat()
        print(f"Publishing verified report: {len(cases)} scenarios; full SIL matrix={summary['CompleteMatrix']}. {folder}", flush=True)
        summary['Passed'] = True;summary['Status'] = 'PASS'
        save()
    except BaseException as error:
        summary['Passed'] = False;summary['Status'] = 'FAILED';summary['Error'] = str(error)
        summary['FinishedUTC'] = datetime.now(timezone.utc).isoformat()
        save()
        raise


if __name__ == '__main__':
    main()
