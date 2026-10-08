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
# File:        test_kit_evidence.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-08
# Version:     0.1.0
# Description: Preserve per-case download evidence when the shared build is replaced.
# =================================================================================

import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('kit_evidence_runner', ROOT / 'tools/validate_kit.py')
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class KitEvidenceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.folder = Path(temporary.name)
        self.elf = self.folder / 'Model.elf'
        self.image = self.folder / 'download-image.srec'
        self.receipt = self.folder / 'download-result.json'
        self.elf.write_bytes(b'first-case-firmware')
        self.image.write_bytes(b'first-case-programming-image')
        self.data = dict(status='command-completed', executionRequested=True,
                         target='S32K144', elf=str(self.elf),
                         elfSha256=RUNNER.TARGET.digest(self.elf),
                         imageSha256=RUNNER.TARGET.digest(self.image),
                         elfVerification=dict(status='passed'))
        self.publish()
        self.result = dict(DownloadReceipt=str(self.receipt), ElfSha256=self.data['elfSha256'])
        self.destination = self.folder / 'case1'
        self.destination.mkdir()

    def publish(self):
        self.receipt.write_text(json.dumps(self.data), encoding='utf-8')

    def snapshot(self):
        return RUNNER.snapshot_download_evidence(self.result, self.destination, 'S32K144')

    def test_preserves_first_case_after_next_build_overwrites_shared_files(self):
        expected = [p.read_bytes() for p in (self.elf, self.image, self.receipt)]
        evidence = self.snapshot()
        for p in (self.elf, self.image, self.receipt):
            p.write_bytes(b'next-case')
        for label, payload in zip(('Elf', 'Image', 'Receipt'), expected):
            saved = Path(evidence[label])
            self.assertEqual(saved.read_bytes(), payload)
            self.assertEqual(evidence[label + 'Sha256'], hashlib.sha256(payload).hexdigest())

    def test_rejects_changed_elf(self):
        self.elf.write_bytes(b'changed-after-download')
        with self.assertRaises(RuntimeError):
            self.snapshot()

    def test_rejects_changed_programming_image(self):
        self.image.write_bytes(b'changed-image')
        with self.assertRaises(RuntimeError):
            self.snapshot()

    def test_rejects_failed_download(self):
        self.data['status'] = 'failed'
        self.publish()
        with self.assertRaises(RuntimeError):
            self.snapshot()

    def test_rejects_other_target(self):
        self.data['target'] = 'S32K344'
        self.publish()
        with self.assertRaises(RuntimeError):
            self.snapshot()

    def test_refuses_to_replace_an_existing_case_snapshot(self):
        self.snapshot()
        with self.assertRaises(FileExistsError):
            self.snapshot()


if __name__ == '__main__':
    unittest.main()
