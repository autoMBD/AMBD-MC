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
% File:        hspPwmCommandTest.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-07
% Version:     0.1.0
% Description: Test RTD PWM scaling, floating-phase isolation and output arming.
% =================================================================================

classdef hspPwmCommandTest < matlab.unittest.TestCase
    %hspPwmCommandTest - Verify the controller-to-RTD output contract
    %   Tests scale conversion, phase isolation and the board arming gate.

    methods (TestClassSetup)
        function addSources(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'mc-models','hsp')));
            testCase.assertNotEmpty(which('ambd.pwm_command'), ...
                'The target output adapter is required.');
        end
    end

    methods (Test)
        function endpointsAndMidpoint(testCase)
            [duty,enabled] = ambd.pwm_command( ...
                uint16([0;32768;65535]),true(3,1),true,true);
            testCase.verifyEqual(duty,uint16([0;16384;32768]));
            testCase.verifyTrue(all(enabled));
        end

        function everyCountIsBoundedAndComplementary(testCase)
            counts = uint16((0:65535)');
            [duty,~] = ambd.pwm_command(counts,true(65536,1),true,true);
            testCase.verifyLessThanOrEqual(max(duty),uint16(32768));
            testCase.verifyEqual(uint32(duty)+uint32(flipud(duty)), ...
                repmat(uint32(32768),65536,1));
            testCase.verifyLessThanOrEqual(max(abs( ...
                double(duty)-double(counts)*32768/65535)),0.5);
        end

        function disabledPhaseReturnsInactiveCommand(testCase)
            [duty,enabled] = ambd.pwm_command( ...
                uint16([12000;53535;32768]),logical([1;1;0]),true,true);
            testCase.verifyEqual(enabled,logical([1;1;0]));
            testCase.verifyEqual(duty(3),uint16(0));
            testCase.verifyEqual(uint32(duty(1))+uint32(duty(2)),uint32(32768));
        end

        function faultGateOverridesAllPhases(testCase)
            [duty,enabled] = ambd.pwm_command( ...
                uint16([65535;65535;65535]),true(3,1),false,true);
            testCase.verifyEqual(duty,zeros(3,1,'uint16'));
            testCase.verifyFalse(any(enabled));
        end

        function unarmedBoardCannotEnableBridge(testCase)
            [duty,enabled] = ambd.pwm_command( ...
                uint16([30000;20000;10000]),true(3,1),true,false);
            testCase.verifyEqual(duty,zeros(3,1,'uint16'));
            testCase.verifyFalse(any(enabled));
        end
    end
end
