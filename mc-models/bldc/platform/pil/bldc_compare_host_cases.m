function result = bldc_compare_host_cases(normalFile,silFile,outputDirectory)
%bldc_compare_host_cases - Bound drift between independently evolving loops
%   RESULT = bldc_compare_host_cases(NORMAL,SIL,OUT) saves metrics and a
%   trace plot. Same-input replay remains a separate, stricter gate.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
root=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
outputDirectory=string(java.io.File(char(outputDirectory)).getCanonicalPath());
assert(startsWith(lower(outputDirectory),lower(string(fullfile(root,'.agent-env'))+filesep)), ...
    'bldc:OutputOutsideArtifactRoot','Comparison output must be below .agent-env.');
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
