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
# Description: Validate complete MIT source headers and saved model root annotations.
# =================================================================================

"""Validate tracked project-owned MIT headers; inspect SLX annotations separately.

Usage: python tools/test_check_spdx.py [repository-or-subdirectory] [--models]
Model inspection reads saved XML only; MCP save/reload and layout checks are
separate runtime evidence. Binary MLX/MDL files are never decoded as source.
"""
import argparse
from datetime import date
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import tokenize
import xml.etree.ElementTree as ET
import zipfile

TOOLS = Path(__file__).resolve().parent
PREFIXES = {".m": "%", ".py": "#", ".ps1": "#", ".c": "//", ".h": "//", ".cpp": "//"}
EXTENSIONS = tuple(PREFIXES)
MODELS = {".slx", ".mdl", ".mlx"}
SEPARATOR = "=" * 81
PROJECT = "autoMBD Motor Control <https://github.com/autoMBD/AMBD-MC>"
POLICY = json.loads((TOOLS / "license-header-exclusions.json").read_text(encoding="utf-8"))
NOTICE = (TOOLS / "license-header-template.txt").read_text(encoding="utf-8").splitlines()


def exclusion(path):
    """Return a documented exclusion reason for a repository-relative path."""
    name = Path(path).as_posix()
    if name in POLICY["files"]:
        return POLICY["files"][name]
    return next((reason for prefix, reason in POLICY["prefixes"].items()
                 if name.startswith(prefix)), None)


def tracked_files(root):
    """Read only Git-tracked paths; fail closed outside a repository."""
    root = Path(root).resolve()
    repo = Path(subprocess.check_output(
        ["git", "-C", str(root), "rev-parse", "--show-toplevel"], text=True).strip())
    names = subprocess.check_output(
        ["git", "-C", str(repo), "ls-files", "-z"], text=True).split("\0")
    return [(repo / name, name) for name in names if name
            and (repo / name).is_relative_to(root)]


def find_files(root):
    for path, name in tracked_files(root):
        if path.suffix.lower() in PREFIXES and not exclusion(name):
            yield path


def validate_header(lines, filename):
    """Validate plain header lines without comment tokens or trailing spaces."""
    if len(lines) < len(NOTICE) + 7:
        return ["missing complete bilingual MIT notice or metadata"]
    copyright_match = re.fullmatch(r"Copyright \(c\) (\d{4}(?:-\d{4})?) (.+)", lines[8])
    if not copyright_match:
        return ["invalid copyright year/holder"]
    year, holder = copyright_match.groups()
    expected = [line.replace("{{YEAR}}", year).replace("{{COPYRIGHT_HOLDER}}", holder)
                for line in NOTICE]
    if lines[:len(NOTICE)] != expected:
        return ["MIT notice text, separators or blank lines differ from project template"]
    fields = {}
    labels = ("Project", "File", "Author", "Date", "Version", "Description")
    for index, label in enumerate(labels, len(NOTICE)):
        prefix = (label + ":").ljust(13)
        if not lines[index].startswith(prefix) or not lines[index][13:].strip():
            return [f"missing or misaligned {label} field"]
        fields[label] = lines[index][13:]
    tail = lines[len(NOTICE)+6:]
    if not tail or tail[-1] != SEPARATOR or any(
            not line.startswith(" " * 13) or not line[13:].strip() for line in tail[:-1]):
        return ["invalid Description continuation or final separator"]
    if re.search(r"\{\{|\}\}|<[^>]*placeholder[^>]*>|\b(?:TODO|TBD)\b", "\n".join(lines), re.I):
        return ["unresolved template placeholder"]
    if fields["File"] != filename:
        return ["File does not match actual basename"]
    if fields["Project"] != PROJECT:
        return ["Project name/URL does not match this repository"]
    if not re.fullmatch(r"[^<>]+ <[^<>\s]+@[^<>\s]+>", fields["Author"]):
        return ["Author requires name and email"]
    try:
        date.fromisoformat(fields["Date"])
    except ValueError:
        return ["invalid Date (expected YYYY-MM-DD)"]
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", fields["Date"]):
        return ["Date must use YYYY-MM-DD"]
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:[-+][\w.-]+)?", fields["Version"]):
        return ["invalid Version"]
    return []


def file_errors(path):
    path = Path(path)
    prefix = PREFIXES.get(path.suffix.lower())
    if prefix is None:
        return ["unsupported text format; use independent model/binary validation"]
    try:
        lines = path.read_text(encoding="utf-8-sig").splitlines()
    except (OSError, UnicodeError) as error:
        return [str(error)]
    start = 0
    if path.suffix.lower() == ".py":
        if lines and lines[0].startswith("#!"):
            start = 1
        if start < len(lines) and re.match(r"#.*coding[:=]\s*[-\w.]+", lines[start]):
            start += 1
    if path.suffix.lower() == ".ps1":
        while start < len(lines) and lines[start].lower().startswith("#requires "):
            start += 1
    end = start
    separators = 0
    plain = []
    while end < len(lines):
        line = lines[end].rstrip()
        if not (line == prefix or line.startswith(prefix + " ")):
            break
        content = line[len(prefix)+1:] if line != prefix else ""
        plain.append(content)
        end += 1
        if content == SEPARATOR:
            separators += 1
            if separators == 3:
                break
    errors = validate_header(plain, path.name)
    declarations = license_declarations("\n".join(lines), path.suffix.lower())
    if declarations != 2:
        errors.append("missing or duplicate license declarations")
    return errors


