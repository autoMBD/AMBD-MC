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
# File:        test_smoke.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-09-11
# Version:     0.1.0
# Description: Test smoke acceptance reporting and failure classification.
# =================================================================================

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

    def test_smoke_selects_checkout_before_matlab_execution(self):
        report = self.run_fake(None, require_project_path=True)
        self.assertEqual(report['status'], 'PASS')

    def run_fake(self, final_integrity, require_project_path=False):
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            bundle = repo / '.agent-env/environments/test'
            (bundle / 'skills').mkdir(parents=True)
            required = ['evaluate_matlab_code', 'check_matlab_code', 'run_matlab_test_file',
                        'detect_matlab_toolboxes', 'model_overview', 'model_read', 'model_query_params', 'model_scan', 'model_read_diagnostics']
            test_case = self
            class FakeClient:
                def __init__(self, *args, **kwargs):
                    instance = kwargs.get('env', {}).get('AMBD_MATLAB_INSTANCE')
                    self.project_path = str(Path(instance) / 'work') if instance else str(repo)
                    if instance:
                        Path(instance, 'matlab.json').write_text('{"pid":42}')
                def __enter__(self): return self
                def __exit__(self, *args): pass
                def initialize(self): return {'serverInfo': {}}
                def request(self, *args): return {'tools': [{'name': n} for n in required]}
                def call(self, name, arguments):
                    if require_project_path and 'ambd_smoke(' in arguments.get('code', ''):
                        test_case.assertEqual(arguments.get('project_path'), self.project_path,
                                              'Keep MATLAB in the instance working directory.')
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
