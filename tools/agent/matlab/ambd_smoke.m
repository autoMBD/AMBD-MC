% SPDX-License-Identifier: MIT
function result = ambd_smoke(outputFolder, modelName)
%AMBD_SMOKE Create a disposable model and assert its simulated output.
assert(~verLessThan('matlab', '9.14'), 'AMBD:Release', 'MATLAB R2023a+ is required.');
assert(license('test', 'Simulink') && ~isempty(ver('simulink')), ...
    'AMBD:Simulink', 'Simulink installation and license are required.');
assert(1 + 1 == 2);
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
    'nxpMbdtDetected', ~isempty(which('mbd_s32k_init')) || ~isempty(which('mbd_s32k3_init')), ...
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
