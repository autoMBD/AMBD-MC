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
# File:        test_foc_bridge.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-07
# Version:     0.1.0
# Description: Compile and test the kit electrical contracts with deterministic SPI peers.
# =================================================================================

"""Execute the real board-to-model adapter against both PMSM interfaces."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
HEADER = r"""
#include <stdint.h>
#include <stdbool.h>
typedef struct {
#if AMBD_FOC_CORE
    float Ia,Ib,Ic;
    bool Disable;
#else
    uint16_t Ia,Ib,Ic;
#endif
    uint8_t McControl;
    bool FaultEvent,McCtrlEvent,McDrivingEvent,McTimerEvent;
    float SpeedReq,DcBusVoltage,RotorAngle,AppliedVoltageAlpha,AppliedVoltageBeta;
} ModelInputs;
typedef struct {
    struct {uint8_t Mode;uint16_t FaultBits;} Monitor;
    bool GateEnable;
} ModelOutputs;
extern ModelInputs TestFoc_U;
extern ModelOutputs TestFoc_Y;
void TestFoc_step(void);
void TestFoc_initialize(void);
"""
DRIVER = r"""
#include <assert.h>
#include <stdio.h>
#include "TestFoc.h"
#include "ambd_kit_board.h"
ModelInputs TestFoc_U;
ModelOutputs TestFoc_Y;
volatile Ambd_KitStatus Ambd_Kit;
volatile uint8_t Ambd_KitControl;
volatile float Ambd_KitSpeedRequest;
static unsigned steps;
bool Ambd_KitCapture(void) {return true;}
void TestFoc_initialize(void) {}
void TestFoc_step(void) {
    assert(TestFoc_U.FaultEvent);
#if AMBD_FOC_CORE
    assert(TestFoc_U.Ia==0.0F && TestFoc_U.Ib==0.0F && TestFoc_U.Ic==0.0F);
#else
    assert(TestFoc_U.Ia==32768U && TestFoc_U.Ib==32768U && TestFoc_U.Ic==32768U);
#endif
    steps++;
}
int main(void) {
    Ambd_KitPrimeModel();assert(steps==32U);
    Ambd_Kit.driver_ready=1U;Ambd_Kit.calibrated=1U;Ambd_Kit.sample_valid=1U;
    Ambd_Kit.current[0]=.125F;Ambd_Kit.current[1]=-.25F;Ambd_Kit.current[2]=.125F;
    Ambd_Kit.voltage_alpha=.5F;Ambd_Kit.voltage_beta=-.25F;Ambd_Kit.vdc=12.0F;
    Ambd_KitControl=1U;Ambd_KitSpeedRequest=100.0F;
    Ambd_KitCaptureModelInputs();
#if AMBD_FOC_CORE
    assert(TestFoc_U.Ia==.125F && TestFoc_U.Ib==-.25F && TestFoc_U.Ic==.125F);
    assert(!TestFoc_U.Disable);
#else
    assert(TestFoc_U.Ia==32893U && TestFoc_U.Ib==32518U && TestFoc_U.Ic==32893U);
#endif
    assert(TestFoc_U.McControl==1U && !TestFoc_U.FaultEvent);
    assert(TestFoc_U.AppliedVoltageAlpha==.5F && TestFoc_U.AppliedVoltageBeta==-.25F);
    Ambd_Kit.driver_ready=0U;Ambd_KitCaptureModelInputs();
    assert(TestFoc_U.McControl==0U && TestFoc_U.FaultEvent);
#if AMBD_FOC_CORE
    assert(TestFoc_U.Disable);
#endif
    puts("FOC_BRIDGE_PASS");return 0;
}
"""


class FocBridgeTest(unittest.TestCase):
    def test_prime_capture_and_inhibit_for_both_interfaces(self):
        compiler = shutil.which("gcc")
        self.assertIsNotNone(compiler)
        board = ROOT / "mc-models/hsp/board"
        with tempfile.TemporaryDirectory(dir=ROOT / ".agent-env") as folder:
            root = Path(folder)
            (root / "TestFoc.h").write_text(HEADER)
            (root / "driver.c").write_text(DRIVER)
            for core in (0, 1):
                with self.subTest(core=core):
                    executable = root / f"bridge-{core}.exe"
                    command = [compiler, "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic",
                               "-DHSP_TARGET=1", "-DAMBD_MODEL=TestFoc", "-DAMBD_BLDC=0",
                               f"-DAMBD_FOC_CORE={core}", "-I" + str(root), "-I" + str(board),
                               str(board / "ambd_kit_bridge.c"), str(root / "driver.c"),
                               "-lm", "-o", str(executable)]
                    result = subprocess.run(command, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    if result.returncode == 0:
                        result = subprocess.run([str(executable)], capture_output=True, text=True)
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                        self.assertIn("FOC_BRIDGE_PASS", result.stdout)


if __name__ == "__main__":
    unittest.main()
