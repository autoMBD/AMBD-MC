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
# File:        concurrent_smoke.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-08
# Version:     0.1.0
# Description: Real N-instance MCP isolation and lifecycle regression.
# =================================================================================

"""Real hardware-free concurrent MATLAB acceptance; reports remain local."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import uuid

from artifacts import atomic_json
from configuration import read_state
from environment import runtime, matlab_quote as mq, verify_bundle
from mcp_client import Client
from smoke import content


def alive(pid):
    api = ctypes.WinDLL('kernel32', use_last_error=True)
    api.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    api.OpenProcess.restype = wintypes.HANDLE
    api.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
    api.CloseHandle.argtypes = [wintypes.HANDLE]
    handle = api.OpenProcess(0x1000, False, pid)
    if not handle:
        return False
    try:
        code = wintypes.DWORD()
        return bool(api.GetExitCodeProcess(handle, ctypes.byref(code))) and code.value == 259
    finally:
        api.CloseHandle(handle)


def fingerprints(repo):
    files = subprocess.check_output(['git', 'ls-files', '-z'], cwd=repo).decode().split('\0')
    return {name: hashlib.sha256((repo / name).read_bytes()).hexdigest()
            for name in files if name and not name.startswith('legacy/') and (repo / name).is_file()}


def evaluate(client, code, marker):
    result = content(client.call('evaluate_matlab_code', {'code': code}))
    if marker not in result.splitlines():
        raise RuntimeError(result)
    return result


def category(error):
    message = str(error).lower()
    if any(text in message for text in ('license checkout', 'license manager', '许可证', 'licensing error')):
        return 'license'
    if any(text in message for text in ('out of memory', 'not enough memory', '内存不足')):
        return 'resource'
    if any(text in message for text in ('sldd:', 'dictionarychangedondisk', 'sharedoutput',
                                       'instanceowner', 'directorybusy', 'foreigninstancewrite')):
        return 'directory-conflict'
    if isinstance(error, (TimeoutError, EOFError, BrokenPipeError)):
        return 'transport'
    return 'workload'


def run(repo, candidate, *, instances=2, cycles=2, timeout=1800):
    if instances < 2 or cycles < 1:
        raise ValueError('Use at least two instances and one cycle')
    if os.name != 'nt':
        raise ValueError('The pinned runtime and lifecycle acceptance require Windows')
    verify_bundle(Path(candidate['bundle']))
    report_dir = repo / '.agent-env/reports' / ('concurrent-' + uuid.uuid4().hex[:12])
    report_dir.mkdir(parents=True)
    report = {'status': 'FAIL', 'instances': instances, 'cycles': [], 'hardware': 'SKIP: no hardware access'}
    before = fingerprints(repo)
    user_discovery = Path(os.environ['APPDATA']) / 'MathWorks/MATLAB MCP Server/v1/sessionDetails.json'
    def discovery_hash():
        return hashlib.sha256(user_discovery.read_bytes()).hexdigest() if user_discovery.is_file() else None
    discovery_before = discovery_hash()
    process_ids = subprocess.check_output(['powershell', '-NoProfile', '-Command',
        "@(Get-Process MATLAB -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id) | ConvertTo-Json -Compress"], text=True).strip()
    existing_pids = json.loads(process_ids) if process_ids else []
    if isinstance(existing_pids, int):
        existing_pids = [existing_pids]
    report['preexisting_matlab_pids'] = existing_pids
    all_roots = set()
    try:
        for cycle in range(cycles):
            entry = {'cycle': cycle + 1, 'workers': [], 'lifecycle': []}
            report['cycles'].append(entry)
            with ExitStack() as stack:
                clients, roots = [], []
                for index in range(instances):
                    command, env = runtime(candidate, session='new')
                    root = Path(env['AMBD_MATLAB_INSTANCE'])
                    if root in all_roots:
                        raise AssertionError('An instance directory was reused')
                    all_roots.add(root)
                    roots.append(root)
                    clients.append(stack.enter_context(Client(command, env=env, cwd=root / 'work', timeout=timeout)))
                def initialize(index):
                    clients[index].initialize()
                    evaluate(clients[index], "assert(isfile(fullfile(getenv('AMBD_MATLAB_INSTANCE'),'matlab.json'))); disp('READY');", 'READY')
                    record = json.loads((roots[index] / 'matlab.json').read_text())
                    record['root'] = str(roots[index])
                    return record
                with ThreadPoolExecutor(max_workers=instances) as pool:
                    records = list(pool.map(initialize, range(instances)))
                entry['workers'] = records
                pids = [record['pid'] for record in records]
                if len(set(pids)) != instances:
                    raise AssertionError('MCP connections did not create distinct MATLAB processes')
                for field in ('temp', 'work', 'root'):
                    if len({os.path.normcase(r[field]) for r in records}) != instances:
                        raise AssertionError('Shared actual directory: ' + field)
                print(f'Cycle {cycle+1}: {instances} real MATLAB PIDs {pids} ready', flush=True)
                exclusive = report_dir / f'exclusive-{cycle+1}'
                evaluate(clients[0], 'ambd_claim_directory(' + mq(repo) + ',' + mq(exclusive) + "); disp('CLAIMED');", 'CLAIMED')
                evaluate(clients[1], "caught=false; try; ambd_claim_directory(" + mq(repo) + ',' + mq(exclusive) +
                         "); catch e; caught=strcmp(e.identifier,'ambd:DirectoryBusy'); end; assert(caught); disp('EXCLUDED');", 'EXCLUDED')
                entry['lifecycle'].append('explicit output directory excluded a concurrent second writer')
                def workload(index):
                    output = roots[index] / 'acceptance.json'
                    text = content(clients[index].call('evaluate_matlab_code', {'code':
                        'ambd_concurrent_probe(' + mq(repo) + ',' + mq(output) + ');'}))
                    (report_dir / f'cycle-{cycle+1}-worker-{index+1}.log').write_text(text, encoding='utf-8')
                    data = json.loads(output.read_text(encoding='utf-8')) if output.is_file() else {'passed': False, 'error': text}
                    records[index]['result'] = data
                    if not data.get('passed') or 'AMBD_CONCURRENT_PASS' not in text.splitlines():
                        raise RuntimeError(data.get('errorIdentifier', '') + ': ' + data.get('error', '') + '\n' + text)
                    print(f'Cycle {cycle+1} worker {index+1}: HSP {data["tests"]}, BLDC/PMSM simulation PASS', flush=True)
                with ThreadPoolExecutor(max_workers=instances) as pool:
                    # Joining every future before cleanup prevents a sibling failure
                    # from being mistaken for a server still running in background.
                    futures = [pool.submit(workload, i) for i in range(instances)]
                    errors = []
                    for future in futures:
                        try:
                            future.result()
                        except Exception as error:
                            errors.append(error)
                    if errors:
                        raise errors[0]
                shared_command, shared_env = runtime(candidate, session='existing', attach_instance=roots[0])
                with Client(shared_command, env=shared_env, cwd=repo, timeout=timeout) as shared:
                    shared.initialize()
                    evaluate(shared, f"assert(feature('getpid')=={pids[0]}); disp('ATTACHED');", 'ATTACHED')
                evaluate(clients[0], "disp('SURVIVED_ATTACHMENT');", 'SURVIVED_ATTACHMENT')
                entry['lifecycle'].append('existing attached to same PID and detached without stopping owner')
                # A MATLAB error is recorded but does not terminate other instances.
                failed = content(clients[0].call('evaluate_matlab_code', {'code': "error('ambd:ExpectedFailure','AMBD_EXPECTED_FAILURE');"}))
                if 'AMBD_EXPECTED_FAILURE' not in failed:
                    raise AssertionError('Failed MATLAB workload was not observed')
                clients[0].close()
                for client in clients[1:]:
                    evaluate(client, "disp('SURVIVED_SIBLING_EXIT');", 'SURVIVED_SIBLING_EXIT')
                entry['lifecycle'].append('failed workload/owner exit preserved every sibling')
                cancellation = roots[1] / 'cancellation-started'
                clients[1].timeout = 5
                try:
                    clients[1].call('evaluate_matlab_code', {'code':
                        "f=fopen(" + mq(cancellation) + ",'w'); fclose(f); pause(30); disp('UNEXPECTED_COMPLETION');"})
                    raise AssertionError('Cancellation workload unexpectedly completed')
                except TimeoutError:
                    if not cancellation.is_file():
                        raise AssertionError('MATLAB did not enter the cancellation workload')
                    clients[1].close()
                for client in clients[2:]:
                    evaluate(client, "disp('SURVIVED_CANCEL');", 'SURVIVED_CANCEL')
                entry['lifecycle'].append('in-flight timeout cancelled only owned process tree')
            deadline = time.monotonic() + 15
            while any(alive(pid) for pid in pids) and time.monotonic() < deadline:
                time.sleep(0.1)
            if any(alive(pid) for pid in pids):
                raise AssertionError('Owned MATLAB process survived cleanup')
            if any(not root.is_dir() for root in roots):
                raise AssertionError('An instance artifact directory was deleted')
            entry['lifecycle'].append('all owned MATLAB PIDs exited; all artifacts retained')
            atomic_json(report_dir / 'concurrent.json', report)
        if before != fingerprints(repo):
            raise AssertionError('Tracked sources changed during concurrent execution')
        if discovery_before != discovery_hash():
            raise AssertionError('User MCP session discovery changed during managed launches')
        if any(not alive(pid) for pid in existing_pids):
            raise AssertionError('A preexisting MATLAB process exited during the regression')
        verify_bundle(Path(candidate['bundle']))
        report['sources_unchanged'] = True
        report['preexisting_matlab_alive'] = True
        report['user_discovery_unchanged'] = True
        report['status'] = 'PASS'
    except BaseException as error:
        report['category'] = category(error)
        report['error'] = str(error)
        raise
    finally:
        atomic_json(report_dir / 'concurrent.json', report)
        print('Concurrency report: ' + str(report_dir / 'concurrent.json'), flush=True)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--instances', type=int, default=2)
    parser.add_argument('--cycles', type=int, default=2)
    parser.add_argument('--timeout', type=float, default=1800)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    candidate = read_state(repo).get('active')
    if not candidate:
        raise ValueError('Run Bootstrap first')
    run(repo, candidate, instances=args.instances, cycles=args.cycles, timeout=args.timeout)


if __name__ == '__main__':
    main()
