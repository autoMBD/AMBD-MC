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
% File:        compare_plant_reference.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Compare host plant with the native PMSM block
% =================================================================================

function report = compare_plant_reference()
%compare_plant_reference - Compare host plant with the native PMSM block
%   REPORT = compare_plant_reference() simulates the prepared native
%   reference model, compares five open-loop cases and checks convergence.
%   Run tools/pmsm/validate_plant_reference.py to prepare the model in a
%   fresh official MATLAB MCP session. Artifacts go below .agent-env.
%
%   See also Simulink.SimulationInput


repo = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
outdir = fullfile(repo,'.agent-env','pmsm-plant-validation');
addpath(fullfile(repo,'mc-models','pmsm','algo'));
clear mc.plant_step mc.plant_measure mc.defaults
rehash;
p = mc.defaults();
dt = 1/16000;
duration = .1;
t = (0:round(duration/dt))'*dt;
names = {'zero_equilibrium','positive_no_load','negative_no_load', ...
    'positive_loaded_initial_state','negative_loaded_initial_state'};
duties = [.5 .5 .5; .5 .7 .3; .5 .3 .7; .65 .6 .25; .35 .4 .75];
loads = [0 0 0 .015 -.015];
initials = [zeros(4,3) [.4;-.3;30;.7] [-.5;.6;-20;-.9]];
report = struct( ...
    'oracle','MathWorks autolibpmsminterior/Interior PMSM (Continuous)', ...
    'documentation','https://www.mathworks.com/help/autoblks/ref/interiorpmsm.html', ...
    'matlab',version,'dt_s',dt,'duration_s',duration,'parameters',p, ...
    'sample_alignment',['Both x(0) included; custom step k maps t(k) to t(k+1); ' ...
        'native ode4 outputs sampled every 16 or 32 exact solver steps; ' ...
        'no time shift or interpolation.'], ...
    'scope',['Gate-enabled averaged voltage only. Gate-off decay/coast is an ' ...
        'intentional abstraction, not validated by this oracle.'], ...
    'columns',{{'Ia_A','Ib_A','Ic_A','wm_rad_s','theta_e_rad','Id_A','Iq_A'}}, ...
    'absolute_tolerances',[1e-5 1e-5 1e-5 1e-4 1e-5 1e-5 1e-5], ...
    'tolerance_basis',['Current: 0.01 ADC count at 1000 count/A. ' ...
        'Angle: 0.000573 degrees. Speed: 0.0001 rad/s. ' ...
        'Allow single output rounding while staying below sensor resolution.']);
