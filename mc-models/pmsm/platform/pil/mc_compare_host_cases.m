function result = mc_compare_host_cases(normalFile,silFile,outputDirectory)
%mc_compare_host_cases - Compare and plot independent host closed-loop runs
%   RESULT = mc_compare_host_cases(NORMALFILE,SILFILE,OUTPUTDIRECTORY)
%   checks matched time grids and bounded physical drift, and saves a PNG
%   and JSON report below .agent-env. Same-input replay is a separate gate.
%   See also mc_run_host_case, mc_compare_replay

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
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
