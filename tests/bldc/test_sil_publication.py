# SPDX-License-Identifier: MIT
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
