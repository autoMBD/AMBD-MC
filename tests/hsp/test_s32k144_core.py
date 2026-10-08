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
# File:        test_s32k144_core.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-08
# Version:     0.1.0
# Description: Compile and test the kit electrical contracts with deterministic SPI peers.
# =================================================================================

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
class K144CoreTest(unittest.TestCase):
    def test_physical_sampling_and_commit_contract(self):
        board=ROOT/'mc-models/hsp/board'
        self.assertTrue((board/'ambd_kit_s32k144_core.c').is_file(), 'S32K144 electrical contract is missing')
        with tempfile.TemporaryDirectory(dir=ROOT/'.agent-env') as directory:
            exe=Path(directory)/'k144.exe'
            result=subprocess.run([shutil.which('gcc'),'-std=c11','-Wall','-Wextra','-Werror','-pedantic',
                '-I'+str(board),str(board/'ambd_kit_s32k144_core.c'),
                str(ROOT/'tests/hsp/s32k144_core_test.c'),'-lm','-o',str(exe)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            result=subprocess.run([str(exe)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertIn('K144_CORE_PASS',result.stdout)
    def test_real_driver_interlocks_with_rtd_peers(self):
        board=ROOT/'mc-models/hsp/board'
        for bldc in [0,1]:
            with tempfile.TemporaryDirectory(dir=ROOT/'.agent-env') as directory:
                exe=Path(directory)/'k144-runtime.exe'
                command=[shutil.which('gcc'),'-std=c11','-Wall','-Wextra','-Werror','-pedantic',
                    '-DHSP_TARGET=1','-DAMBD_KIT_HOST_TEST=1','-DAMBD_BLDC='+str(bldc),
                    '-I'+str(board),'-I'+str(ROOT/'tests/hsp'),str(board/'ambd_kit_core.c'),
                    str(board/'ambd_kit_s32k144_core.c'),str(board/'ambd_kit_s32k144.c'),
                    str(ROOT/'tests/hsp/s32k144_driver_test.c'),'-lm','-o',str(exe)]
                result=subprocess.run(command,capture_output=True,text=True)
                self.assertEqual(result.returncode,0,result.stdout+result.stderr)
                for scenario in range(9):
                    with self.subTest(bldc=bldc,scenario=scenario):
                        result=subprocess.run([str(exe),str(scenario)],capture_output=True,text=True)
                        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
                        self.assertIn('K144_RUNTIME_PASS',result.stdout)
if __name__=='__main__':unittest.main()
