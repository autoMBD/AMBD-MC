# SPDX-License-Identifier: MIT
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
