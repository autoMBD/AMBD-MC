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
# File:        test_publish.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-08
# Version:     0.1.0
# Description: Test release publication ordering and review gates.
# =================================================================================

"""Release publishing is draft-first and fails closed before public visibility."""

import importlib.util
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/release"))


class PublishTest(unittest.TestCase):
    def load(self):
        path = ROOT / "tools/release/publish.py"
        self.assertTrue(path.is_file(), "Missing draft-first release publisher")
        spec = importlib.util.spec_from_file_location("release_publish_test", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_publication_requires_runtime_review(self):
        publish = self.load()
        with self.assertRaisesRegex(ValueError, "runtime"):
            publish.validate_mode("0.2.0-rc.1", "prerelease", False)

    def test_prerelease_and_stable_versions_cannot_be_confused(self):
        publish = self.load()
        for version, mode in [("0.2.0-rc.1", "release"), ("0.2.0", "prerelease")]:
            with self.assertRaises(ValueError):
                publish.validate_mode(version, mode, True)
        publish.validate_mode("0.2.0-rc.1", "draft", False)
        publish.validate_mode("0.2.0-rc.1", "prerelease", True)

    def test_failure_to_verify_downloads_never_publishes(self):
        publish = self.load()
        calls = []

        def gh(*args):
            calls.append(args)
            return b""

        def failed():
            raise ValueError("corrupt download")

        with self.assertRaisesRegex(ValueError, "corrupt"):
            publish.publish_assets(gh, "v0.2.0-rc.1", [], Path("notes.md"), "prerelease", failed)
        self.assertEqual(len(calls), 1)
        self.assertIn("--draft", calls[0])

    def test_verified_assets_are_published_after_download_check(self):
        publish = self.load()
        calls = []

        def gh(*args):
            calls.append(args)
            return b""

        publish.publish_assets(gh, "v0.2.0-rc.1", [], Path("notes.md"), "prerelease", lambda: calls.append(("verified",)))
        self.assertIn("--draft", calls[0])
        self.assertEqual(calls[1], ("verified",))
        self.assertIn("--draft=false", calls[2])
        self.assertIn("--prerelease", calls[2])
        self.assertNotIn("--clobber", str(calls))


if __name__ == "__main__":
    unittest.main()
