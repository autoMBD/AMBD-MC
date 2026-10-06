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
# File:        mcp_client.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-09-11
# Version:     0.1.0
# Description: Small sequential MCP stdio *client* for testing the official server.
# =================================================================================

"""Small sequential MCP stdio *client* for testing the official server."""
from __future__ import annotations

from collections import deque
import json
import os
import queue
import subprocess
import threading
import time

from process_tree import OwnedTree


class Client:
    def __init__(self, command, *, timeout=600, cwd=None, env=None):
        self.timeout = timeout
        self.sequence = 0
        self.messages = queue.Queue()
        self.diagnostics = deque(maxlen=20)
        child_env = (env if env is not None else os.environ).copy()
        child_env['PYTHONIOENCODING'] = 'utf-8'  # MCP stdio is UTF-8, including Python launchers on Windows.
        self.process = subprocess.Popen(
            command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, encoding='utf-8', errors='replace', bufsize=1, cwd=cwd, env=child_env,
            start_new_session=os.name != 'nt',
            creationflags=(subprocess.CREATE_NO_WINDOW | 0x4) if os.name == 'nt' else 0)  # CREATE_SUSPENDED
        try:
            self.tree = OwnedTree(self.process)
            self.tree.resume()
        except BaseException:
            if hasattr(self, 'tree'):
                self.tree.close()
            self.process.kill()
            self.process.wait(timeout=3)
            for stream in (self.process.stdin, self.process.stdout, self.process.stderr):
                stream.close()
            raise
        self.readers = [threading.Thread(target=self._read, daemon=True),
                        threading.Thread(target=self._stderr, daemon=True)]
        for reader in self.readers:
            reader.start()

    def _read(self):
        try:
            for line in self.process.stdout:
                try:
                    self.messages.put(json.loads(line))
                except json.JSONDecodeError:
                    self.messages.put(RuntimeError('MCP server emitted invalid JSON on stdout'))
        finally:
            self.messages.put(EOFError('MCP server closed stdout'))
            self.process.stdout.close()

    def _stderr(self):
        try:
            for line in self.process.stderr:
                self.diagnostics.append(line.rstrip())
        finally:
            self.process.stderr.close()

    def notify(self, method, params=None):
        self._send({'jsonrpc': '2.0', 'method': method, 'params': params or {}})

    def _send(self, message):
        self.process.stdin.write(json.dumps(message, ensure_ascii=False) + '\n')
        self.process.stdin.flush()

    def request(self, method, params=None):
        self.sequence += 1
        request_id = self.sequence
        self._send({'jsonrpc': '2.0', 'id': request_id, 'method': method, 'params': params or {}})
        deadline = time.monotonic() + self.timeout
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError(f'MCP {method} exceeded {self.timeout}s')
            try:
                message = self.messages.get(timeout=remaining)
            except queue.Empty as error:
                raise TimeoutError(f'MCP {method} exceeded {self.timeout}s') from error
            if isinstance(message, Exception):
                raise message
            if message.get('id') != request_id:
                continue  # Server notifications do not complete a request.
            if 'error' in message:
                raise RuntimeError(f"MCP {method}: {message['error'].get('message', message['error'])}")
            if 'result' not in message:
                raise RuntimeError(f'MCP {method} returned no result')
            return message['result']

    def initialize(self):
        result = self.request('initialize', {'protocolVersion': '2024-11-05',
                              'capabilities': {}, 'clientInfo': {'name': 'ambd-env-smoke', 'version': '1.0'}})
        self.notify('notifications/initialized')
        return result

    def call(self, name, arguments):
        result = self.request('tools/call', {'name': name, 'arguments': arguments})
        if result.get('isError'):
            texts = [item.get('text', '') for item in result.get('content', []) if item.get('type') == 'text']
            raise RuntimeError(f"MCP tool {name} failed: {' '.join(texts)}")
        return result

    def close(self):
        if self.process.stdin:
            try:
                self.process.stdin.close()
            except BrokenPipeError:
                pass
        try:
            self.process.wait(timeout=1)
        except subprocess.TimeoutExpired:
            pass
        finally:
            self.tree.close()
        self.process.wait(timeout=3)
        for reader in self.readers:
            reader.join(timeout=1)

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()
