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
import io
import os
from pathlib import Path
import tempfile
import subprocess
import unittest
from unittest.mock import patch

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

    def test_internal_report_and_plan_paths_are_forbidden(self):
        for name in ("validation/report/index.html", "agent-environment-validation/index.html",
                     "specs/motor-test-plan/index.html", "reports/run.json"):
            with self.subTest(name=name):
                self.write(name, "internal fixture")
                self.assertTrue(any("Forbidden publication" in error for error in self.errors()))

    def test_public_redirect_is_checked_but_not_indexed(self):
        self.write("old/index.html", '<meta http-equiv="refresh" content="0; url=../guide/">')
        self.assertEqual(self.errors(), [])

    def test_broken_redirect_fails(self):
        self.write("old/index.html", '<meta http-equiv="refresh" content="0; url=../missing/">')
        self.assertTrue(any("Missing target" in error for error in self.errors()))

    def test_private_github_history_link_is_rejected(self):
        self.write("index.html", '<a href="https://github.com/autoMBD/AMBD-MC/blob/af47a41/docs/validation/report.md">private</a>')
        self.assertTrue(any("Internal document link" in error for error in self.errors()))

    def test_exception_is_exact_and_status_limited(self):
        rules = {"https://outside.test/doc": {"statuses": [403], "reason": "Bot protection"}}
        self.assertTrue(checker.is_exception("https://outside.test/doc", 403, rules))
        self.assertFalse(checker.is_exception("https://outside.test/doc", 404, rules))
        self.assertFalse(checker.is_exception("https://outside.test/other", 403, rules))



class RepositoryPolicyTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(callable(getattr(checker, "check_tracked_documents", None)),
                        "Git-tracked document boundary check is not implemented")
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        subprocess.run(["git", "init", "--quiet", str(self.root)], check=True)

    def track(self, name):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("fixture", encoding="utf-8")
        subprocess.run(["git", "-C", str(self.root), "add", "-f", "--", name], check=True)

    def test_public_guides_and_generator_sources_are_allowed(self):
        for name in ("docs/index.md", "docs/McStruct.md", "docs/BldcStruct.md",
                     "docs/manual/verification.md", "docs/hardware/environment.example.json",
                     "docs/specs/algorithms/motor/system.md"):
            self.track(name)
        self.assertEqual(checker.check_tracked_documents(self.root), [])

    def test_force_added_internal_documents_are_rejected(self):
        names = ("docs/validation/run.json", "docs/superpowers/plans/task.md",
                 "docs/agent-environment-validation.md", "docs/license-header-audit.md",
                 "docs/specs/motor-implementation-plan.md", "docs/specs/motor-test-plan.md",
                 "docs/project/2026-10-08-results.md", ".agent-env/reports/run.json")
        for name in names:
            self.track(name)
        errors = checker.check_tracked_documents(self.root)
        for name in names:
            self.assertTrue(any(name in error for error in errors), name)

    def test_internal_documents_outside_docs_are_rejected(self):
        names = ("plans/task-implementation-plan.md", "reports/run-acceptance.md",
                 "audit-report.md", "task-plan.md", "DOCS/Validation/run.json")
        for name in names:
            self.track(name)
        errors = checker.check_tracked_documents(self.root)
        for name in names:
            self.assertTrue(any(name in error for error in errors), name)

    def test_protected_historical_and_third_party_trees_are_not_reclassified(self):
        for name in ("legacy/reports/old.md", ".agents/skills/vendor/plans/template.md",
                     "mc-models/hsp/config/S32K344/reports/vendor.json"):
            self.track(name)
        self.assertEqual(checker.check_tracked_documents(self.root), [])

    def test_internal_file_still_in_index_is_rejected_after_local_delete(self):
        self.track("docs/validation/run.md")
        (self.root / "docs/validation/run.md").unlink()
        self.assertTrue(checker.check_tracked_documents(self.root))

    def test_new_loose_root_page_is_rejected(self):
        self.track("docs/new-topic.md")
        self.assertTrue(checker.check_tracked_documents(self.root))


class GitHubHistoryTests(unittest.TestCase):
    @staticmethod
    def response(payload):
        def open_response(*args, **kwargs):
            response = io.BytesIO(json.dumps(payload).encode('utf-8'))
            response.status = 200
            return response
        return open_response

    def test_history_link_uses_commit_api_and_scoped_authentication(self):
        with patch.dict(os.environ, {'GITHUB_TOKEN': 'fixture-token'}), \
                patch.object(checker, 'urlopen', side_effect=self.response({'sha': 'a' * 40})) as opened:
            _, passed = checker.check_external(checker.REPO_URL + 'commits/main/', {}, Path.cwd())
        self.assertTrue(passed)
        request = opened.call_args.args[0]
        self.assertEqual(request.full_url, 'https://api.github.com/repos/autoMBD/AMBD-MC/commits/main')
        self.assertEqual(request.get_header('Authorization'), 'Bearer fixture-token')

    def test_success_status_without_commit_identity_is_rejected(self):
        with patch.object(checker, 'urlopen', side_effect=self.response({'message': 'not a commit'})):
            _, passed = checker.check_external(checker.REPO_URL + 'commits/main/', {}, Path.cwd())
        self.assertFalse(passed)

    def test_token_is_not_sent_to_other_links(self):
        with patch.dict(os.environ, {'GITHUB_TOKEN': 'fixture-token'}), \
                patch.object(checker, 'urlopen', side_effect=self.response({})) as opened:
            _, passed = checker.check_external('https://outside.test/page', {}, Path.cwd())
        self.assertTrue(passed)
        self.assertIsNone(opened.call_args.args[0].get_header('Authorization'))

    def test_missing_commit_is_rejected(self):
        from urllib.error import HTTPError
        with patch.object(checker, 'urlopen', side_effect=lambda *args, **kwargs:
                          (_ for _ in ()).throw(HTTPError(args[0].full_url, 404, 'missing', {}, None))):
            message, passed = checker.check_external(checker.REPO_URL + 'commits/main/', {}, Path.cwd())
        self.assertFalse(passed)
        self.assertIn('HTTP 404', message)


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
