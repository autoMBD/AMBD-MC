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
% File:        export_sldd_to_m.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-03-16
% Version:     0.1.0
% Description: Export Simulink Data Dictionary (.sldd) type definitions to MATLAB 
%               script (.m) file.
% =================================================================================

function export_sldd_to_m(sldd_file, output_m)

dict = Simulink.data.dictionary.open(sldd_file);
dDataSect = getSection(dict, 'Design Data');

entries = find(dDataSect);

fid = fopen(output_m, 'w');
if fid == -1
    close(dict);
    error('Cannot open output file: %s', output_m);
end

count = 0;
try
    for i = 1:numel(entries)
        entry = entries(i);
        name  = entry.Name;
        value = getValue(entry);

        if writeValue(fid, name, value)
            count = count + 1;
        end
    end
catch ME
    fclose(fid);
    close(dict);
    rethrow(ME);
end

fclose(fid);
close(dict);

fprintf('Exported %d entries to %s\n', count, output_m);

end

%% ---- helper: dispatch by type (only export type definitions) ----
function exported = writeValue(fid, name, value)
    exported = true;
    if isa(value, 'Simulink.data.dictionary.EnumTypeDefinition')
        writeEnumTypeDef(fid, name, value);
    elseif isa(value, 'Simulink.Bus')
        writeBus(fid, name, value);
    else
        exported = false;
    end
end

%% ---- helper: write Simulink.data.dictionary.EnumTypeDefinition ----
function writeEnumTypeDef(fid, name, enumDef)
    enumerals  = enumDef.Enumerals;
    numMembers = numel(enumerals);

    fprintf(fid, '%% --- EnumTypeDefinition: %s ---\n', name);
    fprintf(fid, '%s = Simulink.data.dictionary.EnumTypeDefinition;\n', name);

    % Remove the default member created by constructor (index 1)
    fprintf(fid, 'removeEnumeral(%s, 1);\n', name);

    for k = 1:numMembers
        mName = enumerals(k).Name;
        mValue = enumerals(k).Value;
        mDesc  = enumerals(k).Description;
        if ischar(mValue) || isstring(mValue)
            mValue = str2double(mValue);
        end
        if ischar(mDesc)
            mDesc = strrep(mDesc, '''', '''''');
        end
        fwrite(fid, sprintf('appendEnumeral(%s, ''%s'', %d, ''%s'');\n', ...
               name, mName, mValue, mDesc));
    end

    if ~isempty(enumDef.DefaultValue)
        fprintf(fid, '%s.DefaultValue = ''%s'';\n', name, enumDef.DefaultValue);
    end
    if ~isempty(enumDef.Description)
        fprintf(fid, '%s.Description = ''%s'';\n', name, enumDef.Description);
    end
    if ~isempty(enumDef.HeaderFile)
        fprintf(fid, '%s.HeaderFile = ''%s'';\n', name, enumDef.HeaderFile);
    end
    if ~strcmp(enumDef.DataScope, 'Auto')
        fprintf(fid, '%s.DataScope = ''%s'';\n', name, enumDef.DataScope);
    end
    if ~isempty(enumDef.StorageType)
        fprintf(fid, '%s.StorageType = ''%s'';\n', name, enumDef.StorageType);
    end
    if enumDef.AddClassNameToEnumNames
        fprintf(fid, '%s.AddClassNameToEnumNames = true;\n', name);
    end
    fprintf(fid, '\n');
end

%% ---- helper: write Simulink.Bus ----
function writeBus(fid, name, bus)
    elems = bus.Elements;
    numElems = numel(elems);

    fprintf(fid, '%% --- Bus: %s ---\n', name);

    if numElems > 0
        fprintf(fid, 'clear elems;\n');
        for k = 1:numElems
            elem = elems(k);
            writeBusElement(fid, k, elem);
        end
        fprintf(fid, '\n');
    end

    fprintf(fid, '%s = Simulink.Bus;\n', name);
    if ~isempty(bus.Description)
        fprintf(fid, '%s.Description = ''%s'';\n', name, bus.Description);
    end
    if ~isempty(bus.HeaderFile)
        fprintf(fid, '%s.HeaderFile = ''%s'';\n', name, bus.HeaderFile);
    end
    if ~isempty(bus.DataScope)
        fprintf(fid, '%s.DataScope = ''%s'';\n', name, bus.DataScope);
    end
    if numElems > 0
        fprintf(fid, '%s.Elements = elems;\n', name);
    end
    fprintf(fid, '\n');
end

%% ---- helper: write single Simulink.BusElement ----
function writeBusElement(fid, idx, elem)
    fprintf(fid, 'elems(%d) = Simulink.BusElement;\n', idx);
    fprintf(fid, 'elems(%d).Name = ''%s'';\n', idx, elem.Name);

    if ~strcmp(elem.DataType, 'double')
        fprintf(fid, 'elems(%d).DataType = ''%s'';\n', idx, elem.DataType);
    end

    dims = elem.Dimensions;
    if ~isequal(dims, 1)
        fprintf(fid, 'elems(%d).Dimensions = %s;\n', idx, mat2str(dims));
    end

    if ~strcmp(elem.Complexity, 'real')
        fprintf(fid, 'elems(%d).Complexity = ''%s'';\n', idx, elem.Complexity);
    end

    if ~strcmp(elem.DimensionsMode, 'Fixed')
        fprintf(fid, 'elems(%d).DimensionsMode = ''%s'';\n', idx, elem.DimensionsMode);
    end

    if elem.Min ~= -Inf
        fprintf(fid, 'elems(%d).Min = %s;\n', idx, mat2str(elem.Min));
    end

    if elem.Max ~= Inf
        fprintf(fid, 'elems(%d).Max = %s;\n', idx, mat2str(elem.Max));
    end

    if ~isempty(elem.Unit)
        fprintf(fid, 'elems(%d).Unit = ''%s'';\n', idx, elem.Unit);
    end

    if ~isempty(elem.Description)
        fprintf(fid, 'elems(%d).Description = ''%s'';\n', idx, elem.Description);
    end
end
