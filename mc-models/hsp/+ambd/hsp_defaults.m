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
% File:        hsp_defaults.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-07
% Version:     0.1.0
% Description: Create portable settings for a selected motor hardware target.
% =================================================================================

function cfg = hsp_defaults(model,target)
%hsp_defaults - Create portable motor component settings
%   CFG = hsp_defaults(MODEL) selects the S32K344 EB project and runtime.
%
%   CFG = hsp_defaults(MODEL,TARGET) selects "s32k144" or "s32k344".
%   Installation paths and connection identities stay empty.
%
%   See also autombd.hsp.config.defaults

if nargin<2,target='s32k344';end
profile=ambd.target_profile(target);
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
modelFile = get_param(model,'FileName');
assert(~isempty(modelFile),'ambd:UnsavedModel','Save the model before configuring HSP.');
modelDirectory = fileparts(modelFile);
relative = erase(string(modelDirectory),string(root)+filesep);
assert(relative~=string(modelDirectory),'ambd:ModelLocation','The model must be inside this project.');
depth = numel(split(relative,filesep));
prefix = repmat(['..',filesep],1,depth);
hspDirectory = fullfile(prefix,'mc-models','hsp');
cfg = autombd.hsp.config.defaults(profile.targetId);
cfg.environment.execution.basePeriodSeconds = profile.samplePeriod;
cfg.environment.configurationTool.templateId = profile.templateId;
cfg.environment.externalProjectRoot = fullfile(hspDirectory,'config',profile.configuration);
cfg.environment.configurationTool.projectName = profile.projectName;
cfg.environment.pil.uartInstance=profile.uartInstance;
cfg.environment.pil.rxPin=profile.uartRx;
cfg.environment.pil.txPin=profile.uartTx;
cfg.runtime.schedulerMode = 'callback-task';
cfg.runtime.eventCallbackName = 'Hsp_ModelEvent';
cfg.runtime.eventCaptureFunction = 'Ambd_KitCaptureModelInputs';
cfg.runtime.startFunction = 'Ambd_KitStart';
cfg.runtime.stopFunction = 'Ambd_KitStop';
cfg.runtime.eventIrqPriority = 6;
cfg.runtime.eventTimeoutTicks = 2;
cfg.runtime.taskStackWords = 4096;
cfg.runtime.sources = {fullfile(hspDirectory,'board','ambd_kit_core.c'), ...
    fullfile(hspDirectory,'board',profile.boardSource),fullfile(hspDirectory,'board','ambd_kit_bridge.c')};
if strcmp(profile.name,'s32k144')
    cfg.runtime.sources{end+1}=fullfile(hspDirectory,'board','ambd_kit_s32k144_core.c');
end
cfg.runtime.includeDirectories = {fullfile(hspDirectory,'board')};
isBldc=startsWith(string(model),"BLDC");
cfg.runtime.defines={['AMBD_MODEL=',char(model)],['AMBD_BLDC=',num2str(isBldc)],profile.define};
cfg.runtime.compilerFlags={'-O3','-ffp-contract=off'};
cfg.outputDirectory = fullfile('build',model);
end
