function info = bldc_initialize(options)
%bldc_initialize - Verify BLDC types and load independent calibrations
%   INFO = bldc_initialize checks types and preserves valid calibrations.
%   INFO = bldc_initialize(SyncDictionary=true) resets owned defaults in
%   a clean, unreferenced dictionary and preserves unrelated entries.
%   INFO = bldc_initialize(Dictionary=FILE,OutputDirectory=DIR) uses FILE
%   and writes artifacts under DIR, which must be below .agent-env.
%   See also generate_data_type_from_md, bldc_setup

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
arguments
    options.OutputDirectory {mustBeTextScalar} = ""
    options.Dictionary {mustBeTextScalar} = ""
    options.SyncDictionary {mustBeA(options.SyncDictionary,'logical'),mustBeScalarOrEmpty} = false
end
if isempty(options.SyncDictionary)
    error('bldc:InvalidOption','SyncDictionary must be a logical scalar.');
end
bldcRoot=string(fileparts(mfilename('fullpath')));
repoRoot=string(fileparts(fileparts(bldcRoot)));
artifactRoot=canonicalPath(fullfile(repoRoot,'.agent-env'));
outputDirectory=string(options.OutputDirectory);
if outputDirectory=="",outputDirectory=fullfile(artifactRoot,'bldc');end
outputDirectory=canonicalPath(outputDirectory);
if ~startsWith(lower(outputDirectory),lower(artifactRoot+filesep))
    error('bldc:OutputOutsideArtifactRoot','OutputDirectory must be below .agent-env.');
end
ownedDictionary=canonicalPath(fullfile(bldcRoot,'commom','BldcData.sldd'));
dictionaryFile=string(options.Dictionary);
if dictionaryFile=="",dictionaryFile=ownedDictionary;end
dictionaryFile=canonicalPath(dictionaryFile);
if options.SyncDictionary && ~strcmpi(dictionaryFile,ownedDictionary) && ...
        ~startsWith(lower(dictionaryFile),lower(artifactRoot+filesep))
    error('bldc:DictionaryOutsideOwnedDirectories', ...
        'Sync requires BldcData.sldd or a dictionary below .agent-env.');
end
sourceDirectories=[bldcRoot;fullfile(bldcRoot,'algo'); ...
    fullfile(bldcRoot,'commom');fullfile(bldcRoot,'data'); ...
    fullfile(bldcRoot,'platform','codegen'); ...
    fullfile(bldcRoot,'platform','pil');fullfile(repoRoot,'tools')];
sourceDirectories=sourceDirectories(isfolder(sourceDirectories));
for directory=sourceDirectories',addpath(char(directory));end
if ~isfile(dictionaryFile)
    if ~options.SyncDictionary
        error('bldc:MissingDictionary','Dictionary missing; use SyncDictionary=true.');
    end
    if ~isfolder(fileparts(dictionaryFile)),mkdir(fileparts(dictionaryFile));end
    dictionary=Simulink.data.dictionary.create(char(dictionaryFile));
else
    dictionary=Simulink.data.dictionary.open(char(dictionaryFile));
end
if options.SyncDictionary && dictionary.HasUnsavedChanges
    error('bldc:DirtyDictionary','Save or discard existing dictionary edits first.');
end
if options.SyncDictionary && ~isempty(dictionary.DataSources)
    error('bldc:ReferencedDictionary','Referenced dictionaries cannot be synchronized.');
end
addpath(char(fileparts(dictionaryFile)));
cacheDirectory=fullfile(outputDirectory,'cache');
codegenDirectory=fullfile(outputDirectory,'codegen');
Simulink.fileGenControl('set','CacheFolder',char(cacheDirectory), ...
    'CodeGenFolder',char(codegenDirectory),'createDir',true);
generatedDirectory=fullfile(outputDirectory,'types');
generate_data_type_from_md(fullfile(repoRoot,'docs','BldcStruct.md'),generatedDirectory);
generatedTypeFile=fullfile(generatedDirectory,'bldc_data_types.m');
movefile(fullfile(generatedDirectory,'mc_data_types.m'),generatedTypeFile,'f');
% Keep generated license text intact while normalizing line-end whitespace.
generatedText=regexprep(fileread(generatedTypeFile),'[ \t]+(?=\r?\n)','');
file=fopen(generatedTypeFile,'w','n','UTF-8');
assert(file>=0,'bldc:GeneratedFileWrite','Cannot normalize generated types.');
fileCleanup=onCleanup(@()fclose(file));
fprintf(file,'%s',generatedText);clear fileCleanup
types=collectGeneratedTypes(generatedTypeFile);
section=getSection(dictionary,'Design Data');
changed=false;
try
    names=fieldnames(types);
    for index=1:numel(names)
        changed=synchronizeEntry(section,names{index},types.(names{index}), ...
            options.SyncDictionary)||changed;
    end
    p=bldc.defaults();
    names={'BldcControl_Params','BldcRuntime_Init','BldcInput_Default','BldcPlant_Params'};
    buses={'tBldcParams','tBldcRuntime','tBldcInput','tBldcParams'};
    defaults={p,bldc.initial_state(p),bldc.default_input(p),p};
    parameters=cell(1,4);
    for index=1:4
        if options.SyncDictionary
            parameter=typedParameter(section,names{index},buses{index},defaults{index});
            changed=synchronizeEntry(section,names{index},parameter,true)||changed;
        else
            parameter=readParameter(section,names{index},buses{index});
        end
        validateShape(parameter.Value,defaults{index},names{index});
        parameters{index}=parameter;
    end
    validateCalibration(parameters{1}.Value);
    validateCalibration(parameters{2}.Value.Parameters);
    validateCalibration(parameters{4}.Value);
    if options.SyncDictionary && changed,saveChanges(dictionary);end
