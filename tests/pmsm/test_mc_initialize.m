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
% File:        test_mc_initialize.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: PMSM initialization and dictionary ownership
% =================================================================================

classdef test_mc_initialize < matlab.unittest.TestCase
    %test_mc_initialize - Verify PMSM initialization and dictionary ownership


    properties
        OutputDirectory
        DictionaryFile
    end

    methods (TestMethodSetup)
        function isolateArtifacts(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, 'mc-models', 'pmsm')));
            originalPath = path;
            testCase.addTeardown(@() path(originalPath));
            originalConfig = Simulink.fileGenControl('getConfig');
            testCase.addTeardown(@() Simulink.fileGenControl( ...
                'setConfig', 'config', originalConfig));
            base = fullfile(root, '.agent-env', 'tests', 'initializer');
            if ~isfolder(base), mkdir(base); end
            testCase.OutputDirectory = tempname(base);
            mkdir(testCase.OutputDirectory);
            testCase.DictionaryFile = fullfile( ...
                testCase.OutputDirectory, 'InitializerTest.sldd');
            testCase.addTeardown(@() testCase.closeDictionary());
        end
    end

    methods (Test)
        function generatedTypesAgreeWithDictionary(testCase)
            info = mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true);
            dictionary = Simulink.data.dictionary.open(testCase.DictionaryFile);
            section = getSection(dictionary, 'Design Data');

            testCase.verifyClass(info.Types.McSingle_T, 'Simulink.AliasType');
            testCase.verifyClass(info.Types.McU8Raw_T, 'Simulink.NumericType');
            testCase.verifyClass(info.Types.Voltage_V, 'Simulink.ValueType');
            testCase.verifyClass(info.Types.tMcDrive, 'Simulink.Bus');
            testCase.verifyClass(info.Types.eMotorType, ...
                'Simulink.data.dictionary.EnumTypeDefinition');
            testCase.verifyEqual(getValue(getEntry(section, 'tMcDrive')), ...
                info.Types.tMcDrive);
            testCase.verifyEqual(getValue(getEntry(section, 'eSmStates')), ...
                info.Types.eSmStates);
        end

        function initializesTypedMotorAndEnumDefaults(testCase)
            info = mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true);
            value = info.Parameter.Value;

            testCase.verifyEqual(info.Parameter.DataType, 'Bus: tMcDrive');
            testCase.verifyEqual(value.MotorPara.Rs, single(0.56), AbsTol=single(1e-7));
            testCase.verifyEqual(value.MotorPara.Ld, single(0.000375), AbsTol=single(1e-10));
            testCase.verifyEqual(value.MotorPara.Lq, single(0.000435), AbsTol=single(1e-10));
            testCase.verifyEqual(value.MotorPara.Flux, single(0.0039052261), AbsTol=single(1e-9));
            testCase.verifyEqual(value.MotorPara.RotorInertia, single(1.2e-5), AbsTol=single(1e-11));
            testCase.verifyEqual(value.MotorPara.Fdamp, single(0.0005), AbsTol=single(1e-10));
            testCase.verifyEqual(value.MotorPara.PolePairNum, uint8(2));
            testCase.verifyClass(value.McType.MotorType, 'eMotorType');
            testCase.verifyEqual(char(value.McType.MotorType), 'MC_MOTOR_PMSM');
            testCase.verifyEqual(char(value.StateMachine.State), 'MC_STATE_RESET');
            testCase.verifyEqual(char(value.McCtrl), 'McNotStart');
            testCase.verifyEqual(value.McCfg.SampleRate, uint32(16000));
        end

        function repeatInitializationDoesNotWriteDictionary(testCase)
            first = mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true);
            before = dir(testCase.DictionaryFile);
            second = mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true);
            after = dir(testCase.DictionaryFile);

            testCase.verifyTrue(first.DictionaryChanged);
            testCase.verifyFalse(second.DictionaryChanged);
            testCase.verifyEqual(first.Parameter.Value, second.Parameter.Value);
            testCase.verifyEqual(before.datenum, after.datenum, AbsTol=0);
            dictionary = Simulink.data.dictionary.open(testCase.DictionaryFile);
            testCase.verifyFalse(dictionary.HasUnsavedChanges);
        end

        function preservesUnrelatedEntries(testCase)
            dictionary = Simulink.data.dictionary.create(testCase.DictionaryFile);
            section = getSection(dictionary, 'Design Data');
            addEntry(section, 'UserCalibration', single(3.25));
            saveChanges(dictionary);
            mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true);

            testCase.verifyEqual(getValue(getEntry(section, 'UserCalibration')), ...
                single(3.25), AbsTol=single(0));
        end

        function reportsDriftWithoutChangingSavedDictionary(testCase)
            mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true);
            dictionary = Simulink.data.dictionary.open(testCase.DictionaryFile);
            section = getSection(dictionary, 'Design Data');
            entry = getEntry(section, 'McSingle_T');
            drift = getValue(entry);
            drift.BaseType = 'double';
            setValue(entry, drift);
            saveChanges(dictionary);

            testCase.verifyError(@() mc_initialize( ...
                OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile), 'mc:TypeMismatch');
            testCase.verifyEqual(getValue(entry).BaseType, 'double');
            testCase.verifyFalse(dictionary.HasUnsavedChanges);
        end

        function protectsExistingUnsavedChanges(testCase)
            dictionary = Simulink.data.dictionary.create(testCase.DictionaryFile);
            section = getSection(dictionary, 'Design Data');
            addEntry(section, 'UnsavedUserValue', 17);

            testCase.verifyError(@() mc_initialize( ...
                OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true), ...
                'mc:DirtyDictionary');
            testCase.verifyEqual(getValue(getEntry(section, 'UnsavedUserValue')), 17);
            testCase.verifyTrue(dictionary.HasUnsavedChanges);
        end

        function usesExplicitSourceAndGeneratedPaths(testCase)
            info = mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true);
            config = Simulink.fileGenControl('getConfig');

            testCase.verifyTrue(isfile(info.GeneratedTypeFile));
            testCase.verifyTrue(startsWith(info.GeneratedTypeFile, ...
                string(testCase.OutputDirectory)));
            testCase.verifyEqual(string(config.CacheFolder), info.CacheDirectory);
            testCase.verifyEqual(string(config.CodeGenFolder), info.CodegenDirectory);
            testCase.verifyFalse(any(contains(lower(info.SourceDirectories), ...
                ["legacy", "hardware", "config"])));
        end

        function readsCalibratedParameterWithoutResettingIt(testCase)
            mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true);
            dictionary = Simulink.data.dictionary.open(testCase.DictionaryFile);
            section = getSection(dictionary, 'Design Data');
            entry = getEntry(section, 'tMcDrive_Param');
            parameter = getValue(entry);
            parameter.Value.MotorPara.Rs = single(0.75);
            setValue(entry, parameter);
            saveChanges(dictionary);
            info = mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile);

            testCase.verifyEqual(info.Parameter.Value.MotorPara.Rs, ...
                single(0.75), AbsTol=single(1e-7));
            testCase.verifyFalse(info.DictionaryChanged);
            testCase.verifyFalse(dictionary.HasUnsavedChanges);
        end

        function rejectsArtifactsOutsideAgentEnvironment(testCase)
            testCase.verifyError(@() mc_initialize( ...
                OutputDirectory=tempdir, Dictionary=testCase.DictionaryFile, ...
                SyncDictionary=true), 'mc:OutputOutsideArtifactRoot');
        end

        function explicitSyncRepairsDriftAndResetsMotorDefaults(testCase)
            first = mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true);
            dictionary = first.DictionaryConnection;
            section = getSection(dictionary, 'Design Data');
            typeEntry = getEntry(section, 'McSingle_T');
            drift = getValue(typeEntry);
            drift.BaseType = 'double';
            setValue(typeEntry, drift);
            parameterEntry = getEntry(section, 'tMcDrive_Param');
            calibration = getValue(parameterEntry);
            calibration.Value.MotorPara.Rs = single(0.75);
            setValue(parameterEntry, calibration);
            saveChanges(dictionary);

            repaired = mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true);
            before = dir(testCase.DictionaryFile);
            repeated = mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true);
            after = dir(testCase.DictionaryFile);

            testCase.verifyTrue(repaired.DictionaryChanged);
            testCase.verifyEqual(getValue(typeEntry).BaseType, 'single');
            testCase.verifyEqual(repaired.Parameter.Value.MotorPara.Rs, ...
                single(0.56), AbsTol=single(1e-7));
            testCase.verifyFalse(repeated.DictionaryChanged);
            testCase.verifyEqual(before.datenum, after.datenum, AbsTol=0);
            testCase.verifyFalse(dictionary.HasUnsavedChanges);
        end

        function failedSyncRollsBackPendingTypeChanges(testCase)
            first = mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true);
            dictionary = first.DictionaryConnection;
            section = getSection(dictionary, 'Design Data');
            typeEntry = getEntry(section, 'McSingle_T');
            drift = getValue(typeEntry);
            drift.BaseType = 'double';
            setValue(typeEntry, drift);
            setValue(getEntry(section, 'tMcDrive_Param'), uint32(23));
            addEntry(section, 'UnrelatedSavedValue', single(7.5));
            saveChanges(dictionary);
            before = dir(testCase.DictionaryFile);

            testCase.verifyError(@() mc_initialize( ...
                OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true), ...
                'mc:InvalidParameter');
            after = dir(testCase.DictionaryFile);

            testCase.verifyEqual(getValue(typeEntry).BaseType, 'double');
            testCase.verifyEqual(getValue(getEntry(section, 'tMcDrive_Param')), uint32(23));
            testCase.verifyEqual(getValue(getEntry(section, 'UnrelatedSavedValue')), ...
                single(7.5), AbsTol=single(0));
            testCase.verifyEqual(before.datenum, after.datenum, AbsTol=0);
            testCase.verifyFalse(dictionary.HasUnsavedChanges);
        end

        function seedsFrameworkParametersFromAlgorithmDefaults(testCase)
            info = mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true);
            section = getSection(info.DictionaryConnection, 'Design Data');
            p = mc.defaults();

            testCase.verifyEqual(info.ControlParameter.DataType, 'Bus: tMcControlParams');
            testCase.verifyEqual(info.PlantParameter.DataType, 'Bus: tMcControlParams');
            testCase.verifyEqual(info.RuntimeParameter.DataType, 'Bus: tMcRuntime');
            testCase.verifyEqual(info.InputParameter.DataType, 'Bus: tMcInput');
            testCase.verifyEqual(info.ControlParameter.Value, p);
            testCase.verifyEqual(info.PlantParameter.Value, p);
            testCase.verifyEqual(info.RuntimeParameter.Value, mc.initial_state(p));
            testCase.verifyEqual(info.InputParameter.Value, mc.default_input(p));
            testCase.verifyEqual(getValue(getEntry(section, 'McControl_Params')), info.ControlParameter);
            testCase.verifyEqual(getValue(getEntry(section, 'McPlant_Params')), info.PlantParameter);
            testCase.verifyEqual(getValue(getEntry(section, 'McRuntime_Init')), info.RuntimeParameter);
            testCase.verifyEqual(getValue(getEntry(section, 'McInput_Default')), info.InputParameter);
        end

        function defaultReadRetainsFrameworkCalibrations(testCase)
            first = mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true);
            section = getSection(first.DictionaryConnection, 'Design Data');
            control = first.ControlParameter;
            plant = first.PlantParameter;
            runtime = first.RuntimeParameter;
            input = first.InputParameter;
            control.Value.CurrentLimit = single(4);
            plant.Value.Rs = single(0.75);
            runtime.Value.Direction = single(-1);
            input.Value.Vdc = single(13);
            setValue(getEntry(section, 'McControl_Params'), control);
            setValue(getEntry(section, 'McPlant_Params'), plant);
            setValue(getEntry(section, 'McRuntime_Init'), runtime);
            setValue(getEntry(section, 'McInput_Default'), input);
            saveChanges(first.DictionaryConnection);

            actual = mc_initialize(OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile);

            testCase.verifyEqual(actual.ControlParameter.Value.CurrentLimit, single(4), AbsTol=single(0));
            testCase.verifyEqual(actual.ControlParameter.Value.Rs, single(0.56), AbsTol=single(1e-7));
            testCase.verifyEqual(actual.PlantParameter.Value.Rs, single(0.75), AbsTol=single(1e-7));
            testCase.verifyEqual(actual.RuntimeParameter.Value.Direction, single(-1), AbsTol=single(0));
            testCase.verifyEqual(actual.InputParameter.Value.Vdc, single(13), AbsTol=single(0));
            testCase.verifyFalse(actual.DictionaryChanged);
            testCase.verifyFalse(actual.DictionaryConnection.HasUnsavedChanges);
        end

        function rejectsSynchronizationOutsideOwnedDirectories(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.verifyError(@() mc_initialize( ...
                OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=fullfile(root, 'tools', 'generate_data_type_from_md.m'), ...
                SyncDictionary=true), 'mc:DictionaryOutsideOwnedDirectories');
        end

        function refusesToWriteReferencedDictionaries(testCase)
            referenceFile = fullfile(testCase.OutputDirectory, 'Reference.sldd');
            reference = Simulink.data.dictionary.create(referenceFile);
            testCase.addTeardown(@() close(reference));
            section = getSection(reference, 'Design Data');
            addEntry(section, 'ReferenceValue', 42);
            saveChanges(reference);
            dictionary = Simulink.data.dictionary.create(testCase.DictionaryFile);
            addpath(testCase.OutputDirectory);
            addDataSource(dictionary, 'Reference.sldd');
            saveChanges(dictionary);

            testCase.verifyError(@() mc_initialize( ...
                OutputDirectory=testCase.OutputDirectory, ...
                Dictionary=testCase.DictionaryFile, SyncDictionary=true), ...
                'mc:ReferencedDictionary');
            testCase.verifyEqual(getValue(getEntry(section, 'ReferenceValue')), 42);
            testCase.verifyFalse(reference.HasUnsavedChanges);
        end
    end

    methods (Access=private)
        function closeDictionary(testCase)
            if isfile(testCase.DictionaryFile)
                dictionary = Simulink.data.dictionary.open(testCase.DictionaryFile);
                discardChanges(dictionary);
                close(dictionary);
            end
        end
    end
end
