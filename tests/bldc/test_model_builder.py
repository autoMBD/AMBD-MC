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
# File:        test_model_builder.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-06
# Version:     0.1.0
# Description: Focused safety regressions for the official-MCP BLDC model builder.
# =================================================================================

"""Focused safety regressions for the official-MCP BLDC model builder."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest
import tempfile
from unittest.mock import Mock

ROOT=Path(__file__).resolve().parents[2]
SPEC=importlib.util.spec_from_file_location('bldc_model_builder',ROOT/'tools/bldc/build_models.py')
MODULE=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class FreshModelGuardTest(unittest.TestCase):
    def setUp(self):
        MODULE.ARTIFACTS.mkdir(parents=True,exist_ok=True)
        temporary=tempfile.TemporaryDirectory(prefix='guard-test-',dir=MODULE.ARTIFACTS)
        self.addCleanup(temporary.cleanup)
        self.output=Path(temporary.name)
        self.assertTrue(self.output.resolve().is_relative_to((ROOT/'.agent-env').resolve()))

    def test_content_only_guard_error_stops_before_read_or_edit(self):
        call=Mock(return_value={'content':[{'type':'text','text':
            'Error using assert: Refusing to replace dirty loaded model.'}]})
        builder=MODULE.Builder(call,self.output)
        with self.assertRaises(RuntimeError):
            builder.fresh('BLDC_GuardProbe',MODULE.ARTIFACTS)
        self.assertEqual(call.call_count,1)
        self.assertEqual(call.call_args.args[0],'evaluate_matlab_code')

    def test_empty_response_also_stops_before_read_or_edit(self):
        call=Mock(return_value={'content':[]})
        builder=MODULE.Builder(call,self.output)
        with self.assertRaises(RuntimeError):
            builder.fresh('BLDC_GuardProbe',MODULE.ARTIFACTS)
        self.assertEqual(call.call_count,1)

    def test_echoed_marker_is_not_creation_confirmation(self):
        call=Mock(return_value={'content':[{'type':'text','text':
            "Error executing: disp('FRESH_MODEL BLDC_GuardProbe');"}]})
        builder=MODULE.Builder(call,self.output)
        with self.assertRaises(RuntimeError):
            builder.fresh('BLDC_GuardProbe',MODULE.ARTIFACTS)
        self.assertEqual(call.call_count,1)

    def test_confirmed_creation_continues_to_inspection_and_binding(self):
        call=Mock(side_effect=[
            {'content':[{'type':'text','text':'FRESH_MODEL BLDC_GuardProbe\n'}]},
            {'content':[{'type':'text','text':'status: ok'}]},
            {'content':[]}])
        builder=MODULE.Builder(call,self.output)
        path=builder.fresh('BLDC_GuardProbe',self.output)
        self.assertEqual(path,self.output/'BLDC_GuardProbe.slx')
        self.assertEqual([entry.args[0] for entry in call.call_args_list],
                         ['evaluate_matlab_code','model_read','evaluate_matlab_code'])


if __name__=='__main__':
    unittest.main()
