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
# File:        test_build_receipt.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-07
# Version:     0.1.0
# Description: Verify HSP application receipt location, model identity and ELF integrity.
# =================================================================================

"""Consumer uses the installed HSP verifier with independently selected identity."""
from pathlib import Path
import importlib.util
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('target_runner', ROOT / 'tools/hsp/validate_target.py')
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)

class BuildReceiptTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.stage = Path(temporary.name)
        self.hsp = self.stage / 'installed-hsp'
        self.verifier = Mock(return_value={'verified': True})

    def test_delegates_selected_identity_to_public_verifier(self):
        with patch.object(RUNNER, 'load_receipt_verifier', return_value=self.verifier) as load:
            path, result = RUNNER.read_application_receipt(
                self.stage, 'Motor', 'nxp.target', hsp_root=self.hsp)
        load.assert_called_once_with(self.hsp)
        self.assertEqual(path, self.stage / 'build/Motor/application/hsp-build-result.json')
        self.verifier.assert_called_once_with(path, model='Motor', target_id='nxp.target',
            mode='application', project_root=self.stage / 'build/Motor/project')
        self.assertEqual(result, {'verified': True})

    def test_rejected_receipt_cannot_be_reinterpreted_as_success(self):
        self.verifier.side_effect = ValueError('wrong project identity')
        with patch.object(RUNNER, 'load_receipt_verifier', return_value=self.verifier):
            with self.assertRaisesRegex(RuntimeError, 'wrong project identity'):
                RUNNER.read_application_receipt(self.stage, 'Motor', 'nxp.target', hsp_root=self.hsp)

    def test_missing_public_helper_fails_explicitly(self):
        with self.assertRaisesRegex(RuntimeError, 'HSP.*receipt'):
            RUNNER.read_application_receipt(self.stage, 'Motor', 'nxp.target', hsp_root=self.hsp)

    def test_loads_helper_from_selected_hsp_installation(self):
        helper = self.hsp / 'adapters/common/tools/verify_build_receipt.py'
        helper.parent.mkdir(parents=True)
        helper.write_text("def verify_build_receipt(*args, **kwargs): return kwargs\n", encoding='utf-8')
        function = RUNNER.load_receipt_verifier(self.hsp)
        self.assertEqual(function(model='Expected'), {'model': 'Expected'})

if __name__ == '__main__':
    unittest.main()
