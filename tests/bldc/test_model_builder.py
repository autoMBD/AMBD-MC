# SPDX-License-Identifier: MIT
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
