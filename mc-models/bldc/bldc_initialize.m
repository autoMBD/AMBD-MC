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
% File:        bldc_initialize.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: BLDC types and load independent calibrations
% =================================================================================

function info = bldc_initialize(options)
%bldc_initialize - Verify BLDC types and load independent calibrations
%   INFO = bldc_initialize checks types and preserves valid calibrations.
%   INFO = bldc_initialize(SyncDictionary=true) resets owned defaults in
%   a clean, unreferenced dictionary and preserves unrelated entries.
%   INFO = bldc_initialize(Dictionary=FILE,OutputDirectory=DIR) uses FILE
%   and writes artifacts under DIR, which must be below .agent-env.
%   See also generate_data_type_from_md, bldc_setup

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
% Initialize Simulink before creating dictionaries in a fresh MATLAB session.
load_system('simulink');
drawnow;
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
    'LowSpeedThreshold','HallGainSpeed','HallMinGainScale'};
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
        p.MaxModulation>1 || p.SpeedFilterAlpha<=0 || p.SpeedFilterAlpha>1 || p.HallMinGainScale>1 || ...
        p.ZcMinTicks>=p.ZcMaxTicks || p.ZcTimeoutFactor<=1 || ...
        p.AdcOffset<0 || p.AdcOffset>65535 || p.AdcOffset~=fix(p.AdcOffset) || ...
        p.AlignCurrent>p.CurrentLimit || p.OpenCurrent>p.CurrentLimit || ...
        p.OpenSpeed>p.SpeedLimit || p.StopSpeed>=p.SpeedLimit
    error('bldc:InvalidCalibration','Inconsistent BLDC calibration ranges.');
end
end
