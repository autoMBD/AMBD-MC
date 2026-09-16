# SPDX-License-Identifier: MIT
"""End-to-end acceptance using the official MCP server, never a mock server."""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import uuid
import xml.etree.ElementTree as ET
import zipfile

from artifacts import atomic_json
import capabilities
from environment import matlab_quote as mq, runtime, verify_bundle
from mcp_client import Client


def content(result):
    return '\n'.join(item.get('text', '') for item in result.get('content', []) if item.get('type') == 'text')


def saved_structure(model: Path):
    """Inspect saved structure without executing model or hardware callbacks."""
    with zipfile.ZipFile(model) as archive:
        names = archive.namelist()
        system_files = [name for name in names if name.startswith('simulink/systems/') and name.endswith('.xml')]
        if not system_files:
            system_files = ['simulink/blockdiagram.xml']
        root_name = 'simulink/systems/system_root.xml' if 'simulink/systems/system_root.xml' in names else system_files[0]
        root = ET.fromstring(archive.read(root_name))
        if root.tag != 'System':
            root = root.find('.//System')
        if root is None:
            raise ValueError('No saved root System was found')
        root_blocks = [{'name': block.attrib.get('Name'), 'type': block.attrib.get('BlockType')} for block in root.findall('Block')]
        count = sum(len(list(ET.fromstring(archive.read(name)).iter('Block'))) for name in system_files)
        if not root_blocks or not count:
            raise ValueError('No saved blocks were found')
        return {'root_blocks': root_blocks, 'saved_block_count': count}


