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
# File:        test_workflow_sources.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-09
# Version:     0.1.0
# Description: Verify source evidence covers shared MATLAB workflows.
# =================================================================================

"""Every verification mode must invalidate evidence when shared workflows change."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def runner(name):
    spec = importlib.util.spec_from_file_location(
        "workflow_sources_" + name, ROOT / "tools" / name /
        ("validate_target.py" if name == "hsp" else "validate_sil.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class WorkflowSourceTest(unittest.TestCase):
    def setUp(self):
        parent = ROOT / ".agent-env/tests"
        parent.mkdir(parents=True, exist_ok=True)
        temporary = tempfile.TemporaryDirectory(dir=parent)
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        for name in ("ambd_mc.m", "docs/BldcStruct.md", "docs/McStruct.md",
                     "tools/generate_data_type_from_md.m", "tools/pmsm/build_models.py",
                     "mc-models/+ambd_workflows/setup.m",
                     "mc-models/+ambd_workflows/stage.m"):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("original " + name, encoding="utf-8")

    def verify_workflow_invalidation(self, name):
        module = runner(name)
        args = (["bldc", "pmsm"],) if name == "hsp" else ()
        with patch.object(module, "ROOT", self.root):
            before = module.source_hashes(*args)
            for filename in ("setup.m", "stage.m"):
                with self.subTest(runner=name, helper=filename):
                    relative = "mc-models/+ambd_workflows/" + filename
                    path = self.root / relative
                    self.assertIn(relative, before)
                    self.assertEqual(before[relative], hashlib.sha256(path.read_bytes()).hexdigest())
                    path.write_text("changed workflow", encoding="utf-8")
                    after = module.source_hashes(*args)
                    self.assertNotEqual(before[relative], after[relative])
            self.assertFalse(any(key.startswith("private/") for key in before))

    def test_bldc_sil_invalidates_changed_workflows(self):
        self.verify_workflow_invalidation("bldc")

    def test_pmsm_sil_invalidates_changed_workflows(self):
        self.verify_workflow_invalidation("pmsm")

    def test_target_pil_invalidates_changed_workflows(self):
        self.verify_workflow_invalidation("hsp")


if __name__ == "__main__":
    unittest.main()
