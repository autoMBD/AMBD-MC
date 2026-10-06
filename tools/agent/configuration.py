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
# File:        configuration.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-09-11
# Version:     0.1.0
# Description: Transactional project-owned MCP configuration and skill registration.
# =================================================================================

"""Transactional project-owned MCP configuration and skill registration."""
from __future__ import annotations

from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import tomllib
import uuid

from artifacts import atomic_json

BEGIN = '# BEGIN AMBD-MC MANAGED MCP'
END = '# END AMBD-MC MANAGED MCP'
BLOCK = re.compile(re.escape(BEGIN) + r'.*?' + re.escape(END) + r'\n?', re.S)


def read_state(repo: Path) -> dict:
    path = repo / '.agent-env/state.json'
    return json.loads(path.read_text(encoding='utf-8')) if path.exists() else {}


def tree_hash(root: Path) -> str:
    digest = hashlib.sha256()
    for file in sorted(p for p in root.rglob('*') if p.is_file()):
        digest.update(file.relative_to(root).as_posix().encode())
        digest.update(file.read_bytes())
    return digest.hexdigest()


def config_block(repo: Path) -> str:
    args = [str(repo / 'tools/agent/agent_env.py'), 'Serve', '--repo-root', str(repo)]
    return '\n'.join([BEGIN, '[mcp_servers.ambd_matlab]',
                      'command = ' + json.dumps(sys.executable),
                      'args = ' + json.dumps(args),
                      'env_vars = ["WINDIR", "SystemRoot", "TEMP", "TMP"]',
                      'startup_timeout_sec = 120', 'tool_timeout_sec = 600', END, ''])


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, mode='w', encoding='utf-8',
                                     delete=False, newline='\n') as stream:
        stream.write(text)
        tmp = Path(stream.name)
    try:
        os.replace(tmp, path)
    finally:
        tmp.unlink(missing_ok=True)


@contextmanager
def operation_lock(repo: Path):
    path = repo / '.agent-env/operation.lock'
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with path.open('x') as stream:
            stream.write(str(os.getpid()))
    except FileExistsError as error:
        raise RuntimeError(f'Another environment operation is active: {path}. Check its PID before removing a stale lock.') from error
    try:
        yield
    finally:
        path.unlink(missing_ok=True)


def _check_registration(repo: Path, state: dict) -> None:
    path = repo / '.agents/skills/ambd-mathworks'
    if not os.path.lexists(path):
        return
    if not state.get('active') or not state.get('skills_hash'):
        raise ValueError('Unmanaged skill directory collision: .agents/skills/ambd-mathworks')
    if path.is_symlink() and path.resolve() != (Path(state['active']['bundle']) / 'skills').resolve():
        raise ValueError('Managed skill link was changed; refusing to overwrite it')
    if tree_hash(path) != state['skills_hash']:
        raise ValueError('Managed skills contain local changes; preserve them outside the managed directory first')


def _remove_registration(repo: Path) -> None:
    path = repo / '.agents/skills/ambd-mathworks'
    if path.is_symlink():
        path.unlink()
    elif path.exists():
        # Recursive deletion is limited to this exact, previously ownership-checked path.
        expected = repo.resolve() / '.agents' / 'skills' / 'ambd-mathworks'
        if path.resolve() != expected or not path.resolve().is_relative_to(repo.resolve()):
            raise ValueError('Skill directory resolves outside the managed project location')
        shutil.rmtree(path)


def _discard_stage(repo: Path, target: Path):
    expected = repo.resolve() / '.agent-env' / 'registrations'
    if target.absolute().parent != expected or not re.fullmatch('[0-9a-f]{32}', target.name):
        raise ValueError('Unsafe registration staging path')
    if target.is_symlink():
        target.unlink()
    elif target.exists():
        if target.resolve().parent != expected:
            raise ValueError('Registration staging directory resolves outside the project cache')
        shutil.rmtree(target)


def _stage_registration(repo: Path, bundle: Path):
    target = repo / '.agent-env/registrations' / uuid.uuid4().hex
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        try:
            target.symlink_to(bundle / 'skills', target_is_directory=True)
            return target, 'symlink'
        except OSError:
            shutil.copytree(bundle / 'skills', target)
            return target, 'copy'
    except BaseException:
        _discard_stage(repo, target)
        raise


def _register(repo: Path, bundle: Path) -> str:
    stage, mode = _stage_registration(repo, bundle)
    target = repo / '.agents/skills/ambd-mathworks'
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        stage.rename(target)
    finally:
        _discard_stage(repo, stage)
    return mode