catch exception
    if options.SyncDictionary,discardChanges(dictionary);end
    rethrow(exception);
end
info=struct('RepositoryRoot',repoRoot,'SourceDirectories',sourceDirectories, ...
    'GeneratedTypeFile',generatedTypeFile,'Types',types, ...
    'Dictionary',dictionaryFile,'DictionaryConnection',dictionary, ...
    'DictionaryChanged',changed,'ControlParameter',parameters{1}, ...
    'RuntimeParameter',parameters{2},'InputParameter',parameters{3}, ...
    'PlantParameter',parameters{4},'CacheDirectory',cacheDirectory, ...
    'CodegenDirectory',codegenDirectory);
end

function result=canonicalPath(input)
result=string(java.io.File(char(input)).getCanonicalPath());
end

function types=collectGeneratedTypes(scriptFile)
run(char(scriptFile));
variables=whos;
classes={'Simulink.NumericType','Simulink.AliasType','Simulink.ValueType', ...
    'Simulink.Bus','Simulink.data.dictionary.EnumTypeDefinition'};
types=struct;
for index=1:numel(variables)
    if any(strcmp(variables(index).class,classes))
        types.(variables(index).name)=eval(variables(index).name);
    end
end
end

function changed=synchronizeEntry(section,name,value,update)
present=exist(section,name);
if present
    entry=getEntry(section,name);
    if numel(entry)~=1,error('bldc:AmbiguousEntry','Ambiguous entry %s.',name);end
    if isequaln(getValue(entry),value),changed=false;return;end
end
if ~update,error('bldc:TypeMismatch','Type %s differs from BldcStruct.md.',name);end
if present,setValue(entry,value);else,addEntry(section,name,value);end
changed=true;
end

function parameter=typedParameter(section,name,busName,value)
if exist(section,name)
    parameter=getValue(getEntry(section,name));
    if ~isa(parameter,'Simulink.Parameter')
        error('bldc:InvalidParameter','%s is not a Simulink.Parameter.',name);
    end
else
    parameter=Simulink.Parameter;
end
parameter.DataType=['Bus: ' busName];
parameter.Value=value;
end

function parameter=readParameter(section,name,busName)
if ~exist(section,name),error('bldc:MissingParameter','Missing parameter %s.',name);end
parameter=getValue(getEntry(section,name));
if ~isa(parameter,'Simulink.Parameter') || ~strcmp(parameter.DataType,['Bus: ' busName])
    error('bldc:InvalidParameter','%s must use Bus: %s.',name,busName);
end
end

function validateShape(value,prototype,name)
if ~strcmp(class(value),class(prototype)) || ~isequal(size(value),size(prototype))
    error('bldc:InvalidParameterShape','Wrong class or dimensions in %s.',name);
end
if isstruct(prototype)
    fields=fieldnames(prototype);
    if ~isequal(fieldnames(value),fields)
        error('bldc:InvalidParameterShape','Wrong fields or order in %s.',name);
    end
    for index=1:numel(fields)
        validateShape(value.(fields{index}),prototype.(fields{index}),[name '.' fields{index}]);
    end
elseif ~isreal(value) || any(~isfinite(value),'all')
    error('bldc:InvalidCalibration','Nonfinite or complex value in %s.',name);
end
end

function validateCalibration(p)
positive={'Ts','SpeedDivider','AdcCountsPerAmp','PwmPeriod','Rs','Ls','Ke', ...
    'PolePairs','Inertia','PlantSubsteps','NominalVdc','VdcMin','VdcMax', ...
    'CurrentLimit','TripCurrent','SpeedLimit','MaxModulation','SpeedSlew', ...
    'CurrentSlew','AlignTime','OpenAccel','OpenSpeed','TrackingTime', ...
    'TrackingTimeout','StartTimeout','StopSpeed','StopTimeout','StopCoastTime','HallTimeout', ...
    'HallStartTimeout','ZcMinTicks','ZcMaxTicks','ZcRequired','ZcTimeoutFactor', ...
    'ZcMinSpeed','AcquireSpacing','AcquireMinVoltage','AcquireTimeout', ...
    'LowSpeedThreshold'};
for index=1:numel(positive)
    if p.(positive{index})<=0
        error('bldc:InvalidCalibration','%s must be positive.',positive{index});
    end
end
nonnegative={'Friction','KpCurrent','KiCurrent','KpSpeed','KiSpeed', ...
    'AlignCurrent','OpenCurrent','HallStallCurrent','ZcHysteresis','FloatCurrentLimit'};
for index=1:numel(nonnegative)
    if p.(nonnegative{index})<0
        error('bldc:InvalidCalibration','%s must be nonnegative.',nonnegative{index});
    end
end
if p.PositionMode>1 || p.CurrentLimit>=p.TripCurrent || ...
        ~(p.VdcMin<p.NominalVdc && p.NominalVdc<p.VdcMax) || ...
        p.MaxModulation>1 || p.SpeedFilterAlpha<=0 || p.SpeedFilterAlpha>1 || ...
        p.ZcMinTicks>=p.ZcMaxTicks || p.ZcTimeoutFactor<=1 || ...
        p.AdcOffset<0 || p.AdcOffset>65535 || p.AdcOffset~=fix(p.AdcOffset) || ...
        p.AlignCurrent>p.CurrentLimit || p.OpenCurrent>p.CurrentLimit || ...
        p.OpenSpeed>p.SpeedLimit || p.StopSpeed>=p.SpeedLimit
    error('bldc:InvalidCalibration','Inconsistent BLDC calibration ranges.');
end
end
