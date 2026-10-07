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
% File:        ambdMcSetupTest.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-08
% Version:     0.1.0
% Description: Reject unsaved calibration before creating a target stage.
% =================================================================================

classdef ambdMcSetupTest < matlab.unittest.TestCase
    %ambdMcSetupTest - Exercise initialization through the public dispatcher
    properties
        Root
        Folder
        Dictionary
    end
    properties (TestParameter)
        Family = struct('bldc',"bldc",'pmsm',"pmsm")
    end
    methods (TestMethodSetup)
        function isolate(testCase)
            testCase.Root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            originalPath=path;
            testCase.addTeardown(@()path(originalPath));
            addpath(testCase.Root);
            cfg=Simulink.fileGenControl('getConfig');
            testCase.addTeardown(@()Simulink.fileGenControl('setConfig','config',cfg));
            base=fullfile(testCase.Root,'.agent-env','tests','entrypoint');
            if ~isfolder(base),mkdir(base);end
            testCase.Folder=tempname(base);mkdir(testCase.Folder);
            testCase.Dictionary=fullfile(testCase.Folder,'EntryTest.sldd');
            testCase.addTeardown(@()closeFixture(testCase.Dictionary));
        end
    end
    methods (Test)
        function singleFamilyRetainsReturnAndPaths(testCase,Family)
            info=ambd_mc('setup',Family);
            connection=info.DictionaryConnection;
            testCase.addTeardown(@()close(connection));
            testCase.verifyEqual(info.RepositoryRoot,string(testCase.Root));
            testCase.verifyClass(info.DictionaryConnection,'Simulink.data.Dictionary');
            testCase.verifyTrue(isfile(info.GeneratedTypeFile));
            testCase.verifyFalse(info.DictionaryChanged);
            testCase.verifySubstring(path,fullfile(testCase.Root, ...
                'mc-models',Family,'platform','codegen'));
        end
        function preservesCalibrationAndAllowsExplicitReset(testCase,Family)
            first=ambd_mc('setup',Family,Dictionary=testCase.Dictionary, ...
                OutputDirectory=testCase.Folder,SyncDictionary=true);
            section=getSection(first.DictionaryConnection,'Design Data');
            entry=getEntry(section,parameterName(Family));
            parameter=getValue(entry);
            parameter.Value.Rs=single(0.75);setValue(entry,parameter);
            addEntry(section,'UserCalibration',uint32(42));
            saveChanges(first.DictionaryConnection);
            before=dir(testCase.Dictionary);
            again=ambd_mc('setup',Family,'Dictionary',testCase.Dictionary, ...
                'OutputDirectory',testCase.Folder);
            after=dir(testCase.Dictionary);
            testCase.verifyEqual(again.ControlParameter.Value.Rs,single(0.75), ...
                AbsTol=single(0));
            testCase.verifyFalse(again.DictionaryChanged);
            testCase.verifyEqual(before.datenum,after.datenum,AbsTol=0);
            testCase.verifyFalse(again.DictionaryConnection.HasUnsavedChanges);
            reset=ambd_mc('setup',Family,Dictionary=testCase.Dictionary, ...
                OutputDirectory=testCase.Folder,SyncDictionary=true);
            testCase.verifyEqual(reset.ControlParameter.Value.Rs, ...
                first.ControlParameter.Value.Rs,AbsTol=single(0));
            testCase.verifyEqual(getValue(getEntry(section,'UserCalibration')),uint32(42));
        end
        function syncPreservesUnsavedChangesOnRejection(testCase,Family)
            info=ambd_mc('setup',Family,Dictionary=testCase.Dictionary, ...
                OutputDirectory=testCase.Folder,SyncDictionary=true);
            section=getSection(info.DictionaryConnection,'Design Data');
            addEntry(section,'PendingUserValue',uint32(123));
            testCase.verifyError(@()ambd_mc('setup',Family, ...
                Dictionary=testCase.Dictionary,OutputDirectory=testCase.Folder, ...
                SyncDictionary=true),dirtyError(Family));
            testCase.verifyTrue(info.DictionaryConnection.HasUnsavedChanges);
            testCase.verifyEqual(getValue(getEntry(section,'PendingUserValue')),uint32(123));
        end
        function allKeepsSeparateDictionariesAndArtifacts(testCase)
            info=ambd_mc('setup','all',OutputDirectory=testCase.Folder);
            bldcConnection=info.Bldc.DictionaryConnection;
            testCase.addTeardown(@()close(bldcConnection));
            pmsmConnection=info.Pmsm.DictionaryConnection;
            testCase.addTeardown(@()close(pmsmConnection));
            testCase.verifyEqual(info.Root,testCase.Root);
            testCase.verifyEqual(info.Family,"all");
            testCase.verifyEqual(info.HspVersion,"0.1.0");
            testCase.verifyNotEqual(info.Bldc.Dictionary,info.Pmsm.Dictionary);
            testCase.verifySubstring(info.Bldc.GeneratedTypeFile, ...
                string(fullfile(testCase.Folder,'bldc')));
            testCase.verifySubstring(info.Pmsm.GeneratedTypeFile, ...
                string(fullfile(testCase.Folder,'pmsm')));
            testCase.verifyClass(info.Pmsm.Parameter.Value.McType.MotorType,'eMotorType');
            testCase.verifyFalse(info.Bldc.DictionaryConnection.HasUnsavedChanges);
            testCase.verifyFalse(info.Pmsm.DictionaryConnection.HasUnsavedChanges);
        end
    end
end
function name=parameterName(family)
if family=="bldc",name='BldcControl_Params';else,name='McControl_Params';end
end
function id=dirtyError(family)
if family=="bldc",id='bldc:DirtyDictionary';else,id='mc:DirtyDictionary';end
end
function closeFixture(file)
if isfile(file)
    dictionary=Simulink.data.dictionary.open(file);
    discardChanges(dictionary);close(dictionary);
end
end
