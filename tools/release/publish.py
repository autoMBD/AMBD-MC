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
# File:        publish.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-08
# Version:     0.1.0
# Description: Publish verified draft-first GitHub release assets.
# =================================================================================

"""Publish checked assets through GitHub CLI, staging and verifying a draft first."""

import argparse
from pathlib import Path
import subprocess
import sys
import tempfile

from archives import read_archive
from package import ROOT, assets, git, load_release

REPOSITORY = "autoMBD/AMBD-MC"


def gh(*args):
    result = subprocess.run(["gh", *map(str, args)], capture_output=True)
    if result.returncode:
        raise ValueError(result.stderr.decode("utf-8", errors="replace").strip())
    return result.stdout


def validate_mode(version, mode, runtime_reviewed):
    if mode != "draft" and not runtime_reviewed:
        raise ValueError("Public release requires explicit runtime review; retain a draft until reviewed")
    if mode == "release" and "-" in version or mode == "prerelease" and "-" not in version:
        raise ValueError("Version and release/prerelease mode do not match")


def publish_assets(run, tag, paths, notes, mode, verify_downloads):
    run("release", "create", tag, *paths, "--repo", REPOSITORY, "--verify-tag",
        "--draft", "--title", f"AMBD-MC {tag}", "--notes-file", notes)
    # Any failure leaves a draft for investigation, never a partially verified public release.
    verify_downloads()
    if mode != "draft":
        flags = ("--prerelease", "--latest=false") if mode == "prerelease" else ("--prerelease=false", "--latest")
        run("release", "edit", tag, "--repo", REPOSITORY, "--draft=false", *flags)


def verify_remote(tag, commit, source_files, expected):
    scratch = ROOT / ".agent-env/release-downloads"
    scratch.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=scratch) as directory:
        target = Path(directory)
        gh("release", "download", tag, "--repo", REPOSITORY, "--dir", target)
        if {p.name: p.read_bytes() for p in target.iterdir() if p.is_file()} != expected:
            raise ValueError("Downloaded GitHub release assets differ from checked build")
        for kind in ("zipball", "tarball"):
            data = gh("api", f"repos/{REPOSITORY}/{kind}/{commit}")
            if read_archive(data, strip_root=True) != source_files:
                raise ValueError(f"GitHub {kind} violates source distribution manifest")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ref", required=True, help="Existing version tag; never creates a tag")
    parser.add_argument("--assets", required=True, type=Path)
    parser.add_argument("--mode", choices=("draft", "prerelease", "release"), default="draft")
    parser.add_argument("--runtime-reviewed", action="store_true")
    args = parser.parse_args()
    try:
        release = load_release(ROOT, args.ref)
        files, manifest, config, commit, timestamp = release
        tag = "v" + config["version"]
        if args.ref not in {tag, "refs/tags/" + tag}:
            raise ValueError("Publishing requires the exact configured version tag")
        validate_mode(config["version"], args.mode, args.runtime_reviewed)
        if args.mode == "release":
            git(ROOT, "merge-base", "--is-ancestor", commit, "origin/main")
        expected = assets(*release)
        if {p.name: p.read_bytes() for p in args.assets.iterdir() if p.is_file()} != expected:
            raise ValueError("Local release assets differ from the selected commit")
        remote_commit = gh("api", f"repos/{REPOSITORY}/commits/{tag}", "--jq", ".sha").decode().strip()
        if remote_commit != commit:
            raise ValueError("Remote tag does not match selected commit")
        existing = gh("api", "--paginate", f"repos/{REPOSITORY}/releases", "--jq", ".[].tag_name").decode().splitlines()
        if tag in existing:
            raise ValueError("Release already exists; never overwrite or resume implicitly")
        publish_assets(gh, tag, [args.assets / name for name in sorted(expected)],
                       args.assets / "RELEASE_NOTES.md", args.mode,
                       lambda: verify_remote(tag, commit, files, expected))
        print(f"Verified {args.mode}: https://github.com/{REPOSITORY}/releases/tag/{tag}")
        return 0
    except (ValueError, OSError, KeyError) as error:
        print(f"Release publication FAILED: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
