# SPDX-License-Identifier: MIT
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/agent'))
import smoke


class SmokeReportingTests(unittest.TestCase):
    def test_final_integrity_failure_is_recorded_as_failure(self):
        report = self.run_fake(ValueError('integrity changed'))
        self.assertEqual(report['status'], 'FAIL')
        self.assertIn('integrity changed', report['error'])

    def test_successful_smoke_records_pass(self):
        report = self.run_fake(None)
        self.assertEqual(report['status'], 'PASS')
        self.assertNotIn('error', report)

    def run_fake(self, final_integrity):
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            bundle = repo / '.agent-env/environments/test'
            (bundle / 'skills').mkdir(parents=True)
            required = ['evaluate_matlab_code', 'check_matlab_code', 'run_matlab_test_file',
                        'detect_matlab_toolboxes', 'model_overview', 'model_read', 'model_query_params', 'model_scan', 'model_read_diagnostics']
            class FakeClient:
                def __init__(self, *args, **kwargs): pass
                def __enter__(self): return self
                def __exit__(self, *args): pass
                def initialize(self): return {'serverInfo': {}}
                def request(self, *args): return {'tools': [{'name': n} for n in required]}
                def call(self, name, arguments):
                    folder = next((repo / '.agent-env/reports').iterdir())
                    (folder / 'matlab-result.json').write_text(json.dumps({'pid': 42, 'satkInitialize': str(bundle / 'satk'), 'shareMATLABSession': str(bundle / 'share')}))
                    text = 'AMBD_COMPUTE_AND_SIMULATION_PASS AMBD_TESTS_PASS AMBD_MODEL_CLOSED AMBD_SHARED_SESSION_PASS Gain 0.2 '
                    text += Path(arguments.get('model', '')).stem
                    if name == 'check_matlab_code': text = '{"code_issues":[]}'
                    return {'content': [{'type': 'text', 'text': text}]}
            candidate = {'id': 'test', 'bundle': str(bundle), 'matlab_root': 'MATLAB'}
            with patch.object(smoke, 'Client', FakeClient), patch.object(smoke, 'verify_bundle', side_effect=[None, final_integrity]), redirect_stdout(io.StringIO()):
                if final_integrity:
                    with self.assertRaisesRegex(ValueError, 'integrity changed'):
                        smoke.run(repo, candidate)
                else:
                    smoke.run(repo, candidate)
            return json.loads(next((repo / '.agent-env/reports').glob('*/smoke.json')).read_text())


if __name__ == '__main__':
    unittest.main()
