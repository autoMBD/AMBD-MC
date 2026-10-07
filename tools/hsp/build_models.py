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
# File:        build_models.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-07
# Version:     0.1.0
# Description: Rebuild shared algorithms and S32K344 components through official MCP.
# =================================================================================

"""Rebuild BLDC/PMSM libraries and HSP components using the pinned MCP server."""
from pathlib import Path
import argparse
import importlib.util
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/hsp"))
from model_support import HspBuilderMixin


def load_builder(family):
    spec = importlib.util.spec_from_file_location("ambd_" + family, ROOT / "tools" / family / "build_models.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def build(call, family, output, configure_only=False, models=None):
    module = load_builder(family)
    class Builder(HspBuilderMixin, module.Builder):
        def interface_module(self):
            return module
    Builder.family = family
    Builder.library_name = "BldcControllerLibrary" if family == "bldc" else "McControllerLibrary"
    builder = Builder(call, output)
    builder.selected_models=models
    if configure_only:
        builder.configure_existing()
    else:
        builder.run_hsp()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--family", choices=("bldc", "pmsm"), action="append")
    parser.add_argument("--configure-only", action="store_true", help="Inspect and configure existing saved models.")
    parser.add_argument("--model",action="append",help="Select a target model for configuration-only edits.")
    args = parser.parse_args()
    if args.model:
        known={entry['name'] for entry in json.loads((ROOT/'mc-models/hsp/models.json').read_text())['models']
               if entry['role'] in ('component','application') and entry['family'] in (args.family or ['bldc','pmsm'])}
        if not args.configure_only or not set(args.model)<=known:
            parser.error('--model requires --configure-only and target models in the selected families.')
    sys.path.insert(0, str(ROOT / "tools/agent"))
    import configuration
    import environment
    from mcp_client import Client
    command, env = environment.runtime(configuration.read_state(ROOT)["active"], session="new")
    with Client(command, cwd=ROOT, env=env, timeout=1200) as client:
        client.initialize()
        for family in args.family or ("bldc", "pmsm"):
            build(client.call, family, ROOT / ".agent-env/hsp-authoring" / family, args.configure_only,args.model)


if __name__ == "__main__":
    main()
