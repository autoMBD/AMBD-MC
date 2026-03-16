% =================================================================================
% The MIT License 
% MIT许可证
% 
% <https://opensource.org/license/mit>
% 
% SPDX short identifier / SPDX 短标识符：MIT 
% 
% Copyright (c) 2026 autoMBD
% 版权所有 (c) 2026 autoMBD
%
% Permission is hereby granted, free of charge, to any person obtaining a 
% copy of this software and associated documentation files (the “Software”), 
% to deal in the Software without restriction, including without limitation 
% the rights to use, copy, modify, merge, publish, distribute, sublicense, 
% and/or sell copies of the Software, and to permit persons to whom the 
% Software is furnished to do so, subject to the following conditions:
% 特此向获得本软件及相关文档（合称“本软件”）副本的任何人免费授予不受限制地利用本软
% 件的许可，包括而不限于：使用、复制、修改、合并、发布、分发、分许可和/或销售本软
% 件副本，并允许本软件的接收者也获得前述许可，但须遵守以下条件：
% 
% The above copyright notice and this permission notice shall be included 
% in all copies or substantial portions of the Software.
% 以上版权声明及本许可声明应包含在本软件的所有副本或主要部分中。
% 
% THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, 
% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
% MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
% NONINFRINGEMENT. IN NO EVENT SHALLTHE AUTHORS OR COPYRIGHT 
% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER 
% IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
% CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
% SOFTWARE.
% 本软件系“按原样”提供，不包含任何形式的明示或默示保证，包括但不限于适销性、特定
% 目的适用性及不侵权的保证。在任何情况下，无论是在合同、侵权或其他案件中，作者或版
% 权持有人均不对因本软件、或因本软件的使用或其他利用而引起的、引发的或与之相关的任
% 何权利主张、损害赔偿或其他责任承担责任。
% =================================================================================
% Project:     autoMBD Motor Control <https://github.com/autoMBD/AMBD-MC>
% File:        generate_data_type_from_md.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-03-17
% Version:     0.1.0
% Description: Parse docs/McStruct.md and generate layered Simulink data type
%              definitions (NumericType, AliasType, ValueType, Enum, Bus).
% =================================================================================

function generate_data_type_from_md(md_file, output_dir)
repo_root = fileparts(fileparts(mfilename("fullpath")));

if nargin < 1 || strlength(string(md_file)) == 0
    md_file = fullfile(repo_root, "docs", "McStruct.md");
end
if nargin < 2 || strlength(string(output_dir)) == 0
    output_dir = fullfile(repo_root, "mc-models", "pmsm", "data");
end

md_file = char(md_file);
output_dir = char(output_dir);

if ~isfile(md_file)
    error("Markdown file not found: %s", md_file);
end
if ~exist(output_dir, "dir")
    mkdir(output_dir);
end

text = fileread(md_file);
numeric_defs = parseMarkedTable(text, "NUMERIC", ...
    ["Name", "Signed", "WordLength", "FractionLength", "Slope", "Bias", "Description"]);
alias_defs = parseMarkedTable(text, "ALIAS", ...
    ["Name", "BaseType", "HeaderFile", "Description"]);
value_defs = parseMarkedTable(text, "VALUE", ...
    ["Name", "DataType", "Unit", "Min", "Max", "Description"]);

enum_defs = parseEnumBlocks(text);
bus_defs = [parseStandardBusBlocks(text), parseGenericBusBlocks(text)];
bus_defs = sortBusDefinitions(bus_defs);

output_file = fullfile(output_dir, "mc_data_types.m");
writeGeneratedScript(output_file, md_file, numeric_defs, alias_defs, value_defs, enum_defs, bus_defs);
fprintf("Generated layered data type script:\n  %s\n", output_file);
end

function rows = parseMarkedTable(text, marker, headers)
start_token = sprintf("<!-- MC_TYPE_TABLE:%s -->", marker);
start_idx = strfind(text, start_token);
if isempty(start_idx)
    error("Missing marker %s in markdown.", start_token);
