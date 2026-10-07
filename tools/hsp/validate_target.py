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
# File:        validate_target.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-07
# Version:     0.1.0
# Description: Build HSP firmware and verify target PIL with source and ELF fingerprints.
# =================================================================================

"""Build all selected HSP components and run actual S32K344 PIL replays."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]


def quote(value):
    return "'" + str(value).replace("\\", "/").replace("'", "''") + "'"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_application_receipt(stage, model):
    path = stage / 'build' / model / 'application/hsp-build-result.json'
    receipt = json.loads(path.read_text(encoding='utf-8'))
    artifact = receipt.get('target', {})
    elf = Path(artifact.get('elf', ''))
    if (receipt.get('status') != 'passed' or receipt.get('stage') != 'target-compiled'
            or receipt.get('model') != model or artifact.get('status') != 'passed'
            or artifact.get('mode') != 'application'
            or artifact.get('elfVerification', {}).get('status') != 'passed' or not elf.is_file()):
        raise RuntimeError('Missing verified native build receipt for ' + model)
    if digest(elf) != artifact.get('elfSha256'):
        raise RuntimeError('ELF changed after native build: ' + model)
    return path, receipt


def source_hashes(families):
    paths = [ROOT / "hsp_setup.m", ROOT / "hsp_stage.m"]
    for directory in [ROOT / "mc-models/hsp", ROOT / "tools/hsp"] + [ROOT / "mc-models" / f for f in families]:
        paths.extend(p for p in directory.rglob('*') if p.is_file()
                     and p.suffix.lower() in ('.m', '.slx', '.sldd', '.py', '.json', '.c', '.h', '.xdm', '.tdb')
                     and '__pycache__' not in p.parts)
    return {p.relative_to(ROOT).as_posix(): digest(p) for p in sorted(set(paths))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--settings', type=Path, required=True, help='Ignored local tool/connection JSON.')
    parser.add_argument('--family', choices=('bldc', 'pmsm'), action='append')
    parser.add_argument('--model', action='append', help='Restrict the matrix for diagnosis.')
    args = parser.parse_args()
    settings = args.settings.resolve()
    families = args.family or ['bldc', 'pmsm']
    manifest = json.loads((ROOT / 'mc-models/hsp/models.json').read_text(encoding='utf-8'))
    selected = [m for m in manifest['models'] if m['family'] in families
                and m['role'] in ('component', 'application') and (not args.model or m['name'] in args.model)]
    selected.sort(key=lambda model: model['role'] != 'application')
    if not selected or (args.model and set(args.model) != {m['name'] for m in selected}):
        parser.error('Select existing target components within the chosen family.')
    folder = ROOT / '.agent-env/hsp/validation' / uuid.uuid4().hex[:8]
    folder.mkdir(parents=True)
    baseline = source_hashes(families)
    summary = dict(Passed=False, CompleteMatrix=not args.family and not args.model,
                   StartedUTC=datetime.now(timezone.utc).isoformat(),
                   SourceHashes=baseline, SettingsSha256=digest(settings), Models=[])
    transcript = []

    def save():
        for name, value in [('transcript.json', transcript), ('summary.json', summary)]:
            temporary = folder / (name + '.tmp')
            temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding='utf-8')
            temporary.replace(folder / name)

    def evaluate(client, code, marker):
        result = client.call('evaluate_matlab_code', {'code': code, 'project_path': str(ROOT)})
        transcript.append(dict(Code=code, Result=result))
        save()
        text = '\n'.join(p.get('text', '') for p in result.get('content', []))
        if result.get('isError') or marker not in text.splitlines():
            raise RuntimeError(text or str(result))
        print(marker, flush=True)

    sys.path.insert(0, str(ROOT / 'tools/agent'))
    import configuration
    import environment
    from mcp_client import Client
    save()
    print('Target reports: ' + str(folder), flush=True)
    try:
        for family in families:
            entries = [m for m in selected if m['family'] == family]
            if not entries:
                continue
            command, env = environment.runtime(configuration.read_state(ROOT)['active'], session='new')
            with Client(command, cwd=ROOT, env=env, timeout=1800) as client:
                client.initialize()
                stage_file = folder / (family + '-stage.txt')
                evaluate(client, f"addpath({quote(ROOT)});stageInfo=hsp_stage({quote(family)},{quote(settings)});"
                         f"fid=fopen({quote(stage_file)},'w');fprintf(fid,'%s',stageInfo.Stage);fclose(fid);"
                         "disp('HSP_STAGE_READY');", 'HSP_STAGE_READY')
                stage = Path(stage_file.read_text(encoding='utf-8'))
                for entry in entries:
                    name = entry['name']
                    model_folder = folder / name
                    model_folder.mkdir()
                    record = dict(Model=name, Family=family, Stage=str(stage), Passed=False)
                    summary['Models'].append(record)
                    save()
                    log = model_folder / 'build.log'
                    marker = 'TARGET_BUILD_PASS_' + name
                    evaluate(client, "buildFailure=[];"
                             f"buildText=evalc('try;slbuild(''{name}'');catch exception;buildFailure=exception;end');"
                             f"fid=fopen({quote(log)},'w','n','UTF-8');fprintf(fid,'%s',buildText);fclose(fid);"
                             f"if ~isempty(buildFailure),rethrow(buildFailure);end;disp('{marker}');", marker)
                    receipt_path, receipt = read_application_receipt(stage, name)
                    artifact = receipt['target']
                    elf = Path(artifact['elf'])
                    record['Build'] = dict(Passed=True, Receipt=str(receipt_path), Elf=str(elf), SHA256=digest(elf))
                    save()
                    marker = 'TARGET_PIL_PASS_' + name
                    evaluate(client, f"result=ambd.validate_pil({quote(name)},{quote(family)},"
                             f"{quote(model_folder / 'pil')});assert(result.Passed);"
                             f"saved=load({quote(model_folder / 'pil/traces.mat')},'result');"
                             f"assert(isequaln(saved.result,result));disp('{marker}');", marker)
                    record['PIL'] = json.loads((model_folder / 'pil/result.json').read_text(encoding='utf-8'))
                    record['Passed'] = record['PIL']['Passed']
                    save()
        summary['SourcesUnchanged'] = source_hashes(families) == baseline
        summary['SettingsUnchanged'] = digest(settings) == summary['SettingsSha256']
        if not summary['SourcesUnchanged'] or not summary['SettingsUnchanged']:
            raise RuntimeError('Validation inputs changed; repeat with stable sources/settings.')
        summary['Passed'] = len(summary['Models']) == len(selected) and all(m['Passed'] for m in summary['Models'])
        if not summary['Passed']:
            raise RuntimeError('One or more required target cases are incomplete.')
    except BaseException as error:
        summary['Passed'] = False
        summary['Error'] = str(error)
        raise
    finally:
        summary['FinishedUTC'] = datetime.now(timezone.utc).isoformat()
        save()
    print(f"PASS: {len(selected)} native builds and target PIL replays. {folder}", flush=True)


if __name__ == '__main__':
    main()
