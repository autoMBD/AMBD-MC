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
# File:        test_hsp_models.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-07
# Version:     0.1.0
# Description: Verify portable S32K344 model configuration and active asset isolation.
# =================================================================================

"""Offline acceptance checks for the saved, portable motor model suite."""
from pathlib import Path
import json
import re
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]

class HspModelsTest(unittest.TestCase):
    def test_inventory_covers_every_active_model(self):
        path = ROOT / "mc-models/hsp/models.json"
        self.assertTrue(path.is_file(), "A complete HSP model inventory is required")
        manifest = json.loads(path.read_text(encoding="utf-8"))
        actual = {p.relative_to(ROOT).as_posix() for p in (ROOT / "mc-models").rglob("*.slx")}
        self.assertEqual(actual, {m["path"] for m in manifest["models"]})
        self.assertEqual("0.1.0", manifest["hspVersion"])
        self.assertEqual({"bldc", "pmsm"}, {m["family"] for m in manifest["models"]})

    def test_target_components_use_hsp_and_portable_configuration(self):
        components = [p for p in (ROOT / "mc-models").rglob("*.slx")
                      if not p.stem.endswith("_top") and not p.stem.endswith("Library")]
        self.assertEqual(10, len(components))
        for path in components:
            with self.subTest(model=path.stem), zipfile.ZipFile(path) as archive:
                xml = "\n".join(archive.read(n).decode("utf-8") for n in archive.namelist()
                                if n.endswith(".xml") and n.startswith("simulink/"))
                self.assertTrue("hsp_driver_lib/HSP Config" in xml, path.stem)
                self.assertTrue("autombd_s32k3.tlc" in xml, path.stem)
                self.assertTrue("ARM Cortex" in xml, path.stem)
                self.assertNotRegex(xml, r"[A-Za-z]:[\\/](?:Users|WorkSpace|NXP|EB|SoftwareSpace)")
                self.assertTrue("legacy/" not in xml, path.stem)
                self.assertTrue('BlockType="ModelReference"' not in xml,
                                "Target components use linked algorithm subsystems: " + path.stem)

    def test_retired_models_and_configuration_are_outside_active_tree(self):
        for relative in (
            "mc-models/pmsm/algo/FOC_Sub_CoreAlgoithm.slx",
            "mc-models/pmsm/algo/FOC_Sub_StateMch.slx",
            "mc-models/pmsm/platform/codegen/FOC_Config.m",
            "mc-models/pmsm/config/FOC_Ctrl_MBD_Integration",
            "mc-models/bldc/config/BLDC_Ctrl_MBD_DS",
            "mc-models/pmsm/uti", "mc-models/bldc/uti",
            "mc-models/pmsm/commom/struct_FOC_Crtl.mat",
            "mc-models/bldc/platform/codegen/struct_BLDC_Crtl.mat",
        ):
            with self.subTest(path=relative):
                self.assertFalse((ROOT / relative).exists())

    def test_smoke_detects_supported_hardware_package(self):
        smoke = (ROOT / "tools/agent/matlab/ambd_smoke.m").read_text(encoding="utf-8")
        self.assertTrue("autoMbdHspDetected" in smoke)

if __name__ == "__main__":
    unittest.main()