end
rows = struct([]);
expected_headers = strip(string(headers));
for block_i = 1:numel(start_idx)
    tail_text = extractAfter(text, start_idx(block_i) + strlength(start_token) - 1);
    lines = splitlines(string(tail_text));
    table_lines = strings(0, 1);
    table_started = false;
    for i = 1:numel(lines)
        line = strip(lines(i));
        if startsWith(line, "|")
            table_lines(end + 1, 1) = line; %#ok<AGROW>
            table_started = true;
        elseif table_started
            break;
        end
    end
    if numel(table_lines) < 3
        error("Marker %s does not contain a valid markdown table.", marker);
    end
    actual_headers = strip(splitMarkdownRow(table_lines(1)));
    if numel(actual_headers) ~= numel(expected_headers)
        warning("Header width mismatch for marker %s. Continue with positional parsing.", marker);
    end
    for row_i = 3:numel(table_lines)
        values = splitMarkdownRow(table_lines(row_i));
        if numel(values) ~= numel(headers)
            continue;
        end
        row = struct();
        for j = 1:numel(headers)
            row.(headers(j)) = char(values(j));
        end
        rows = appendStruct(rows, row);
    end
end
end

function enum_defs = parseEnumBlocks(text)
blocks = parseLevel3Blocks(text);
enum_defs = struct([]);
for i = 1:numel(blocks)
    if ~startsWith(blocks(i).Title, "e")
        continue;
    end
    lines = blocks(i).Lines;
    table_idx = find(contains(lines, "| 枚举值 | 数值 | 说明 |"), 1, "first");
    if isempty(table_idx)
        continue;
    end
    desc_lines = collectDescriptionLines(lines, table_idx - 1);
    table_lines = collectTableLines(lines, table_idx);
    members = struct([]);
    for k = 3:numel(table_lines)
        cols = splitMarkdownRow(table_lines(k));
        if numel(cols) ~= 3
            continue;
        end
        member = struct();
        member.Name = char(cols(1));
        member.Value = str2double(cols(2));
        member.Description = char(cols(3));
        members = appendStruct(members, member);
    end
    block_text = strjoin(cellstr(lines), newline);
    enum_def = struct();
    enum_def.Name = blocks(i).Title;
    enum_def.Description = char(strjoin(desc_lines, " "));
    enum_def.StorageType = extractBacktickValue(block_text, "存储类型");
    enum_def.DefaultValue = extractBacktickValue(block_text, "默认值");
    enum_def.Members = members;
    enum_defs = appendStruct(enum_defs, enum_def);
end
end

function bus_defs = parseStandardBusBlocks(text)
blocks = parseLevel3Blocks(text);
bus_defs = struct([]);
for i = 1:numel(blocks)
    if ~startsWith(blocks(i).Title, "t")
        continue;
    end
    lines = blocks(i).Lines;
    table_idx = find(contains(lines, "| 字段 | 类型 | 说明 |"), 1, "first");
    if isempty(table_idx)
        continue;
    end
    desc_lines = collectDescriptionLines(lines, table_idx - 1);
    table_lines = collectTableLines(lines, table_idx);
    fields = struct([]);
    for k = 3:numel(table_lines)
        cols = splitMarkdownRow(table_lines(k));
        if numel(cols) ~= 3
            continue;
        end
        field = struct();
        field.Name = char(cols(1));
        field.RawType = char(cols(2));
        field.Description = char(cols(3));
        fields = appendStruct(fields, field);
    end
    bus_def = struct();
    bus_def.Name = blocks(i).Title;
    bus_def.Description = char(strjoin(desc_lines, " "));
    bus_def.Fields = fields;
    bus_defs = appendStruct(bus_defs, bus_def);
end
end

