function info = mc_initialize(options)
%mc_initialize - Initialize repository PMSM types and simulation paths
%   INFO = mc_initialize verifies generated types and reads tMcDrive_Param.
%   INFO = mc_initialize(SyncDictionary=true) updates types and defaults,
%   preserving unrelated entries. Dirty dictionaries cannot be synced.
%   INFO = mc_initialize(OutputDirectory=DIR,Dictionary=FILE) selects DIR
%   below .agent-env and a dictionary. Retain INFO while using its enums.
%   See also generate_data_type_from_md, Simulink.fileGenControl

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD

arguments
    options.OutputDirectory (1,1) string = ""
    options.Dictionary (1,1) string = ""
    options.SyncDictionary (1,1) logical = false
end

pmsmRoot = string(fileparts(mfilename('fullpath')));
repoRoot = string(fileparts(fileparts(pmsmRoot)));
artifactRoot = canonicalPath(fullfile(repoRoot, '.agent-env'));
if options.OutputDirectory == ""
    options.OutputDirectory = fullfile(artifactRoot, 'pmsm');
end
outputDirectory = canonicalPath(options.OutputDirectory);
if ~startsWith(lower(outputDirectory), lower(artifactRoot + filesep))
    error('mc:OutputOutsideArtifactRoot', ...
        'OutputDirectory must be below %s.', artifactRoot);
end
if options.Dictionary == ""
    options.Dictionary = fullfile(pmsmRoot, 'commom', 'McData.sldd');
end
dictionaryFile = canonicalPath(options.Dictionary);
ownedDictionary = canonicalPath(fullfile(pmsmRoot, 'commom', 'McData.sldd'));
if options.SyncDictionary && ~strcmpi(dictionaryFile, ownedDictionary) && ...
        ~startsWith(lower(dictionaryFile), lower(artifactRoot + filesep))
    error('mc:DictionaryOutsideOwnedDirectories', ...
        'Synchronization requires McData.sldd or a dictionary below .agent-env.');
end
sourceDirectories = [pmsmRoot; fullfile(pmsmRoot, 'algo'); ...
    fullfile(pmsmRoot, 'commom'); fullfile(pmsmRoot, 'data'); ...
    fullfile(pmsmRoot, 'platform', 'pil'); fullfile(repoRoot, 'tools')];
sourceDirectories = sourceDirectories(isfolder(sourceDirectories));
for directory = sourceDirectories'
    addpath(char(directory));
end

if ~isfile(dictionaryFile)
    if ~options.SyncDictionary
        error('mc:MissingDictionary', ...
            'Dictionary not found. Use SyncDictionary=true: %s', dictionaryFile);
    end
    dictionaryParent = fileparts(dictionaryFile);
    if ~isfolder(dictionaryParent), mkdir(dictionaryParent); end
    dictionary = Simulink.data.dictionary.create(char(dictionaryFile));
else
    dictionary = Simulink.data.dictionary.open(char(dictionaryFile));
end
% Keep the dictionary open while returned parameter enum instances exist.
% Closing it here would orphan their definitions before a model can use them.
if options.SyncDictionary && dictionary.HasUnsavedChanges
    error('mc:DirtyDictionary', ...
        'Save or discard existing dictionary edits before synchronization.');
end
if options.SyncDictionary && ~isempty(dictionary.DataSources)
    error('mc:ReferencedDictionary', ...
        'Synchronization of a dictionary with referenced sources is not supported.');
end
addpath(char(fileparts(dictionaryFile)));

cacheDirectory = fullfile(outputDirectory, 'cache');
codegenDirectory = fullfile(outputDirectory, 'codegen');
Simulink.fileGenControl('set', 'CacheFolder', char(cacheDirectory), ...
    'CodeGenFolder', char(codegenDirectory), 'createDir', true);
generatedDirectory = fullfile(outputDirectory, 'types');
generate_data_type_from_md(fullfile(repoRoot, 'docs', 'McStruct.md'), ...
    generatedDirectory);
generatedTypeFile = fullfile(generatedDirectory, 'mc_data_types.m');
types = collectGeneratedTypes(generatedTypeFile);
section = getSection(dictionary, 'Design Data');
changed = false;
try
    names = fieldnames(types);
    for index = 1:numel(names)
        name = names{index};
        changed = synchronizeEntry(section, name, types.(name), ...
            options.SyncDictionary) || changed;
    end
    if options.SyncDictionary
        parameter = defaultDriveParameter(dictionary, section);
        changed = synchronizeEntry(section, 'tMcDrive_Param', parameter, true) ...
            || changed;
    else
        parameter = readParameter(section, 'tMcDrive_Param', 'tMcDrive');
    end
    [framework, frameworkChanged] = frameworkParameters( ...
        section, types, options.SyncDictionary);
    changed = changed || frameworkChanged;
    if options.SyncDictionary && changed, saveChanges(dictionary); end
