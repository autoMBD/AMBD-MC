classdef bldcInitializeTest < matlab.unittest.TestCase
    %bldcInitializeTest - Verify isolated BLDC type and dictionary startup

    % SPDX-License-Identifier: MIT
    % Copyright (c) 2026 autoMBD
    properties
        Root
        Folder
        Dictionary
    end
    properties (TestParameter)
        invalidCalibration = struct( ...
            'zeroDivider',struct('Field','SpeedDivider','Value',uint16(0)), ...
            'zeroPeriod',struct('Field','PwmPeriod','Value',uint16(0)), ...
            'invalidMode',struct('Field','PositionMode','Value',uint8(2)), ...
            'nonfinite',struct('Field','Rs','Value',single(NaN)), ...
            'zeroTrackingTimeout',struct('Field','TrackingTimeout','Value',single(0)), ...
            'voltageOrder',struct('Field','VdcMin','Value',single(12)), ...
            'currentOrder',struct('Field','CurrentLimit','Value',single(10)), ...
            'modulationRange',struct('Field','MaxModulation','Value',single(1.01)), ...
            'filterRange',struct('Field','SpeedFilterAlpha','Value',single(0)), ...
            'fractionalOffset',struct('Field','AdcOffset','Value',single(32768.5)))
    end
    methods (TestMethodSetup)
        function arrange(test)
            test.Root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            test.Folder = string(tempname(fullfile(test.Root,'.agent-env')));
            mkdir(test.Folder);
            test.applyFixture(matlab.unittest.fixtures.PathFixture(test.Folder));
            test.Dictionary = fullfile(test.Folder,'Fixture.sldd');
            test.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(test.Root,'mc-models','bldc')));
            test.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(test.Root,'mc-models','bldc','algo')));
            original = Simulink.fileGenControl('getConfig');
            test.addTeardown(@() Simulink.fileGenControl('setConfig', ...
                'config',original));
            test.addTeardown(@() closeFixture(test.Dictionary));
        end
    end
    methods (Test)
        function initializerExists(test)
            test.verifyEqual(exist('bldc_initialize','file'),2);
        end
        function createsIndependentTypedDefaults(test)
            info = test.initialize(true);
            test.verifyEqual(info.ControlParameter.DataType,'Bus: tBldcParams');
            test.verifyEqual(info.ControlParameter.Value,bldc.defaults());
            test.verifyEqual(info.PlantParameter.Value,bldc.defaults());
            test.verifyEqual(info.RuntimeParameter.Value,bldc.initial_state(bldc.defaults()));
            test.verifyEqual(info.InputParameter.Value,bldc.default_input(bldc.defaults()));
            test.verifyTrue(isfield(info.Types,'tBldcDebug'));
            test.verifyTrue(isfield(info.Types,'tBldcMonitor'));
            test.verifyEmpty(info.DictionaryConnection.DataSources);
        end
        function idempotentStartupPreservesCalibration(test)
            info = test.initialize(true);
            section = getSection(info.DictionaryConnection,'Design Data');
            p = info.ControlParameter;p.Value.KpCurrent=single(4);
            setValue(getEntry(section,'BldcControl_Params'),p);
            addEntry(section,'UserValue',uint32(42));
            saveChanges(info.DictionaryConnection);
            again = test.initialize(false);
            test.verifyEqual(again.ControlParameter.Value.KpCurrent,single(4));
            test.verifyFalse(again.DictionaryChanged);
            reset = test.initialize(true);
            test.verifyEqual(reset.ControlParameter.Value,bldc.defaults());
            test.verifyEqual(getValue(getEntry(section,'UserValue')),uint32(42));
            twice = test.initialize(true);
            test.verifyFalse(twice.DictionaryChanged);
        end
        function busPrototypesMatchNativeInterfaces(test)
            info=test.initialize(true);
            runtime=Simulink.Bus.createMATLABStruct('tBldcRuntime',[],1,info.DictionaryConnection);
            input=Simulink.Bus.createMATLABStruct('tBldcInput',[],1,info.DictionaryConnection);
            test.verifyEqual(fieldnames(runtime),fieldnames(bldc.initial_state(bldc.defaults())));
            test.verifyEqual(fieldnames(runtime.Parameters),fieldnames(bldc.defaults()));
            test.verifySize(input.CurrentRaw,[3 1]);
            test.verifySize(input.TerminalVoltage,[3 1]);
            test.verifyClass(input.CurrentRaw,'uint16');
            test.verifyClass(runtime.Current,'single');
            test.verifySize(runtime.Current,[3 1]);
            verifyInterface(test,runtime,bldc.initial_state(bldc.defaults()));
            verifyInterface(test,input,bldc.default_input(bldc.defaults()));
            [~,~,~,debug,monitor]=bldc.monitor(bldc.initial_state(bldc.defaults()),bldc.defaults());
            verifyInterface(test,Simulink.Bus.createMATLABStruct( ...
                'tBldcDebug',[],1,info.DictionaryConnection),debug);
            verifyInterface(test,Simulink.Bus.createMATLABStruct( ...
                'tBldcMonitor',[],1,info.DictionaryConnection),monitor);
        end
        function committedGeneratedSourceMatchesMarkdown(test)
            info=test.initialize(true);
            committed=fileread(fullfile(test.Root,'mc-models','bldc','data','bldc_data_types.m'));
            generated=fileread(info.GeneratedTypeFile);
            committed=strrep(committed,char([13 10]),char(10));
            generated=strrep(generated,char([13 10]),char(10));
            test.verifyEqual(regexprep(committed,'% Date:[^\n]*',''), ...
                regexprep(generated,'% Date:[^\n]*',''));
            test.verifyFalse(contains(generated,test.Root));
            test.verifyTrue(contains(generated,'docs/BldcStruct.md'));
        end
        function missingDictionaryRequiresExplicitSync(test)
            test.verifyError(@() test.initialize(false),'bldc:MissingDictionary');
        end
        function dirtyDictionaryRefused(test)
            info = test.initialize(true);
            section=getSection(info.DictionaryConnection,'Design Data');
            addEntry(section,'UnsavedUserValue',42);
            test.verifyError(@() test.initialize(true),'bldc:DirtyDictionary');
            test.verifyEqual(getValue(getEntry(section,'UnsavedUserValue')),42);
        end
        function typeDriftFailsWithoutRepair(test)
            info=test.initialize(true);section=getSection(info.DictionaryConnection,'Design Data');
            bus=info.Types.tBldcInput;bus.Elements(1).Dimensions=2;
            setValue(getEntry(section,'tBldcInput'),bus);saveChanges(info.DictionaryConnection);
            test.verifyError(@() test.initialize(false),'bldc:TypeMismatch');
            test.verifyEqual(getValue(getEntry(section,'tBldcInput')),bus);
            test.verifyFalse(info.DictionaryConnection.HasUnsavedChanges);
        end
        function invalidCalibrationRejected(test)
            info=test.initialize(true);section=getSection(info.DictionaryConnection,'Design Data');
            p=info.ControlParameter;p.Value.Ls=single(-1);
            setValue(getEntry(section,'BldcControl_Params'),p);saveChanges(info.DictionaryConnection);
            test.verifyError(@() test.initialize(false),'bldc:InvalidCalibration');
            test.verifyEqual(getValue(getEntry(section,'BldcControl_Params')),p);
        end
        function wrongShapeRejectedWithoutCoercion(test)
            info=test.initialize(true);section=getSection(info.DictionaryConnection,'Design Data');
            p=info.InputParameter;p.Value.CurrentRaw=p.Value.CurrentRaw';
            setValue(getEntry(section,'BldcInput_Default'),p);saveChanges(info.DictionaryConnection);
            test.verifyError(@() test.initialize(false),'bldc:InvalidParameterShape');
        end
        function calibrationConstraintsRejectInvalidValues(test,invalidCalibration)
            info=test.initialize(true);section=getSection(info.DictionaryConnection,'Design Data');
            p=info.PlantParameter;
            p.Value.(invalidCalibration.Field)=invalidCalibration.Value;
            setValue(getEntry(section,'BldcPlant_Params'),p);saveChanges(info.DictionaryConnection);
            test.verifyError(@() test.initialize(false),'bldc:InvalidCalibration');
        end
        function wrongTypeRejectedWithoutCoercion(test)
            info=test.initialize(true);section=getSection(info.DictionaryConnection,'Design Data');
            p=info.ControlParameter;p.Value.Ts=double(p.Value.Ts);
            setValue(getEntry(section,'BldcControl_Params'),p);saveChanges(info.DictionaryConnection);
            test.verifyError(@() test.initialize(false),'bldc:InvalidParameterShape');
        end
        function syncRollbackPreservesOriginalEntries(test)
            info=test.initialize(true);section=getSection(info.DictionaryConnection,'Design Data');
            bus=info.Types.tBldcInput;bus.Elements(1).Dimensions=2;
            setValue(getEntry(section,'tBldcInput'),bus);
            setValue(getEntry(section,'BldcControl_Params'),42);saveChanges(info.DictionaryConnection);
            test.verifyError(@() test.initialize(true),'bldc:InvalidParameter');
            test.verifyEqual(getValue(getEntry(section,'tBldcInput')),bus);
            test.verifyFalse(info.DictionaryConnection.HasUnsavedChanges);
        end
        function externalDictionarySyncRefused(test)
            test.verifyError(@() bldc_initialize(Dictionary=fullfile(test.Root, ...
                'foreign.sldd'),SyncDictionary=true),'bldc:DictionaryOutsideOwnedDirectories');
        end
        function referencedDictionarySyncRefused(test)
            info=test.initialize(true);
            other=Simulink.data.dictionary.create(char(fullfile(test.Folder,'Other.sldd')));
            test.addTeardown(@() close(other));
            addDataSource(info.DictionaryConnection,'Other.sldd');
            saveChanges(info.DictionaryConnection);
            test.verifyError(@() test.initialize(true),'bldc:ReferencedDictionary');
        end
    end
    methods
        function info=initialize(test,sync)
            info=bldc_initialize(Dictionary=test.Dictionary, ...
                OutputDirectory=fullfile(test.Folder,'generated'),SyncDictionary=sync);
        end
    end
end

function closeFixture(file)
if isfile(file)
    dictionary=Simulink.data.dictionary.open(char(file));
    discardChanges(dictionary);close(dictionary);
end
end

function verifyInterface(test,actual,expected)
test.verifyClass(actual,class(expected));
test.verifySize(actual,size(expected));
if isstruct(expected)
    fields=fieldnames(expected);
    test.assertEqual(fieldnames(actual),fields);
    for index=1:numel(fields)
        verifyInterface(test,actual.(fields{index}),expected.(fields{index}));
    end
end
end
