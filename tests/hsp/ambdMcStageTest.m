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
% File:        ambdMcStageTest.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-08
% Version:     0.1.0
% Description: Reject unsaved calibration before creating a target stage.
% =================================================================================

classdef ambdMcStageTest < matlab.unittest.TestCase
    %ambdMcStageTest - Protect source state while preparing target copies
    properties
        Root
        Settings
        Folder
    end
    properties (TestParameter)
        Family = struct('bldc',"bldc",'pmsm',"pmsm")
    end
    methods (TestMethodSetup)
        function isolate(testCase)
            testCase.Root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            oldPath=path;testCase.addTeardown(@()path(oldPath));
            addpath(testCase.Root);
            cfg=Simulink.fileGenControl('getConfig');
            testCase.addTeardown(@()Simulink.fileGenControl('setConfig','config',cfg));
            base=fullfile(testCase.Root,'.agent-env','tests','stage');
            if ~isfolder(base),mkdir(base);end
            testCase.Folder=tempname(base);mkdir(testCase.Folder);
            testCase.Settings=fullfile(testCase.Folder,'local.json');
            fid=fopen(testCase.Settings,'w');fprintf(fid,'{}');fclose(fid);
        end
    end
    methods (Test)
        function refusesDirtySourceModel(testCase,Family)
            [model,source]=application(testCase.Root,Family);
            testCase.assumeFalse(bdIsLoaded(model),'Existing model must remain untouched.');
            info=ambd_mc('setup',Family);
            connection=info.DictionaryConnection;
            testCase.addTeardown(@()close(connection));
            prior=find_system('type','block_diagram');
            testCase.addTeardown(@()closeNewModels(testCase.Root,prior));
            load_system(source);
            set_param(model,'Dirty','on');
            testCase.verifyError(@()ambd_mc('stage',Family,testCase.Settings), ...
                'ambd:LoadedModel');
            testCase.verifyEqual(get_param(model,'Dirty'),'on');
            testCase.verifyEqual(get_param(model,'FileName'),source);
        end
        function refusesSameNameFromAnotherFolder(testCase,Family)
            [model,source]=application(testCase.Root,Family);
            testCase.assumeFalse(bdIsLoaded(model),'Existing model must remain untouched.');
            info=ambd_mc('setup',Family);
            connection=info.DictionaryConnection;
            testCase.addTeardown(@()close(connection));
            prior=find_system('type','block_diagram');
            testCase.addTeardown(@()closeNewModels(testCase.Root,prior));
            target=fullfile(testCase.Folder,[model,'.slx']);copyfile(source,target);
            addpath(testCase.Folder,'-begin');
            load_system(target);
            testCase.verifyError(@()ambd_mc('stage',Family,testCase.Settings), ...
                'ambd:LoadedModel');
            testCase.verifyEqual(get_param(model,'FileName'),target);
        end
        function stagesIsolatedUnarmedCopies(testCase,Family)
            manifest=jsondecode(fileread(fullfile(testCase.Root,'mc-models','hsp','models.json')));
            entries=manifest.models(strcmp({manifest.models.family},Family));
            assertModelsNotLoaded(testCase,entries);
            testCase.addTeardown(@()closeModels(entries));
            sourceBefore=sourceBytes(testCase.Root,entries,Family);
            info=ambd_mc('stage',Family,testCase.Settings);
            details=familyDetails(info,Family);
            connection=details.DictionaryConnection;
            testCase.addTeardown(@()releaseStage(connection,entries));
            testCase.verifyEqual(info.Family,Family);
            testCase.verifyEqual(info.HspVersion,"0.1.0");
            testCase.verifySubstring(info.Stage,fullfile(testCase.Root,'.agent-env','t'));
            testCase.verifyTrue(isfile(fullfile(info.Stage,'stage.json')));
            testCase.verifyTrue(isfolder(fullfile(info.Stage,'configuration','S32K344')));
            testCase.verifyEqual(sourceBytes(testCase.Root,entries,Family),sourceBefore);
            testCase.verifySubstring(details.Dictionary,string(info.Stage));
            testCase.verifyEqual(details.ControlParameter.Value,ambd.kit_parameters(Family));
            section=getSection(details.DictionaryConnection,'Design Data');
            armed=getValue(getEntry(section,'AmbdOutputsArmed'));
            testCase.verifyFalse(armed.Value);
            verifyModels(testCase,entries,info.Stage,Family);
        end
    end
end
function [name,file]=application(root,family)
if family=="bldc",name='BLDC_Ctrl_MBD';else,name='FOC_Ctrl_MBD';end
file=fullfile(root,'mc-models',char(family),'platform','codegen',[name,'.slx']);
end
function details=familyDetails(info,family)
if family=="bldc",details=info.Bldc;else,details=info.Pmsm;end
end
function assertModelsNotLoaded(testCase,entries)
for i=1:numel(entries)
    testCase.assumeFalse(bdIsLoaded(entries(i).name),'Existing models must remain untouched.');
end
end
function closeModels(entries)
for i=1:numel(entries)
    if bdIsLoaded(entries(i).name),close_system(entries(i).name,0);end
end
end
function verifyModels(testCase,entries,folder,family)
for i=1:numel(entries)
    name=entries(i).name;
    testCase.verifyEqual(get_param(name,'FileName'),fullfile(folder,[name,'.slx']));
    if ~strcmp(entries(i).role,'library')
        testCase.verifyEqual(get_param(name,'DataDictionary'),[char(family),'_TargetData.sldd']);
    end
end
end
function data=sourceBytes(root,entries,family)
if family=="bldc",name='BldcData.sldd';else,name='McData.sldd';end
files=[{entries.path},{fullfile('mc-models',family,'commom',name)}];
data=cell(size(files));
for i=1:numel(files)
    fid=fopen(fullfile(root,files{i}),'rb');
    cleanup=onCleanup(@()fclose(fid));
    data{i}=fread(fid,Inf,'*uint8');clear cleanup
end
end

function closeNewModels(root,prior)
manifest=jsondecode(fileread(fullfile(root,'mc-models','hsp','models.json')));
entries=manifest.models(~ismember({manifest.models.name},prior));
closeModels(entries);
end
function releaseStage(connection,entries)
closeModels(entries);close(connection);
end