catch exception
    % The synchronization began clean, so only our pending edits are lost.
    if options.SyncDictionary, discardChanges(dictionary); end
    rethrow(exception);
end

info = struct('RepositoryRoot', repoRoot, ...
    'SourceDirectories', sourceDirectories, ...
    'GeneratedTypeFile', generatedTypeFile, 'Types', types, ...
    'Dictionary', dictionaryFile, 'DictionaryConnection', dictionary, ...
    'DictionaryChanged', changed, ...
    'Parameter', parameter, 'ControlParameter', framework{1}, ...
    'RuntimeParameter', framework{2}, 'InputParameter', framework{3}, ...
    'PlantParameter', framework{4}, ...
    'CacheDirectory', cacheDirectory, ...
    'CodegenDirectory', codegenDirectory);
end

function result = canonicalPath(input)
result = string(java.io.File(char(input)).getCanonicalPath());
end

function types = collectGeneratedTypes(scriptFile)
% Keep generated variables out of the base workspace and model scope.
run(char(scriptFile));
variables = whos;
typeClasses = {'Simulink.NumericType', 'Simulink.AliasType', ...
    'Simulink.ValueType', 'Simulink.Bus', ...
    'Simulink.data.dictionary.EnumTypeDefinition'};
types = struct;
for index = 1:numel(variables)
    if any(strcmp(variables(index).class, typeClasses))
        types.(variables(index).name) = eval(variables(index).name);
    end
end
end

function changed = synchronizeEntry(section, name, value, update)
present = exist(section, name);
if present
    entry = getEntry(section, name);
    if numel(entry) ~= 1
        error('mc:AmbiguousEntry', 'Multiple dictionary entries named %s.', name);
    end
    if isequaln(getValue(entry), value)
        changed = false;
        return;
    end
end
if ~update
    error('mc:TypeMismatch', ...
        'Dictionary type %s differs from McStruct.md. Use SyncDictionary=true.', name);
end
if present
    setValue(entry, value);
else
    addEntry(section, name, value);
end
changed = true;
end

function parameter = defaultDriveParameter(dictionary, section)
value = Simulink.Bus.createMATLABStruct('tMcDrive', [], 1, dictionary);
value.MotorPara.NomVoltage = single(12);
value.MotorPara.Rs = single(0.56);
value.MotorPara.Ld = single(0.000375);
value.MotorPara.Lq = single(0.000435);
value.MotorPara.Flux = single(0.0039052261);
value.MotorPara.PolePairNum = uint8(2);
value.MotorPara.RotorInertia = single(1.2e-5);
value.MotorPara.Fdamp = single(0.0005);
value.MotorPara.Kt = single(1.5 * 0.0039052261 * 2);
value.McCfg.SampleRate = uint32(16000);
value.McCfg.PwmFreq = uint32(16000);
value.McType.MotorType = feval(class(value.McType.MotorType), 1);
parameter = typedParameter(section, 'tMcDrive_Param', 'tMcDrive', value);
end

function parameter = typedParameter(section, name, busName, value)
if exist(section, name)
    parameter = getValue(getEntry(section, name));
    if ~isa(parameter, 'Simulink.Parameter')
        error('mc:InvalidParameter', ...
            'Existing %s is not a Simulink.Parameter.', name);
    end
else
    parameter = Simulink.Parameter;
end
parameter.DataType = ['Bus: ' busName];
parameter.Value = value;
end

function parameter = readParameter(section, name, busName)
if ~exist(section, name)
    error('mc:MissingParameter', ...
        '%s is missing. Use SyncDictionary=true.', name);
end
parameter = getValue(getEntry(section, name));
if ~isa(parameter, 'Simulink.Parameter') || ...
        ~strcmp(parameter.DataType, ['Bus: ' busName])
    error('mc:InvalidParameter', ...
        '%s must be a Simulink.Parameter of Bus: %s.', name, busName);
end
end

function [parameters, changed] = frameworkParameters(section, types, update)
names = {'McControl_Params', 'McRuntime_Init', 'McInput_Default', 'McPlant_Params'};
busNames = {'tMcControlParams', 'tMcRuntime', 'tMcInput', 'tMcControlParams'};
parameters = cell(1, numel(names));
changed = false;
present = isfield(types, busNames);
if update && any(present)
    p = mc.defaults();
    values = {p, mc.initial_state(p), mc.default_input(p), p};
end
for index = 1:numel(names)
    if ~present(index), continue; end
    if update
        parameter = typedParameter(section, names{index}, ...
            busNames{index}, values{index});
        changed = synchronizeEntry(section, names{index}, parameter, true) ...
            || changed;
    else
        parameter = readParameter(section, names{index}, busNames{index});
    end
    parameters{index} = parameter;
end
end
