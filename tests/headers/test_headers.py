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
# File:        test_headers.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-07
# Version:     0.1.0
# Description: Regression tests for complete MIT headers and tracked ownership scope.
# =================================================================================

from pathlib import Path
import importlib.util
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('headers', ROOT / 'tools/test_check_spdx.py')
headers = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(headers)


def fixture(name='sample.py', prefix='#'):
    text = (ROOT / 'tools/export_sldd_to_m.m').read_text(encoding='utf-8').split('\n\nfunction')[0]
    text = text.replace('export_sldd_to_m.m', name).replace('%               script', '%              script')
    return '\n'.join(prefix + line[1:] for line in text.splitlines()) + '\n\n'


class HeaderTests(unittest.TestCase):
    def check(self, text, name='sample.py'):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / name
            path.write_text(text, encoding='utf-8')
            return headers.check_file(path)

    def test_complete_headers_for_supported_languages(self):
        for ext, prefix in [('.py','#'),('.ps1','#'),('.m','%'),('.c','//'),('.h','//'),('.cpp','//')]:
            with self.subTest(ext=ext):
                self.assertTrue(self.check(fixture('sample'+ext,prefix), 'sample'+ext))

    def test_spdx_only_rejected(self):
        self.assertFalse(self.check('# SPDX-License-Identifier: MIT\nprint(1)\n'))

    def test_broken_notice_rejected(self):
        self.assertFalse(self.check(fixture().replace('THE SOFTWARE IS PROVIDED', 'THE SOFTWAREISPROVIDED')))

    def test_missing_field_rejected(self):
        self.assertFalse(self.check(fixture().replace('# Author:      autoMBD <tkung.lqk@foxmail.com>\n','')))

    def test_placeholder_rejected(self):
        self.assertFalse(self.check(fixture().replace('autoMBD <tkung.lqk@foxmail.com>','{{AUTHOR}}')))

    def test_wrong_filename_rejected(self):
        self.assertFalse(self.check(fixture('other.py')))

    def test_invalid_date_rejected(self):
        self.assertFalse(self.check(fixture().replace('2026-03-16','2026-02-30')))

    def test_bad_continuation_indent_rejected(self):
        self.assertFalse(self.check(fixture().replace('#              script', '#   script')))

    def test_wrong_comment_prefix_rejected(self):
        self.assertFalse(self.check(fixture(prefix='%')))

    def test_duplicate_header_rejected(self):
        self.assertFalse(self.check(fixture()+fixture()))

    def test_embedded_python_source_notice_is_not_a_duplicate(self):
        body = 'SOURCE = """\n# SPDX-License-Identifier: MIT\n"""\n'
        self.assertTrue(self.check(fixture() + body))

    def test_old_c_block_notice_is_a_duplicate(self):
        body = '/*\n * The MIT License\n * SPDX-License-Identifier: MIT\n */\n'
        self.assertFalse(self.check(fixture('sample.c', '//') + body, 'sample.c'))

    def test_c_string_notice_is_not_a_duplicate(self):
        body = 'const char *example = "// SPDX-License-Identifier: MIT";\n'
        self.assertTrue(self.check(fixture('sample.c', '//') + body, 'sample.c'))

    def test_powershell_here_string_is_not_a_duplicate(self):
        for quote in ["'", '"']:
            body = '$source = @' + quote + '\n# SPDX-License-Identifier: MIT\n' + quote + '@\n'
            self.assertTrue(self.check(fixture('sample.ps1') + body, 'sample.ps1'))

    def test_powershell_block_notice_is_a_duplicate(self):
        body = '<#\nThe MIT License\nSPDX-License-Identifier: MIT\n#>\n'
        self.assertFalse(self.check(fixture('sample.ps1') + body, 'sample.ps1'))

    def test_matlab_block_notice_is_a_duplicate(self):
        body = '%{\nThe MIT License\nSPDX-License-Identifier: MIT\n%}\n'
        self.assertFalse(self.check(fixture('sample.m', '%') + body, 'sample.m'))

    def test_header_after_code_rejected(self):
        self.assertFalse(self.check('print(1)\n'+fixture()))

    def test_interpreter_preamble_accepted(self):
        self.assertTrue(self.check('#!/usr/bin/env python3\n# -*- coding: utf-8 -*-\n'+fixture()))
        self.assertTrue(self.check('#requires -Version 7.0\n'+fixture('sample.ps1'), 'sample.ps1'))

    def test_binary_not_treated_as_text(self):
        self.assertFalse(self.check(fixture('sample.slx'), 'sample.slx'))

    def test_scope_uses_git_not_recursive_walk(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            subprocess.run(['git','init','-q',folder],check=True)
            for name in ['owned.py','local.py','legacy/restricted.m','.agent-env/cache.py']:
                path=root/name; path.parent.mkdir(parents=True,exist_ok=True); path.write_text('')
            subprocess.run(['git','-C',folder,'add','owned.py','legacy','.agent-env'],check=True)
            self.assertEqual([Path(p).relative_to(root).as_posix() for p in headers.find_files(root)], ['owned.py'])

    def test_legacy_and_generated_exclusions_have_reasons(self):
        for name in [
            'legacy/restricted.h',
            'mc-models/pmsm/data/mc_data_types.m',
            'mc-models/bldc/data/bldc_data_types.m',
        ]:
            self.assertTrue(headers.exclusion(name))
        self.assertIsNone(headers.exclusion('mc-models/pmsm/algo/+mc/clarke.m'))

    def test_git_paths_use_utf8_even_with_windows_ansi_default(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve() / '许可项目'
            root.mkdir()
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            source = root / '许可证.py'
            source.write_text('', encoding='utf-8')
            subprocess.run(['git', '-C', str(root), 'add', source.name], check=True)
            # Reproduce the Windows Python 3.11 CI default on every platform.
            with patch('subprocess._text_encoding', return_value='cp1252'):
                self.assertEqual(list(headers.find_files(root)), [source])


class SavedModelTests(unittest.TestCase):
    def check(self, notices, nested=False):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'sample.slx'
            root = ET.Element('System')
            parent = ET.SubElement(root, 'System') if nested else root
            for notice in notices:
                annotation = ET.SubElement(parent, 'Annotation')
                ET.SubElement(annotation, 'P', Name='Name').text = notice
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr('simulink/systems/system_root.xml', ET.tostring(root))
            return headers.model_errors(path)

    def notice(self):
        return '\n'.join(line[2:] if line.startswith('# ') else line[1:]
                         for line in fixture('sample.slx').rstrip().splitlines())

    def test_complete_root_annotation_passes(self):
        self.assertEqual(self.check([self.notice()]), [])

    def test_unrelated_annotation_is_preserved(self):
        self.assertEqual(self.check(['Signal flow', self.notice()]), [])

    def test_missing_annotation_fails(self):
        self.assertTrue(self.check([]))

    def test_duplicate_annotations_fail(self):
        self.assertTrue(self.check([self.notice(), self.notice()]))

    def test_subsystem_annotation_does_not_satisfy_root(self):
        self.assertTrue(self.check([self.notice()], nested=True))

    def test_corrupt_saved_notice_fails(self):
        self.assertTrue(self.check([self.notice().replace('THE SOFTWARE IS PROVIDED', 'THE SOFTWAREISPROVIDED')]))

    def test_non_zip_model_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'sample.slx'
            path.write_text(self.notice(), encoding='utf-8')
            self.assertTrue(headers.model_errors(path))


if __name__ == '__main__':
    unittest.main()
