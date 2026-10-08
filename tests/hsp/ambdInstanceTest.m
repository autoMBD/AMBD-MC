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
% File:        ambdInstanceTest.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-08
% Version:     0.1.0
% Description: Verify instance output ownership and shared-source protection.
% =================================================================================

classdef ambdInstanceTest < matlab.unittest.TestCase
    %ambdInstanceTest - Verify process ownership survives initialization
    properties (TestParameter)
        Family = struct('bldc',"bldc",'pmsm',"pmsm")
        Writer = struct( ...
            'bldcReplay',@(folder)bldc_run_replay('missing',folder), ...
            'bldcComparison',@(folder)bldc_compare_host_cases('missing','missing',folder), ...
            'pmsmComparison',@(folder)mc_compare_host_cases('missing','missing',folder))
    end
    methods (TestMethodSetup)
        function requireManagedInstance(testCase)
            testCase.assumeNotEmpty(getenv('AMBD_MATLAB_INSTANCE'));
            oldPath=path;
            testCase.addTeardown(@()path(oldPath));
            cfg=Simulink.fileGenControl('getConfig');
            testCase.addTeardown(@()Simulink.fileGenControl('setConfig','config',cfg));
        end
    end
    methods (Test)
        function defaultsStayOwnedAfterSetup(testCase,Family)
            info=ambd_mc('setup',Family);
            connection=info.DictionaryConnection;
            testCase.addTeardown(@()close(connection));
            owned=string(getenv('AMBD_MATLAB_INSTANCE'))+filesep;
            cfg=Simulink.fileGenControl('getConfig');
            testCase.verifyTrue(startsWith(info.GeneratedTypeFile,owned));
            testCase.verifyTrue(startsWith(string(cfg.CacheFolder),owned));
            testCase.verifyTrue(startsWith(string(cfg.CodeGenFolder),owned));
            testCase.verifyFalse(connection.HasUnsavedChanges);
        end
        function managedSyncRejectsSharedSource(testCase,Family)
            testCase.verifyError(@()ambd_mc('setup',Family,SyncDictionary=true), ...
                'ambd:SharedSourceWrite');
        end
        function refusesForeignInstanceOutput(testCase,Family)
            foreign=fullfile(fileparts(getenv('AMBD_MATLAB_INSTANCE')),'foreign-instance','output');
            testCase.verifyError(@()ambd_mc('setup',Family,OutputDirectory=foreign), ...
                'ambd:ForeignInstanceWrite');
        end
        function refusesForeignInstanceDictionary(testCase,Family)
            foreign=fullfile(fileparts(getenv('AMBD_MATLAB_INSTANCE')),'foreign-instance','Data.sldd');
            testCase.verifyError(@()ambd_mc('setup',Family,Dictionary=foreign,SyncDictionary=true), ...
                'ambd:ForeignInstanceWrite');
        end
        function refusesForeignReportDirectory(testCase,Writer)
            repo=fileparts(which('ambd_mc'));
            addpath(fullfile(repo,'mc-models','bldc','platform','pil'), ...
                fullfile(repo,'mc-models','pmsm','platform','pil'));
            foreign=fullfile(fileparts(getenv('AMBD_MATLAB_INSTANCE')),'foreign-instance','reports');
            testCase.verifyError(@()Writer(foreign),'ambd:ForeignInstanceWrite');
        end
    end
end