function bus_defs = parseGenericBusBlocks(text)
section_text = extractSectionByTitles(text, "通用数据容器（Generic Data）", "枚举类型（Enum）");
lines = splitlines(string(section_text));
bus_defs = struct([]);
current_base_type = "";
for i = 1:numel(lines)
    line = strip(lines(i));
    if startsWith(line, "### uint16")
        current_base_type = "uint16";
        continue;
    end
    if startsWith(line, "### single")
        current_base_type = "single";
        continue;
    end
    if line ~= "| 结构体 | 字段数 | 字段名 | 说明 |" && line ~= "| 结构体 | 字段数 | 字段名 | 成员类型 | 说明 |"
        continue;
    end
    table_lines = collectTableLines(lines, i);
    for k = 3:numel(table_lines)
        cols = splitMarkdownRow(table_lines(k));
        if numel(cols) ~= 4 && numel(cols) ~= 5
            continue;
        end
        if numel(cols) == 5
            member_type = cols(4);
            description = cols(5);
        else
            member_type = current_base_type;
            description = cols(4);
        end
        field_count = str2double(cols(2));
        fields = struct([]);
        for n = 1:field_count
            field = struct();
            field.Name = sprintf("D%d", n);
            field.RawType = char(member_type);
            field.Description = sprintf("%s member %d", cols(1), n);
            fields = appendStruct(fields, field);
        end
        bus_def = struct();
        bus_def.Name = char(cols(1));
        bus_def.Description = char(description);
        bus_def.Fields = fields;
        bus_defs = appendStruct(bus_defs, bus_def);
    end
end
end

function sorted_defs = sortBusDefinitions(bus_defs)
if isempty(bus_defs)
    sorted_defs = bus_defs;
    return;
end
names = string({bus_defs.Name});
visited = false(1, numel(bus_defs));
visiting = false(1, numel(bus_defs));
order = zeros(1, numel(bus_defs));
order_idx = 0;
for i = 1:numel(bus_defs)
    visitNode(i);
end
sorted_defs = bus_defs(order);
    function visitNode(idx)
        if visited(idx), return; end
        if visiting(idx), error("Circular bus dependency detected at %s.", bus_defs(idx).Name); end
        visiting(idx) = true;
        dep_list = localDependencies(bus_defs(idx));
        for dep_i = 1:numel(dep_list)
            dep = dep_list(dep_i);
            dep_idx = find(names == dep, 1, "first");
            if ~isempty(dep_idx), visitNode(dep_idx); end
        end
        visiting(idx) = false;
        visited(idx) = true;
        order_idx = order_idx + 1;
        order(order_idx) = idx;
    end
end

function deps = localDependencies(bus_def)
deps = strings(0, 1);
for i = 1:numel(bus_def.Fields)
    raw_type = string(bus_def.Fields(i).RawType);
    if startsWith(raw_type, "t")
        deps(end + 1, 1) = raw_type; %#ok<AGROW>
    end
end
deps = unique(deps);
end

function writeGeneratedScript(output_file, md_file, numeric_defs, alias_defs, value_defs, enum_defs, bus_defs)
fid = fopen(output_file, "w");
if fid == -1
    error("Cannot open output file: %s", output_file);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
