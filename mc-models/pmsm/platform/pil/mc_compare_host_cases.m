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
% File:        mc_compare_host_cases.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Compare and plot independent host closed-loop runs
% =================================================================================

function result = mc_compare_host_cases(normalFile,silFile,outputDirectory)
%mc_compare_host_cases - Compare and plot independent host closed-loop runs
%   RESULT = mc_compare_host_cases(NORMALFILE,SILFILE,OUTPUTDIRECTORY)
%   checks matched time grids and bounded physical drift, and saves a PNG
%   and JSON report below .agent-env. Same-input replay is a separate gate.
%   See also mc_run_host_case, mc_compare_replay

arguments
    normalFile (1,1) string
    silFile (1,1) string
    outputDirectory (1,1) string
end
repo=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
artifactRoot=string(java.io.File(fullfile(repo,'.agent-env')).getCanonicalPath());
outputDirectory=string(java.io.File(char(outputDirectory)).getCanonicalPath());
assert(startsWith(lower(outputDirectory),lower(artifactRoot+filesep)), ...
    'mc:OutputOutsideArtifactRoot','Comparison artifacts must be below .agent-env.');
addpath(fullfile(repo,'tools'));
ambd_claim_directory(repo,outputDirectory);
if ~isfolder(outputDirectory),mkdir(outputDirectory);end
a=load(normalFile,'trace','scenario','assessment');
b=load(silFile,'trace','scenario','assessment');
assert(a.scenario.Name==b.scenario.Name,'mc:ComparisonScenario','Scenarios must match.');
assert(isequal(a.trace.Time,b.trace.Time),'mc:ComparisonTime','Time grids must match.');
normal=a.trace;sil=b.trace;t=normal.Time;
result.Scenario=a.scenario.Name;
result.SpeedMaxDifference=max(abs(double(normal.OmegaTruth)-double(sil.OmegaTruth)));
result.CurrentMaxDifference=max(abs(double(normal.CurrentTruth)-double(sil.CurrentTruth)),[],'all');
result.DutyMaxDifference=max(abs(double(normal.Duty)-double(sil.Duty)),[],'all');
result.SpeedLimit=1; % One fifth of the smallest physical steady-error bound.
result.CurrentLimit=0.1; % One percent of the nominal 10-A trip level.
result.DutyLimit=0.01; % 1% normalized duty, below physical modulation limits.
result.FaultOutputsEqual=isequal(normal.FaultBits,sil.FaultBits);
result.GateMismatchSamples=nnz(normal.GateOutput~=sil.GateOutput);
result.ModeMismatchSamples=nnz(normal.Mode~=sil.Mode);
result.Passed=a.assessment.Passed && b.assessment.Passed ...
    && result.SpeedMaxDifference<=result.SpeedLimit ...
    && result.CurrentMaxDifference<=result.CurrentLimit ...
    && result.DutyMaxDifference<=result.DutyLimit && result.FaultOutputsEqual;
fig=figure('Visible','off','Color','w','Position',[100 100 1200 800]);
cleanup=onCleanup(@() close(fig));
layout=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
title(layout,strrep(a.scenario.Name,'_',' ') + " | independent closed loops");
nexttile;plot(t,normal.OmegaTruth,'LineWidth',1);hold on;
plot(t,sil.OmegaTruth,'--','LineWidth',1);plot(a.scenario.Time,a.scenario.Speed,':','Color',[.3 .3 .3]);
ylabel('Electrical speed (rad/s)');xlabel('Time (s)');grid on;
legend('Normal','SIL','Request','Location','best');
nexttile;plot(t,max(abs(normal.CurrentTruth),[],2),'LineWidth',1);hold on;
plot(t,max(abs(sil.CurrentTruth),[],2),'--','LineWidth',1);
ylabel('Peak phase magnitude (A)');xlabel('Time (s)');grid on;
legend('Normal','SIL','Location','best');
nexttile;plot(t,normal.Mode,'LineWidth',1);hold on;plot(t,sil.Mode,'--','LineWidth',1);
ylabel('Lifecycle state code');xlabel('Time (s)');ylim([-0.5 15.5]);grid on;
legend('Normal','SIL','Location','best');
nexttile;plot(t,double(normal.Duty(:,1))-double(sil.Duty(:,1)),'LineWidth',1);
ylabel('Phase-A duty: Normal minus SIL');xlabel('Time (s)');grid on;
result.Plot=fullfile(outputDirectory,'closed-loop.png');
exportgraphics(fig,result.Plot,'Resolution',140);
file=fopen(fullfile(outputDirectory,'result.json'),'w','n','UTF-8');
assert(file>=0,'mc:ReportOpen','Cannot open comparison report.');
fileCleanup=onCleanup(@() fclose(file));
fprintf(file,'%s',jsonencode(result,PrettyPrint=true));
assert(result.Passed,'mc:ClosedLoopDrift','Independent closed-loop drift exceeds the declared bound.');
end