def run(repo: Path, candidate: dict, *, timeout=600):
    verify_bundle(Path(candidate['bundle']))
    token = uuid.uuid4().hex[:12]
    folder = repo / '.agent-env/reports' / (candidate['id'] + '-' + token)
    folder.mkdir(parents=True)
    for file in (repo / 'tools/agent/matlab').glob('*.m'):
        shutil.copyfile(file, folder / file.name)
    model_name = 'ambd_smoke_' + token
    model = folder / (model_name + '.slx')
    report = {'environment': candidate['id'], 'status': 'FAIL',
              'timestamp': datetime.now(timezone.utc).isoformat(), 'checks': [], 'project': []}
    command, env = runtime(candidate, session='new')  # Never mutate or terminate an existing user session.
    try:
        with Client(command, cwd=repo, env=env, timeout=timeout) as client:
            report['server'] = client.initialize()['serverInfo']
            listed = client.request('tools/list')['tools']
            names = {tool['name'] for tool in listed}
            required = {'evaluate_matlab_code', 'check_matlab_code', 'run_matlab_test_file',
                        'detect_matlab_toolboxes', 'model_overview', 'model_read', 'model_query_params', 'model_scan', 'model_read_diagnostics'}
            if not required <= names:
                raise RuntimeError('Required MCP tools missing: ' + ', '.join(sorted(required - names)))
            report['tools'] = {t['name']: hashlib.sha256(json.dumps(t, sort_keys=True).encode()).hexdigest() for t in listed}

            def call(name, arguments, marker=None, connection=None):
                print('MCP smoke: ' + name, flush=True)
                result = (connection or client).call(name, arguments)
                text = content(result)
                if re.search(r'(?im)^\s*"?\s*status\s*:\s*(?:error|failed)\b', text):
                    raise RuntimeError(f'{name} returned an error: {text}')
                # Extension functions can return a structured error inside text content.
                for item in result.get('content', []):
                    if item.get('type') == 'text':
                        try:
                            payload = json.loads(item['text'])
                        except (json.JSONDecodeError, KeyError):
                            continue
                        if isinstance(payload, dict) and (payload.get('success') is False or
                                                          payload.get('status') == 'error' or payload.get('error')):
                            raise RuntimeError(f'{name}: {item["text"]}')
                if marker and marker not in text:
                    raise RuntimeError(f'{name} did not return required evidence {marker}: {text}')
                report['checks'].append({'tool': name, 'status': 'PASS', 'output': text})
                return text

            call('evaluate_matlab_code', {'code': 'addpath(' + mq(folder) + '); ambd_smoke(' + mq(folder) + ', ' + mq(model_name) + ');'},
                 'AMBD_COMPUTE_AND_SIMULATION_PASS')
            result = json.loads((folder / 'matlab-result.json').read_text(encoding='utf-8'))
            bundle = Path(candidate['bundle']).resolve()
            for key in ('satkInitialize', 'shareMATLABSession'):
                if not Path(result[key]).resolve().is_relative_to(bundle):
                    raise RuntimeError(f'{key} is shadowed by a different environment: {result[key]}')
            report['matlab'] = result
            report['skill_eligibility'] = capabilities.skills(bundle / 'skills', result, names)
            shared_command, shared_env = runtime(candidate, session='existing')
            with Client(shared_command, cwd=repo, env=shared_env, timeout=timeout) as shared:
                shared.initialize()
                call('evaluate_matlab_code', {'code': "assert(feature('getpid')==" + str(result['pid']) +
                     ", 'Shared MATLAB PID differs'); assert(strcmp(strrep(pwd,filesep,'/')," + mq(repo) +
                     "), 'MATLAB working directory differs'); disp('AMBD_SHARED_SESSION_PASS');"},
                     'AMBD_SHARED_SESSION_PASS', connection=shared)
                report['checks'][-1]['session'] = 'existing'
            # Subsequent calls also prove disconnecting a shared client preserves its MATLAB session.
            analysis = call('check_matlab_code', {'script_path': str(folder / 'ambd_probe.m')})
            if json.loads(analysis).get('code_issues') != []:
                raise RuntimeError('Static analysis returned issues for the smoke function: ' + analysis)
            call('run_matlab_test_file', {'script_path': str(folder / 'test_ambd_probe.m')})
            # Assert the result as data as well: tool transport success alone is insufficient.
            call('evaluate_matlab_code', {'code': 'r=runtests(' + mq(folder / 'test_ambd_probe.m') +
                 '); assert(numel(r)==3 && all([r.Passed]) && ~any([r.Incomplete])); disp(\'AMBD_TESTS_PASS\');'}, 'AMBD_TESTS_PASS')
            call('detect_matlab_toolboxes', {})
            call('model_overview', {'model': str(model), 'scope': 'root', 'detail': 'full'}, model_name)
            call('model_read', {'model': str(model), 'scope': 'root', 'depth': '1'}, 'Gain')
            call('model_query_params', {'model': str(model), 'targets': json.dumps(['config:' + model_name]),
                 'params': '["StopTime", "Solver"]', 'compile': 'false'}, '0.2')
            call('model_read_diagnostics', {'model': str(model), 'severity': 'all', 'scope': 'root',
                 'message_id': '', 'detail': 'summary', 'sort_by': 'severity', 'limit': '50', 'offset': '0', 'token_limit': '2000'})
            if result.get('capabilities', {}).get('SimulinkTest', {}).get('status') == 'AVAILABLE':
                feature = folder / 'triple.feature'
                feature.write_text('# --- front-matter:toml ---\nmodel = ' + json.dumps(model.name) +
                    '\ncomponent = "' + model_name + '/Triple"\n[inputs]\nu = "u"\n[outputs]\ny = "y"\n# --- end front-matter ---\n\n'
                    'Feature: Gain behavior\nScenario: Triple a constant\n  Given inputs\n    * u = const(2)\n'
                    '  When simulate for 0.2s in Normal mode\n  Then outputs\n    * CorrectGain: y == 6\n', encoding='utf-8')
                for draft in ('true', 'false'):
                    tests = call('model_test', {'model': model.name, 'gherkin_file': str(feature), 'scenarios': '[]',
                                 'verbose': 'true', 'draft_mode': draft, 'coverage': 'none'})
                    if not re.search(r'(?i)(?:\b[1-9]\d*\s+passed\b|\bstatus\s*:\s*passed\b|\bpassed\s*:\s*[1-9]\d*)', tests):
                        raise RuntimeError('model_test did not report passing scenarios: ' + tests)
                    if re.search(r'(?i)(?:\b[1-9]\d*\s+failed\b|\bfailed\s*:\s*[1-9]\d*)', tests):
                        raise RuntimeError('model_test reported failures: ' + tests)
            else:
                report['checks'].append({'tool': 'model_test', 'status': 'SKIP', 'reason': 'Simulink Test installation/license unavailable'})
            call('evaluate_matlab_code', {'code': 'close_system(' + mq(model_name) + ',0); disp(\'AMBD_MODEL_CLOSED\');'}, 'AMBD_MODEL_CLOSED')
            models = sorted((repo / 'mc-models').rglob('*.slx'))
            if not models:
                report['project'].append({'check': 'current-model', 'status': 'SKIP', 'reason': 'No .slx model under mc-models on this branch'})
                models = sorted((repo / 'legacy').rglob('*.slx'))
            if models:
                # Search saved XML without loading hardware callbacks or writing legacy assets.
                before = hashlib.sha256(models[0].read_bytes()).hexdigest()
                call('model_scan', {'model': str(models[0]), 'command': 'grep', 'pattern': '(?i)PWM'})
                assert hashlib.sha256(models[0].read_bytes()).hexdigest() == before
                report['project'].append({'check': 'saved-model-scan', 'status': 'PASS', 'path': str(models[0].relative_to(repo))})
                report['project'].append({'check': 'saved-model-structure', 'status': 'PASS',
                                         'path': str(models[0].relative_to(repo)), **saved_structure(models[0])})
            generator = repo / 'tools/generate_data_type_from_md.m'
            definitions = repo / 'docs/McStruct.md'
            if generator.exists() and definitions.exists():
                try:
                    generated = folder / 'generated-types'
                    call('evaluate_matlab_code', {'code': 'addpath(' + mq(generator.parent) + '); generate_data_type_from_md(' +
                         mq(definitions) + ',' + mq(generated) + '); run(' + mq(generated / 'mc_data_types.m') +
                         '); disp(\'AMBD_TYPES_PASS\');'}, 'AMBD_TYPES_PASS')
                    report['project'].append({'check': 'type-generator', 'status': 'PASS'})
                except Exception as error:
                    report['project'].append({'check': 'type-generator', 'status': 'FAIL', 'reason': str(error)})
            else:
                report['project'].append({'check': 'type-generator', 'status': 'SKIP',
                                         'reason': 'Generator or docs/McStruct.md not present on this branch'})
        # Validate after shutdown too; a runtime must not alter the pinned bundle.
        verify_bundle(Path(candidate['bundle']))
        report['status'] = 'PASS'
    except BaseException as error:
        report['error'] = f'{type(error).__name__}: {error}'
        raise
    finally:
        atomic_json(folder / 'smoke.json', report)
        print('Smoke report: ' + str(folder / 'smoke.json'), flush=True)
    return report
