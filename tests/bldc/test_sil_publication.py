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
# File:        test_sil_publication.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-06
# Version:     0.1.0
# Description: SIL report publication must not expose PASS before evidence is saved.
# =================================================================================

"""SIL report publication must not expose PASS before evidence is saved."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('bldc_sil_publication', ROOT / 'tools/bldc/validate_sil.py')
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class SilPublicationTest(unittest.TestCase):
    def test_transient_windows_replace_denial_recovers_atomically(self):
        for winerror in (5, 32, 33):
            with self.subTest(winerror=winerror), tempfile.TemporaryDirectory() as temporary:
                path = Path(temporary) / 'summary.json'
                RUNNER.write_json(path, {'Passed': False})
                original = Path.replace
                attempts = []

                def denied_then_available(source, destination):
                    attempts.append(source)
                    self.assertFalse(json.loads(path.read_text())['Passed'])
                    if len(attempts) <= 2:
                        error = PermissionError(13, 'injected Windows file lock')
                        error.winerror = winerror
                        raise error
                    return original(source, destination)

                with patch.object(Path, 'replace', denied_then_available), patch('time.sleep'):
                    RUNNER.write_json(path, {'Passed': True, 'Evidence': 'complete'})
                self.assertEqual(len(attempts), 3)
                self.assertEqual(json.loads(path.read_text()), {'Passed': True, 'Evidence': 'complete'})

    def test_persistent_windows_denial_is_bounded_and_preserves_old_report(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'summary.json'
            RUNNER.write_json(path, {'Passed': False})
            error = PermissionError(13, 'persistent Windows lock')
            error.winerror = 5
            with patch.object(Path, 'replace', side_effect=error) as replace, patch('time.sleep'):
                with self.assertRaises(PermissionError):
                    RUNNER.write_json(path, {'Passed': True})
            self.assertGreater(replace.call_count, 1)
            self.assertLessEqual(replace.call_count, 10)
            self.assertFalse(json.loads(path.read_text())['Passed'])

    def test_other_io_error_is_not_retried(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'summary.json'
            RUNNER.write_json(path, {'Passed': False})
            with patch.object(Path, 'replace', side_effect=OSError('disk failure')) as replace:
                with self.assertRaises(OSError):
                    RUNNER.write_json(path, {'Passed': True})
            self.assertEqual(replace.call_count, 1)
            self.assertFalse(json.loads(path.read_text())['Passed'])

    def test_failed_transcript_cannot_publish_pass(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            RUNNER.write_json(folder / 'summary.json', {'Passed': False, 'Status': 'RUNNING'})
            original = RUNNER.write_json

            def failing(path, value):
                if path.name == 'transcript.json':
                    raise OSError('injected evidence write failure')
                original(path, value)

            with patch.object(RUNNER, 'write_json', side_effect=failing):
                with self.assertRaises(OSError):
                    RUNNER.save_report(folder, {'Passed': True}, [{'actual': 'SIL'}])
            self.assertFalse(json.loads((folder / 'summary.json').read_text())['Passed'])

    def test_success_binds_publication_to_existing_transcript(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            original = RUNNER.write_json

            def inspecting(path, value):
                if path.name == 'summary.json':
                    self.assertEqual(json.loads((folder / 'transcript.json').read_text()), [{'actual': 'SIL'}])
                original(path, value)

            with patch.object(RUNNER, 'write_json', side_effect=inspecting):
                RUNNER.save_report(folder, {'Passed': True}, [{'actual': 'SIL'}])
            self.assertTrue(json.loads((folder / 'summary.json').read_text())['Passed'])


if __name__ == '__main__':
    unittest.main()
