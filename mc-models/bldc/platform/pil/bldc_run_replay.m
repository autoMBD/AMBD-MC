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
% File:        bldc_run_replay.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Replay captured controller inputs in Normal and PC SIL
% =================================================================================

function result = bldc_run_replay(sourceFile,outputDirectory,buildDirectory)
%bldc_run_replay - Replay captured controller inputs in Normal and PC SIL
%   RESULT = bldc_run_replay(SOURCE,OUT,BUILD) also checks exact alignment
%   with the recorded Normal controller output before comparing SIL.

if nargin<3,buildDirectory="";end
root=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
artifactRoot=string(fullfile(root,'.agent-env'));
outputDirectory=string(java.io.File(char(outputDirectory)).getCanonicalPath());
assert(startsWith(lower(outputDirectory),lower(artifactRoot+filesep)), ...
    'bldc:OutputOutsideArtifactRoot','Replay artifacts must be below .agent-env.');
if ~isfolder(outputDirectory),mkdir(outputDirectory);end
result=struct('Passed',false,'Status',"RUNNING",'SourceTrace',string(sourceFile));
writeResult(outputDirectory,result);
try
    info=bldc_initialize(OutputDirectory=buildDirectory);
    source=load(sourceFile,'trace','scenario');scenario=source.scenario;
    names={'CurrentRaw','Hall','TerminalVoltage','Control','Fault','CommandEvent', ...
        'DrivingEvent','TimerEvent','SpeedReq','Vdc','AppliedSector','AppliedDirection','VoltageValid'};
    assert(all(isfield(source.trace.Input,names)),'bldc:RecordedInputs','Missing actual recorded controller input.');
    inputs=Simulink.SimulationData.Dataset;
    for k=1:numel(names)
        signal=timeseries(source.trace.Input.(names{k}),source.trace.Time,'Name',names{k});
        signal=setinterpmethod(signal,'zoh');inputs=addElement(inputs,signal,names{k});
    end
    model="BLDC_SIL_Replay";addpath(fullfile(root,'.agent-env','bldc-models'));open_system(model);
    references=find_system(char(model),'SearchDepth',1,'BlockType','ModelReference');
    assert(isscalar(references),'bldc:ReplayContract','Expected one replay controller reference.');
    traces=cell(1,2);evidence=false(1,2);modes={'Normal','Software-in-the-loop (SIL)'};
    for k=1:2
        in=Simulink.SimulationInput(model);
        in=in.setExternalInput(inputs);
        in=in.setModelParameter('StopTime',num2str(scenario.Duration,17),'SimulationMode','normal', ...
            'SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset', ...
            'SaveTime','on','TimeSaveName','tout','LimitDataPoints','off', ...
            'Decimation','1','ReturnWorkspaceOutputs','on');
        in=in.setBlockParameter(references{1},'SimulationMode',modes{k});
        in=in.setVariable('BldcControl_Params',parameter(scenario.Control,'tBldcParams'));
        in=in.setVariable('BldcRuntime_Init',parameter(bldc.initial_state(scenario.Control),'tBldcRuntime'));
        in=in.setVariable('BldcInput_Default',parameter(bldc.default_input(scenario.Control),'tBldcInput')); %#ok<NASGU>
        failure=[];logText=evalc('try; out=sim(in); catch simulationError; failure=simulationError; end');
        mode="Normal";if k==2,mode="SIL";end
        file=fopen(fullfile(outputDirectory,mode+'.log'),'w','n','UTF-8');
        assert(file>=0,'bldc:ReportWrite','Cannot write replay log.');fprintf(file,'%s',logText);fclose(file);
        if ~isempty(failure),rethrow(failure);end
        evidence(k)=contains(logText,'Starting SIL simulation') || contains(logText,'SIL simulation for component') ...
            || ~isempty(regexp(logText,'(启动|开始)[^\n]*SIL|SIL[^\n]*仿真[^\n]*组件','once'));
        traces{k}=bldc_read_trace(out,"replay");
    end
    assert(evidence(2),'bldc:MissingSILEvidence','Replay did not execute actual SIL.');
    alignment=bldc_compare_outputs(source.trace,traces{1});
    comparison=bldc_compare_outputs(traces{1},traces{2});
    result.Scenario=scenario.Name;result.Model=model;
    result.ControllerReference=string(get_param(references{1},'ModelName'));
    result.Samples=numel(source.trace.Time);result.SILExecutionEvidence=evidence(2);
    result.RecordedNormalAlignment=alignment;result.NormalVersusSIL=comparison;
    result.StrictBitwisePassed=alignment.StrictBitwisePassed && comparison.StrictBitwisePassed;
    result.Passed=alignment.StrictBitwisePassed && comparison.Passed;
    result.Status="FAILED";if result.Passed,result.Status="PASS";end
    normal=traces{1};sil=traces{2};save(fullfile(outputDirectory,'traces.mat'),'normal','sil','scenario','-v7.3');
    writeResult(outputDirectory,result);
    assert(~isempty(info.DictionaryConnection));
    fprintf('BLDC_REPLAY %s: passed=%d, strict=%d, samples=%d\n', ...
        scenario.Name,result.Passed,result.StrictBitwisePassed,result.Samples);
catch exception
    result.Passed=false;result.Status="FAILED";result.ErrorMessage=string(exception.message);
    writeResult(outputDirectory,result);rethrow(exception);
end
end

function value=parameter(data,bus)
value=Simulink.Parameter;value.Value=data;value.DataType=['Bus: ',bus];
end

function writeResult(folder,result)
file=fopen(fullfile(folder,'result.json'),'w','n','UTF-8');
assert(file>=0,'bldc:ReportWrite','Cannot write replay result.');
cleanup=onCleanup(@()fclose(file));fprintf(file,'%s',jsonencode(result,PrettyPrint=true));
end
