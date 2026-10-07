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
# Description: Run component tests and real PC SIL acceptance via the pinned official
#              MCP.
# =================================================================================

"""Run component tests and real PC SIL acceptance via the pinned official MCP.

Run from any directory: python tools/pmsm/validate_sil.py
Each invocation creates a new report directory. No production models are saved.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
CASES = (
    ('FOC_PIL_Algth_top', 'sensored_steps'),
    ('FOC_PIL_StateMch_top', 'sensorless_forward'),
    ('FOC_PIL_StateMch_top', 'sensorless_reverse'),
    ('FOC_PIL_StateMch_top', 'sensorless_100'),
    ('FOC_PIL_Algth_top', 'load_voltage'),
    ('FOC_PIL_StateMch_top', 'reversal'),
    ('FOC_PIL_StateMch_top', 'stop_restart'),
    ('FOC_PIL_StateMch_top', 'stop_mid_tracking'),
    ('FOC_PIL_StateMch_top', 'fault_recovery'),
    ('FOC_PIL_StateMch_top', 'bus_fault'),
    ('FOC_PIL_Algth_top', 'saturation_recovery'),
    ('FOC_PIL_Algth_top', 'parameter_variation'),
    ('FOC_PIL_StateMch_top', 'low_speed_transition'),
)


def quote(value):
    return "'" + str(value).replace('\\', '/').replace("'", "''") + "'"


def source_hashes():
    paths = [ROOT / 'pmsm_setup.m', ROOT / 'docs/McStruct.md',
             ROOT / 'tools/generate_data_type_from_md.m']
    for folder in ('mc-models/pmsm', 'tests/pmsm', 'tools/pmsm'):
        paths.extend(p for p in (ROOT / folder).rglob('*')
                     if p.suffix in ('.m', '.slx', '.sldd', '.py'))
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(paths)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scenario', choices=[name for _, name in CASES],
                        action='append', help='Run selected scenarios; default is the complete matrix.')
    args = parser.parse_args()
    cases = [case for case in CASES if not args.scenario or case[1] in args.scenario]
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    folder = ROOT / '.agent-env/pmsm/validation' / f'{stamp}-{uuid.uuid4().hex[:8]}'
    folder.mkdir(parents=True)
    sys.path.insert(0, str(ROOT / 'tools/agent'))
    import configuration
    import environment
    from mcp_client import Client
    from create_replay_model import create_replay

    before = source_hashes()
    summary = dict(Passed=False, CompleteMatrix=not args.scenario,
                   StartedUTC=stamp, SourceHashes=before, Cases=[], Comparisons=[], Replays=[])
    transcript = []

    def save():
        (folder / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
        (folder / 'transcript.json').write_text(
            json.dumps(transcript, indent=2, ensure_ascii=False), encoding='utf-8')

    def evaluate(client, code, marker):
        response = client.call('evaluate_matlab_code', {'code': code})
        transcript.append(dict(Code=code, Response=response))
        save()
        output = '\n'.join(part.get('text', '') for part in response.get('content', []))
        if response.get('isError') or marker not in output:
            raise RuntimeError(output or str(response))
        print(marker, flush=True)

    def new_client():
        command, env = environment.runtime(configuration.read_state(ROOT)['active'], session='new')
        return Client(command, cwd=ROOT, env=env, timeout=1200)

    save()
    print(f'Reports: {folder}', flush=True)
    try:
        # Initializer tests intentionally exercise temporary dictionaries/enums.
        # A separate owned process isolates those from production compilation.
        with new_client() as client:
            client.initialize()
            unit_file = folder / 'unit-results.json'
            evaluate(client,
                     f"addpath({quote(ROOT / 'mc-models/pmsm')},{quote(ROOT / 'mc-models/pmsm/algo')}); "
                     "suite=testsuite(fullfile(pwd,'tests','pmsm'),'IncludeSubfolders',false); "
                     "results=run(suite); unit=struct('Total',numel(results),"
                     "'Passed',sum([results.Passed]),'Failed',sum([results.Failed]),"
                     "'Incomplete',sum([results.Incomplete])); "
                     f"fid=fopen({quote(unit_file)},'w'); fprintf(fid,'%s',jsonencode(unit)); fclose(fid); "
                     "assert(unit.Total>0 && unit.Passed==unit.Total); disp('UNIT_TESTS_PASS');",
                     'UNIT_TESTS_PASS')
            summary['UnitTests'] = json.loads(unit_file.read_text(encoding='utf-8'))
        with new_client() as client:
            client.initialize()
            evaluate(client, f"addpath({quote(ROOT)}); info=pmsm_setup; disp('SETUP_PASS');", 'SETUP_PASS')
            compiler_file = folder / 'compiler.json'
            evaluate(client,
                     "compiler=mex.getCompilerConfigurations('C','Selected'); "
                     "assert(~isempty(compiler),'mc:MissingHostCompiler','A selected C compiler is required.'); "
                     "hostCompiler=struct('Name',string(compiler(1).Name),"
                     "'Version',string(compiler(1).Version),'MATLAB',string(version)); "
                     f"fid=fopen({quote(compiler_file)},'w'); fprintf(fid,'%s',jsonencode(hostCompiler)); fclose(fid); "
                     "disp('HOST_COMPILER_RECORDED');", 'HOST_COMPILER_RECORDED')
            summary['Compiler'] = json.loads(compiler_file.read_text(encoding='utf-8'))
            create_replay(client.call, force=True)
            replay_model = ROOT / '.agent-env/pmsm-models/FOC_SIL_Replay.slx'
            replay_hash = hashlib.sha256(replay_model.read_bytes()).hexdigest()
            summary['ReplayHarness'] = dict(Path=replay_model.relative_to(ROOT).as_posix(),
                                           SHA256=replay_hash, Rebuilt=True)
            save()
            standalone_log = folder / 'standalone-codegen.log'
            evaluate(client,
                     f"info=mc_initialize(OutputDirectory={quote(folder / 'build')}); "
                     "load_system('FOC_Ctrl_CodeModel'); buildFailure=[]; "
                     "buildLog=evalc('try; slbuild(''FOC_Ctrl_CodeModel''); "
                     "catch buildError; buildFailure=buildError; end'); "
                     f"fid=fopen({quote(standalone_log)},'w','n','UTF-8'); fprintf(fid,'%s',buildLog); fclose(fid); "
                     "if ~isempty(buildFailure),rethrow(buildFailure);end; disp('STANDALONE_CODEGEN_PASS');",
                     'STANDALONE_CODEGEN_PASS')
            summary['StandaloneCodeGeneration'] = dict(Model='FOC_Ctrl_CodeModel',
                                                        Log=standalone_log.name, Passed=True)
            save()
            for model, scenario in cases:
                for mode in ('Normal', 'SIL'):
                    destination = folder / 'closed-loop' / scenario / mode
                    marker = f'CASE_PASS_{scenario}_{mode}'
                    evaluate(client,
                             f"result=mc_run_host_case({quote(model)},{quote(scenario)},"
                             f"{quote(mode)},{quote(destination)},{quote(folder / 'build')}); "
                             f"assert(result.Passed); disp({quote(marker)});",
                             marker)
                    summary['Cases'].append(json.loads((destination / 'result.json').read_text(encoding='utf-8')))
                    save()
                destination = folder / 'comparison' / scenario
                marker = f'CLOSED_LOOP_COMPARISON_PASS_{scenario}'
                evaluate(client,
                         f"result=mc_compare_host_cases({quote(folder / 'closed-loop' / scenario / 'Normal' / 'trace.mat')},"
                         f"{quote(folder / 'closed-loop' / scenario / 'SIL' / 'trace.mat')},{quote(destination)}); "
                         f"assert(result.Passed); disp({quote(marker)});", marker)
                summary['Comparisons'].append(json.loads((destination / 'result.json').read_text(encoding='utf-8')))
                save()
                destination = folder / 'replay' / scenario
                marker = f'REPLAY_PASS_{scenario}'
                evaluate(client,
                         f"result=mc_run_replay({quote(folder / 'closed-loop' / scenario / 'Normal' / 'trace.mat')},"
                         f"{quote(destination)},{quote(folder / 'build')}); "
                         f"assert(result.Passed); disp({quote(marker)});", marker)
                summary['Replays'].append(json.loads((destination / 'result.json').read_text(encoding='utf-8')))
                save()
        after = source_hashes()
        summary['SourcesUnchanged'] = before == after
        if before != after:
            raise RuntimeError('Sources changed during validation; rerun with stable sources.')
        if hashlib.sha256(replay_model.read_bytes()).hexdigest() != replay_hash:
            raise RuntimeError('Replay harness changed during validation; rerun.')
        build_root = folder / 'build' / 'codegen'
        binaries = sorted(build_root.rglob('*.exe'))
        controllers = {model.replace('_top', '_model') for model, _ in cases}
        controllers.add('FOC_PIL_StateMch_model')  # Explicit replay reference.
        if not controllers.issubset({p.stem for p in binaries}):
            raise RuntimeError('Missing host SIL executable for a required controller.')
        core_sources = list(build_root.rglob('MotorFramework.c'))
        standalone_sources = list(build_root.rglob('FOC_Ctrl_CodeModel.c'))
        if not core_sources or not standalone_sources or any(
                p.stat().st_size == 0 for p in core_sources + standalone_sources + binaries):
            raise RuntimeError('Missing or empty generated core C/build artifacts.')
        summary['BuildArtifacts'] = [dict(Path=p.relative_to(folder).as_posix(),
                                         Bytes=p.stat().st_size,
                                         SHA256=hashlib.sha256(p.read_bytes()).hexdigest())
                                     for p in core_sources + standalone_sources + binaries]
        summary['Passed'] = (len(summary['Cases']) == 2 * len(cases)
                             and len(summary['Comparisons']) == len(cases)
                             and len(summary['Replays']) == len(cases))
    except Exception as error:
        summary['Error'] = str(error)
        raise
    finally:
        summary['FinishedUTC'] = datetime.now(timezone.utc).isoformat()
        save()
    print(f'PASS: {len(cases)} scenarios, Normal + SIL + recorded-input replay. {folder}', flush=True)


if __name__ == '__main__':
    main()
