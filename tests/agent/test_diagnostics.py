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
# File:        test_diagnostics.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-09-11
# Version:     0.1.0
# Description: Test environment command diagnostics and failure reporting.
# =================================================================================

import argparse
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/agent'))
import agent_env
import configuration


class DiagnosticTests(unittest.TestCase):
    def test_doctor_rejects_missing_skill_registration(self):
        with tempfile.TemporaryDirectory() as folder:
            repo = Path(folder)
            bundle = repo / '.agent-env/environments/first'
            (bundle / 'skills/test').mkdir(parents=True)
            (bundle / 'skills/test/SKILL.md').write_text('test')
            configuration.activate(repo, {'id': 'first', 'bundle': str(bundle)}, lambda _: None)
            configuration._remove_registration(repo)
            args = argparse.Namespace(lock=repo / 'lock.json', matlab_root='MATLAB')
            with patch.object(agent_env.artifacts, 'read_lock', return_value={}), patch.object(agent_env.artifacts, 'lock_id', return_value='id'), patch.object(agent_env.environment, 'verify_bundle'), patch.object(agent_env, 'matlab_root', return_value='MATLAB'):
                result = agent_env.doctor(repo, args)
            self.assertTrue(any(c['status'] == 'FAIL' and c['check'] == 'skill ownership' for c in result['checks']))

    def test_license_check_excludes_downloaded_upstream_files(self):
        path = Path(__file__).resolve().parents[2] / 'tools/test_check_spdx.py'
        spec = importlib.util.spec_from_file_location('spdx_check', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as folder:
            repo = Path(folder).resolve()
            subprocess.run(['git', 'init', '-q', str(repo)], check=True)
            (repo / '.agent-env').mkdir()
            (repo / '.agent-env/official.m').write_text('upstream')
            (repo / 'own.m').write_text('source')
            subprocess.run(['git', '-C', str(repo), 'add', 'own.m', '.agent-env'], check=True)
            self.assertEqual(list(module.find_files(repo)), [repo / 'own.m'])


if __name__ == '__main__':
    unittest.main()