model = 'pmsm_native_reference';
motor = Simulink.ID.getFullName([model ':1']);
report.mask_parameters = get_param(motor,'MaskValues');
report.reference_block = get_param(motor,'ReferenceBlock');
allData = cell(numel(names),1);
for c = 1:numel(names)
    x0 = initials(:,c);
    duty = duties(c,:)';
    loadTorque = loads(c);
    phaseVoltage = 12*(duty-mean(duty));
    ref = cell(2,1);
    for r = 1:2
        divisor = 16*2^(r-1);
        in = Simulink.SimulationInput(model);
        in = in.setVariable('p',p).setVariable('x0',x0) ...
            .setVariable('phaseVoltage',phaseVoltage) ...
            .setVariable('loadTorque',loadTorque);
        in = in.setModelParameter('StopTime',num2str(duration,17), ...
            'SolverType','Fixed-step','Solver','ode4', ...
            'FixedStep',num2str(dt/divisor,17),'ReturnWorkspaceOutputs','on');
        out = sim(in);
        times = out.speed.Time;
        indices = 1:divisor:numel(times);
        assert(numel(indices)==numel(t),'Native sample count mismatch.');
        assert(max(abs(times(indices)-t))<1e-12,'Native sample time mismatch.');
        phase = double(squeeze(out.currents.Data));
        if size(phase,1)~=numel(times)
            phase = phase';
        end
        ref{r} = [phase(indices,:) double(out.speed.Data(indices)) ...
            double(p.PolePairs)*double(out.position.Data(indices)) ...
            double(out.id.Data(indices)) double(out.iq.Data(indices))];
    end
    [custom,truth] = custom_run(x0,duty,loadTorque,p,dt,numel(t),1);
    [finer,truthFiner] = custom_run(x0,duty,loadTorque,p,dt,numel(t),2);
    truthError = wrapped_difference(truth,ref{2}(:,[6 7 4 5]),4);
    truthConvergence = wrapped_difference(truth,truthFiner,4);
    err = wrapped_difference(custom,ref{2},5);
    conv = wrapped_difference(custom,finer,5);
    oracleConv = wrapped_difference(ref{1},ref{2},5);
    result = struct('name',names{c},'initial_state',x0','duty',duty', ...
        'phase_voltage_V',phaseVoltage','signed_load_Nm',loadTorque, ...
        'max_abs_error',max(abs(err),[],1),'rms_error',sqrt(mean(err.^2,1)), ...
        'custom_step_halving_max_abs_change',max(abs(conv),[],1), ...
        'native_step_halving_max_abs_change',max(abs(oracleConv),[],1), ...
        'reference_peak_abs',max(abs(ref{2}),[],1), ...
        'state_columns',{{'Id_A','Iq_A','wm_rad_s','theta_e_rad'}}, ...
        'double_state_max_abs_error',max(abs(truthError),[],1), ...
        'double_state_rms_error',sqrt(mean(truthError.^2,1)), ...
        'double_state_step_halving_max_abs_change',max(abs(truthConvergence),[],1));
    result.pass = all(result.max_abs_error<=report.absolute_tolerances) && ...
        all(result.native_step_halving_max_abs_change<=report.absolute_tolerances/10);
    report.cases(c) = result;
    allData{c} = struct('t',t,'reference',ref{2},'custom',custom, ...
        'custom_half_step',finer,'error',err);
    disp(jsonencode(result));
end
report.pass = all([report.cases.pass]);
fid = fopen(fullfile(outdir,'results.json'),'w');
assert(fid~=-1,'Cannot write validation results.');
cleanupFile = onCleanup(@() fclose(fid));
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));
clear cleanupFile
save(fullfile(outdir,'trajectories.mat'),'allData','report');
save_system(model,fullfile(outdir,[model '.slx']));
fig = figure('Visible','off','Position',[50 50 1250 900]);
cleanupFigure = onCleanup(@() close(fig));
for c = 1:numel(names)
    for k = 1:3
        subplot(numel(names),3,(c-1)*3+k);
        columns = [1 4 5];
        col = columns(k);
        plot(t,allData{c}.reference(:,col),'k-',t,allData{c}.custom(:,col),'r--');
        ylabel(report.columns{col},'Interpreter','none');
        if k==1
            title(names{c},'Interpreter','none');
        end
        if c==numel(names)
            xlabel('Time (s)');
        end
        if c==1 && k==3
            legend('Official reference','Custom plant');
        end
    end
end
exportgraphics(fig,fullfile(outdir,'comparison.png'));
assert(report.pass,'Official PMSM reference comparison failed.');
end

function [measured,truth] = custom_run(x,duty,loadTorque,p,dt,n,subdivisions)
measured = zeros(n,7);
truth = zeros(n,4);
for k = 1:n
    [~,current,theta,omega] = mc.plant_measure(x,p);
    measured(k,:) = [double(current)' double(omega)/double(p.PolePairs) ...
        double(theta) x(1:2)'];
    truth(k,:) = x';
    if k<n
        for j = 1:subdivisions
            x = mc.plant_step(x,duty,12,loadTorque,true,p,dt/subdivisions);
        end
    end
end
end

function e = wrapped_difference(a,b,angleColumn)
e = a-b;
e(:,angleColumn) = atan2(sin(e(:,angleColumn)),cos(e(:,angleColumn)));
end
