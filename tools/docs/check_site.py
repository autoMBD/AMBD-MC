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
# File:        check_site.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-08
# Version:     0.1.0
# Description: Validate rendered documentation links and publication boundaries.
# =================================================================================

"""Check the rendered Pages artifact, then optionally check HTTP links."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from html.parser import HTMLParser
import json
from pathlib import Path
import posixpath
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import unquote, urldefrag, urljoin, urlsplit
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET

SITE_URL = "https://autombd.github.io/AMBD-MC/"
REPO_URL = "https://github.com/autoMBD/AMBD-MC/"
FORBIDDEN = {".agent-env", "legacy", "superpowers", "license-header-audit",
             ".codex", ".agents"}
BINARY_SUFFIXES = {".slx", ".sldd", ".mat", ".elf", ".exe", ".dll"}


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.anchors = set()
        self.links = []
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "link" and set(attrs.get("rel", "").split()) & {"preconnect", "dns-prefetch"}:
            return
        if attrs.get("id"):
            self.anchors.add(attrs["id"])
        if tag == "a" and attrs.get("name"):
            self.anchors.add(attrs["name"])
        key = "href" if tag in {"a", "link"} else "src"
        if tag in {"a", "link", "img", "script", "source", "video", "audio"} and attrs.get(key):
            self.links.append(attrs[key])


def inspect_site(root, site_url=SITE_URL):
    """Return local publication errors and unique external URLs without fragments."""
    root = Path(root)
    files = {p.relative_to(root).as_posix(): p for p in root.rglob("*") if p.is_file()}
    pages = {name: Page(path.read_text(encoding="utf-8"))
             for name, path in files.items() if name.endswith(".html")}
    errors, external = [], set()
    base = urlsplit(site_url)
    if not base.path.endswith("/"):
        raise ValueError("site_url must end in /")

    for name in files:
        parts = set(Path(name).parts) | {Path(name).stem}
        if parts & FORBIDDEN or Path(name).suffix.lower() in BINARY_SUFFIXES:
            errors.append(f"Forbidden publication: {name}")

    def resolve(reference, origin):
        origin_url = urljoin(site_url, origin.removesuffix("index.html"))
        url = urlsplit(urljoin(origin_url, reference))
        if url.scheme in {"mailto", "tel", "data", "javascript"}:
            return None
        if url.scheme not in {"http", "https"}:
            errors.append(f"Unsupported URL: {origin} -> {reference}")
            return None
        if (url.scheme, url.netloc) != (base.scheme, base.netloc):
            external.add(urldefrag(url.geturl())[0])
            return None
        path = unquote(url.path)
        if not path.startswith(base.path):
            errors.append(f"Outside site: {origin} -> {reference}")
            return None
        relative = posixpath.normpath(path[len(base.path):])
        if relative == ".":
            relative = ""
        if path.endswith("/"):
            relative += ("/" if relative else "") + "index.html"
        # Match exact spelling even when the host filesystem is case-insensitive.
        if relative not in files:
            errors.append(f"Missing target: {origin} -> {reference}")
            return relative
        fragment = unquote(url.fragment)
        if fragment and relative in pages and fragment not in pages[relative].anchors:
            errors.append(f"Missing anchor: {origin} -> {reference}")
        return relative

    for name, page in pages.items():
        for reference in page.links:
            resolve(reference, name)

    expected = set(pages) - {"404.html"}
    if "index.html" not in expected:
        errors.append("Missing homepage: index.html")
    try:
        sitemap = ET.parse(root / "sitemap.xml")
        locations = [node.text for node in sitemap.iter() if node.tag.split("}")[-1] == "loc"]
        actual = {resolve(location, "index.html") for location in locations if location}
        if actual != expected:
            errors.append(f"Sitemap pages differ: missing={sorted(expected - actual)}, "
                          f"extra={sorted(str(x) for x in actual - expected)}")
    except (OSError, ET.ParseError) as exc:
        errors.append(f"Invalid sitemap: {exc}")
    try:
        data = json.loads((root / "search/search_index.json").read_text(encoding="utf-8"))
        search_pages = set()
        for entry in data["docs"]:
            location = entry["location"]
            target = resolve(location, "index.html")
            if "#" not in location:
                search_pages.add(target)
        if search_pages != expected:
            errors.append(f"Search pages differ: missing={sorted(expected - search_pages)}, "
                          f"extra={sorted(str(x) for x in search_pages - expected)}")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        errors.append(f"Invalid search index: {exc}")
    return errors, external


def is_exception(url, status, rules):
    rule = rules.get(url, {})
    return bool(rule.get("reason")) and status in rule.get("statuses", [])


def check_external(url, rules, repository):
    """Validate current-repository source links locally, others by HTTP GET."""
    for kind in ("blob", "tree"):
        prefix = REPO_URL + kind + "/main/"
        if url.startswith(prefix):
            relative = unquote(urlsplit(url).path.split(f"/{kind}/main/", 1)[1])
            target = (repository / relative).resolve()
            if not target.is_relative_to(repository.resolve()) or not target.exists():
                return f"FAIL repository target: {url}", False
            if (kind == "blob" and not target.is_file()) or (kind == "tree" and not target.is_dir()):
                return f"FAIL repository target kind: {url}", False
            return f"OK repository target: {url}", True
    failure = ""
    status = None
    for _ in range(2):
        try:
            request = Request(url, headers={"User-Agent": "AMBD-MC-docs-link-check/1.0"})
            with urlopen(request, timeout=20) as response:
                status = response.status
                if 200 <= status < 400:
                    return f"OK HTTP {status}: {url}", True
                failure = f"HTTP {status}"
        except HTTPError as exc:
            status, failure = exc.code, f"HTTP {exc.code}"
            exc.close()
        except (URLError, TimeoutError, OSError) as exc:
            status, failure = None, str(exc)
    if is_exception(url, status, rules):
        return f"EXCEPTION {failure}: {url} ({rules[url]['reason']})", True
    return f"FAIL {failure}: {url}", False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("site", type=Path)
    parser.add_argument("--site-url", default=SITE_URL)
    parser.add_argument("--external", action="store_true")
    parser.add_argument("--exceptions", type=Path, default=Path(__file__).with_name("link-exceptions.json"))
    args = parser.parse_args()
    errors, links = inspect_site(args.site, args.site_url)
    for error in errors:
        print(error)
    if errors:
        print(f"FAIL: {len(errors)} local publication errors")
        return 1
    count = len(list(args.site.rglob("*.html"))) - 1
    print(f"PASS: local links, anchors, search, sitemap and publication boundaries ({count} pages)")
    if args.external:
        rules = json.loads(args.exceptions.read_text(encoding="utf-8"))
        for url, rule in rules.items():
            if (not url.startswith(("https://", "http://")) or "*" in url
                    or not rule.get("reason") or not rule.get("statuses")
                    or not all(isinstance(s, int) and 400 <= s <= 599 for s in rule["statuses"])):
                raise ValueError(f"Invalid exact-URL exception: {url}")
        repository = Path(__file__).resolve().parents[2]
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda url: check_external(url, rules, repository), sorted(links)))
        for message, _ in results:
            print(message)
        failures = sum(not passed for _, passed in results)
        print(f"External/source checks: {len(results)}, failures: {failures}")
        return int(failures > 0)
    return 0


if __name__ == "__main__":
    sys.exit(main())
