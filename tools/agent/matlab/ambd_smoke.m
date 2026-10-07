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
% File:        ambd_smoke.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-09-11
% Version:     0.1.0
% Description: Create a disposable model and assert its simulated output.
% =================================================================================

function result = ambd_smoke(outputFolder, modelName)
%AMBD_SMOKE Create a disposable model and assert its simulated output.
assert(~verLessThan('matlab', '9.14'), 'AMBD:Release', 'MATLAB R2023a+ is required.');
assert(license('test', 'Simulink') && ~isempty(ver('simulink')), ...
    'AMBD:Simulink', 'Simulink installation and license are required.');
assert(1 + 1 == 2);
Simulink.fileGenControl('set','CacheFolder',fullfile(outputFolder,'cache'), ...
    'CodeGenFolder',fullfile(outputFolder,'codegen'),'createDir',true);
new_system(modelName);
add_block('simulink/Sources/Constant', [modelName '/Input'], 'Value', '2');
component = [modelName '/Triple'];
add_block('built-in/Subsystem', component);
add_block('simulink/Sources/In1', [component '/u']);
add_block('simulink/Math Operations/Gain', [component '/Gain'], 'Gain', '3');
add_block('simulink/Sinks/Out1', [component '/y']);
add_line(component, 'u/1', 'Gain/1');
add_line(component, 'Gain/1', 'y/1');
add_block('simulink/Sinks/To Workspace', [modelName '/Output'], ...
    'VariableName', 'smokeOutput', 'SaveFormat', 'Array');
add_line(modelName, 'Input/1', 'Triple/1');
add_line(modelName, 'Triple/1', 'Output/1');
set_param(modelName, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', ...
    'FixedStep', '0.1', 'StopTime', '0.2');
save_system(modelName, fullfile(outputFolder, [modelName '.slx']));
simulation = sim(modelName, 'ReturnWorkspaceOutputs', 'on');
assert(all(simulation.smokeOutput == 6, 'all'), 'AMBD:Simulation', ...
    'Expected Constant(2) times Gain(3) to produce 6.');
result = struct('release', version('-release'), 'version', version, ...
    'pid', feature('getpid'), 'simulatedValue', simulation.smokeOutput(end), ...
    'toolboxes', ver, 'simulinkTestLicensed', logical(license('test', 'Simulink_Test')), ...
    'embeddedCoderLicensed', logical(license('test', 'RTW_Embedded_Coder')), ...
    'autoMbdHspDetected', ~isempty(which('autombd.hsp.initialize')), ...
    'satkInitialize', which('satk_initialize'), 'shareMATLABSession', which('shareMATLABSession'));
result.capabilities = struct( ...
    'Simulink', capability('Simulink', 'Simulink'), ...
    'Stateflow', capability('Stateflow', 'Stateflow'), ...
    'Simscape', capability('Simscape', 'Simscape'), ...
    'SimulinkTest', capability('Simulink Test', 'Simulink_Test'), ...
    'SimulinkCoder', capability('Simulink Coder', 'Real-Time_Workshop'), ...
    'EmbeddedCoder', capability('Embedded Coder', 'RTW_Embedded_Coder'));
file = fopen(fullfile(outputFolder, 'matlab-result.json'), 'w', 'n', 'UTF-8');
assert(file ~= -1, 'AMBD:Report', 'Cannot open the MATLAB result file.');
cleanup = onCleanup(@() fclose(file));
fprintf(file, '%s\n', jsonencode(result));
disp('AMBD_COMPUTE_AND_SIMULATION_PASS');
end

function value = capability(product, featureName)
installedProducts = ver;
installed = any(strcmp({installedProducts.Name}, product));
licensed = logical(license('test', featureName));
status = 'AVAILABLE';
if ~installed
    status = 'MISSING_INSTALLATION';
elseif ~licensed
    status = 'MISSING_LICENSE';
end
value = struct('installed', installed, 'licensed', licensed, 'status', status);
end
