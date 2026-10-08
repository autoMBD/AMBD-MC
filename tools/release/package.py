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
# File:        package.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-08
# Version:     0.1.0
# Description: Build and verify reproducible release packages from Git.
# =================================================================================

"""Build or verify an AMBD-MC release from committed Git blobs, never the worktree."""

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import io
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tarfile
import tempfile
from urllib.parse import unquote, urlsplit
import posixpath
import zipfile

from archives import check_payload, forbidden, read_archive, safe_path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = "tools/release/manifest.json"
CONFIG = "tools/release/release.json"
EXCLUDED_ROOTS = {"legacy", ".agent-env", ".agents", ".codex", ".claude", "AGENTS.md"}
SEMVER = re.compile(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?")


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def git(repo, *args, input=None):
    completed = subprocess.run(["git", "-C", str(repo), *args], input=input, capture_output=True)
    if completed.returncode:
        raise ValueError(completed.stderr.decode("utf-8", errors="replace").strip())
    return completed.stdout


def attributes_text(names):
    paths = set(names)
    for name in names:
        safe_path(name)
        if re.search(r"[\s*?\[\]\\]", name):
            raise ValueError(f"Unsupported attributes path: {name}")
        paths.update(p.as_posix() for p in PurePosixPath(name).parents if p.as_posix() != ".")
    return ("# Generated from tools/release/manifest.json; default deny.\n"
            "* export-ignore\n" + "".join(f"/{name} -export-ignore\n" for name in sorted(paths))).encode()


def blobs(repo, entries):
    """Read a bounded set of immutable blobs in one Git process."""
    request = "".join(f"{oid}\n" for mode, oid in entries.values()).encode()
    stream = io.BytesIO(git(repo, "cat-file", "--batch", input=request))
    result = {}
    for name, (mode, oid) in entries.items():
        header = stream.readline().decode().split()
        if len(header) != 3 or header[1] != "blob" or int(header[2]) > 128 * 1024 * 1024:
            raise ValueError(f"Invalid/oversized Git blob: {name}")
        result[name] = stream.read(int(header[2]))
        if stream.read(1) != b"\n":
            raise ValueError("Invalid Git batch response")
    return result


def check_headers(files):
    # Reuse the repository's full MIT text/model checker, without running code from the ref.
    spec = importlib.util.spec_from_file_location("release_header_check", ROOT / "tools/test_check_spdx.py")
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    for name, data in files.items():
        if checker.exclusion(name):
            continue
        extension = PurePosixPath(name).suffix.lower()
        if extension not in checker.PREFIXES and extension != ".slx":
            continue
        # Only the selected bytes are materialized, no model is loaded or saved.
        scratch = ROOT / ".agent-env/release-checks"
        scratch.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="header-", dir=scratch) as folder:
            target = Path(folder) / PurePosixPath(name).name
            target.write_bytes(data)
            errors = checker.model_errors(target) if extension == ".slx" else checker.file_errors(target)
        if errors:
            raise ValueError(f"License header {name}: {'; '.join(errors)}")


def check_links(files):
    for name, data in files.items():
        if not name.endswith(".md"):
            continue
        # Fenced examples are not document links.
        text = re.sub(r"```.*?```", "", data.decode("utf-8-sig"), flags=re.S)
        for match in re.finditer(r"!?\[[^\]]*\]\(([^)]+)\)", text):
            url = match[1].strip().split(' "', 1)[0].strip("<>")
            parsed = urlsplit(url)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            target = posixpath.normpath(posixpath.join(posixpath.dirname(name), unquote(parsed.path)))
            if target not in files and not any(p.startswith(target.rstrip("/") + "/") for p in files):
                raise ValueError(f"Missing package document link: {name} -> {url}")