md_display = headerDisplayPath(md_file);
fprintf(fid, "%% =================================================================================\n");
fprintf(fid, "%% The MIT License \n");
fprintf(fid, "%% MIT许可证\n");
fprintf(fid, "%% \n");
fprintf(fid, "%% <https://opensource.org/license/mit>\n");
fprintf(fid, "%% \n");
fprintf(fid, "%% SPDX short identifier / SPDX 短标识符：MIT \n");
fprintf(fid, "%% \n");
fprintf(fid, "%% Copyright (c) 2026 autoMBD\n");
fprintf(fid, "%% 版权所有 (c) 2026 autoMBD\n");
fprintf(fid, "%%\n");
fprintf(fid, "%% Permission is hereby granted, free of charge, to any person obtaining a \n");
fprintf(fid, "%% copy of this software and associated documentation files (the “Software”), \n");
fprintf(fid, "%% to deal in the Software without restriction, including without limitation \n");
fprintf(fid, "%% the rights to use, copy, modify, merge, publish, distribute, sublicense, \n");
fprintf(fid, "%% and/or sell copies of the Software, and to permit persons to whom the \n");
fprintf(fid, "%% Software is furnished to do so, subject to the following conditions:\n");
fprintf(fid, "%% 特此向获得本软件及相关文档（合称“本软件”）副本的任何人免费授予不受限制地利用本软\n");
fprintf(fid, "%% 件的许可，包括而不限于：使用、复制、修改、合并、发布、分发、分许可和/或销售本软\n");
fprintf(fid, "%% 件副本，并允许本软件的接收者也获得前述许可，但须遵守以下条件：\n");
fprintf(fid, "%% \n");
fprintf(fid, "%% The above copyright notice and this permission notice shall be included \n");
fprintf(fid, "%% in all copies or substantial portions of the Software.\n");
fprintf(fid, "%% 以上版权声明及本许可声明应包含在本软件的所有副本或主要部分中。\n");
fprintf(fid, "%% \n");
fprintf(fid, "%% THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, \n");
fprintf(fid, "%% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF \n");
fprintf(fid, "%% MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND \n");
fprintf(fid, "%% NONINFRINGEMENT. IN NO EVENT SHALLTHE AUTHORS OR COPYRIGHT \n");
fprintf(fid, "%% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER \n");
fprintf(fid, "%% IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN \n");
fprintf(fid, "%% CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \n");
fprintf(fid, "%% SOFTWARE.\n");
fprintf(fid, "%% 本软件系“按原样”提供，不包含任何形式的明示或默示保证，包括但不限于适销性、特定\n");
fprintf(fid, "%% 目的适用性及不侵权的保证。在任何情况下，无论是在合同、侵权或其他案件中，作者或版\n");
fprintf(fid, "%% 权持有人均不对因本软件、或因本软件的使用或其他利用而引起的、引发的或与之相关的任\n");
fprintf(fid, "%% 何权利主张、损害赔偿或其他责任承担责任。\n");
fprintf(fid, "%% =================================================================================\n");
fprintf(fid, "%% Project:     autoMBD Motor Control <https://github.com/autoMBD/AMBD-MC>\n");
fprintf(fid, "%% File:        mc_data_types.m\n");
fprintf(fid, "%% Author:      autoMBD <tkung.lqk@foxmail.com>\n");
fprintf(fid, "%% Date:        %s\n", datestr(now, "yyyy-mm-dd"));
fprintf(fid, "%% Version:     0.1.0\n");
fprintf(fid, "%% Description: Layered Simulink data type definitions generated from\n");
fprintf(fid, "%%              %s.\n", escapeText(md_display));
fprintf(fid, "%% =================================================================================\n\n");

for i = 1:numel(numeric_defs)
    row = numeric_defs(i);
    fprintf(fid, "%s = createNumericType(%s, %s, %s, %s, %s, '%s');\n", ...
        row.Name, lower(row.Signed), row.WordLength, row.FractionLength, row.Slope, row.Bias, escapeText(row.Description));
end
fprintf(fid, "\n");
for i = 1:numel(alias_defs)
    row = alias_defs(i);
    fprintf(fid, "%s = createAliasType('%s', '%s', '%s');\n", ...
        row.Name, escapeText(row.BaseType), escapeText(row.HeaderFile), escapeText(row.Description));
end
fprintf(fid, "\n");
for i = 1:numel(value_defs)
    row = value_defs(i);
    fprintf(fid, "%s = createValueType('%s', '%s', %s, %s, '%s');\n", ...
        row.Name, escapeText(row.DataType), escapeText(row.Unit), scalarLiteral(row.Min), scalarLiteral(row.Max), escapeText(row.Description));
end
fprintf(fid, "\n");

for i = 1:numel(enum_defs)
    enum_def = enum_defs(i);
    fprintf(fid, "%s = Simulink.data.dictionary.EnumTypeDefinition;\n", enum_def.Name);
    fprintf(fid, "removeEnumeral(%s, 1);\n", enum_def.Name);
    for k = 1:numel(enum_def.Members)
        m = enum_def.Members(k);
        fprintf(fid, "appendEnumeral(%s, '%s', %d, '%s');\n", enum_def.Name, escapeText(m.Name), m.Value, escapeText(m.Description));
    end
    if ~isempty(enum_def.DefaultValue)
        fprintf(fid, "%s.DefaultValue = '%s';\n", enum_def.Name, escapeText(enum_def.DefaultValue));
    end
    if ~isempty(enum_def.StorageType)
        fprintf(fid, "%s.StorageType = '%s';\n", enum_def.Name, escapeText(enum_def.StorageType));
    end
    fprintf(fid, "\n");
