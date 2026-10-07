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
# File:        test_mcp_client.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-09-11
# Version:     0.1.0
# Description: Test MCP protocol transport and process cleanup.
# =================================================================================

import importlib
import os
from pathlib import Path
import sys
import time
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools' / 'agent'))
try:
    mcp_client = importlib.import_module('mcp_client')
except ModuleNotFoundError:
    mcp_client = None

SERVER = '''import sys,json,time
for line in sys.stdin:
 msg=json.loads(line)
 if 'id' not in msg: continue
 if msg['method']=='hang': time.sleep(10); continue
 print(json.dumps({'jsonrpc':'2.0','method':'notifications/progress','params':{}}),flush=True)
 if msg['method']=='bad': result={'error':{'code':-1,'message':'tool failed'}}
 else: result={'result':{'method':msg['method'],'params':msg.get('params')}}
 print(json.dumps({'jsonrpc':'2.0','id':msg['id'],**result}),flush=True)
'''


class MCPClientTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(mcp_client, 'MCP stdio client is not implemented')

    def test_protocol_ignores_notifications_and_preserves_arguments(self):
        with mcp_client.Client([sys.executable, '-u', '-c', SERVER], timeout=3) as client:
            result = client.request('example', {'path': '含 空格/test.m'})
            self.assertEqual(result['params']['path'], '含 空格/test.m')

    def test_protocol_error_is_not_a_success(self):
        with mcp_client.Client([sys.executable, '-u', '-c', SERVER], timeout=3) as client:
            with self.assertRaisesRegex(RuntimeError, 'tool failed'):
                client.request('bad', {})

    def test_timeout_is_bounded(self):
        with mcp_client.Client([sys.executable, '-u', '-c', SERVER], timeout=0.1) as client:
            with self.assertRaises(TimeoutError):
                client.request('hang', {})

    def test_cleanup_does_not_wait_for_inherited_descendant_pipes(self):
        server = SERVER.replace('import sys,json,time', 'import sys,json,time,subprocess\nsubprocess.Popen([sys.executable,"-c","import time;time.sleep(20)"])')
        started = time.monotonic()
        with mcp_client.Client([sys.executable, '-u', '-c', server], timeout=1) as client:
            client.request('example', {})
        self.assertLess(time.monotonic() - started, 6)

    def test_serve_launcher_forwards_real_stdio(self):
        script = f'''import sys,os
sys.path.insert(0,{str(Path(__file__).resolve().parents[2] / 'tools/agent')!r})
from unittest.mock import patch
import agent_env
with patch.object(agent_env.configuration,'read_state',return_value={{'active':{{'bundle':sys.argv[1]}}}}), patch.object(agent_env.environment,'verify_bundle'), patch.object(agent_env.environment,'runtime',return_value=([sys.executable,'-u','-c',{SERVER!r}],os.environ.copy())):
 sys.exit(agent_env.main(['Serve','--repo-root',sys.argv[1]]))
'''
        with tempfile.TemporaryDirectory() as folder:
            with mcp_client.Client([sys.executable, '-u', '-c', script, folder], timeout=2) as client:
                result = client.request('example', {'path': '含 空格/test.m'})
                self.assertEqual(result['params']['path'], '含 空格/test.m')

    @unittest.skipUnless(os.name == 'nt', 'Windows creation ordering')
    def test_server_cannot_run_before_job_assignment(self):
        with tempfile.TemporaryDirectory() as folder:
            marker = Path(folder) / 'started'
            server = 'from pathlib import Path\nPath(' + repr(str(marker)) + ').touch()\n' + SERVER
            real_tree = mcp_client.OwnedTree
            def delayed_attach(process):
                time.sleep(0.2)
                self.assertFalse(marker.exists(), 'Server executed before containment was established')
                return real_tree(process)
            with patch.object(mcp_client, 'OwnedTree', side_effect=delayed_attach):
                with mcp_client.Client([sys.executable, '-u', '-c', server], timeout=3) as client:
                    client.request('example', {})
            self.assertTrue(marker.exists())


if __name__ == '__main__':
    unittest.main()