def load_release(repo, ref, version=None):
    if ref.startswith("-"):
        raise ValueError("Invalid ref")
    commit = git(repo, "rev-parse", "--verify", "--end-of-options", ref + "^{commit}").decode().strip()
    entries = {}
    for row in git(repo, "ls-tree", "-rz", "--full-tree", commit).split(b"\0"):
        if row:
            metadata, path = row.split(b"\t", 1)
            mode, kind, oid = metadata.decode().split()
            entries[path.decode("utf-8")] = (mode, oid)
    if MANIFEST not in entries or CONFIG not in entries:
        raise ValueError("Missing committed release manifest/configuration")
    manifest = json.loads(blobs(repo, {MANIFEST: entries[MANIFEST]})[MANIFEST])
    if manifest.get("schema_version") != 1:
        raise ValueError("Unsupported manifest schema")
    listed = manifest["files"]
    seen = set()
    restricted = {oid for name, (mode, oid) in entries.items() if name.split("/")[0] in EXCLUDED_ROOTS}
    for name in listed:
        safe_path(name)
        if forbidden(name) or name.split("/")[0] in EXCLUDED_ROOTS:
            raise ValueError(f"Forbidden manifest path: {name}")
        if name.casefold() in seen:
            raise ValueError(f"Case-colliding manifest path: {name}")
        seen.add(name.casefold())
        if name not in entries:
            raise ValueError(f"Missing listed file: {name}")
        mode, oid = entries[name]
        if mode not in {"100644", "100755"}:
            raise ValueError(f"Not a regular file: {name}")
        if oid in restricted:
            raise ValueError(f"Copy of restricted blob: {name}")
    unlisted = set(entries) - set(listed)
    unlisted = {p for p in unlisted if p.split("/")[0] not in EXCLUDED_ROOTS}
    if unlisted:
        raise ValueError(f"Unlisted tracked files require review: {', '.join(sorted(unlisted))}")
    for name in [MANIFEST, CONFIG, ".gitattributes", "LICENSE", "README.md", "mc-models/hsp/models.json", *manifest["required"]]:
        if name not in listed:
            raise ValueError(f"Missing required file from manifest: {name}")
    files = blobs(repo, {name: entries[name] for name in sorted(listed)})
    if files[".gitattributes"] != attributes_text(listed):
        raise ValueError(".gitattributes does not match the default-deny release manifest")
    components = manifest["components"]
    for name, component in listed.items():
        if component not in components:
            raise ValueError(f"Unknown license component: {name}: {component}")
        # These vendor-derived configurations must never inherit the root MIT license.
        if name.startswith("mc-models/hsp/config/") and components[component]["license"] != "Apache-2.0":
            raise ValueError(f"Wrong license for HSP configuration: {name}")
    for key, component in components.items():
        if component["license"] not in {"MIT", "Apache-2.0"}:
            raise ValueError(f"Unreviewed license: {key}")
        if not component.get("license_files") or not component.get("source"):
            raise ValueError(f"Missing license/source materials: {key}")
        for path in component["license_files"] + component.get("notice_files", []) + component.get("provenance_files", []):
            if path not in files or not files[path].strip():
                raise ValueError(f"Missing license/provenance material: {path}")
        license_text = b"\n".join(files[p] for p in component["license_files"])
        signature = b"Permission is hereby granted" if component["license"] == "MIT" else b"Apache License"
        if signature not in license_text:
            raise ValueError(f"License text mismatch: {key}")
        if component["license"] == "Apache-2.0" and not component.get("provenance_files"):
            raise ValueError(f"Missing Apache provenance: {key}")
    for name, data in files.items():
        check_payload(name, data)
    for model in json.loads(files["mc-models/hsp/models.json"])["models"]:
        if model["path"] not in files:
            raise ValueError(f"Missing active model: {model['path']}")
    check_headers(files)
    check_links(files)
    config = json.loads(files[CONFIG])
    if config.get("schema_version") != 1:
        raise ValueError("Unsupported release configuration schema")
    actual = config["version"]
    match = SEMVER.fullmatch(actual)
    if not match or (match[4] and any(x.isdigit() and len(x) > 1 and x.startswith("0") for x in match[4].split("."))):
        raise ValueError(f"Invalid release version: {actual}")
    if version and version != actual:
        raise ValueError(f"Version mismatch: requested {version}, committed {actual}")
    tag = "v" + actual
    is_tag = ref.startswith("refs/tags/") or ref.startswith("v") and SEMVER.fullmatch(ref[1:])
    if is_tag and ref not in {tag, "refs/tags/" + tag}:
        raise ValueError("Tag/version mismatch")
    tag_check = subprocess.run(["git", "-C", str(repo), "rev-parse", "--verify", "refs/tags/" + tag + "^{commit}"], capture_output=True)
    if is_tag and tag_check.returncode == 0 and tag_check.stdout.decode().strip() != commit:
        raise ValueError(f"Tag {tag} points to another commit")
    if config["notes"] not in files or not files[config["notes"]].strip():
        raise ValueError("Missing release notes")
    timestamp = int(git(repo, "show", "-s", "--format=%ct", commit).strip())
    return files, manifest, config, commit, timestamp


