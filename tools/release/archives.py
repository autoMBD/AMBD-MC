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
# File:        archives.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-08
# Version:     0.1.0
# Description: Inspect release archives without extracting unsafe members.
# =================================================================================

"""Bounded archive inspection without extracting untrusted paths."""

import io
from pathlib import PurePosixPath
import re
import stat
import tarfile
import zipfile

LIMIT = 128 * 1024 * 1024
FORBIDDEN_PARTS = {
    "legacy", ".agent-env", ".git", ".agents", ".codex", ".claude",
    "__pycache__", ".pytest_cache", "slprj", "plans", "reports", "audits",
    "internal-docs", "node_modules", "credentials", "rtd", "sdk",
}
FORBIDDEN_SUFFIXES = {
    ".exe", ".dll", ".elf", ".hex", ".mexw64", ".slxc", ".autosave",
    ".log", ".pem", ".key", ".pfx", ".zip", ".gz", ".7z", ".tar", ".rar", ".bz2", ".xz",
}


def safe_path(name):
    parts = name.split("/")
    if (not name or name.startswith("/") or "\\" in name or ":" in name
            or any(p in {"", ".", ".."} or p.endswith((".", " ")) for p in parts)
            or any(ord(c) < 32 for c in name)
            or any(re.fullmatch(r"(?i)(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?", p) for p in parts)):
        raise ValueError(f"Unsafe archive path: {name!r}")
    return PurePosixPath(name)


def forbidden(name):
    path = safe_path(name)
    return (any(p.lower() in FORBIDDEN_PARTS for p in path.parts)
            or path.suffix.lower() in FORBIDDEN_SUFFIXES
            or path.name.lower().startswith(".env")
            or any(p.lower().endswith(("_ert_rtw", "_mbd_rtw")) for p in path.parts)
            or path.stem.lower().endswith(("-report", "-audit", "-test-plan", "-implementation-plan")))


def read_archive(data, *, strip_root=False):
    """Reject links, duplicate/colliding names, traversal and oversized members."""
    result, seen, roots = {}, set(), set()
    total = 0

    def add(name, size, regular, directory, read):
        nonlocal total
        path = safe_path(name.rstrip("/") if directory else name)
        roots.add(path.parts[0])
        if directory:
            return
        if not regular:
            raise ValueError(f"Archive member is not a regular file: {name}")
        if size < 0 or size > LIMIT or total + size > LIMIT * 4:
            raise ValueError(f"Archive exceeds size limit: {name}")
        total += size
        relative = "/".join(path.parts[1:]) if strip_root else name
        safe_path(relative)
        if relative.casefold() in seen:
            raise ValueError(f"Duplicate archive path: {relative}")
        seen.add(relative.casefold())
        result[relative] = read()

    if zipfile.is_zipfile(io.BytesIO(data)):
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            for item in archive.infolist():
                mode = item.external_attr >> 16
                kind = stat.S_IFMT(mode)
                if kind not in ({0, stat.S_IFDIR} if item.is_dir() else {0, stat.S_IFREG}):
                    raise ValueError(f"Archive member is not a regular file/directory: {item.filename}")
                add(item.filename, item.file_size,
                    stat.S_IFMT(mode) in {0, stat.S_IFREG}, item.is_dir(),
                    lambda item=item: archive.read(item))
    else:
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as archive:
            for item in archive:
                add(item.name, item.size, item.isfile(), item.isdir(),
                    lambda item=item: archive.extractfile(item).read())
    if strip_root and len(roots) != 1:
        raise ValueError("Source archive must have exactly one top-level directory")
    return result


def archive_signature(data):
    return (zipfile.is_zipfile(io.BytesIO(data))
            or data.startswith((b"\x1f\x8b", b"7z\xbc\xaf\x27\x1c", b"Rar!", b"BZh", b"\xfd7zXZ\x00"))
            or data[257:262] == b"ustar")


def check_payload(name, data):
    """Only reviewed Simulink container formats may contain ZIP members."""
    if forbidden(name):
        raise ValueError(f"Forbidden distribution path: {name}")
    is_zip = zipfile.is_zipfile(io.BytesIO(data))
    if is_zip and PurePosixPath(name).suffix in {".slx", ".sldd"}:
        contents = read_archive(data)
        required = "simulink/blockdiagram.xml" if name.endswith(".slx") else "[Content_Types].xml"
        if required not in contents:
            raise ValueError(f"Invalid Simulink archive: {name}")
        for inner, body in contents.items():
            if forbidden(inner) or archive_signature(body):
                raise ValueError(f"Forbidden nested archive/member: {name}: {inner}")
    elif archive_signature(data):
        raise ValueError(f"Unapproved archive payload: {name}")
