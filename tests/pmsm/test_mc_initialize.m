classdef test_mc_initialize < matlab.unittest.TestCase
    %test_mc_initialize - Verify PMSM initialization and dictionary ownership

    % SPDX-License-Identifier: MIT
    % Copyright (c) 2026 autoMBD

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
