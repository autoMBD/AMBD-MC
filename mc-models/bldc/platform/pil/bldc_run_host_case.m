function result = bldc_run_host_case(scenarioName,executionMode,outputDirectory,buildDirectory)
%bldc_run_host_case - Execute a complete Normal or actual PC SIL case
%   RESULT = bldc_run_host_case(NAME,MODE,OUT,BUILD) saves exact full-rate
%   input/output traces, physical checks and compiler/runtime evidence.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
if nargin<3,outputDirectory="";end
if nargin<4,buildDirectory="";end
scenarioName=string(scenarioName);executionMode=string(executionMode);
assert(isscalar(executionMode) && any(executionMode==["Normal","SIL"]), ...
    'bldc:ExecutionMode','Execution mode must be Normal or SIL.');
root=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
artifactRoot=string(fullfile(root,'.agent-env'));
if string(outputDirectory)==""
    outputDirectory=fullfile(artifactRoot,'bldc','acceptance',scenarioName,executionMode);
end
outputDirectory=string(java.io.File(char(outputDirectory)).getCanonicalPath());
assert(startsWith(lower(outputDirectory),lower(artifactRoot+filesep)), ...
    'bldc:OutputOutsideArtifactRoot','Reports must be below .agent-env.');
if ~isfolder(outputDirectory),mkdir(outputDirectory);end
result=struct('Scenario',scenarioName,'RequestedMode',executionMode,'Passed',false,'Status',"RUNNING");
writeResult(outputDirectory,result);
try
    info=bldc_initialize(OutputDirectory=buildDirectory);
    scenario=bldc_host_scenario(scenarioName);modelName=scenario.Model;
    open_system(modelName);
    references=find_system(char(modelName),'SearchDepth',1,'BlockType','ModelReference');
    initial=find_system(char(modelName),'SearchDepth',1,'BlockType','Constant','Name','InitialPlantState');
    assert(isscalar(references) && isscalar(initial),'bldc:HostContract','Controller and initial-state blocks must be unique.');
    reference=references{1};referenceMode='Normal';
    if executionMode=="SIL",referenceMode='Software-in-the-loop (SIL)';end
    in=Simulink.SimulationInput(modelName);
    in=in.setExternalInput(scenario.Inputs);
    in=in.setModelParameter('StopTime',num2str(scenario.Duration,17), ...
        'SimulationMode','normal','SaveOutput','on','OutputSaveName','yout', ...
        'SaveFormat','Dataset','SaveTime','on','TimeSaveName','tout', ...
        'LimitDataPoints','off','Decimation','1','ReturnWorkspaceOutputs','on');
    in=in.setBlockParameter(reference,'SimulationMode',referenceMode);
    in=in.setBlockParameter(initial{1},'Value',mat2str(scenario.PlantInitial,17));
    in=in.setVariable('BldcControl_Params',parameter(scenario.Control,'tBldcParams'));
    in=in.setVariable('BldcPlant_Params',parameter(scenario.Plant,'tBldcParams'));
    in=in.setVariable('BldcRuntime_Init',parameter(bldc.initial_state(scenario.Control),'tBldcRuntime'));
    in=in.setVariable('BldcInput_Default',parameter(bldc.default_input(scenario.Control),'tBldcInput')); %#ok<NASGU>
    failure=[];
    logText=evalc('try; out=sim(in); catch simulationError; failure=simulationError; end');
    logFile=fullfile(outputDirectory,'simulation.log');file=fopen(logFile,'w','n','UTF-8');
    assert(file>=0,'bldc:ReportWrite','Cannot write simulation log.');
    fprintf(file,'%s',logText);fclose(file);
    if ~isempty(failure),rethrow(failure);end
    trace=bldc_read_trace(out,"host");assessment=bldc_assess_host_trace(trace,scenario);
    result.Model=modelName;result.ControllerReference=string(get_param(reference,'ModelName'));
    result.ReferenceBlock=string(reference);result.SILExecutionEvidence= ...
        contains(logText,'Starting SIL simulation') || contains(logText,'SIL simulation for component') ...
        || ~isempty(regexp(logText,'(启动|开始)[^\n]*SIL|SIL[^\n]*仿真[^\n]*组件','once'));
    if executionMode=="SIL"
        assert(result.SILExecutionEvidence,'bldc:MissingSILEvidence','No executed SIL evidence in runtime log.');
    end
    result.Assessment=assessment;result.Samples=numel(trace.Time);result.MATLAB=string(version);
    result.TraceFile=fullfile(outputDirectory,'trace.mat');result.LogFile=logFile;
    result.Passed=assessment.Passed;result.Status="FAILED";
    if result.Passed,result.Status="PASS";end
    metadata=out.SimulationMetadata;
    save(result.TraceFile,'trace','scenario','metadata','assessment','-v7.3');
    writeResult(outputDirectory,result);
    fprintf('BLDC_CASE %s/%s: %d, samples=%d, peakCurrent=%.4g A\n', ...
        scenarioName,executionMode,result.Passed,result.Samples,assessment.PeakCurrent);
    % Retain the dictionary connection through model execution.
    assert(~isempty(info.DictionaryConnection));
catch exception
    result.Passed=false;result.Status="FAILED";result.ErrorIdentifier=string(exception.identifier);
    result.ErrorMessage=string(exception.message);writeResult(outputDirectory,result);rethrow(exception);
end
end

function value=parameter(data,bus)
value=Simulink.Parameter;value.Value=data;value.DataType=['Bus: ',bus];
end

function writeResult(folder,result)
file=fopen(fullfile(folder,'result.json'),'w','n','UTF-8');
assert(file>=0,'bldc:ReportWrite','Cannot write case result.');
cleanup=onCleanup(@()fclose(file));
fprintf(file,'%s',jsonencode(result,PrettyPrint=true));
end
