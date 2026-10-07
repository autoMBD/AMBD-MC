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
# File:        test_check_site.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-08
# Version:     0.1.0
# Description: Verify public documentation output with regression fixtures.
# =================================================================================

"""Regression fixtures for the public documentation artifact."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "tools/docs/check_site.py"
if SCRIPT.exists():
    spec = importlib.util.spec_from_file_location("check_site", SCRIPT)
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
else:
    checker = None


class SiteTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(checker, "Generated-site checker is not implemented")
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.url = "https://example.test/project/"
        self.write("index.html", '<a href="guide/#说明">guide</a>')
        self.write("guide/index.html", '<h1 id="说明">Guide</h1><a href="../">home</a>')
        self.write("search/search_index.json", json.dumps({"docs": [
            {"location": "", "title": "Home", "text": ""},
            {"location": "guide/", "title": "Guide", "text": ""},
            {"location": "guide/#说明", "title": "Section", "text": ""},
        ]}))
        self.write("sitemap.xml", '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
                   '<url><loc>https://example.test/project/</loc></url>'
                   '<url><loc>https://example.test/project/guide/</loc></url></urlset>')

    def write(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding="utf-8")

    def errors(self):
        return checker.inspect_site(self.root, self.url)[0]

    def test_valid_site_and_encoded_anchor(self):
        self.write("index.html", '<a href="/project/guide/#%E8%AF%B4%E6%98%8E">guide</a>')
        self.assertEqual(self.errors(), [])

    def test_preconnect_is_not_a_document_link(self):
        self.write("index.html", '<link rel="preconnect" href="https://cdn.test">')
        self.assertEqual(checker.inspect_site(self.root, self.url), ([], set()))

    def test_missing_file_and_resource_fail(self):
        self.write("index.html", '<a href="missing/">bad</a><img src="missing.png">')
        errors = self.errors()
        self.assertEqual(sum("Missing target" in error for error in errors), 2)

    def test_missing_anchor_fails(self):
        self.write("index.html", '<a href="guide/#missing">bad</a>')
        self.assertTrue(any("Missing anchor" in error for error in self.errors()))

    def test_wrong_case_fails_even_on_windows(self):
        self.write("index.html", '<a href="Guide/">bad</a>')
        self.assertTrue(any("Missing target" in error for error in self.errors()))

    def test_local_evidence_outside_site_fails(self):
        self.write("index.html", '<a href="../.agent-env/report.json">bad</a>')
        self.assertTrue(any("Outside site" in error for error in self.errors()))

    def test_excluded_page_in_artifact_fails(self):
        self.write("superpowers/plans/work/index.html", "<p>private</p>")
        self.assertTrue(any("Forbidden publication" in error for error in self.errors()))

    def test_excluded_attachment_fails(self):
        self.write("legacy/model.slx", "binary fixture")
        self.assertTrue(any("Forbidden publication" in error for error in self.errors()))

    def test_empty_sitemap_fails(self):
        self.write("sitemap.xml", "<urlset/>")
        self.assertTrue(any("Sitemap pages differ" in error for error in self.errors()))

    def test_missing_search_page_fails(self):
        self.write("search/search_index.json", '{"docs":[]}')
        self.assertTrue(any("Search pages differ" in error for error in self.errors()))

    def test_search_anchor_is_checked(self):
        self.write("search/search_index.json", json.dumps({"docs": [
            {"location": ""}, {"location": "guide/"}, {"location": "guide/#missing"}]}))
        self.assertTrue(any("Missing anchor" in error for error in self.errors()))

    def test_external_urls_deduplicate_without_fragments(self):
        self.write("index.html", '<a href="https://outside.test/doc#one">1</a>'
                   '<a href="https://outside.test/doc#two">2</a><a href="mailto:a@b.test">mail</a>')
        errors, links = checker.inspect_site(self.root, self.url)
        self.assertEqual(errors, [])
        self.assertEqual(links, {"https://outside.test/doc"})

    def test_exception_is_exact_and_status_limited(self):
        rules = {"https://outside.test/doc": {"statuses": [403], "reason": "Bot protection"}}
        self.assertTrue(checker.is_exception("https://outside.test/doc", 403, rules))
        self.assertFalse(checker.is_exception("https://outside.test/doc", 404, rules))
        self.assertFalse(checker.is_exception("https://outside.test/other", 403, rules))



class HttpTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
        import threading

        class Handler(BaseHTTPRequestHandler):
            attempts = 0

            def do_GET(self):
                if self.path == "/retry":
                    Handler.attempts += 1
                    status = 503 if Handler.attempts == 1 else 200
                else:
                    status = int(self.path.strip("/"))
                self.send_response(status)
                self.end_headers()

            def log_message(self, *args):
                pass

        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def test_http_error_fails_without_exception(self):
        message, passed = checker.check_external(self.base + "/404", {}, Path.cwd())
        self.assertFalse(passed)
        self.assertIn("HTTP 404", message)

    def test_exact_http_exception_is_reported(self):
        url = self.base + "/403"
        message, passed = checker.check_external(url, {url: {"statuses": [403], "reason": "Fixture"}}, Path.cwd())
        self.assertTrue(passed)
        self.assertTrue(message.startswith("EXCEPTION"))

    def test_transient_failure_is_retried(self):
        message, passed = checker.check_external(self.base + "/retry", {}, Path.cwd())
        self.assertTrue(passed)
        self.assertTrue(message.startswith("OK HTTP 200"))

    def test_missing_repository_source_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            message, passed = checker.check_external(checker.REPO_URL + "blob/main/missing.md", {}, Path(directory))
        self.assertFalse(passed)
        self.assertIn("FAIL repository target", message)


if __name__ == "__main__":
    unittest.main()
