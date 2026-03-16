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
# File:        test_check_spdx.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-03-16
# Version:     0.1.0
# Description: Test and check if .m files (extensible) in the repository contain 
#              SPDX-License-Identifier or explicit License field.
# =================================================================================

"""
Tool: Check if .m files (extensible) in the repository contain SPDX-License-Identifier or explicit License field.
Usage (local/CI):
  python3 tools/test_check_spdx.py [path]
If missing is detected, exit with non-zero status code.
"""
import os
import re
import sys

SPDX_RE = re.compile(r"SPDX-License-Identifier", re.IGNORECASE)
LICENSE_WORD_RE = re.compile(r"\blicense\b", re.IGNORECASE)
EXTENSIONS = [".m", ".mlx"]  # Can be extended as needed

def check_file(path):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            lines = []
            # Read first 12 lines (including blank lines) for detection
            for _ in range(12):
                l = f.readline()
                if not l:
                    break
                lines.append(l)
            head = "\n".join(lines)
            if SPDX_RE.search(head) or LICENSE_WORD_RE.search(head):
                return True
            return False
    except Exception:
        return False

def find_files(root):
    for dirpath, dirs, files in os.walk(root):
        # skip .git and legacy directories
        path_parts = dirpath.split(os.sep)
        if ".git" in path_parts or "legacy" in path_parts:
            continue
        for fn in files:
            if any(fn.lower().endswith(ext) for ext in EXTENSIONS):
                yield os.path.join(dirpath, fn)

def main(root="."):
    missing = []
    for f in find_files(root):
        ok = check_file(f)
        if not ok:
            missing.append(f)
    if missing:
        print("SPDX/license header check FAILED. The following files miss SPDX/license in header:")
        for p in missing:
            print("  " + p)
        print("\nRecommended: Add a short SPDX header to each file, e.g.:")
        print("% SPDX-FileCopyrightText: 2026 autoMBD")
        print("% SPDX-License-Identifier: Apache-2.0")
        return 2
    else:
        print("SPDX/license header check OK.")
        return 0

if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    rc = main(root)
    sys.exit(rc)