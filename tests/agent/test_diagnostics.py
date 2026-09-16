# SPDX-License-Identifier: MIT
import argparse
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/agent'))
import agent_env
import configuration


class DiagnosticTests(unittest.TestCase):
    def test_doctor_rejects_missing_skill_registration(self):
        with tempfile.TemporaryDirectory() as folder:
            repo = Path(folder)
            bundle = repo / '.agent-env/environments/first'
            (bundle / 'skills/test').mkdir(parents=True)
            (bundle / 'skills/test/SKILL.md').write_text('test')
            configuration.activate(repo, {'id': 'first', 'bundle': str(bundle)}, lambda _: None)
            configuration._remove_registration(repo)
            args = argparse.Namespace(lock=repo / 'lock.json', matlab_root='MATLAB')
            with patch.object(agent_env.artifacts, 'read_lock', return_value={}), patch.object(agent_env.artifacts, 'lock_id', return_value='id'), patch.object(agent_env.environment, 'verify_bundle'), patch.object(agent_env, 'matlab_root', return_value='MATLAB'):
                result = agent_env.doctor(repo, args)
            self.assertTrue(any(c['status'] == 'FAIL' and c['check'] == 'skill ownership' for c in result['checks']))

    def test_license_check_excludes_downloaded_upstream_files(self):
        path = Path(__file__).resolve().parents[2] / 'tools/test_check_spdx.py'
        spec = importlib.util.spec_from_file_location('spdx_check', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as folder:
            repo = Path(folder)
            (repo / '.agent-env').mkdir()
            (repo / '.agent-env/official.m').write_text('upstream')
            (repo / 'own.m').write_text('source')
            self.assertEqual(list(module.find_files(str(repo))), [str(repo / 'own.m')])


if __name__ == '__main__':
    unittest.main()
