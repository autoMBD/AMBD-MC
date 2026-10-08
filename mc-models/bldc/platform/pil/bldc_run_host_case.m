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
% File:        bldc_run_host_case.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Execute a complete Normal or actual PC SIL case
% =================================================================================

function result = bldc_run_host_case(scenarioName,executionMode,outputDirectory,buildDirectory)
%bldc_run_host_case - Execute a complete Normal or actual PC SIL case
%   RESULT = bldc_run_host_case(NAME,MODE,OUT,BUILD) saves exact full-rate
%   input/output traces, physical checks and compiler/runtime evidence.

if nargin<3,outputDirectory="";end
if nargin<4,buildDirectory="";end
scenarioName=string(scenarioName);executionMode=string(executionMode);
assert(isscalar(executionMode) && any(executionMode==["Normal","SIL"]), ...
    'bldc:ExecutionMode','Execution mode must be Normal or SIL.');
root=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
artifactRoot=string(fullfile(root,'.agent-env'));
addpath(fullfile(root,'tools'));
if string(outputDirectory)==""
    outputDirectory=fullfile(ambd_instance_root(root),'bldc','acceptance',scenarioName,executionMode);
end
outputDirectory=string(java.io.File(char(outputDirectory)).getCanonicalPath());
assert(startsWith(lower(outputDirectory),lower(artifactRoot+filesep)), ...
    'bldc:OutputOutsideArtifactRoot','Reports must be below .agent-env.');
ambd_claim_directory(root,outputDirectory);
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
