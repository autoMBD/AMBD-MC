# SPDX-License-Identifier: MIT
"""Bootstrap, inspect and explicitly update the AMBD-MC MathWorks environment."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tomllib

import artifacts
import configuration
import environment
import smoke


def matlab_root(value):
    value = value or os.environ.get('MATLAB_ROOT')
    if not value and shutil.which('matlab'):
        value = str(Path(shutil.which('matlab')).parent.parent)
    if not value:
        installed = sorted((Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'MATLAB').glob('R*'))
        value = str(installed[-1]) if installed else None
    if not value or not (Path(value) / 'bin/matlab.exe').is_file():
        raise ValueError('MATLAB was not found. Pass --matlab-root / -MatlabRoot with the installation root (without bin).')
    return str(Path(value).resolve())


def check_updates(repo, lock, cache, output):
    releases = artifacts.latest_releases()
    changes = environment.release_changes(lock, releases)
    report = {'updates_available': bool(changes), 'versions': changes,
              'sources': {key: value['html_url'] for key, value in releases.items()},
              'inventory': artifacts.inventory_diff({}, {}), 'mcp_builtin_schema': 'unchanged'}
    candidate = lock
    if changes:
        candidate = artifacts.resolve_latest(lock['skill_groups'], cache, releases)
        new_bundle = environment.prepare(repo, candidate, cache)
        new_inventory = json.loads((new_bundle / 'inventory.json').read_text(encoding='utf-8'))
        baseline = lock.get('inventory')
        if baseline is None:
            old_bundle = environment.prepare(repo, lock, cache)
            baseline = json.loads((old_bundle / 'inventory.json').read_text(encoding='utf-8'))
        report['inventory'] = artifacts.inventory_diff(baseline, new_inventory)
        if 'mcp' in changes:
            # Static release checks do not launch binaries or MATLAB on CI.
            report['mcp_builtin_schema'] = 'requires runtime tools/list during Sync; static diff covers Simulink extension schemas'
        candidate['inventory'] = new_inventory
    candidate_path = output.with_name('candidate.lock.json')
    artifacts.atomic_json(candidate_path, candidate)
    report['candidate_lock'] = str(candidate_path)
    artifacts.atomic_json(output, report)
    return candidate, report


def doctor(repo, args):
    result = {'python': platform.python_version(), 'platform': platform.platform(), 'checks': []}
    checks = result['checks']
    def check(name, function):
        try:
            detail = function()
            checks.append({'check': name, 'status': 'PASS', 'detail': str(detail or 'OK')})
        except Exception as error:
            checks.append({'check': name, 'status': 'FAIL', 'detail': str(error)})
    check('lock', lambda: artifacts.lock_id(artifacts.read_lock(args.lock)))
    state = configuration.read_state(repo)
    check('MATLAB installation', lambda: matlab_root(args.matlab_root or state.get('active', {}).get('matlab_root')))
    check('WINDIR', lambda: os.environ['WINDIR'])
    if not state.get('active'):
        checks.append({'check': 'active environment', 'status': 'FAIL', 'detail': 'Run Bootstrap first'})
    else:
        check('bundle integrity', lambda: environment.verify_bundle(Path(state['active']['bundle'])))
        def skills_check():
            registration = repo / '.agents/skills/ambd-mathworks'
            if not registration.is_dir():
                raise ValueError('Skill registration missing; run Bootstrap to repair it')
            configuration._check_registration(repo, state)
            return registration
        check('skill ownership', skills_check)
        def config_check():
            file = repo / '.codex/config.toml'
            text = file.read_text(encoding='utf-8')
            tomllib.loads(text)
            if state['config_block'] not in text:
                raise ValueError('Managed MCP configuration missing or changed')
            return file
        check('project MCP config', config_check)
        result['active'] = state['active']
        result['skills'] = len(list((Path(state['active']['bundle']) / 'skills').glob('*/SKILL.md')))
        reports = sorted((repo / '.agent-env/reports').glob(state['active']['id'] + '-*/smoke.json'), key=lambda p: p.stat().st_mtime)
        if reports:
            last = json.loads(reports[-1].read_text(encoding='utf-8'))
            result['last_smoke'] = {'path': str(reports[-1]), 'timestamp': last['timestamp'], 'status': last['status'],
                                    'capabilities': last.get('matlab', {}).get('capabilities', {}),
                                    'skill_eligibility': last.get('skill_eligibility', {})}
    for file in ('operation.lock', 'activation-journal.json'):
        if (repo / '.agent-env' / file).exists():
            checks.append({'check': file, 'status': 'FAIL', 'detail': 'Review interrupted operation; see recovery documentation'})
    result['status'] = 'FAIL' if any(c['status'] == 'FAIL' for c in checks) else 'PASS'
    result['runtime_note'] = 'Read-only checks; run Smoke for MATLAB license, toolbox and MCP execution acceptance.'
    return result


def parser():
    command = argparse.ArgumentParser(description=__doc__)
    command.add_argument('action', choices=['Bootstrap', 'Doctor', 'CheckUpdates', 'Sync', 'Smoke', 'Rollback', 'Recover', 'Serve'])
    command.add_argument('--repo-root', type=Path, default=Path(__file__).resolve().parents[2])
    command.add_argument('--lock', type=Path)
    command.add_argument('--cache', type=Path)
    command.add_argument('--matlab-root')
    command.add_argument('--session', choices=['new', 'existing', 'auto'])
    command.add_argument('--offline', action='store_true')
    command.add_argument('--latest', action='store_true', help='Sync only: resolve, validate, activate, then update the selected lock file')
    command.add_argument('--output', type=Path)
    command.add_argument('--timeout', type=float, default=600)
    return command


def main(argv=None):
    args = parser().parse_args(argv)
    repo = args.repo_root.resolve()
    args.lock = (args.lock or repo / 'tools/agent/official.lock.json').resolve()
    cache = (args.cache or repo / '.agent-env/cache').resolve()
    output = (args.output or repo / '.agent-env/update-report.json').resolve()
    if args.latest and (args.action != 'Sync' or args.offline):
        raise ValueError('--latest requires online Sync')
    if args.action == 'Serve':
        state = configuration.read_state(repo)
        if not state.get('active'):
            raise ValueError('No verified environment. Run Bootstrap first.')
        if (repo / '.agent-env/activation-journal.json').exists():
            raise ValueError('Activation interrupted. Run Recover first.')
        environment.verify_bundle(Path(state['active']['bundle']))
        command, env = environment.runtime(state['active'])
        # Transparent stdio launcher; MATLAB and Simulink tools come from the official executable.
        return subprocess.call(command, env=env, cwd=repo, stdin=sys.stdin, stdout=sys.stdout, stderr=sys.stderr,
                               creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
    if args.action == 'Doctor':
        result = doctor(repo, args)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0 if result['status'] == 'PASS' else 1
    if args.action == 'CheckUpdates':
        if args.offline:
            raise ValueError('CheckUpdates requires network access; offline Bootstrap/Sync use cached locked artifacts')
        _, result = check_updates(repo, artifacts.read_lock(args.lock), cache, output)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    if args.action == 'Recover':
        configuration.recover(repo)
        print('Recovered the previous project configuration. Run Doctor and Smoke.')
        return 0
    if os.name != 'nt':
        raise ValueError('Runtime setup currently supports Windows x64. CheckUpdates and unit tests are portable.')
    def validate(candidate):
        return smoke.run(repo, candidate, timeout=args.timeout)
    if args.action == 'Smoke':
        candidate = configuration.read_state(repo).get('active')
        if not candidate:
            raise ValueError('No active environment. Run Bootstrap first.')
        validate(candidate)
    elif args.action == 'Rollback':
        configuration.rollback(repo, validate)
        print('Previous environment verified and activated. Restart the Codex task to reconnect.')
    else:
        lock = artifacts.read_lock(args.lock)
        if args.latest:
            lock, report = check_updates(repo, lock, cache, output)
            print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)
        bundle = environment.prepare(repo, lock, cache, args.offline)
        active = configuration.read_state(repo).get('active', {})
        candidate = {'id': bundle.name, 'bundle': str(bundle),
                     'matlab_root': matlab_root(args.matlab_root or active.get('matlab_root')),
                     'session': args.session or active.get('session', 'new')}
        runtime_report = None
        def verify(value):
            nonlocal runtime_report
            runtime_report = validate(value)
            old_active = configuration.read_state(repo).get('active')
            old_lock = artifacts.read_lock(Path(old_active['bundle']) / 'lock.json') if old_active else lock
            baseline = old_lock.get('verification', {}).get('mcp_tools', {})
            previous_tools = repo / '.agent-env/runtime-tools' / ((old_active or {}).get('id', '') + '.json')
            if previous_tools.is_file():
                baseline = json.loads(previous_tools.read_text(encoding='utf-8'))
            old_inventory = json.loads((Path(old_active['bundle']) / 'inventory.json').read_text(encoding='utf-8')) if old_active else {}
            new_inventory = json.loads((Path(value['bundle']) / 'inventory.json').read_text(encoding='utf-8'))
            delta = artifacts.inventory_diff({'tools': baseline, 'skills': old_inventory.get('skills', {})},
                                             {'tools': runtime_report['tools'], 'skills': new_inventory['skills']})
            artifacts.atomic_json(repo / '.agent-env/runtime-tools' / (value['id'] + '.json'), runtime_report['tools'])
            artifacts.atomic_json(repo / '.agent-env/runtime-update-report.json', {'from': (old_active or {}).get('id'),
                                  'to': value['id'], **delta, 'baseline_available': bool(baseline)})
            print('Validated tool/skill changes: ' + json.dumps(delta), flush=True)
        configuration.activate(repo, candidate, verify)
        if args.latest:
            lock['verification'] = {'timestamp': runtime_report['timestamp'], 'matlab': runtime_report['matlab']['release'],
                                    'python': platform.python_version(), 'mcp_tools': runtime_report['tools']}
            artifacts.atomic_json(args.lock, lock)
        print('Verified environment activated: ' + candidate['id'])
        print('Project MCP: ' + str(repo / '.codex/config.toml'))
        print('Restart the Codex task to load MCP and official skills.')
    return 0


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    try:
        raise SystemExit(main())
    except (Exception, KeyboardInterrupt) as error:
        # stderr is essential: Serve stdout belongs exclusively to the MCP protocol.
        print(f'Agent environment failed: {type(error).__name__}: {error}', file=sys.stderr)
        raise SystemExit(1)
