# SPDX-License-Identifier: MIT
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
