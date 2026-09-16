# SPDX-License-Identifier: MIT
import importlib
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools' / 'agent'))
try:
    configuration = importlib.import_module('configuration')
except ModuleNotFoundError:
    configuration = None


class ConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(configuration, 'Transactional project configuration is not implemented')
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        (self.repo / '.codex').mkdir()
        (self.repo / '.codex/config.toml').write_text('model = "keep-me"\n[mcp_servers.other]\ncommand = "other"\n')
        self.first = self.bundle('first')
        self.second = self.bundle('second')

    def bundle(self, name):
        root = self.repo / '.agent-env' / 'environments' / name
        (root / 'skills' / 'test-skill').mkdir(parents=True)
        (root / 'skills' / 'test-skill' / 'SKILL.md').write_text(f'---\nname: test-skill\n---\n{name}\n')
        return {'id': name, 'bundle': str(root), 'matlab_root': 'MATLAB'}

    def test_activation_is_idempotent_and_preserves_unrelated_config(self):
        configuration.activate(self.repo, self.first, lambda _: None)
        configuration.activate(self.repo, self.first, lambda _: None)
        text = (self.repo / '.codex/config.toml').read_text()
        self.assertIn('model = "keep-me"', text)
        self.assertIn('[mcp_servers.other]', text)
        self.assertEqual(text.count('[mcp_servers.ambd_matlab]'), 1)
        self.assertEqual(configuration.read_state(self.repo)['active']['id'], 'first')

    def test_failed_smoke_keeps_active_state_and_skills(self):
        configuration.activate(self.repo, self.first, lambda _: None)
        def fail(_):
            raise RuntimeError('smoke failed')
        with self.assertRaisesRegex(RuntimeError, 'smoke failed'):
            configuration.activate(self.repo, self.second, fail)
        self.assertEqual(configuration.read_state(self.repo)['active']['id'], 'first')
        self.assertIn('first', (self.repo / '.agents/skills/ambd-mathworks/test-skill/SKILL.md').read_text())

    def test_rollback_preserves_later_user_configuration(self):
        configuration.activate(self.repo, self.first, lambda _: None)
        configuration.activate(self.repo, self.second, lambda _: None)
        config = self.repo / '.codex/config.toml'
        config.write_text(config.read_text() + '\n[mcp_servers.added_later]\ncommand = "mine"\n')
        configuration.rollback(self.repo, lambda _: None)
        self.assertEqual(configuration.read_state(self.repo)['active']['id'], 'first')
        self.assertIn('[mcp_servers.added_later]', config.read_text())

    def test_unmanaged_server_collision_is_not_overwritten(self):
        config = self.repo / '.codex/config.toml'
        config.write_text('[mcp_servers.ambd_matlab]\ncommand = "user-owned"\n')
        with self.assertRaisesRegex(ValueError, 'owned|managed|collision'):
            configuration.activate(self.repo, self.first, lambda _: None)
        self.assertIn('user-owned', config.read_text())

    def test_unmanaged_skill_directory_is_not_removed(self):
        owned_name = self.repo / '.agents/skills/ambd-mathworks'
        owned_name.mkdir(parents=True)
        (owned_name / 'personal.txt').write_text('keep')
        with self.assertRaisesRegex(ValueError, 'owned|managed|collision'):
            configuration.activate(self.repo, self.first, lambda _: None)
        self.assertEqual((owned_name / 'personal.txt').read_text(), 'keep')

    def test_refuses_environment_path_outside_project_cache(self):
        outside = dict(self.first, bundle=str(self.repo.parent))
        with self.assertRaises(ValueError):
            configuration.activate(self.repo, outside, lambda _: None)

    def test_failed_recovery_keeps_journal(self):
        configuration.activate(self.repo, self.first, lambda _: None)
        with patch.object(configuration, '_write', side_effect=OSError('disk error')):
            with self.assertRaises(OSError):
                configuration.activate(self.repo, self.second, lambda _: None)
        self.assertTrue((self.repo / '.agent-env/activation-journal.json').exists())

    def test_config_edit_during_validation_is_preserved(self):
        configuration.activate(self.repo, self.first, lambda _: None)
        config = self.repo / '.codex/config.toml'
        def edit(_):
            config.write_text(config.read_text() + '\n[mcp_servers.new_user_server]\ncommand = "mine"\n')
        with self.assertRaisesRegex(ValueError, 'during validation'):
            configuration.activate(self.repo, self.second, edit)
        self.assertIn('new_user_server', config.read_text())
        self.assertEqual(configuration.read_state(self.repo)['active']['id'], 'first')

    def test_interrupted_skill_copy_leaves_active_registration_intact(self):
        configuration.activate(self.repo, self.first, lambda _: None)
        def partial_copy(source, target):
            target.mkdir()
            (target / 'partial.txt').write_text('partial')
            raise KeyboardInterrupt()
        with patch.object(Path, 'symlink_to', side_effect=OSError('no privilege')):
            with patch.object(configuration.shutil, 'copytree', side_effect=partial_copy):
                with self.assertRaises(KeyboardInterrupt):
                    configuration.activate(self.repo, self.second, lambda _: None)
        self.assertIn('first', (self.repo / '.agents/skills/ambd-mathworks/test-skill/SKILL.md').read_text())

    def test_switch_never_recursively_deletes_active_copied_skills(self):
        with patch.object(Path, 'symlink_to', side_effect=OSError('no privilege')):
            configuration.activate(self.repo, self.first, lambda _: None)
            with patch.object(configuration.shutil, 'rmtree', side_effect=AssertionError('recursive delete during switch')):
                configuration.activate(self.repo, self.second, lambda _: None)
        backups = list((self.repo / '.agent-env/registrations').glob('*/test-skill/SKILL.md'))
        self.assertTrue(any('first' in p.read_text() for p in backups))

    def test_modified_managed_skills_are_preserved(self):
        configuration.activate(self.repo, self.first, lambda _: None)
        skill = self.repo / '.agents/skills/ambd-mathworks/test-skill/SKILL.md'
        skill.write_text('user edits')
        with self.assertRaisesRegex(ValueError, 'local changes'):
            configuration.activate(self.repo, self.second, lambda _: None)
        self.assertEqual(skill.read_text(), 'user edits')


if __name__ == '__main__':
    unittest.main()
