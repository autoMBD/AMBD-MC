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
% File:        bldc_compare_host_cases.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Bound drift between independently evolving loops
% =================================================================================

function result = bldc_compare_host_cases(normalFile,silFile,outputDirectory)
%bldc_compare_host_cases - Bound drift between independently evolving loops
%   RESULT = bldc_compare_host_cases(NORMAL,SIL,OUT) saves metrics and a
%   trace plot. Same-input replay remains a separate, stricter gate.

root=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
outputDirectory=string(java.io.File(char(outputDirectory)).getCanonicalPath());
assert(startsWith(lower(outputDirectory),lower(string(fullfile(root,'.agent-env'))+filesep)), ...
    'bldc:OutputOutsideArtifactRoot','Comparison output must be below .agent-env.');
addpath(fullfile(root,'tools'));
ambd_claim_directory(root,outputDirectory);
if ~isfolder(outputDirectory),mkdir(outputDirectory);end
result=struct('Passed',false,'Status',"RUNNING");writeResult(outputDirectory,result);
try
normal=load(normalFile,'trace','scenario');sil=load(silFile,'trace');
a=normal.trace;b=sil.trace;result.Scenario=normal.scenario.Name;
result.TimeExactlyEqual=isequal(a.Time,b.Time);
assert(result.TimeExactlyEqual,'bldc:ClosedLoopTime','Closed-loop time vectors differ.');
result.SpeedMaxDifference=max(abs(double(a.OmegaTruth)-double(b.OmegaTruth)),[],'all');
result.CurrentMaxDifference=max(abs(double(a.CurrentTruth)-double(b.CurrentTruth)),[],'all');
result.ModulationMaxDifference=max(abs(double(a.Modulation)-double(b.Modulation)),[],'all');
result.FaultOutputsEqual=isequal(a.FaultBits,b.FaultBits);
result.GateMismatchSamples=sum(a.GateOutput~=b.GateOutput);
result.MaskMismatchSamples=sum(any(a.PhaseMask~=b.PhaseMask,2));
result.ModeMismatchSamples=sum(a.Mode~=b.Mode);
passed=result.SpeedMaxDifference<=1 && result.CurrentMaxDifference<=.1 ...
    && result.ModulationMaxDifference<=.001 && result.FaultOutputsEqual ...
    && result.GateMismatchSamples==0 && result.MaskMismatchSamples==0 && result.ModeMismatchSamples==0;
figureHandle=figure('Visible','off','Position',[100,100,1300,850]);
cleanup=onCleanup(@()close(figureHandle));tiledlayout(2,2);
nexttile;plot(a.Time,a.OmegaTruth,b.Time,b.OmegaTruth,'--',normal.scenario.Time,normal.scenario.Speed,':');
xlabel('Time (s)');ylabel('Electrical speed (rad/s)');legend('Normal','SIL','Request');grid on;
nexttile;plot(a.Time,max(abs(a.CurrentTruth),[],2),b.Time,max(abs(b.CurrentTruth),[],2),'--');
xlabel('Time (s)');ylabel('Peak phase current magnitude (A)');grid on;
nexttile;stairs(a.Time,a.Mode);hold on;stairs(b.Time,b.Mode,'--');
xlabel('Time (s)');ylabel('Lifecycle state');grid on;
nexttile;plot(a.Time,double(a.Modulation)-double(b.Modulation));
xlabel('Time (s)');ylabel('Normal minus SIL modulation');grid on;
sgtitle(strrep(char(normal.scenario.Name),'_',' '));
result.Plot=fullfile(outputDirectory,'closed-loop.png');exportgraphics(figureHandle,result.Plot,Resolution=140);
result.Passed=passed;result.Status="FAILED";if passed,result.Status="PASS";end
writeResult(outputDirectory,result);
catch exception
    result.Passed=false;result.Status="FAILED";result.ErrorMessage=string(exception.message);
    writeResult(outputDirectory,result);rethrow(exception);
end
end

function writeResult(folder,result)
file=fopen(fullfile(folder,'result.json'),'w','n','UTF-8');
assert(file>=0,'bldc:ReportWrite','Cannot write closed-loop comparison.');
fileCleanup=onCleanup(@()fclose(file));fprintf(file,'%s',jsonencode(result,PrettyPrint=true));
end
