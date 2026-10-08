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
# File:        test_package.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-08
# Version:     0.1.0
# Description: Test release packaging and redistribution boundaries.
# =================================================================================

"""Exercise release boundaries using real Git objects and archives."""

import hashlib
import io
import json
from pathlib import Path
import subprocess
import stat
import sys
import tarfile
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools/release/package.py"


class PackageTest(unittest.TestCase):
    def setUp(self):
        scratch = ROOT / ".agent-env/tests/release"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=scratch)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.root.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Release Test")
        self.git("config", "user.email", "release@example.invalid")
        self.git("config", "core.autocrlf", "false")
        self.files = {
            "LICENSE": (ROOT / "LICENSE").read_bytes(),
            "README.md": b"# Sample\n[Guide](docs/manual/start.md)\n",
            "docs/manual/start.md": b"# Getting started\n",
            "mc-models/hsp/models.json": b'{"models": []}',
            "tools/release/notes.md": b"## Changes\nA test release.\n",
            "tools/release/release.json": json.dumps({
                "schema_version": 1, "version": "0.2.0-rc.1",
                "notes": "tools/release/notes.md", "dependencies": [],
            }).encode(),
        }
        self.components = {"project": {
            "name": "AMBD-MC", "license": "MIT", "license_files": ["LICENSE"],
            "source": "https://github.com/autoMBD/AMBD-MC", "modified": False,
        }}
        self.write("legacy/restricted.txt", b"restricted content")
        self.write(".agent-env/secret.txt", b"local private content")
        self.git("add", "legacy")
        self.write_manifest()
        self.commit()

    def git(self, *args, input=None):
        return subprocess.check_output(["git", "-C", str(self.root), *args], input=input)

    def write(self, name, data):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def attributes(self, names):
        paths = set(names)
        for name in names:
            paths.update(p.as_posix() for p in Path(name).parents if p.as_posix() != ".")
        return ("# Generated from tools/release/manifest.json; default deny.\n"
                "* export-ignore\n" + "".join(f"/{name} -export-ignore\n" for name in sorted(paths))).encode()

    def write_manifest(self, extra=None):
        names = sorted(set(self.files) | {"tools/release/manifest.json", ".gitattributes"})
        manifest = {"schema_version": 1, "components": self.components,
                    "required": ["LICENSE", "README.md", "mc-models/hsp/models.json"],
                    "files": {name: "project" for name in names}}
        if extra:
            extra(manifest)
        self.files["tools/release/manifest.json"] = (json.dumps(manifest, indent=2) + "\n").encode()
        self.files[".gitattributes"] = self.attributes(names)
        for name, data in self.files.items():
            self.write(name, data)
            self.git("add", "--", name)

    def commit(self):
        self.git("commit", "-qm", "fixture", "--allow-empty")
        return self.git("rev-parse", "HEAD").decode().strip()

    def run_tool(self, *args, ok=True):
        result = subprocess.run([sys.executable, str(SCRIPT), "--repo", str(self.root),
                                 "--ref", "HEAD", *args], capture_output=True, text=True, encoding="utf-8")
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def build(self, name="out"):
        output = Path(self.temp.name) / name
        self.run_tool("--output", str(output))
        return output

    def test_check_is_read_only_and_package_ignores_dirty_worktree(self):
        self.write("README.md", b"UNCOMMITTED")
        self.run_tool("--check")
        output = self.build()
        with zipfile.ZipFile(output / "AMBD-MC-0.2.0-rc.1.zip") as archive:
            self.assertEqual(archive.read("AMBD-MC-0.2.0-rc.1/README.md"), self.files["README.md"])
            self.assertFalse(any("legacy/" in n or ".agent-env/" in n for n in archive.namelist()))
        self.assertEqual((self.root / "README.md").read_bytes(), b"UNCOMMITTED")

    def test_repeat_builds_are_identical_and_checksums_verify(self):
        first, second = self.build("first"), self.build("second")
        self.assertEqual({p.name: p.read_bytes() for p in first.iterdir()},
                         {p.name: p.read_bytes() for p in second.iterdir()})
        for line in (first / "SHA256SUMS").read_text().splitlines():
            digest, name = line.split("  ")
            self.assertEqual(digest, hashlib.sha256((first / name).read_bytes()).hexdigest())
        self.run_tool("--verify", str(first))

    def test_does_not_overwrite_existing_output(self):
        output = self.build()
        before = {p.name: p.read_bytes() for p in output.iterdir()}
        self.run_tool("--output", str(output), ok=False)
        self.assertEqual(before, {p.name: p.read_bytes() for p in output.iterdir()})

    def test_corrupt_asset_is_rejected(self):
        output = self.build()
        (output / "AMBD-MC-0.2.0-rc.1.zip").write_bytes(b"corrupt")
        self.run_tool("--verify", str(output), ok=False)

    def test_unlisted_tracked_file_is_rejected(self):
        self.write("vendor/unknown.txt", b"unknown")
        self.git("add", "vendor")
        self.commit()
        self.assertIn("unlisted", self.run_tool("--check", ok=False).stderr.lower())

    def test_unknown_license_is_rejected(self):
        self.components["project"]["license"] = "UNKNOWN"
        self.write_manifest()
        self.commit()
        self.assertIn("license", self.run_tool("--check", ok=False).stderr.lower())

    def test_missing_required_file_is_rejected(self):
        self.git("rm", "README.md")
        self.commit()
        self.assertIn("missing", self.run_tool("--check", ok=False).stderr.lower())

    def test_missing_model_dependency_is_rejected(self):
        self.files["mc-models/hsp/models.json"] = b'{"models": [{"path":"mc-models/lost.slx"}]}'
        self.write_manifest()
        self.commit()
        self.assertIn("model", self.run_tool("--check", ok=False).stderr.lower())

    def test_forbidden_path_cannot_be_allowlisted(self):
        self.files["docs/reports/private.md"] = b"internal record"
        self.write_manifest()
        self.commit()
        self.assertIn("forbidden", self.run_tool("--check", ok=False).stderr.lower())

    def test_renamed_legacy_blob_is_rejected(self):
        self.files["docs/manual/copied.txt"] = b"restricted content"
        self.write_manifest()
        self.commit()
        self.assertIn("restricted", self.run_tool("--check", ok=False).stderr.lower())

    def test_symlink_is_rejected_without_following_it(self):
        self.files["link.txt"] = b"/outside"
        self.write_manifest()
        oid = self.git("hash-object", "-w", "--stdin", input=b"/outside").decode().strip()
        self.git("update-index", "--cacheinfo", f"120000,{oid},link.txt")
        self.commit()
        self.assertIn("regular", self.run_tool("--check", ok=False).stderr.lower())

    def test_nested_archive_is_rejected_even_when_renamed(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, "w") as archive:
            archive.writestr("secret.txt", "secret")
        self.files["payload.txt"] = data.getvalue()
        self.write_manifest()
        self.commit()
        self.assertIn("archive", self.run_tool("--check", ok=False).stderr.lower())

    def test_version_and_tag_must_match(self):
        self.run_tool("--version", "1.0.0", "--check", ok=False)
        self.git("tag", "v9.0.0")
        self.assertIn("tag", self.run_tool("--ref", "v9.0.0", "--check", ok=False).stderr.lower())

    def test_missing_license_text_is_rejected(self):
        self.files["LICENSE"] = b"placeholder"
        self.write_manifest()
        self.commit()
        self.assertIn("license", self.run_tool("--check", ok=False).stderr.lower())

    def test_missing_offline_document_link_is_rejected(self):
        self.files["README.md"] = b"[Missing](docs/manual/gone.md)"
        self.write_manifest()
        self.commit()
        self.assertIn("link", self.run_tool("--check", ok=False).stderr.lower())

    def test_path_traversal_in_manifest_is_rejected(self):
        self.write_manifest(lambda m: m["files"].update({"../secret.txt": "project"}))
        self.commit()
        self.assertIn("unsafe", self.run_tool("--check", ok=False).stderr.lower())

    def test_modified_archive_policy_is_rejected(self):
        self.write(".gitattributes", b"legacy export-ignore\n")
        self.git("add", ".gitattributes")
        self.commit()
        self.assertIn("attributes", self.run_tool("--check", ok=False).stderr.lower())

    def test_downloaded_source_zip_and_tar_are_checked_against_commit(self):
        for fmt in ("zip", "tar.gz"):
            source = Path(self.temp.name) / f"source.{fmt}"
            source.write_bytes(self.git("archive", f"--format={fmt}", "--prefix=AMBD-MC-test/", "HEAD"))
            self.run_tool("--verify-source", str(source))
        with zipfile.ZipFile(source.with_suffix(".zip"), "w") as archive:
            archive.writestr("repo/legacy/secret.txt", "restricted")
        self.run_tool("--verify-source", str(source.with_suffix(".zip")), ok=False)

    def test_source_tar_symlinks_are_rejected(self):
        source = Path(self.temp.name) / "links.tar.gz"
        with tarfile.open(source, "w:gz") as archive:
            info = tarfile.TarInfo("repo/link")
            info.type = tarfile.SYMTYPE
            info.linkname = "/outside"
            archive.addfile(info)
        self.run_tool("--verify-source", str(source), ok=False)

    def test_zip_symlink_with_directory_name_is_rejected(self):
        source = Path(self.temp.name) / "source.zip"
        source.write_bytes(self.git("archive", "--format=zip", "--prefix=repo/", "HEAD"))
        with zipfile.ZipFile(source, "a") as archive:
            link = zipfile.ZipInfo("repo/link/")
            link.create_system = 3
            link.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(link, b"/outside")
        self.run_tool("--verify-source", str(source), ok=False)

    def test_tar_or_rar_disguised_inside_model_is_rejected(self):
        tar = io.BytesIO()
        with tarfile.open(fileobj=tar, mode="w") as archive:
            member = tarfile.TarInfo("legacy/restricted.txt")
            member.size = 6
            archive.addfile(member, io.BytesIO(b"secret"))
        for body in [tar.getvalue(), b"Rar!\x1a\x07\x00payload"]:
            with self.subTest(signature=body[:4]):
                model = io.BytesIO()
                with zipfile.ZipFile(model, "w") as archive:
                    archive.writestr("simulink/blockdiagram.xml", b"<root/>")
                    archive.writestr("attachment.bin", body)
                # Direct payload boundary check precedes model license validation.
                sys.path.insert(0, str(ROOT / "tools/release"))
                import archives
                with self.assertRaisesRegex(ValueError, "archive"):
                    archives.check_payload("sample.slx", model.getvalue())


if __name__ == "__main__":
    unittest.main()