end

enum_names = string({enum_defs.Name});
bus_names = string({bus_defs.Name});
for i = 1:numel(bus_defs)
    bus_def = bus_defs(i);
    fprintf(fid, "%s = createBusType('%s', {\n", bus_def.Name, escapeText(bus_def.Description));
    for k = 1:numel(bus_def.Fields)
        field = bus_def.Fields(k);
        [data_type, dimensions] = resolveBusFieldType(bus_def.Name, field.Name, field.RawType, enum_names, bus_names);
        fprintf(fid, "    '%s', '%s', %s, '%s';\n", escapeText(field.Name), escapeText(data_type), dimensionLiteral(dimensions), escapeText(field.Description));
    end
    fprintf(fid, "});\n\n");
end

fprintf(fid, "function numeric_type = createNumericType(signed_flag, word_length, fraction_length, slope, bias, description)\n");
fprintf(fid, "numeric_type = Simulink.NumericType; numeric_type.DataTypeMode = 'Fixed-point: binary point scaling';\n");
fprintf(fid, "numeric_type.SignednessBool = logical(signed_flag); numeric_type.WordLength = word_length; numeric_type.FractionLength = fraction_length;\n");
fprintf(fid, "numeric_type.Slope = slope; numeric_type.Bias = bias; numeric_type.Description = description;\nend\n\n");

fprintf(fid, "function alias_type = createAliasType(base_type, header_file, description)\n");
fprintf(fid, "alias_type = Simulink.AliasType; alias_type.BaseType = base_type;\n");
fprintf(fid, "if ~isempty(header_file), alias_type.HeaderFile = header_file; end; alias_type.Description = description;\nend\n\n");

fprintf(fid, "function value_type = createValueType(data_type, unit, min_value, max_value, description)\n");
fprintf(fid, "value_type = Simulink.ValueType; value_type.DataType = data_type;\n");
fprintf(fid, "if ~isempty(unit), value_type.Unit = unit; end; if ~isempty(min_value), value_type.Min = min_value; end; if ~isempty(max_value), value_type.Max = max_value; end;\n");
fprintf(fid, "value_type.Description = description;\nend\n\n");

fprintf(fid, "function bus_type = createBusType(description, field_defs)\n");
fprintf(fid, "elems = repmat(Simulink.BusElement, size(field_defs, 1), 1);\n");
fprintf(fid, "for idx = 1:size(field_defs, 1), elems(idx).Name = field_defs{idx,1}; elems(idx).DataType = field_defs{idx,2}; elems(idx).Dimensions = field_defs{idx,3}; elems(idx).Description = field_defs{idx,4}; end\n");
fprintf(fid, "bus_type = Simulink.Bus; bus_type.DataScope = 'Auto'; bus_type.Description = description; bus_type.Elements = elems;\nend\n");
end

function display_path = headerDisplayPath(file_path)
repo_root = string(fileparts(fileparts(mfilename("fullpath"))));
file_path = string(file_path);
prefix = repo_root + filesep;
if startsWith(file_path, prefix, "IgnoreCase", ispc)
    display_path = extractAfter(file_path, strlength(prefix));
else
    display_path = file_path;
