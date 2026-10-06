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
