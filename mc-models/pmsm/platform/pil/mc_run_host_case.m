function result = mc_run_host_case(modelName,scenarioName,executionMode,outputDirectory,buildDirectory)
%MC_RUN_HOST_CASE Run a finite Normal or real host SIL closed-loop scenario.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
arguments
    modelName (1,1) string {mustBeMember(modelName, ...
        ["FOC_PIL_Algth_top","FOC_PIL_StateMch_top"])}
    scenarioName (1,1) string
    executionMode (1,1) string {mustBeMember(executionMode,["Normal","SIL"])}
    outputDirectory (1,1) string = ""
    buildDirectory (1,1) string = ""
end
info=mc_initialize(OutputDirectory=buildDirectory);
artifactRoot=fullfile(info.RepositoryRoot,'.agent-env');
if outputDirectory==""
    outputDirectory=fullfile(artifactRoot,'pmsm','acceptance',modelName,scenarioName,executionMode);
end
outputDirectory=string(java.io.File(char(outputDirectory)).getCanonicalPath());
assert(startsWith(lower(outputDirectory),lower(artifactRoot+filesep)), ...
    'mc:OutputOutsideArtifactRoot','Validation artifacts must be below .agent-env.');
if ~isfolder(outputDirectory),mkdir(outputDirectory);end
scenario=mc_host_scenario(scenarioName);
load_system(modelName);
references=find_system(char(modelName),'SearchDepth',1,'BlockType','ModelReference');
assert(isscalar(references),'mc:ReferenceContract','Expected one controller Model block.');
reference=references{1};
if executionMode=="SIL",referenceMode='Software-in-the-loop (SIL)';
else,referenceMode='Normal';end

in=Simulink.SimulationInput(modelName);
in=in.setExternalInput(scenario.Inputs);
in=in.setModelParameter('StopTime',num2str(scenario.Duration,17), ...
    'SimulationMode','normal','SaveOutput','on','OutputSaveName','yout', ...
    'SaveFormat','Dataset','SaveTime','on','TimeSaveName','tout', ...
    'LimitDataPoints','off','Decimation','1','ReturnWorkspaceOutputs','on');
in=in.setBlockParameter(reference,'SimulationMode',referenceMode);
in=in.setVariable('McControl_Params',parameter(scenario.Control,'tMcControlParams'));
in=in.setVariable('McPlant_Params',parameter(scenario.Plant,'tMcControlParams'));
in=in.setVariable('McRuntime_Init',parameter(mc.initial_state(scenario.Control),'tMcRuntime'));
% The configured input is consumed inside the command-window capture below.
in=in.setVariable('McInput_Default',parameter(mc.default_input(scenario.Control),'tMcInput')); %#ok<NASGU>
result=struct('Model',modelName,'Scenario',scenarioName,'RequestedMode',executionMode, ...
    'ControllerReference',string(get_param(reference,'ModelName')), ...
    'ReferenceBlock',string(reference),'Passed',false);
diaryFile=fullfile(outputDirectory,'simulation.log');
% MCP already captures the command window, so diary alone may be empty.
% A local capture preserves the actual compiler and SIL execution transcript.
simulationError=[];
logText=evalc('try; out=sim(in); catch caughtError; simulationError=caughtError; end');
logFile=fopen(diaryFile,'w','n','UTF-8');
assert(logFile>=0,'mc:ReportOpen','Cannot open simulation transcript.');
fprintf(logFile,'%s',logText);fclose(logFile);
if ~isempty(simulationError)
    exception=simulationError;
    result.ErrorIdentifier=string(exception.identifier);
    result.ErrorMessage=string(exception.message);
    writeResult(outputDirectory,result);
    rethrow(exception);
end
trace=mc_read_host_trace(out);
assessment=mc_assess_host_trace(trace,scenario);
result.Passed=assessment.Passed;
result.Assessment=assessment;
result.Samples=numel(trace.Time);
result.MATLAB=string(version);
result.TraceFile=fullfile(outputDirectory,'trace.mat');
result.LogFile=diaryFile;
result.SILExecutionEvidence=contains(logText,'Starting SIL simulation') ...
    || contains(logText,'SIL simulation for component') ...
    || ~isempty(regexp(logText,'(启动|开始)[^\n]*SIL|SIL[^\n]*仿真[^\n]*组件','once'));
if executionMode=="SIL"
    assert(result.SILExecutionEvidence,'mc:MissingSILEvidence', ...
        'Requested SIL but runtime log does not show SIL execution.');
end
metadata=out.SimulationMetadata;
save(result.TraceFile,'trace','scenario','metadata','assessment','-v7.3');
writeResult(outputDirectory,result);
fprintf('AMBD_CASE %s/%s/%s: %d, samples=%d, peakCurrent=%.4g A\n', ...
    modelName,scenarioName,executionMode,result.Passed,result.Samples,assessment.PeakCurrent);
end

function value=parameter(data,bus)
value=Simulink.Parameter;
value.Value=data;
value.DataType=['Bus: ',bus];
end

function writeResult(folder,result)
file=fopen(fullfile(folder,'result.json'),'w','n','UTF-8');
assert(file>=0,'mc:ReportOpen','Cannot open validation report.');
cleanup=onCleanup(@() fclose(file));
fprintf(file,'%s',jsonencode(result,PrettyPrint=true));
end