def activate(repo: Path, candidate: dict, validator) -> dict:
    repo = repo.resolve()
    bundle = Path(candidate['bundle']).resolve()
    if not bundle.is_relative_to(repo / '.agent-env/environments') or not (bundle / 'skills').is_dir():
        raise ValueError('Environment must be inside the project environment cache')
    with operation_lock(repo):
        journal = repo / '.agent-env/activation-journal.json'
        if journal.exists():
            raise RuntimeError('Interrupted activation detected. Run Recover before changing environments.')
        old = read_state(repo)
        config = repo / '.codex/config.toml'
        original = config.read_text(encoding='utf-8') if config.exists() else ''
        parsed = tomllib.loads(original)
        match = BLOCK.search(original)
        if 'ambd_matlab' in parsed.get('mcp_servers', {}) and not match:
            raise ValueError('MCP server ambd_matlab is user-owned; refusing managed name collision')
        if match and (not old.get('config_block') or match.group(0) != old['config_block']):
            raise ValueError('Managed MCP configuration changed; refusing to overwrite local changes')
        _check_registration(repo, old)
        validator(candidate)  # No active configuration is changed until validation succeeds.
        if (config.read_text(encoding='utf-8') if config.exists() else '') != original:
            raise ValueError('Project configuration changed during validation; retry with the preserved edits')
        _check_registration(repo, old)
        # Finish the potentially interruptible copy before removing any active entry.
        stage, mode = _stage_registration(repo, bundle)
        block = config_block(repo)
        updated = BLOCK.sub('', original).rstrip() + '\n\n' + block
        tomllib.loads(updated)
        finished = False
        backup = repo / '.agent-env/registrations' / uuid.uuid4().hex
        try:
            if (config.read_text(encoding='utf-8') if config.exists() else '') != original:
                raise ValueError('Project configuration changed during validation; retry with the preserved edits')
            _check_registration(repo, old)
            atomic_json(journal, {'old_state': old, 'old_config': original,
                                 'candidate': candidate, 'new_config': updated, 'backup': str(backup)})
            target = repo / '.agents/skills/ambd-mathworks'
            target.parent.mkdir(parents=True, exist_ok=True)
            if os.path.lexists(target):
                target.rename(backup)  # Preserve the entire old tree; never delete it mid-switch.
            stage.rename(target)
            _write(config, updated)
            previous = old.get('active') if old.get('active') != candidate else old.get('previous')
            state = {'active': candidate, 'previous': previous, 'skills_mode': mode,
                     'skills_hash': tree_hash(bundle / 'skills'), 'config_block': block}
            atomic_json(repo / '.agent-env/state.json', state)
            finished = True
        except BaseException:
            if journal.exists():
                _restore(repo, old, original, backup)
            finished = True
            raise
        finally:
            # Retain the journal when recovery itself failed.
            if finished:
                journal.unlink(missing_ok=True)
            _discard_stage(repo, stage)
        return state


def _restore(repo: Path, old: dict, original: str, backup: Path | None = None) -> None:
    target = repo / '.agents/skills/ambd-mathworks'
    if backup and (backup.absolute().parent != repo.resolve() / '.agent-env/registrations' or
                   not re.fullmatch('[0-9a-f]{32}', backup.name)):
        raise ValueError('Invalid registration backup path')
    if os.path.lexists(target):
        preserved = repo / '.agent-env/registrations' / uuid.uuid4().hex
        preserved.parent.mkdir(parents=True, exist_ok=True)
        target.rename(preserved)
    if backup and os.path.lexists(backup):
        backup.rename(target)
    elif old.get('active'):
        _register(repo, Path(old['active']['bundle']))
    _write(repo / '.codex/config.toml', original)
    atomic_json(repo / '.agent-env/state.json', old)


def recover(repo: Path) -> None:
    with operation_lock(repo):
        journal = repo / '.agent-env/activation-journal.json'
        saved = json.loads(journal.read_text(encoding='utf-8'))
        config = repo / '.codex/config.toml'
        current = config.read_text(encoding='utf-8') if config.exists() else ''
        if current not in (saved['old_config'], saved['new_config']):
            raise ValueError('Configuration changed after interruption; preserve those edits before recovery')
        registration = repo / '.agents/skills/ambd-mathworks'
        if os.path.lexists(registration):
            candidates = [saved['old_state'].get('active'), saved['candidate']]
            hashes = [tree_hash(Path(item['bundle']) / 'skills') for item in candidates if item]
            if tree_hash(registration) not in hashes:
                raise ValueError('Skills changed after interruption; refusing to discard local edits')
        backup = Path(saved['backup']) if saved.get('backup') else None
        if backup and os.path.lexists(backup) and tree_hash(backup) != saved['old_state'].get('skills_hash'):
            raise ValueError('Registration backup changed; preserve its edits before recovery')
        _restore(repo, saved['old_state'], saved['old_config'], backup)
        journal.unlink()


def rollback(repo: Path, validator) -> dict:
    previous = read_state(repo).get('previous')
    if not previous:
        raise ValueError('No previous verified environment is available')
    return activate(repo, previous, validator)
