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
# File:        test_plant_reference_runner.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-06
# Version:     0.1.0
# Description: Failure-path tests for the authoritative native-reference report
#              publisher.
# =================================================================================

"""Failure-path tests for the authoritative native-reference report publisher."""
from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    'plant_runner_under_test', REPO / 'tools/bldc/validate_plant_reference.py')
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class PlantReferenceRunnerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.artifacts = self.root / '.agent-env/bldc-plant'
        self.artifacts.mkdir(parents=True)
        self.source = self.root / 'plant.m'
        self.source.write_text('original source', encoding='utf-8')
        self.prior = {'pass': True, 'status': 'PASS', 'attempt': 'previous'}
        (self.artifacts / 'results.json').write_text(json.dumps(self.prior), encoding='utf-8')
        (self.artifacts / 'source-hashes.json').write_text('{"old":"hash"}', encoding='utf-8')
        (self.artifacts / 'native-results.json').write_text(
            json.dumps({'pass': True, 'status': 'PROVISIONAL', 'attempt': 'stale'}), encoding='utf-8')
        reports = self.root / '.agent-env/reports/previous'
        reports.mkdir(parents=True)
        self.smoke = reports / 'smoke.json'
        self.smoke.write_text(json.dumps({'skill_eligibility': {
            'building-simulink-models': {'status': 'ELIGIBLE'},
            'matlab-run-tests': {'status': 'ELIGIBLE'}}}), encoding='utf-8')
        self.mode = 'success'
        self.calls = []
        owner = self

        class FakeClient:
            def __init__(self, *args, **kwargs):
                self.project_path = str(owner.root / '.agent-env/i/test/work')

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def initialize(self):
                pass

            def call(self, name, arguments):
                if name == 'evaluate_matlab_code':
                    owner.assertEqual(arguments.get('project_path'), self.project_path)
                owner.calls.append(name)
                output = 'status: ok'
                code = arguments.get('code', '')
                if 'library.settingsLookup' in code:
                    output = '{"gatePass":true}'
                if 'new_system' in code:
                    (owner.artifacts / (runner.MODEL + '.slx')).write_bytes(b'native model')
                if name == 'model_check':
                    output = 'status: healthy'
                if 'compare_plant_reference' in code:
                    owner.assertFalse(owner.report()['pass'], 'PASS became authoritative during MATLAB execution')
                    match = re.search(r"compare_plant_reference\('([^']+)'\)", code)
                    attempt = match.group(1) if match else 'manual'
                    if owner.mode != 'missing_native_report':
                        native = {'pass': True, 'status': 'PROVISIONAL', 'attempt': attempt,
                                  'cases': [{'name': 'mocked_physics', 'pass': True}]}
                        if owner.mode == 'wrong_attempt':
                            native['attempt'] = 'different-attempt'
                        (owner.artifacts / 'native-results.json').write_text(
                            json.dumps(native), encoding='utf-8')
                    if owner.mode == 'source_changed':
                        owner.source.write_text('changed during validation', encoding='utf-8')
                    output = 'BLDC_NATIVE_REFERENCE_PASS'
                return {'content': [{'type': 'text', 'text': output}]}

        configuration = types.ModuleType('configuration')
        configuration.read_state = lambda root: {'active': {}}
        environment = types.ModuleType('environment')
        environment.runtime = lambda candidate, session: ([], {})
        mcp_client = types.ModuleType('mcp_client')
        mcp_client.Client = FakeClient
        for context in (
            patch.multiple(runner, ROOT=self.root, ARTIFACTS=self.artifacts, SOURCE_FILES=[self.source]),
            patch.dict(sys.modules, configuration=configuration, environment=environment, mcp_client=mcp_client),
            patch.object(sys, 'path', list(sys.path)),
        ):
            context.start()
            self.addCleanup(context.stop)

    def report(self):
        return json.loads((self.artifacts / 'results.json').read_text(encoding='utf-8'))

    def assert_failed_and_archived(self):
        report = self.report()
        self.assertFalse(report['pass'])
        self.assertEqual(report['status'], 'FAILED')
        self.assertTrue(report['failure'])
        self.assertFalse((self.artifacts / 'source-hashes.json').exists())
        archived = list((self.artifacts / 'history').glob('*/results.json'))
        self.assertEqual(len(archived), 1)
        self.assertEqual(json.loads(archived[0].read_text(encoding='utf-8')), self.prior)

    def test_missing_smoke_invalidates_prior_pass(self):
        self.smoke.unlink()
        with self.assertRaises(Exception):
            runner.main()
        self.assert_failed_and_archived()
        self.assertEqual(self.calls, [])

    def test_import_failure_invalidates_prior_pass(self):
        with patch.dict(sys.modules, configuration=None):
            with self.assertRaises(ImportError):
                runner.main()
        self.assert_failed_and_archived()
        self.assertEqual(self.calls, [])

    def test_unavailable_skill_invalidates_prior_pass(self):
        data = json.loads(self.smoke.read_text(encoding='utf-8'))
        data['skill_eligibility']['building-simulink-models']['status'] = 'UNAVAILABLE'
        self.smoke.write_text(json.dumps(data), encoding='utf-8')
        with self.assertRaises(RuntimeError):
            runner.main()
        self.assert_failed_and_archived()
        self.assertEqual(self.calls, [])

    def test_source_change_cannot_publish_pass_or_keep_old_hashes(self):
        self.mode = 'source_changed'
        with self.assertRaisesRegex(RuntimeError, 'changed'):
            runner.main()
        self.assert_failed_and_archived()

    def test_missing_provisional_report_cannot_reuse_old_pass(self):
        self.mode = 'missing_native_report'
        with self.assertRaises(Exception):
            runner.main()
        self.assert_failed_and_archived()

    def test_other_attempt_provisional_report_is_rejected(self):
        self.mode = 'wrong_attempt'
        with self.assertRaisesRegex(RuntimeError, 'attempt'):
            runner.main()
        self.assert_failed_and_archived()

    def test_hash_write_failure_cannot_publish_pass(self):
        original_write = Path.write_text

        def write(path, text, *args, **kwargs):
            if path.parent == self.artifacts and 'source-hashes.json' in path.name:
                raise OSError('Injected hash write failure')
            return original_write(path, text, *args, **kwargs)

        with patch.object(Path, 'write_text', write):
            with self.assertRaisesRegex(OSError, 'hash write'):
                runner.main()
        self.assert_failed_and_archived()

    def test_source_change_while_writing_hashes_is_rejected(self):
        original_write = Path.write_text

        def write(path, text, *args, **kwargs):
            result = original_write(path, text, *args, **kwargs)
            if path.parent == self.artifacts and 'source-hashes.json' in path.name:
                self.source.write_text('changed during hash publication', encoding='utf-8')
            return result

        with patch.object(Path, 'write_text', write):
            with self.assertRaisesRegex(RuntimeError, 'changed'):
                runner.main()
        self.assert_failed_and_archived()

    def test_summary_output_failure_cannot_leave_pass(self):
        original_print = print

        def output(*args, **kwargs):
            if args and 'native reference' in str(args[0]):
                raise OSError('Injected summary output failure')
            return original_print(*args, **kwargs)

        with patch('builtins.print', output):
            with self.assertRaisesRegex(OSError, 'summary output'):
                runner.main()
        self.assert_failed_and_archived()

    def test_success_publishes_pass_after_bound_hashes_exist(self):
        original_replace = Path.replace
        publications = []

        def replace(path, target):
            if Path(target) == self.artifacts / 'results.json':
                payload = json.loads(path.read_text(encoding='utf-8'))
                if payload['pass']:
                    hash_bytes = (self.artifacts / 'source-hashes.json').read_bytes()
                    self.assertEqual(payload['sourceHashesSha256'], hashlib.sha256(hash_bytes).hexdigest())
                    publications.append(payload['attempt'])
            return original_replace(path, target)

        with patch.object(Path, 'replace', replace):
            runner.main()
        final = self.report()
        self.assertTrue(final['pass'])
        self.assertEqual(final['status'], 'PASS')
        self.assertEqual(publications, [final['attempt']])
        hashes = json.loads((self.artifacts / 'source-hashes.json').read_text(encoding='utf-8'))
        self.assertEqual(hashes['plant.m'], hashlib.sha256(self.source.read_bytes()).hexdigest())


if __name__ == '__main__':
    unittest.main()