def assets(files, manifest, config, commit, timestamp):
    version = config["version"]
    date = datetime.fromtimestamp(timestamp, timezone.utc).strftime("%Y-%m-%d")
    base = f"AMBD-MC-{version}"
    notes = (f"# AMBD-MC {version}\n\nSource: `{commit}` · source date (UTC): {date}\n\n"
             + files[config["notes"]].decode("utf-8")
             + f"\n## Downloads\n\n[Model/source ZIP](https://github.com/autoMBD/AMBD-MC/releases/download/v{version}/{base}.zip) · "
             + f"[SHA256SUMS](https://github.com/autoMBD/AMBD-MC/releases/download/v{version}/SHA256SUMS)\n\n"
             + "Verify SHA256SUMS before unpacking; checksums verify integrity, not publisher identity.\n").encode()
    notices = ["# Distribution components\n", "The root MIT license does not replace third-party licenses.\n"]
    for key, component in sorted(manifest["components"].items()):
        notices += [f"## {component['name']}\n", f"License: {component['license']}; source: {component['source']}\n",
                    f"Modified: {component['modified']}\n",
                    "Materials: " + ", ".join(f"[{p}]({p})" for p in component["license_files"] + component.get("notice_files", []) + component.get("provenance_files", [])) + "\n"]
    payload = dict(files)
    # Pin source browsing links in delivered Markdown; input blobs are not modified.
    for name, data in payload.items():
        if name.endswith(".md"):
            text = data.decode("utf-8")
            for kind in ("blob", "tree"):
                text = text.replace(f"https://github.com/autoMBD/AMBD-MC/{kind}/main/", f"https://github.com/autoMBD/AMBD-MC/{kind}/{commit}/")
            payload[name] = text.encode("utf-8")
    for name in ("RELEASE_NOTES.md", "THIRD_PARTY_NOTICES.md", "release-metadata.json"):
        if name in payload:
            raise ValueError(f"Reserved generated path: {name}")
    payload["RELEASE_NOTES.md"] = notes
    payload["THIRD_PARTY_NOTICES.md"] = "\n".join(notices).encode()
    metadata = {"schema_version": 1, "version": version, "tag": "v" + version,
                "commit": commit, "source_date": date, "dependencies": config["dependencies"],
                "files": [{"path": p, "sha256": hashlib.sha256(b).hexdigest(),
                           "component": manifest["files"].get(p, "project")}
                          for p, b in sorted(payload.items())]}
    payload["release-metadata.json"] = encoded(metadata)
    check_links(payload)
    buffer = io.BytesIO()
    # STORE avoids zlib-version-dependent compressed bytes; these small source bundles
    # contain already-compressed SLX/SLDD files. All entry metadata is fixed.
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_STORED) as archive:
        for name, body in sorted(payload.items()):
            info = zipfile.ZipInfo(f"{base}/{name}", date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            archive.writestr(info, body)
    archive_bytes = buffer.getvalue()
    if read_archive(archive_bytes, strip_root=True) != payload:
        raise ValueError("Final ZIP contents differ from selected payload")
    result = {base + ".zip": archive_bytes, "release-metadata.json": encoded(metadata), "RELEASE_NOTES.md": notes}
    result["SHA256SUMS"] = "".join(f"{hashlib.sha256(b).hexdigest()}  {p}\n" for p, b in sorted(result.items())).encode()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=ROOT)
    parser.add_argument("--ref", default="HEAD")
    parser.add_argument("--version")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--output", type=Path)
    mode.add_argument("--verify", type=Path, help="Verify downloaded release assets against the source commit")
    mode.add_argument("--verify-source", type=Path, help="Verify a GitHub-generated ZIP or TAR.GZ")
    mode.add_argument("--attributes-from", type=Path, help="Print export policy from a reviewed local manifest")
    args = parser.parse_args()
    try:
        if args.attributes_from:
            sys.stdout.buffer.write(attributes_text(json.loads(args.attributes_from.read_text(encoding="utf-8"))["files"]))
            return 0
        release = load_release(args.repo, args.ref, args.version)
        files, manifest, config, commit, timestamp = release
        if args.verify_source:
            if read_archive(args.verify_source.read_bytes(), strip_root=True) != files:
                raise ValueError("Source archive differs from committed distribution manifest")
        elif not args.check:
            expected = assets(*release)
            if args.verify:
                actual = {p.name: p.read_bytes() for p in args.verify.iterdir() if p.is_file() and not p.is_symlink()}
                if actual != expected or any(p.is_dir() or p.is_symlink() for p in args.verify.iterdir()):
                    raise ValueError("Release asset set/content/checksums differ from expected commit")
            else:
                # Never replace an existing directory or asset, including interrupted output.
                args.output.mkdir(parents=True, exist_ok=False)
                for name, body in expected.items():
                    with (args.output / name).open("xb") as target:
                        target.write(body)
                if {p.name: p.read_bytes() for p in args.output.iterdir()} != expected:
                    raise ValueError("Written release assets failed verification")
        print(f"PASS distribution checks: {config['version']} {commit} ({len(files)} source files)")
        print("SKIP MATLAB/SIL/target/PIL: packaging does not execute or certify runtime behavior.")
        return 0
    except (ValueError, KeyError, TypeError, OSError, zipfile.BadZipFile, tarfile.TarError) as error:
        print(f"Release check FAILED: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
