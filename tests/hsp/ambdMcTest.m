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
% File:        ambdMcTest.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-08
% Version:     0.1.0
% Description: Reject unsaved calibration before creating a target stage.
% =================================================================================

classdef ambdMcTest < matlab.unittest.TestCase
    %ambdMcTest - Validate the public operation interface
    properties (TestParameter)
        Invalid = struct( ...
            'missingFamily', {{'setup'}}, ...
            'missingSettings', {{'stage','bldc'}})
        BadFamily = {"unknown", "", ["bldc","pmsm"], 17, {"bldc"}}
        BadCommand = {"build", "", ["setup","stage"], 17, {"setup"}}
    end
    methods (TestMethodSetup)
        function addRoot(testCase)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end
    methods (Test)
        function helpWithoutDependencies(testCase)
            originalPath=path;
            output=evalc('ambd_mc');
            testCase.verifySubstring(output,'setup');
            testCase.verifySubstring(output,'stage');
            testCase.verifyEqual(evalc('ambd_mc("help")'),output);
            testCase.verifyEqual(path,originalPath);
        end
        function missingArgument(testCase,Invalid)
            testCase.verifyError(@()ambd_mc(Invalid{:}),'ambd:MissingArgument');
        end
        function invalidCommand(testCase,BadCommand)
            testCase.verifyError(@()ambd_mc(BadCommand),'ambd:Command');
        end
        function invalidFamily(testCase,BadFamily)
            testCase.verifyError(@()ambd_mc('setup',BadFamily),'ambd:Family');
        end
        function stageRejectsAll(testCase)
            testCase.verifyError(@()ambd_mc('stage','all','x.json'),'ambd:Family');
        end
        function stageRejectsExtraArguments(testCase)
            testCase.verifyError(@()ambd_mc('stage','bldc','x.json',true), ...
                'ambd:Arguments');
        end
        function helpRejectsExtraArguments(testCase)
            testCase.verifyError(@()ambd_mc('help','bldc'),'ambd:Arguments');
        end
        function rejectsUnknownOption(testCase)
            testCase.verifyError(@()ambd_mc('setup','pmsm','Unknown',true), ...
                'ambd:Option');
        end
        function rejectsMissingOptionValue(testCase)
            testCase.verifyError(@()ambd_mc('setup','pmsm','Dictionary'), ...
                'ambd:Option');
        end
        function rejectsSharedDictionaryForAll(testCase)
            testCase.verifyError(@()ambd_mc('setup','all',Dictionary='x.sldd'), ...
                'ambd:SharedDictionary');
        end
        function rejectsNumericSync(testCase)
            testCase.verifyError(@()ambd_mc('setup','pmsm',SyncDictionary=1), ...
                'ambd:Option');
        end
        function rejectsMissingSettingsText(testCase)
            testCase.verifyError(@()ambd_mc('stage','bldc',string(missing)), ...
                'ambd:SettingsFile');
        end
    end
end
