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
# File:        test_artifacts.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-09-11
# Version:     0.1.0
# Description: Test release artifacts, integrity checks and update inventories.
# =================================================================================

import copy
import hashlib
import importlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools' / 'agent'))
try:
    artifacts = importlib.import_module('artifacts')
except ModuleNotFoundError:
    artifacts = None


def sample_lock():
    components = {}
    for key, repo in [('matlab', 'matlab/matlab-agentic-toolkit'),
                      ('simulink', 'matlab/simulink-agentic-toolkit'),
                      ('mcp', 'matlab/matlab-mcp-server')]:
        components[key] = {
            'repository': repo, 'tag': 'v1', 'commit': 'a' * 40,
            'release_url': f'https://github.com/{repo}/releases/tag/v1',
            'artifacts': [{'name': f'{key}.zip',
                           'url': f'https://codeload.github.com/{repo}/zip/' + 'a' * 40,
                           'sha256': 'b' * 64, 'size': 1}],
        }
    return {'schema_version': 1, 'platform': 'windows-x64',
            'components': components,
            'skill_groups': {'matlab': ['matlab-core'], 'simulink': ['model-based-design-core']}}


class ArtifactTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(artifacts, 'Official artifact/lock management is not implemented')
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)

    def test_valid_lock_has_stable_identity(self):
        lock = sample_lock()
        artifacts.validate_lock(lock)
        same = json.loads(json.dumps(lock, sort_keys=True))
        same['verification'] = {'status': 'passed'}
        self.assertEqual(artifacts.lock_id(lock), artifacts.lock_id(same))

    def test_rejects_unpinned_and_nonofficial_artifacts(self):
        for field, value in [('commit', 'main'), ('repository', 'someone/unofficial')]:
            lock = sample_lock()
            lock['components']['matlab'][field] = value
            with self.assertRaises(ValueError):
                artifacts.validate_lock(lock)
        for url in ['https://example.org/tool.zip',
                    'https://codeload.github.com/other/repo/zip/' + 'a' * 40,
                    'https://github.com/matlab/matlab-agentic-toolkit/releases/latest/download/tool.zip']:
            lock = sample_lock()
            lock['components']['matlab']['artifacts'][0]['url'] = url
            with self.assertRaises(ValueError):
                artifacts.validate_lock(lock)

    def test_rejects_malformed_hash_and_unsafe_artifact_name(self):
        for name, digest in [('tool.zip', 'latest'), ('../tool.zip', 'b' * 64),
                             ('C:\\tool.zip', 'b' * 64)]:
            lock = sample_lock()
            lock['components']['matlab']['artifacts'][0].update(name=name, sha256=digest)
            with self.assertRaises(ValueError):
                artifacts.validate_lock(lock)

    def test_offline_cache_rejects_corrupted_bytes(self):
        content = b'official artifact'
        digest = hashlib.sha256(content).hexdigest()
        asset = {'name': 'tool.zip', 'sha256': digest, 'size': len(content), 'url': 'unused'}
        self.root.joinpath(digest).write_bytes(content)
        self.assertEqual(artifacts.obtain(asset, self.root, offline=True).read_bytes(), content)
        self.root.joinpath(digest).write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError, 'hash|SHA|integrity'):
            artifacts.obtain(asset, self.root, offline=True)

    def test_archive_extraction_rejects_windows_and_posix_traversal(self):
        for name in ['../escape.txt', '/escape.txt', 'C:/escape.txt', 'a/../../escape.txt', '..\\escape.txt']:
            with self.subTest(name=name):
                archive = self.root / 'bad.zip'
                with zipfile.ZipFile(archive, 'w') as zipped:
                    zipped.writestr(name, 'bad')
                with self.assertRaises(ValueError):
                    artifacts.extract(archive, self.root / 'output')
        self.assertFalse((self.root.parent / 'escape.txt').exists())

    def test_archive_extraction_rejects_symlink(self):
        archive = self.root / 'link.zip'
        info = zipfile.ZipInfo('link')
        info.create_system = 3
        info.external_attr = 0o120777 << 16
        with zipfile.ZipFile(archive, 'w') as zipped:
            zipped.writestr(info, '../../outside')
        with self.assertRaises(ValueError):
            artifacts.extract(archive, self.root / 'output')

    def test_inventory_diff_reports_added_removed_changed(self):
        before = {'tools': {'model_read': 'old', 'old_tool': 'x'}, 'skills': {'debug': 'a'}}
        after = {'tools': {'model_read': 'new', 'model_scan': 'y'}, 'skills': {'debug': 'a'}}
        diff = artifacts.inventory_diff(before, after)
        self.assertEqual(diff['tools'], {'added': ['model_scan'], 'removed': ['old_tool'], 'changed': ['model_read']})
        self.assertEqual(diff['skills'], {'added': [], 'removed': [], 'changed': []})


if __name__ == '__main__':
    unittest.main()
