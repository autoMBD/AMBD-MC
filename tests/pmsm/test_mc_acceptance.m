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
% File:        test_mc_acceptance.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Reject incomplete or behaviorally invalid evidence
% =================================================================================

classdef test_mc_acceptance < matlab.unittest.TestCase
    %test_mc_acceptance - Reject incomplete or behaviorally invalid evidence
    methods (TestMethodSetup)
        function paths(testCase)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'mc-models','pmsm','platform','pil')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'mc-models','pmsm','algo')));
        end
    end
    methods (Test)
        function idealSensoredEvidencePasses(testCase)
            [trace,scenario]=test_mc_acceptance.evidence("sensored_steps");
            result=mc_assess_host_trace(trace,scenario);
            testCase.verifyTrue(result.Passed);
        end
        function firstStepOvershootCannotHideBehindLaterTarget(testCase)
            [trace,scenario]=test_mc_acceptance.evidence("sensored_steps");
            trace.OmegaTruth(trace.Time>=0.5 & trace.Time<0.6)=single(160);
            result=mc_assess_host_trace(trace,scenario);
            testCase.verifyFalse(result.Passed);
        end
        function saturationCaseMustActuallyReachCurrentLimit(testCase)
            [trace,scenario]=test_mc_acceptance.evidence("saturation_recovery");
            trace.ReferenceDq(:,2)=single(1);
            result=mc_assess_host_trace(trace,scenario);
            testCase.verifyFalse(result.Passed);
        end
        function currentReferenceCannotExceedCalibration(testCase)
            [trace,scenario]=test_mc_acceptance.evidence("sensored_steps");
            trace.ReferenceDq(trace.Time>=0.5 & trace.Time<0.6,2)=single(7);
            result=mc_assess_host_trace(trace,scenario);
            testCase.verifyFalse(result.Passed);
        end
        function missingTimingOutputCannotPassReplay(testCase)
            [reference,~]=test_mc_acceptance.evidence("sensored_steps");
            actual=rmfield(reference,'Tick');
            testCase.verifyError(@() mc_compare_replay(reference,actual,65535), ...
                'mc:ReplayRequiredField');
        end
        function completeIdenticalReplayPasses(testCase)
            [trace,~]=test_mc_acceptance.evidence("sensored_steps");
            result=mc_compare_replay(trace,trace,65535);
            testCase.verifyTrue(result.Passed && result.StrictBitwisePassed);
        end
        function changedStateCannotPassReplay(testCase)
            [trace,~]=test_mc_acceptance.evidence("sensored_steps");
            actual=trace;actual.Mode(1000)=uint8(3);
            result=mc_compare_replay(trace,actual,65535);
            testCase.verifyFalse(result.Passed);
        end
        function forgedAdjacentCountCannotPassReplay(testCase)
            [trace,~]=test_mc_acceptance.evidence("sensored_steps");
            actual=trace;actual.DutyCounts(1000,1)=actual.DutyCounts(1000,1)+uint16(1);
            result=mc_compare_replay(trace,actual,65535);
            testCase.verifyFalse(result.Passed);
        end
        function negativeTargetOvershootIsDirectional(testCase)
            [trace,scenario]=test_mc_acceptance.evidence("reversal");
            trace.OmegaTruth(trace.Time>=4 & trace.Time<4.1)=single(-200);
            result=mc_assess_host_trace(trace,scenario);
            testCase.verifyFalse(result.Passed);
        end
        function sustainedSaturationAndRecoveryPasses(testCase)
            [trace,scenario]=test_mc_acceptance.evidence("saturation_recovery");
            trace.ReferenceDq(:,2)=single(4);
            trace.ReferenceDq(trace.Time>=1 & trace.Time<2.8,2)=single(6);
            result=mc_assess_host_trace(trace,scenario);
            testCase.verifyTrue(result.Passed);
        end
        function faultAtOneTickMeetsLatency(testCase)
            [trace,scenario]=test_mc_acceptance.faultEvidence(1);
            result=mc_assess_host_trace(trace,scenario);
            testCase.verifyTrue(result.Passed);
        end
        function faultAtTwoTicksMustFailLatency(testCase)
            [trace,scenario]=test_mc_acceptance.faultEvidence(2);
            result=mc_assess_host_trace(trace,scenario);
            testCase.verifyFalse(result.Passed);
        end
    end
    methods (Static,Access=private)
        function [trace,scenario]=faultEvidence(delayTicks)
            [trace,scenario]=test_mc_acceptance.evidence("fault_recovery");
            detected=trace.Time>=2.5+delayTicks/16000-1e-10 & trace.Time<2.8;
            trace.FaultBits(detected)=uint16(1);trace.Mode(detected)=uint8(3);
            disabled=trace.Time>=2.5+delayTicks/16000-1e-10 & trace.Time<2.85;
            trace.GateOutput(disabled)=false;trace.GateEnable=trace.GateOutput;
        end
        function [trace,scenario]=evidence(name)
            scenario=mc_host_scenario(name);n=numel(scenario.Time);
            [counts,debug,monitor]=mc.monitor(mc.initial_state(scenario.Control),scenario.Control);
            trace.Time=scenario.Time;
            for field=fieldnames(monitor)'
                trace.(field{1})=repmat(monitor.(field{1})(:)',n,1);
            end
            for field=fieldnames(debug)'
                trace.(['Debug_',field{1}])=repmat(debug.(field{1})(:)',n,1);
            end
            trace.DutyCounts=repmat(counts',n,1);
            trace.OmegaTruth=scenario.Speed;
            trace.CurrentTruth=zeros(n,3,'single');
            trace.ThetaTruth=zeros(n,1,'single');
            trace.Mode(1:numel(scenario.RequiredModes))=scenario.RequiredModes;
            trace.PositionMode(:)=scenario.PositionMode;
            trace.GateOutput=scenario.Time>=0.05;
            trace.GateEnable=trace.GateOutput;
        end
    end
end
