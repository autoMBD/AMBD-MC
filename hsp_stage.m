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
% File:        hsp_stage.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-07
% Version:     0.1.0
% Description: Stage portable source models for isolated target builds and PIL.
% =================================================================================

function info = hsp_stage(family,localSettingsFile)
%hsp_stage - Prepare isolated model copies for S32K344 builds and PIL
%   INFO = hsp_stage(FAMILY,LOCALSETTINGSFILE) copies the selected model
%   family and EB project below .agent-env. Local tool paths and target
%   connection settings are applied only to these working copies.
%
%   Saved source models keep portable paths. Dirty loaded models are
%   rejected; clean models from this project may be closed and reopened
%   from the stage. The returned dictionary owners must remain alive.
%
%   See also hsp_setup, autombd.hsp.config.importExternalProject

family=string(family);
assert(isscalar(family)&&ismember(family,["bldc","pmsm"]), ...
    'ambd:Family','Stage one family: bldc or pmsm.');
root=fileparts(mfilename('fullpath'));
if family=="bldc",dictionary='BldcData.sldd';else,dictionary='McData.sldd';end
sourceDictionary=Simulink.data.dictionary.open( ...
    fullfile(root,'mc-models',family,'commom',dictionary));
releaseSource=onCleanup(@()close(sourceDictionary));
assert(~sourceDictionary.HasUnsavedChanges,'ambd:DirtyDictionary', ...
    'Save or discard pending changes in %s before staging.',dictionary);
clear releaseSource;
manifest=jsondecode(fileread(fullfile(root,'mc-models','hsp','models.json')));
entries=manifest.models(strcmp({manifest.models.family},family));
for index=1:numel(entries)
    name=entries(index).name;
    if bdIsLoaded(name)
        actual=char(java.io.File(get_param(name,'FileName')).getCanonicalPath());
        expected=char(java.io.File(fullfile(root,entries(index).path)).getCanonicalPath());
        assert(strcmpi(actual,expected)&&strcmp(get_param(name,'Dirty'),'off'), ...
            'ambd:LoadedModel','Close or save the loaded model %s before staging.',name);
    end
end
settings=jsondecode(fileread(localSettingsFile));
if isfield(settings,'environment'),settings=settings.environment;end
identifier=char(java.util.UUID.randomUUID);
familyName=char(family);
% Stateflow and PIL add deep generated paths on Windows.
folder=fullfile(root,'.agent-env','t',[familyName(1),identifier(1:8)]);
assert(~isfolder(folder),'ambd:StageExists','A new stage is required.');
mkdir(folder);
for index=1:numel(entries)
    name=entries(index).name;
    if bdIsLoaded(name),close_system(name,0);end
    copyfile(fullfile(root,entries(index).path),fullfile(folder,[name,'.slx']));
end
targetDictionary=[char(family),'_TargetData.sldd'];
copyfile(fullfile(root,'mc-models',family,'commom',dictionary),fullfile(folder,targetDictionary));
configuration=fullfile(folder,'configuration','S32K344');
mkdir(fileparts(configuration));
copyfile(fullfile(root,'mc-models','hsp','config','S32K344'),configuration);
info=hsp_setup(family,Dictionary=fullfile(folder,targetDictionary));
info.Stage=folder;
info.Models=entries;
addpath(folder,'-begin');
for index=1:numel(entries)
    if strcmp(entries(index).role,'library')
        load_system(fullfile(folder,[entries(index).name,'.slx']));
    end
end
for index=1:numel(entries)
    name=entries(index).name;
    if ~strcmp(entries(index).role,'library')
        open_system(fullfile(folder,[name,'.slx']));
        % DataDictionary is a diagram property, not a ConfigSet parameter.
        % The pinned model_edit cannot bind this root property.
        set_param(name,'DataDictionary',targetDictionary);
    end
    if ismember(entries(index).role,{'component','application'})
        cfg=ambd.hsp_defaults(name);
        [cfg,~]=autombd.hsp.config.importExternalProject(cfg,configuration);
        fields={'sdk','toolchain','freertos','python','pil','deployment'};
        for fieldIndex=1:numel(fields)
            field=fields{fieldIndex};
            if isfield(settings,field),cfg.environment.(field)=settings.(field);end
        end
        if isfield(settings,'configurationTool')
            for field={'executable','guiExecutable'}
                if isfield(settings.configurationTool,field{1})
                    cfg.environment.configurationTool.(field{1})=settings.configurationTool.(field{1});
                end
            end
        end
        cfg.runtime.sources={fullfile(root,'mc-models','hsp','runtime','hsp_motor_board.c')};
        cfg.runtime.includeDirectories={fullfile(root,'mc-models','hsp','runtime')};
        cfg.environment.configurationTool.workspaceRoot=fullfile(folder,'eb-workspace');
        autombd.hsp.config.write(name,cfg);
        autombd.hsp.config.apply(name);
        save_system(name);
    elseif strcmp(entries(index).role,'harness')
        save_system(name);
    end
end
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'), ...
    'CodeGenFolder',fullfile(folder,'codegen'),'createDir',true);
fid=fopen(fullfile(folder,'stage.json'),'w','n','UTF-8');
assert(fid>=0,'ambd:StageReport','Cannot save the stage report.');
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(struct('Family',family,'Models',entries, ...
    'HspVersion',manifest.hspVersion,'MATLAB',version),PrettyPrint=true));
fprintf('HSP working copies: %s\n',folder);
end