end
display_path = replace(display_path, "\", "/");
display_path = char(display_path);
end

function [data_type, dimensions] = resolveBusFieldType(bus_name, field_name, raw_type, enum_names, bus_names)
dimensions = 1;
raw_type = char(string(raw_type));
array_tokens = regexp(raw_type, '^(?<base>\w+)\[(?<dim>\d+)\]$', 'names', 'once');
if ~isempty(array_tokens)
    [data_type, ~] = resolveBusFieldType(bus_name, field_name, array_tokens.base, enum_names, bus_names);
    dimensions = str2double(array_tokens.dim);
    return;
end
if any(enum_names == string(raw_type)), data_type = char("Enum: " + string(raw_type)); return; end
if any(bus_names == string(raw_type)), data_type = char("Bus: " + string(raw_type)); return; end
semantic_type = resolveSemanticFieldType(bus_name, field_name);
if semantic_type ~= "", data_type = char(semantic_type); return; end
switch raw_type
    case "boolean", data_type = "McBool_T";
    case "uint8", data_type = "McUInt8_T";
    case "int8", data_type = "McInt8_T";
    case "uint16", data_type = "McUInt16_T";
    case "uint32", data_type = "McUInt32_T";
    case "single", data_type = "McSingle_T";
    otherwise, data_type = raw_type;
end
end

function semantic_type = resolveSemanticFieldType(bus_name, field_name)
key = string(bus_name) + "." + string(field_name);
switch key
    case ["tSnrHall.HA", "tSnrHall.HB", "tSnrHall.HC"], semantic_type = "HallLevel_V";
    case ["tSnrResolver.A", "tSnrResolver.B", "tSnrResolver.C"], semantic_type = "ResolverLevel_V";
    case ["tSnrEncoder.A", "tSnrEncoder.B", "tSnrEncoder.C"], semantic_type = "EncoderLevel_V";
    case ["tSnrBemf.BemfA", "tSnrBemf.BemfB", "tSnrBemf.BemfC"], semantic_type = "AdcBemfRaw_V";
    case ["tSnrVot.Va", "tSnrVot.Vb", "tSnrVot.Vc"], semantic_type = "AdcVoltageRaw_V";
    case ["tSnrCur.Ia", "tSnrCur.Ib", "tSnrCur.Ic"], semantic_type = "AdcCurrentRaw_V";
    case ["tActrDuty.AH", "tActrDuty.AL", "tActrDuty.BH", "tActrDuty.BL", "tActrDuty.CH", "tActrDuty.CL"], semantic_type = "DutyCount_V";
    case ["tAlgoPI.Kp", "tAlgoPI.Ki"], semantic_type = "Gain_V";
    case "tAlgoPI.Ts", semantic_type = "Time_S_V";
    case "tMcDataFlow.AngleElc", semantic_type = "AngleRad_V";
    case ["tMcDataFlow.WElc", "tMcDataFlow.WReqElc"], semantic_type = "AngularSpeedRadPerSec_V";
    case "tMcDataFlow.DcBusCurRaw", semantic_type = "AdcCurrentRaw_V";
    case "tMcDataFlow.DcBusCurFlt", semantic_type = "Current_A_V";
    case "tMcDataFlow.DcBusVotRaw", semantic_type = "AdcVoltageRaw_V";
    case "tMcDataFlow.DcBusVotFlt", semantic_type = "Voltage_V";
    case "tMcDebug.DebugEn", semantic_type = "LogicBool_V";
    case "tMcCfg.MotorNum", semantic_type = "MotorIndex_V";
    case ["tMcCfg.TuningEn", "tMcCfg.DebugEn"], semantic_type = "LogicBool_V";
    case ["tMcCfg.SampleRate", "tMcCfg.PwmFreq"], semantic_type = "Freq_Hz_V";
    case "tMotorPara.NomVoltage", semantic_type = "Voltage_V";
    case "tMotorPara.NomCurrent", semantic_type = "Current_A_V";
    case "tMotorPara.NornSpd", semantic_type = "SpeedRpm_V";
    case "tMotorPara.PolePairNum", semantic_type = "PolePairCount_V";
    case ["tMotorPara.Ld", "tMotorPara.Lq"], semantic_type = "Inductance_H_V";
    case "tMotorPara.Rs", semantic_type = "Resistance_Ohm_V";
    case "tMotorPara.Bemf", semantic_type = "BemfConst_VsPerRad_V";
    case "tMotorPara.Flux", semantic_type = "Flux_Wb_V";
    case "tMotorPara.RotorInertia", semantic_type = "Inertia_KgM2_V";
    case "tMotorPara.Kt", semantic_type = "TorquePerAmp_NmPerA_V";
    case "tMotorPara.Ke", semantic_type = "BemfConst_VsPerRad_V";
    case "tMcDrive.BasicCnt", semantic_type = "Count_V";
    otherwise, semantic_type = "";
end
end

function blocks = parseLevel3Blocks(text)
lines = splitlines(string(text));
blocks = struct("Title", {}, "Lines", {});
current_title = "";
current_lines = strings(0, 1);
for i = 1:numel(lines)
    line = lines(i);
    title_tokens = regexp(char(line), '^###\s+(.+?)\s*$', 'tokens', 'once');
    if ~isempty(title_tokens)
        if current_title ~= ""
            blocks(end + 1).Title = char(current_title); %#ok<AGROW>
            blocks(end).Lines = current_lines;
        end
        current_title = string(title_tokens{1});
        current_lines = strings(0, 1);
        continue;
    end
    if current_title ~= ""
        if startsWith(strip(line), "## ")
            blocks(end + 1).Title = char(current_title); %#ok<AGROW>
            blocks(end).Lines = current_lines;
            current_title = "";
            current_lines = strings(0, 1);
            continue;
        end
        current_lines(end + 1, 1) = line; %#ok<AGROW>
    end
end
if current_title ~= ""
    blocks(end + 1).Title = char(current_title); %#ok<AGROW>
    blocks(end).Lines = current_lines;
end
end

function desc_lines = collectDescriptionLines(lines, end_idx)
desc_lines = strings(0, 1);
for i = 1:end_idx
    line = strip(lines(i));
    if line == "" || startsWith(line, "|") || startsWith(line, "<!--")
        continue;
    end
    desc_lines(end + 1, 1) = line; %#ok<AGROW>
end
end

function table_lines = collectTableLines(lines, start_idx)
table_lines = strings(0, 1);
for i = start_idx:numel(lines)
    line = strip(lines(i));
    if startsWith(line, "|"), table_lines(end + 1, 1) = line; %#ok<AGROW>
    else, break;
    end
end
end

function values = splitMarkdownRow(line)
line = strip(string(line));
line = strip(extractAfter(line, 1), "right");
line = strip(extractBefore(line, strlength(line)), "left");
values = strip(split(line, "|"));
end

function section_text = extractSectionByTitles(text, start_title, end_title)
lines = splitlines(string(text));
start_idx = [];
end_idx = [];
for i = 1:numel(lines)
    if isempty(start_idx) && matchesLevel2Heading(lines(i), start_title)
        start_idx = i;
        continue;
    end
    if ~isempty(start_idx) && matchesLevel2Heading(lines(i), end_title)
        end_idx = i;
        break;
    end
end
if isempty(start_idx) || isempty(end_idx)
    error("Cannot extract section.");
end
section_text = char(strjoin(cellstr(lines(start_idx:end_idx-1)), newline));
end

function matched = matchesLevel2Heading(line, title_text)
tokens = regexp(char(strip(line)), '^##\s+(?:\d+\.\s+)?(.+?)\s*$', 'tokens', 'once');
matched = ~isempty(tokens) && string(tokens{1}) == string(title_text);
end

function value = extractBacktickValue(text, key)
expr = sprintf('%s\\s+`([^`]+)`', regexptranslate("escape", key));
tokens = regexp(text, expr, "tokens", "once");
if isempty(tokens), value = ""; else, value = string(tokens{1}); end
end

function out = escapeText(in)
out = strrep(char(string(in)), "'", "''");
end

function literal = scalarLiteral(value_text)
value_text = strtrim(char(string(value_text)));
if isempty(value_text), literal = "[]"; else, literal = value_text; end
end

function literal = dimensionLiteral(dimensions)
if isequal(dimensions, 1), literal = "1"; else, literal = num2str(dimensions); end
end

function arr = appendStruct(arr, item)
if isempty(arr)
    arr = item;
else
    arr(end + 1) = item; %#ok<AGROW>
end
end
