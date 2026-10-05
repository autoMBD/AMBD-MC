# SPDX-License-Identifier: MIT
"""Project-local bundles built from unmodified official release artifacts."""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import tempfile
import uuid

from artifacts import atomic_json, extract, inventory, lock_id, obtain, sha256, validate_lock


def matlab_quote(value) -> str:
    return "'" + str(value).replace('\\', '/').replace("'", "''") + "'"


def release_changes(lock, releases):
    return {key: {'from': component['tag'], 'to': releases[key]['tag_name']}
            for key, component in lock['components'].items()
            if component['tag'] != releases[key]['tag_name']}


def verify_bundle(bundle: Path):
    manifest = json.loads((bundle / 'files.json').read_text(encoding='utf-8'))
    actual = {p.relative_to(bundle).as_posix(): sha256(p)
              for p in bundle.rglob('*') if p.is_file() and p != bundle / 'files.json'}
    if actual != manifest:
        raise ValueError(f'Environment files changed or are incomplete: {bundle}. Preserve edits and rebuild from cache.')


def prepare(repo: Path, lock: dict, cache: Path, offline=False) -> Path:
    validate_lock(lock)
    parent = repo / '.agent-env/environments'
    parent.mkdir(parents=True, exist_ok=True)
    destination = parent / lock_id(lock)
    if destination.exists():
        verify_bundle(destination)
        return destination
    stage = Path(tempfile.mkdtemp(prefix='.candidate-', dir=parent))
    try:
        roles = {}
        for key, component in lock['components'].items():
            for asset in component['artifacts']:
                path = obtain(asset, cache, offline)
                name = asset['name']
                if name.endswith('.zip') and key in ('matlab', 'simulink'):
                    unpack = stage / (key + '-archive')
                    extract(path, unpack)
                    children = list(unpack.iterdir())
                    if len(children) != 1 or not children[0].is_dir():
                        raise ValueError('Expected one root in the official toolkit archive')
                    children[0].rename(stage / key)
                    unpack.rmdir()
                    roles[key] = stage / key
                elif key == 'mcp' and name.endswith('.exe'):
                    (stage / 'bin').mkdir(exist_ok=True)
                    shutil.copyfile(path, stage / 'bin/matlab-mcp-server.exe')
                    roles['binary'] = True
                elif name == 'MATLABMCPServerToolbox.mltbx':
                    extract(path, stage / 'mcp-toolbox')
                    roles['toolbox'] = True
                elif name == 'agenticToolkitInstaller.mltbx':
                    # Keep the official installer available for documented manual fallback.
                    shutil.copyfile(path, stage / name)
        if set(roles) != {'matlab', 'simulink', 'binary', 'toolbox'}:
            raise ValueError('Lock must provide both toolkits, a Windows MCP binary and MCP toolbox')
        inventories = inventory({k: roles[k] for k in ('matlab', 'simulink')}, lock['skill_groups'])
        skills = stage / 'skills'
        skills.mkdir()
        names = set()
        for toolkit, groups in lock['skill_groups'].items():
            for group in groups:
                for skill in sorted((stage / toolkit / 'skills-catalog' / group).glob('*/SKILL.md')):
                    if skill.parent.name in names:
                        raise ValueError(f'Duplicate selected skill name: {skill.parent.name}')
                    names.add(skill.parent.name)
                    shutil.copytree(skill.parent, skills / skill.parent.name)
        if not names:
            raise ValueError('Select at least one official skill')
        (stage / 'startup').mkdir()
        startup = '\n'.join([
            '% SPDX-License-Identifier: MIT',
            '% Generated project entry point; official toolkit files remain unmodified.',
            'addpath(' + matlab_quote(destination / 'mcp-toolbox/fsroot') + ');',
            'addpath(' + matlab_quote(destination / 'simulink') + ');',
            'satk_initialize(MCPServerPath=' + matlab_quote(destination / 'bin/matlab-mcp-server.exe') + ');',
            'Simulink.fileGenControl(\'set\', \'CacheFolder\', ' + matlab_quote(repo / '.agent-env/matlab-cache') +
            ', \'CodeGenFolder\', ' + matlab_quote(repo / '.agent-env/matlab-codegen') + ', \'createDir\', true);',
            'cd(' + matlab_quote(repo) + ');', ''])
        (stage / 'startup/startup.m').write_text(startup, encoding='utf-8')
        atomic_json(stage / 'lock.json', lock)
        atomic_json(stage / 'inventory.json', inventories)
        atomic_json(stage / 'files.json', {p.relative_to(stage).as_posix(): sha256(p)
                                          for p in stage.rglob('*') if p.is_file()})
        # Rename commits a complete immutable bundle; active pointers are changed separately.
        stage.rename(destination)
    finally:
        if stage.exists():
            if stage.resolve().parent != parent.resolve() or not stage.name.startswith('.candidate-'):
                raise ValueError('Unsafe candidate cleanup path')
            shutil.rmtree(stage)
    return destination


def runtime(candidate: dict, *, session=None):
    bundle = Path(candidate['bundle'])
    mode = session or candidate.get('session', 'new')
    command = [str(bundle / 'bin/matlab-mcp-server.exe'),
               '--matlab-session-mode=' + mode, '--disable-telemetry=true',
               '--extension-file=' + str(bundle / 'simulink/tools/tools.json'),
               '--log-folder=' + str(bundle.parent.parent / 'logs' / uuid.uuid4().hex),
               '--log-level=warn']
    if mode != 'existing':
        command += ['--matlab-root=' + candidate['matlab_root'], '--matlab-display-mode=nodesktop',
                    '--initial-working-folder=' + str(bundle.parent.parent.parent)]
    env = os.environ.copy()
    env['MATLABPATH'] = str(bundle / 'startup') + (os.pathsep + env['MATLABPATH'] if env.get('MATLABPATH') else '')
    return command, env
