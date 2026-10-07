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
# File:        capabilities.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-09-11
# Version:     0.1.0
# Description: Report skill eligibility from the dependency fields in official
#              manifests.
# =================================================================================

"""Report skill eligibility from the dependency fields in official manifests."""
from pathlib import Path
import re


def _dependency_list(text, key):
    match = re.search(r'^' + re.escape(key) + r':([^\n]*)(\n(?:[ \t]+[^\n]*\n|[ \t]*\n)*)?', text + '\n', re.M)
    if not match:
        return []
    inline = match[1].strip()
    if inline == '[]':
        return []
    if inline and not inline.startswith('#'):
        raise ValueError('Unsupported dependency list syntax: ' + key)
    items = []
    for line in (match[2] or '').splitlines():
        value = line.strip()
        if not value or value.startswith('#'):
            continue
        if not value.startswith('- '):
            raise ValueError('Unsupported dependency list item: ' + key)
        items.append(value[2:].split(' #', 1)[0].strip().strip('"\''))
    return items


def skills(root: Path, matlab: dict, tools) -> dict:
    installed = {product['Name'] for product in matlab.get('toolboxes', [])}
    selected = {path.name for path in root.iterdir() if path.is_dir()}
    result = {}
    for name in sorted(selected):
        try:
            text = (root / name / 'manifest.yaml').read_text(encoding='utf-8')
            match = re.search(r'^matlab-release:\s*[\"\']?(>=R\d{4}[ab])[\"\']?\s*$', text, re.M)
            if not match:
                raise ValueError('Unknown MATLAB release constraint; inspect the official manifest')
            release_ok = matlab['release'] >= match[1][3:]
            missing_products = sorted(set(_dependency_list(text, 'required-products')) - installed)
            missing_tools = sorted(set(_dependency_list(text, 'required-tools')) - set(tools))
            missing_skills = sorted(set(_dependency_list(text, 'required-skills')) - selected)
            result[name] = {'status': 'UNAVAILABLE' if missing_products or missing_tools or missing_skills or not release_ok else 'ELIGIBLE',
                            'missing_products': missing_products, 'missing_tools': missing_tools,
                            'missing_skills': missing_skills, 'release_compatible': release_ok}
        except (OSError, ValueError, KeyError) as error:
            result[name] = {'status': 'UNKNOWN', 'reason': str(error)}
    return result
