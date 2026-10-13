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
# File:        test_pmsm_layers.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-09-11
# Version:     0.1.0
# Description: Saved PMSM component and plant contract tests.
# =================================================================================

"""Check the saved deliverable model contracts without loading callbacks."""
import unittest
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PMSM = ROOT / "mc-models/pmsm"


def xml_parts(path):
    with zipfile.ZipFile(path) as archive:
        return {name: ET.fromstring(archive.read(name))
                for name in archive.namelist()
                if name.startswith("simulink/") and name.endswith(".xml")}


def root_blocks(path):
    return {block.attrib["Name"]: block
            for block in xml_parts(path)["simulink/systems/system_root.xml"].findall("Block")}


def parameter(block, name):
    element = block.find(f"./P[@Name='{name}']")
    return None if element is None else element.text


class PmsmLayersTest(unittest.TestCase):
    def test_algorithm_component_uses_physical_interface(self):
        blocks = root_blocks(PMSM / "platform/pil/FOC_PIL_Algth_model.slx")
        self.assertEqual(parameter(blocks["Controller"], "SourceBlock"),
                         "McControllerLibrary/AlgthController")
        self.assertEqual(parameter(blocks["Ia"], "OutDataTypeStr"), "single")
        self.assertEqual(parameter(blocks["DutyA"], "OutDataTypeStr"), "single")
        self.assertIn("Disable", blocks)

    def test_motor_component_keeps_raw_platform_interface(self):
        blocks = root_blocks(PMSM / "platform/pil/FOC_PIL_StateMch_model.slx")
        self.assertEqual(parameter(blocks["Controller"], "SourceBlock"),
                         "McControllerLibrary/Controller")
        self.assertEqual(parameter(blocks["Ia"], "OutDataTypeStr"), "uint16")
        self.assertEqual(parameter(blocks["DutyA"], "OutDataTypeStr"), "uint16")

    def test_two_wrappers_share_one_stateless_core(self):
        parts = xml_parts(PMSM / "algo/McControllerLibrary.slx")
        blocks = root_blocks(PMSM / "algo/McControllerLibrary.slx")
        self.assertIn("FocCore", blocks)
        self.assertIn("AlgthController", blocks)
        links = [p.text for root in parts.values()
                 for p in root.findall(".//P[@Name='SourceBlock']")
                 if p.text in {"McControllerLibrary/FocCore", "$bdroot/FocCore"}]
        self.assertEqual(len(links), 2)

    def test_host_tops_use_shared_native_plant_and_record_exact_inputs(self):
        for name, bus in [("Algth", "tMcCoreInput"), ("StateMch", "tMcInput")]:
            with self.subTest(layer=name):
                blocks = root_blocks(PMSM / f"platform/pil/FOC_PIL_{name}_top.slx")
                self.assertEqual(parameter(blocks["Plant"], "SourceBlock"),
                                 "McControllerLibrary/AveragePlant")
                self.assertEqual(parameter(blocks["ControllerInput"], "OutDataTypeStr"),
                                 f"Bus: {bus}")

    def test_shared_plant_contains_official_inverter_and_motor(self):
        parts = xml_parts(PMSM / "algo/McControllerLibrary.slx")
        links = {p.text for root in parts.values()
                 for p in root.findall(".//P[@Name='SourceBlock']")}
        self.assertIn("mcbplantlib/Average-Value Inverter", links)
        self.assertIn("autolibpmsminterior/Interior PMSM", links)
        scripts = "\n".join(p.text or "" for root in parts.values()
                            for p in root.findall(".//P[@Name='script']"))
        self.assertNotIn("mc.plant_step(", scripts)
        self.assertNotIn("mc.plant_measure(", scripts)


if __name__ == "__main__":
    unittest.main()
