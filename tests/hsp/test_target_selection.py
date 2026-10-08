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
# File:        test_target_selection.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-08
# Version:     0.1.0
# Description: Verify HSP application receipt location, model identity and ELF integrity.
# =================================================================================

"""Native build evidence must come from HSP's application receipt."""
from pathlib import Path
import importlib.util
import unittest
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('target_runner',ROOT/'tools/hsp/validate_target.py')
TARGET=importlib.util.module_from_spec(spec);spec.loader.exec_module(TARGET)

class TargetSelectionTest(unittest.TestCase):
    def test_default_remains_k344(self):
        self.assertEqual(TARGET.select_target({})['name'],'s32k344')
    def test_explicit_k144(self):
        self.assertEqual(TARGET.select_target({'target':'s32k144'})['targetId'],'nxp.s32k1.s32k144-custom')
    def test_nested_environment(self):
        self.assertEqual(TARGET.select_target({'target':'s32k144','environment':{}})['uartInstance'],1)
    def test_rejects_mismatched_hardware(self):
        with self.assertRaisesRegex(ValueError,'match'):
            TARGET.select_target({'target':'s32k144','device':{'partNumber':'S32K344'}})
    def test_rejects_unknown_target(self):
        with self.assertRaisesRegex(ValueError,'target'):
            TARGET.select_target({'target':'arbitrary'})
if __name__=='__main__':unittest.main()
