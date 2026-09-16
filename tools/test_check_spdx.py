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
        # Downloaded official sources and local generated environments have their own licenses.
        dirs[:] = [d for d in dirs if d not in {'.git', 'legacy', '.agent-env', '.agents', '.codex'}]
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
