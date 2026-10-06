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
# File:        test_capabilities.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-09-11
# Version:     0.1.0
# Description: Test official skill prerequisite and capability detection.
# =================================================================================

import importlib
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/agent'))
try:
    capabilities = importlib.import_module('capabilities')
except ModuleNotFoundError:
    capabilities = None


class CapabilityTests(unittest.TestCase):
    def test_missing_product_and_old_release_are_not_available(self):
        self.assertIsNotNone(capabilities)
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'one').mkdir()
            (root / 'one/manifest.yaml').write_text('matlab-release: ">=R2025a"\nrequired-products:\n  - Simulink Test\nrequired-tools: []\nrequired-skills: []\n')
            result = capabilities.skills(root, {'release': '2024b', 'toolboxes': [{'Name': 'MATLAB'}]}, [])
            self.assertEqual(result['one']['status'], 'UNAVAILABLE')
            self.assertIn('Simulink Test', result['one']['missing_products'])
            self.assertFalse(result['one']['release_compatible'])

    def test_supported_manifest_with_present_dependencies_is_eligible(self):
        self.assertIsNotNone(capabilities)
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'one').mkdir()
            (root / 'one/manifest.yaml').write_text('matlab-release: ">=R2023a"\nrequired-products:\n  - MATLAB\nrequired-tools:\n  - evaluate_matlab_code\nrequired-skills: []\n')
            result = capabilities.skills(root, {'release': '2026a', 'toolboxes': [{'Name': 'MATLAB'}]}, ['evaluate_matlab_code'])
            self.assertEqual(result['one']['status'], 'ELIGIBLE')


if __name__ == '__main__':
    unittest.main()
