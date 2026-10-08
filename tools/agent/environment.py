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
# File:        environment.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-09-11
# Version:     0.1.0
# Description: Project-local bundles built from unmodified official release artifacts.
# =================================================================================

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
    # Project startup changed independently of the pinned upstream artifacts.
    # A revisioned bundle migrates old installations without editing their files.
    destination = parent / (lock_id(lock) + '-startup2')
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
            '% Existing sessions retain their working folder and file generation configuration.',
            ''])
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


def runtime(candidate: dict, *, session=None, attach_instance=None):
    bundle = Path(candidate['bundle'])
    requested = session or candidate.get('session', 'new')
    if requested not in ('new', 'existing', 'auto'):
        raise ValueError('Session must be new, existing or auto')
    # Official auto may attach to a user session. Project auto is deliberately
    # deterministic: only explicit existing requests may attach to a session.
    mode = 'existing' if requested == 'existing' else 'new'
    repo = bundle.parent.parent.parent
    env = os.environ.copy()
    if attach_instance is not None:
        if mode != 'existing':
            raise ValueError('An attachment requires explicit existing mode')
        target = Path(attach_instance).resolve()
        owner = json.loads((target / 'owner.json').read_text(encoding='utf-8'))
        if not target.is_relative_to((repo / '.agent-env/i').resolve()) or Path(owner['repo']).resolve() != repo.resolve():
            raise ValueError('Attachment does not belong to this repository')
        if not (target / 'matlab.json').is_file():
            raise ValueError('Attachment has no initialized MATLAB instance')
        env['APPDATA'] = str(target / 'appdata')
    log_folder = bundle.parent.parent / 'logs' / uuid.uuid4().hex[:12]
    if mode == 'new':
        parent = repo / '.agent-env/i'
        parent.mkdir(parents=True, exist_ok=True)
        instance = Path(tempfile.mkdtemp(prefix='', dir=parent))
        for child in ('tmp', 'work', 'cache', 'codegen', 'startup', 'appdata'):
            (instance / child).mkdir()
        atomic_json(instance / 'owner.json', {
            'instance': instance.name, 'repo': str(repo.resolve()),
            'launcher_pid': os.getpid(), 'requested_mode': requested,
            'lifecycle': 'retained; never automatically delete instance artifacts'})
        for key in ('TEMP', 'TMP', 'TMPDIR'):
            env[key] = str(instance / 'tmp')
        env['AMBD_MATLAB_INSTANCE'] = str(instance)
        startup = '\n'.join([
            '% SPDX-License-Identifier: MIT',
            '% Per-instance entry point; immutable official bundles are not edited.',
            'addpath(' + matlab_quote(repo / 'tools/agent/matlab') + ');',
            'ambd_agent_startup(' + ', '.join(map(matlab_quote, (repo, instance, bundle))) + ');', ''])
        (instance / 'startup/startup.m').write_text(startup, encoding='utf-8')
        env['MATLABPATH'] = str(instance / 'startup') + (os.pathsep + env['MATLABPATH'] if env.get('MATLABPATH') else '')
    # Windows AF_UNIX has a 108-byte path limit, including the server basename.
    # Use an existing directory's short spelling when worktree paths are deep.
    if len(str(log_folder / '.matlab-mcp-server-4294967295').encode('utf-8')) >= 108:
        log_folder.mkdir(parents=True, exist_ok=True)
        if os.name == 'nt':
            import ctypes
            from ctypes import wintypes
            api = ctypes.WinDLL('kernel32', use_last_error=True).GetShortPathNameW
            api.argtypes = [wintypes.LPCWSTR, wintypes.LPWSTR, wintypes.DWORD]
            api.restype = wintypes.DWORD
            buffer = ctypes.create_unicode_buffer(32768)
            if api(str(log_folder), buffer, len(buffer)):
                log_folder = Path(buffer.value)
        if len(str(log_folder / '.matlab-mcp-server-4294967295').encode('utf-8')) >= 108:
            raise ValueError('MCP socket path is too long. Use a shorter checkout path (or enable Windows short names).')
    command = [str(bundle / 'bin/matlab-mcp-server.exe'),
               '--matlab-session-mode=' + mode, '--disable-telemetry=true',
               '--extension-file=' + str(bundle / 'simulink/tools/tools.json'),
               # The official server creates an AF_UNIX socket under this folder.
               # Keep per-launch isolation without exhausting its 108-byte path limit.
               '--log-folder=' + str(log_folder),
               '--log-level=warn']
    if mode != 'existing':
        command += ['--matlab-root=' + candidate['matlab_root'], '--matlab-display-mode=nodesktop',
                    '--initial-working-folder=' + str(instance / 'work')]
    return command, env
