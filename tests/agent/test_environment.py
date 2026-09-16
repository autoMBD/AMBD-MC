# SPDX-License-Identifier: MIT
import importlib
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
            self.assertIn('--initial-working-folder=' + str(repo), command)
            self.assertEqual(env['WINDIR'], 'C:/Windows')
            self.assertIn(str(bundle / 'startup'), env['MATLABPATH'])

    def test_existing_mode_omits_officially_incompatible_launch_arguments(self):
        candidate = {'bundle': 'D:/project/.agent-env/environments/pinned', 'matlab_root': 'D:/MATLAB', 'session': 'existing'}
        command, _ = environment.runtime(candidate)
        for prefix in ('--matlab-root=', '--initial-working-folder=', '--matlab-display-mode='):
            self.assertFalse(any(arg.startswith(prefix) for arg in command))


if __name__ == '__main__':
    unittest.main()