def license_declarations(text, extension):
    """Count notices in comments, excluding embedded source string literals."""
    if extension == ".py":
        try:
            comments = [token.string[1:] for token in tokenize.generate_tokens(
                io.StringIO(text).readline) if token.type == tokenize.COMMENT]
        except (tokenize.TokenError, IndentationError):
            return -1
    elif extension in {".c", ".h", ".cpp"}:
        # Consume quoted strings/chars as well as both C comment forms.
        tokens = re.findall(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*|/\*.*?\*/',
                            text, re.S)
        comments = []
        for token in tokens:
            if token.startswith("//"):
                comments.append(token[2:])
            elif token.startswith("/*"):
                comments.extend(line.lstrip().lstrip("*").lstrip()
                                for line in token[2:-2].splitlines())
    elif extension == ".ps1":
        # Here-strings can contain literal source headers; ordinary quoted
        # strings can span lines too. Consume them before scanning comments.
        tokens = re.findall(
            r"@'[^\S\n]*\n.*?\n'@|@\"[^\S\n]*\n.*?\n\"@|"
            r"'(?:''|[^'])*'|\"(?:`.|[^\"`])*\"|<\#.*?\#>|\#[^\n]*",
            text, re.S)
        comments = []
        for token in tokens:
            if token.startswith("<#"):
                comments.extend(token[2:-2].splitlines())
            elif token.startswith("#"):
                comments.append(token[1:])
    else:  # MATLAB: block delimiters occupy their own comment lines.
        comments = []
        depth = 0
        for line in text.splitlines():
            stripped = line.strip()
            if stripped == "%{":
                depth += 1
            elif stripped == "%}" and depth:
                depth -= 1
            elif depth:
                comments.append(line)
            elif stripped.startswith("%"):
                comments.append(stripped[1:])
    return sum(bool(re.match(
        r"\s*(?:The MIT License|SPDX-License-Identifier:|SPDX short identifier)", line))
        for line in comments)


def check_file(path):
    return not file_errors(path)


def model_errors(path):
    """Inspect the one saved root license annotation, without loading callbacks."""
    path = Path(path)
    if path.suffix.lower() != ".slx":
        return ["SKIP: requires a format-specific MATLAB verification path"]
    try:
        with zipfile.ZipFile(path) as archive:
            root = ET.fromstring(archive.read("simulink/systems/system_root.xml"))
        texts = [node.text or "" for node in root.findall("./Annotation/P[@Name='Name']")]
        notices = [text for text in texts if "MIT License" in text or "SPDX" in text]
        if len(notices) != 1:
            return [f"expected one root license annotation, found {len(notices)}"]
        return validate_header([line.rstrip() for line in notices[0].splitlines()], path.name)
    except (OSError, KeyError, zipfile.BadZipFile, ET.ParseError) as error:
        return [str(error)]


def main(root=None, models=False):
    root = Path(root) if root is not None else TOOLS.parent
    try:
        entries = tracked_files(root)
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"Header scope FAILED: {error}")
        return 2
    checked = failed = model_count = skipped = 0
    for path, name in entries:
        if exclusion(name):
            continue
        if path.suffix.lower() in PREFIXES:
            checked += 1
            errors = file_errors(path)
        elif path.suffix.lower() in MODELS:
            model_count += 1
            if not models:
                continue
            errors = model_errors(path)
            if errors and errors[0].startswith("SKIP:"):
                skipped += 1
                print(f"{name}: {errors[0]}")
                continue
        else:
            continue
        if errors:
            failed += 1
            print(f"FAIL {name}: {'; '.join(errors)}")
    print(f"Full MIT header check: {checked} text files, {failed} failures.")
    if not models:
        print(f"SKIP model/binary validation: {model_count} files; run with --models for saved SLX inspection.")
    else:
        print(f"Saved model inspection: {model_count} files, {skipped} unsupported; MCP reload/layout verified separately.")
    if not checked:
        print("FAIL: no tracked project-owned text files selected")
        return 2
    if failed:
        print("Use the complete bilingual MIT header and metadata from tools/license-header-template.txt")
        print("and .agents/skills/common-uniform-file-header/reference.md (not a short SPDX-only notice).")
    return 2 if failed else 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?")
    parser.add_argument("--models", action="store_true")
    args = parser.parse_args()
    sys.exit(main(args.root, args.models))
