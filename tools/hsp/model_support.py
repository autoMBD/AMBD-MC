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
# File:        model_support.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-07
# Version:     0.1.0
# Description: Author linked controller libraries and HSP target models.
# =================================================================================

"""Author HSP components with shared library algorithms via official model_edit."""
from pathlib import Path
import json
import uuid

ROOT = Path(__file__).resolve().parents[2]


def quote(value):
    return "'" + str(value).replace("\\", "/").replace("'", "''") + "'"


class HspBuilderMixin:
    """Reuse each family's algorithm authoring inside a library subsystem."""
    family = ""
    library_name = ""

    def __init__(self, call, output_directory=None):
        super().__init__(call, output_directory)
        self.library_scopes = {}

    def matlab(self, code):
        marker = "AMBD_OK_" + uuid.uuid4().hex
        text = self.call("evaluate_matlab_code", code=code + f";disp('{marker}');")
        if marker not in text.splitlines():
            raise RuntimeError(text)
        return text

    def read(self, model, scope="root"):
        return super().read(model, self.library_scopes.get(model, scope) if scope == "root" else scope)

    def check(self, model, scope="root"):
        return super().check(model, self.library_scopes.get(model, scope) if scope == "root" else scope)

    def edit(self, model, ops, scope="root", layout="full"):
        return super().edit(model, ops,
                            self.library_scopes.get(model, scope) if scope == "root" else scope,
                            layout)

    def fresh(self, name, directory):
        if name != self.library_name:
            return super().fresh(name, directory)
        self.matlab(f"if bdIsLoaded('{name}'),assert(~strcmp(get_param('{name}','Dirty'),'on'),"
                    f"'ambd:DirtyModel','Save dirty model {name} first.');bdclose('{name}');end;"
                    f"new_system('{name}','Library');open_system('{name}');")
        super().read(name)
        ids = super().edit(name, [dict(op="add_block", type="SubSystem",
                                     name="Controller", ref="Controller")])
        self.library_scopes[name] = ids["Controller"]
        return ROOT / "mc-models" / self.family / "algo" / (name + ".slx")

    def finish(self, name, path, compile_model=True):
        if name in self.library_scopes:
            self.read(name)
            self.check(name)
            self.matlab(f"save_system('{name}',{quote(path)});")
            self.add_notice(name, path.name, "Shared typed motor controller algorithm library.")
            return
        super().finish(name, path, compile_model)
        self.add_notice(name, path.name, "Motor control model for autoMBD HSP.")

    def add_notice(self, name, filename, description):
        text = (ROOT / "tools/license-header-template.txt").read_text(encoding="utf-8")
        text = text.replace("{{YEAR}}", "2026").replace("{{COPYRIGHT_HOLDER}}", "autoMBD")
        text += ("Project:     autoMBD Motor Control <https://github.com/autoMBD/AMBD-MC>\n"
                 f"File:        {filename}\n"
                 "Author:      autoMBD <tkung.lqk@foxmail.com>\n"
                 "Date:        2026-10-07\nVersion:     0.1.0\n"
                 f"Description: {description}\n" + "=" * 81)
        notice = self.artifacts / (name + "-notice.txt")
        notice.write_text(text, encoding="utf-8")
        self.matlab(f"note=Simulink.Annotation('{name}',fileread({quote(notice)}));"
                    "note.Interpreter='off';note.FontName='Consolas';note.FontSize=9;"
                    "note.Position=[-700 -800];"
                    f"save_system('{name}');")

    def wrapper(self, name, directory, reference=None, compile_model=True):
        """Application components link the library; replay harnesses reference models."""
        if reference is not None:
            return super().wrapper(name, directory, reference, compile_model)
        path = self.fresh(name, directory)
        ports = self.interface_module()
        ops = self.ports(ports.INPUTS, ports.OUTPUTS)
        ops.append(dict(op="add_block", type="Controller", name="Controller", ref="Controller",
                        ReferenceBlock=self.library_name + "/Controller"))
        ids = self.edit(name, ops)
        connections = [dict(op="connect", target=f"{ids[item[0]]}.y1 -> {ids['Controller']}.u{i}")
                       for i, item in enumerate(ports.INPUTS, 1)]
        connections += [dict(op="connect", target=f"{ids['Controller']}.y{i} -> {ids[item[0]]}.u1")
                        for i, item in enumerate(ports.OUTPUTS, 1)]
        self.edit(name, connections)
        self.finish(name, path, compile_model)
        self.mapping[name] = ids

    def configure_hsp(self, name):
        text = self.read(name)
        if "hsp_driver_lib/HSP Config" not in text:
            self.edit(name, [dict(op="add_block", type="HSP Config", name="HSP Config", ref="hsp",
                                  ReferenceBlock="hsp_driver_lib/HSP Config")], layout="incremental")
        self.matlab(f"cfg=ambd.hsp_defaults('{name}');autombd.hsp.config.write('{name}',cfg);"
                    f"autombd.hsp.config.apply('{name}');save_system('{name}');")
        self.edit(name, [dict(op="configure", target="config:" + name,
                             params=dict(SupportVariableSizeSignals="off"))], layout="incremental")
        self.read(name)
        self.check(name)
        self.matlab(f"save_system('{name}');")

    def add_output_adapter(self, name):
        """Qualify outputs, write each phase or idle it, then latch synchronously."""
        self.read(name)
        controller = self.matlab(
            f"blocks=find_system('{name}','SearchDepth',1,'Name','Controller');"
            "assert(isscalar(blocks));[~,controllerSid]=strtok(Simulink.ID.getSID(blocks{1}),':');"
            "fprintf('CONTROLLER_ID blk_%s\\n',controllerSid(2:end));")
        controller_id = next(line.split()[1] for line in controller.splitlines()
                             if line.startswith("CONTROLLER_ID "))
        self.matlab(
            f"dd=Simulink.data.dictionary.open(get_param('{name}','DataDictionary'));"
            "section=getSection(dd,'Design Data');"
            "if ~exist(section,'AmbdOutputsArmed'),"
            "arming=Simulink.Parameter(false);arming.DataType='boolean';"
            "arming.CoderInfo.StorageClass='ExportedGlobal';"
            "arming.CoderInfo.Identifier='Ambd_OutputsArmed';"
            "addEntry(section,'AmbdOutputsArmed',arming);saveChanges(dd);end;")
        ops = [dict(op="add_block", type="MATLAB Function", name="TargetCommands", ref="commands"),
               dict(op="add_block", type="Constant", name="OutputsArmed", ref="armed",
                    params=dict(Value="AmbdOutputsArmed", OutDataTypeStr="boolean")),
               dict(op="add_block", type="Demux", name="PhaseDuties", ref="duties", params=dict(Outputs="3")),
               dict(op="add_block", type="Demux", name="PhaseEnables", ref="enables", params=dict(Outputs="3")),
               dict(op="add_block", type="DIO", name="HardwareGate", ref="gate",
                    ReferenceBlock="hsp_driver_lib/NXP/DIO",
                    params=dict(Api="Dio_WriteChannel", ChannelSymbol="DioConf_DioChannel_Hsp_GateEnable",
                                Priority="50")),
               dict(op="add_block", type="PWM", name="LatchPhases", ref="latch",
                    ReferenceBlock="hsp_driver_lib/NXP/PWM",
                    params=dict(Api="Pwm_SyncUpdate", ModuleId="0", Priority="40"))]
        if self.family == "pmsm":
            ops.append(dict(op="add_block", type="Constant", name="EnabledPhases", ref="phase",
                            params=dict(Value="true(3,1)", OutDataTypeStr="boolean")))
        for index, phase in enumerate("ABC", 1):
            ops.extend([
                dict(op="add_block", type="SubSystem", name="WritePhase" + phase, ref="write" + phase,
                     params=dict(Priority=str(index * 10))),
                dict(op="add_block", type="SubSystem", name="IdlePhase" + phase, ref="idle" + phase,
                     params=dict(Priority=str(index * 10 + 1))),
                dict(op="add_block", type="Logic", name="DisabledPhase" + phase, ref="not" + phase,
                     params=dict(Operator="NOT"))])
        ids = self.edit(name, ops, layout="incremental")
        self.script(name, ids["commands"],
                    "function [duty,enabled,gateCommand]=fcn(a,b,c,phase,gate,armed)\n%#codegen\n"
                    "[duty,enabled]=ambd.pwm_command([a;b;c],phase,gate,armed);\n"
                    "gateCommand=uint8(any(enabled));\nend")
        for phase in "ABC":
            channel = "PwmConf_PwmChannel_Hsp_Phase" + phase
            sid = ids["write" + phase]
            self.read(name, sid)
            inner = self.edit(name, [
                dict(op="add_block", type="Inport", name="Duty", ref="duty",
                     params=dict(OutDataTypeStr="uint16")),
                dict(op="add_block", type="EnablePort", name="Enable", ref="enable"),
                dict(op="add_block", type="PWM", name="SetDuty", ref="api",
                     ReferenceBlock="hsp_driver_lib/NXP/PWM",
                     params=dict(Api="Pwm_SetDutyCycle_NoUpdate", ChannelSymbol=channel)),
                dict(op="connect", target="#duty.y1 -> #api.u1")], scope=sid)
            sid = ids["idle" + phase]
            self.read(name, sid)
            self.edit(name, [
                dict(op="add_block", type="EnablePort", name="Enable", ref="enable"),
                dict(op="add_block", type="PWM", name="SetIdle", ref="api",
                     ReferenceBlock="hsp_driver_lib/NXP/PWM",
                     params=dict(Api="Pwm_SetOutputToIdle", ChannelSymbol=channel))], scope=sid)
        connections = [dict(op="connect", target=f"{controller_id}.y{i} -> {ids['commands']}.u{i}")
                       for i in range(1, 4)]
        phase_source = controller_id + ".y4" if self.family == "bldc" else ids["phase"] + ".y1"
        connections.extend([
            dict(op="connect", target=f"{phase_source} -> {ids['commands']}.u4"),
            dict(op="connect", target=f"{controller_id}.y5 -> {ids['commands']}.u5"),
            dict(op="connect", target=f"{ids['armed']}.y1 -> {ids['commands']}.u6"),
            dict(op="connect", target=f"{ids['commands']}.y1 -> {ids['duties']}.u1"),
            dict(op="connect", target=f"{ids['commands']}.y2 -> {ids['enables']}.u1"),
            dict(op="connect", target=f"{ids['commands']}.y3 -> {ids['gate']}.u1")])
        for index, phase in enumerate("ABC", 1):
            connections.extend([
                dict(op="connect", target=f"{ids['duties']}.y{index} -> {ids['write'+phase]}.u1"),
                dict(op="connect", target=f"{ids['enables']}.y{index} -> {ids['write'+phase]}.u2"),
                dict(op="connect", target=f"{ids['enables']}.y{index} -> {ids['not'+phase]}.u1"),
                dict(op="connect", target=f"{ids['not'+phase]}.y1 -> {ids['idle'+phase]}.u1")])
        self.edit(name, connections, layout="incremental")
        self.read(name)
        self.check(name)
        self.matlab(f"set_param('{name}','SimulationCommand','update');save_system('{name}');")

    def run_hsp(self):
        gate = self.matlab("disp(jsonencode(library.settingsLookup()));")
        if not ('"found":false' in gate or '"gatePass":true' in gate):
            raise RuntimeError(gate)
        self.backup()
        self.matlab(f"cd({quote(ROOT)});addpath({quote(ROOT)});"
                    f"addpath({quote(ROOT / 'mc-models/hsp')});"
                    "assert(~isempty(which('autombd.hsp.initialize')),'ambd:MissingHsp','Install autoMBD HSP 0.1.0.');"
                    "autombd.hsp.initialize;"
                    f"info={self.family}_setup;"
                    f"Simulink.fileGenControl('set','CacheFolder',{quote(self.artifacts / 'cache')},"
                    f"'CodeGenFolder',{quote(self.artifacts / 'codegen')},'createDir',true);")
        self.core(self.library_name)
        manifest = json.loads((ROOT / "mc-models/hsp/models.json").read_text(encoding="utf-8"))
        family = [m for m in manifest["models"] if m["family"] == self.family]
        # Build all linked components before applying their target settings;
        # host compile validates the algorithm graph independently of tool paths.
        for entry in family:
            if entry["role"] in ("component", "application"):
                self.wrapper(entry["name"], str(Path(entry["path"]).parent.relative_to(Path("mc-models") / self.family)))
        for entry in family:
            if entry["role"] == "harness":
                self.top(entry["name"], entry["name"].replace("_top", "_model"))
                ids = self.mapping[entry["name"]]
                self.edit(entry["name"], [dict(op="configure", target=ids["Controller"],
                                             params=dict(CodeInterface="Top model"))], layout="incremental")
                self.matlab(f"save_system('{entry['name']}');")
        for entry in family:
            if entry["role"] in ("component", "application"):
                self.configure_hsp(entry["name"])
            if entry["role"] == "application":
                self.add_output_adapter(entry["name"])
        (self.artifacts / "model-map.json").write_text(json.dumps(self.mapping, indent=2), encoding="utf-8")

    def configure_existing(self):
        """Update target configuration after inspecting the saved family models."""
        self.matlab(f"cd({quote(ROOT)});addpath({quote(ROOT)});"
                    f"addpath({quote(ROOT / 'mc-models/hsp')});autombd.hsp.initialize;"
                    f"info={self.family}_setup;")
        manifest = json.loads((ROOT / "mc-models/hsp/models.json").read_text(encoding="utf-8"))
        for entry in manifest["models"]:
            if entry["family"] != self.family or entry["role"] not in ("component", "application"):
                continue
            name = entry["name"]
            self.matlab(f"open_system({quote(ROOT / entry['path'])});")
            self.configure_hsp(name)
            if entry["role"] == "application" and "Name: TargetCommands" not in self.read(name):
                self.add_output_adapter(name)
