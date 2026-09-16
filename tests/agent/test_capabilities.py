# SPDX-License-Identifier: MIT
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
