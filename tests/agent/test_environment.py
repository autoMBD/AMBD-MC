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
# File:        test_environment.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-09-11
# Version:     0.1.0
# Description: Test project-local environment creation and validation.
# =================================================================================

import importlib
import os
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/agent'))
try:
    environment = importlib.import_module('environment')
except ModuleNotFoundError:
    environment = None


class EnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(environment, 'Environment manager is not implemented')

    def test_current_release_check_does_not_download_or_resolve(self):
        lock = {'components': {k: {'tag': 'v1'} for k in ('matlab', 'simulink', 'mcp')}}
        releases = {k: {'tag_name': 'v1'} for k in lock['components']}
        self.assertEqual(environment.release_changes(lock, releases), {})

    def test_changed_release_reports_old_and_new(self):
        lock = {'components': {'matlab': {'tag': 'v1'}, 'mcp': {'tag': 'v2'}}}
        releases = {'matlab': {'tag_name': 'v3'}, 'mcp': {'tag_name': 'v2'}}
        self.assertEqual(environment.release_changes(lock, releases), {'matlab': {'from': 'v1', 'to': 'v3'}})

    def test_matlab_quote_handles_apostrophes(self):
        self.assertEqual(environment.matlab_quote("D:/User's work"), "'D:/User''s work'")

    def test_startup_upgrade_preserves_old_bundle_and_builds_new_revision(self):
        with tempfile.TemporaryDirectory() as folder:
            repo = Path(folder)
            lock = {'schema_version': 1, 'platform': 'windows-x64',
                    'components': {'mcp': {'artifacts': [{}]}}, 'skill_groups': {}}
            old = repo / '.agent-env/environments' / environment.lock_id(lock)
            old.mkdir(parents=True)
            startup = old / 'startup.m'
            startup.write_text('legacy shared cache setup')
            (old / 'files.json').write_text(json.dumps({'startup.m': environment.sha256(startup)}))
            with patch.object(environment, 'validate_lock'), patch.object(environment, 'obtain',
                                                                         side_effect=RuntimeError('new bundle required')):
                with self.assertRaisesRegex(RuntimeError, 'new bundle required'):
                    environment.prepare(repo, lock, repo / 'cache')
            self.assertEqual(startup.read_text(), 'legacy shared cache setup')

    def test_runtime_uses_pinned_binary_and_inherits_windows_variables(self):
        with tempfile.TemporaryDirectory() as folder:
            repo = Path(folder)
            bundle = repo / '.agent-env/environments/pinned'
            bundle.mkdir(parents=True)
            candidate = {'id': 'pinned', 'bundle': str(bundle), 'matlab_root': 'D:/MATLAB', 'session': 'new'}
            with patch.dict('os.environ', {'WINDIR': 'C:/Windows'}):
                command, env = environment.runtime(candidate)
            self.assertEqual(Path(command[0]), bundle / 'bin/matlab-mcp-server.exe')
            self.assertIn('--matlab-session-mode=new', command)
            self.assertIn('--matlab-root=D:/MATLAB', command)
            self.assertIn('--initial-working-folder=' + str(Path(env['AMBD_MATLAB_INSTANCE']) / 'work'), command)
            self.assertEqual(env['WINDIR'], 'C:/Windows')
            self.assertTrue(Path(env['MATLABPATH'].split(os.pathsep)[0], 'startup.m').is_file())

    def test_arbitrary_n_instances_have_exclusive_owned_directories(self):
        with tempfile.TemporaryDirectory() as folder:
            bundle = Path(folder) / '.agent-env/environments/pinned'
            bundle.mkdir(parents=True)
            candidate = {'bundle': str(bundle), 'matlab_root': 'D:/MATLAB'}
            before = os.environ.copy()
            launches = [environment.runtime(candidate) for _ in range(7)]
            self.assertEqual(os.environ, before)
            roots = [Path(env['AMBD_MATLAB_INSTANCE']) for _, env in launches]
            self.assertEqual(len(set(roots)), 7)
            for (_, env), root in zip(launches, roots):
                self.assertEqual(env['TEMP'], str(root / 'tmp'))
                self.assertEqual(env['TMP'], env['TEMP'])
                self.assertEqual(env['TMPDIR'], env['TEMP'])
                for child in ('tmp', 'work', 'cache', 'codegen', 'startup'):
                    self.assertTrue((root / child).is_dir())
                self.assertTrue((root / 'owner.json').is_file())
            self.assertEqual(list(bundle.iterdir()), [])

    def test_auto_always_allocates_new_instead_of_attaching_to_user(self):
        with tempfile.TemporaryDirectory() as folder:
            candidate = {'bundle': str(Path(folder) / '.agent-env/environments/pinned'),
                         'matlab_root': 'D:/MATLAB', 'session': 'auto'}
            command, env = environment.runtime(candidate)
            self.assertIn('--matlab-session-mode=new', command)
            self.assertIn('AMBD_MATLAB_INSTANCE', env)

    def test_existing_does_not_reassign_instance_or_temp_or_matlabpath(self):
        candidate = {'bundle': 'D:/project/.agent-env/environments/pinned', 'session': 'existing'}
        with patch.dict(os.environ, {'TEMP': 'user-temp', 'TMP': 'user-tmp',
                                    'MATLABPATH': 'user-path', 'AMBD_MATLAB_INSTANCE': 'user-instance'}):
            before = os.environ.copy()
            _, env = environment.runtime(candidate)
            self.assertEqual(env, before)

    def test_existing_mode_omits_officially_incompatible_launch_arguments(self):
        candidate = {'bundle': 'D:/project/.agent-env/environments/pinned', 'matlab_root': 'D:/MATLAB', 'session': 'existing'}
        command, _ = environment.runtime(candidate)
        for prefix in ('--matlab-root=', '--initial-working-folder=', '--matlab-display-mode='):
            self.assertFalse(any(arg.startswith(prefix) for arg in command))

    def test_relocated_workspace_leaves_room_for_mcp_socket(self):
        candidate = {'bundle': 'D:/projects/relocated-workspace/AMBD-MC/.agent-env/environments/pinned',
                     'matlab_root': 'D:/MATLAB', 'session': 'existing'}
        command, _ = environment.runtime(candidate)
        log_folder = next(arg.split('=', 1)[1] for arg in command if arg.startswith('--log-folder='))
        # The official server creates an AF_UNIX socket with this generated basename.
        socket_path = str(Path(log_folder) / '.matlab-mcp-server-4294967295')
        self.assertLess(len(socket_path.encode('utf-8')), 108)


if __name__ == '__main__':
    unittest.main()
