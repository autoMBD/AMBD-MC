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
% File:        test_mc_layers.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Test PMSM runtime control and safety behavior.
% =================================================================================

classdef test_mc_layers < matlab.unittest.TestCase
    %test_mc_layers - Verify physical core and motor lifecycle contracts
    properties (TestParameter)
        PositionMode = {uint8(0),uint8(1)}
        InvalidCalibration = {"samples","offset","spread","timeout","clock"}
    end
    methods (TestClassSetup)
        function sourcePath(testCase)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'mc-models','pmsm','algo')));
        end
    end
    methods (Test)
        function coreInterfaceIsIndependent(testCase)
            testCase.verifyNotEmpty(which('mc.core_step'));
            testCase.verifyNotEmpty(which('mc.core_initial_state'));
            testCase.verifyNotEmpty(which('mc.core_default_input'));
        end
        function physicalInputHasNoAdcEncoding(testCase)
            p=mc.defaults();u=mc.core_default_input(p);
            testCase.verifyEqual(u.Current,single([0;0;0]));
            testCase.verifyFalse(isfield(u,'CurrentRaw'));
        end
        function coreStartsWithoutApplicationCalibration(testCase,PositionMode)
            p=mc.defaults();p.PositionMode=PositionMode;
            u=mc.core_default_input(p);u.Control=uint8(1);u.SpeedReq=single(100);
            s=mc.core_step(u,mc.core_initial_state(p),p);
            testCase.verifyEqual(s.Mode,uint8(6));
            testCase.verifyTrue(s.GateEnable);
            testCase.verifyFalse(isfield(s,'CalibrationCount'));
        end
        function immediateDisableWorksWithoutFastTick(testCase)
            p=mc.defaults();u=mc.core_default_input(p);u.Control=uint8(1);
            u.SpeedReq=single(100);s=mc.core_step(u,mc.core_initial_state(p),p);
            u.DrivingEvent=false;u.Disable=true;s=mc.core_step(u,s,p);
            testCase.verifyFalse(s.GateEnable);
            testCase.verifyEqual(s.Duty,single([.5;.5;.5]),AbsTol=single(0));
        end
        function restartAfterAsynchronousDisableDoesNotReuseIntegrators(testCase)
            p=mc.defaults();u=mc.core_default_input(p);
            u.Control=uint8(1);u.SpeedReq=single(100);
            s=mc.core_initial_state(p);s.Mode=uint8(14);
            s.CurrentIntegral=single([2;-3]);s.SpeedIntegral=single(5);
            u.DrivingEvent=false;u.Disable=true;
            s=mc.core_step(u,s,p);
            testCase.verifyEqual(s.CurrentIntegral,single([0;0]),AbsTol=single(0));
            testCase.verifyEqual(s.SpeedIntegral,single(0),AbsTol=single(0));
            u.DrivingEvent=true;u.Disable=false;
            restarted=mc.core_step(u,s,p);
            fresh=mc.core_step(u,mc.core_initial_state(p),p);
            testCase.verifyEqual(restarted.CurrentIntegral,fresh.CurrentIntegral);
            testCase.verifyEqual(restarted.Duty,fresh.Duty);
        end
        function calibrationCompletesWhileDisarmed(testCase)
            [s,p,u]=test_mc_layers.calibrated();
            testCase.verifyTrue(s.Calibrated);
            testCase.verifyEqual(s.AdcOffsets,single(u.CurrentRaw),AbsTol=single(0));
            testCase.verifyEqual(s.CalibrationCount,p.CalibrationSamples);
            testCase.verifyFalse(s.Core.GateEnable);
            testCase.verifyEqual(s.Mode,uint8(2));
        end
        function runRequestWaitsForCalibration(testCase)
            p=mc.defaults();p.CalibrationSamples=uint16(4);
            u=mc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(100);
            s=test_mc_layers.advance(u,mc.initial_state(p),p,3);
            testCase.verifyFalse(s.Calibrated);
            testCase.verifyFalse(s.Core.GateEnable);
        end
        function calibratedOffsetsAreUsedOnce(testCase)
            [s,p,u]=test_mc_layers.calibrated();
            u.CurrentRaw=uint16(single(u.CurrentRaw)+single([300;-100;-200]));
            s=mc.step(u,s,p);
            testCase.verifyEqual(s.Core.Current,single([.3;-.1;-.2]),AbsTol=single(1e-7));
        end
        function excessiveOffsetFailsCalibration(testCase)
            p=mc.defaults();u=mc.default_input(p);
            u.CurrentRaw(1)=uint16(p.AdcOffset+p.CalibrationMaxOffset+single(1));
            s=test_mc_layers.advance(u,mc.initial_state(p),p,3);
            testCase.verifyFalse(s.Calibrated);
            testCase.verifyNotEqual(bitand(s.FaultBits,uint16(1024)),uint16(0));
            testCase.verifyFalse(s.Core.GateEnable);
        end
        function movingInputFailsCalibration(testCase)
            p=mc.defaults();p.CalibrationSamples=uint16(4);u=mc.default_input(p);
            s=test_mc_layers.advance(u,mc.initial_state(p),p,3);
            u.CurrentRaw(1)=u.CurrentRaw(1)+uint16(p.CalibrationMaxSpread+single(1));
            s=mc.step(u,s,p);
            testCase.verifyNotEqual(bitand(s.FaultBits,uint16(1024)),uint16(0));
            testCase.verifyFalse(s.Core.GateEnable);
        end
        function calibrationTimeoutIsLatched(testCase)
            p=mc.defaults();p.CalibrationSamples=uint16(10);
            p.CalibrationTimeout=single(2)*p.Ts;u=mc.default_input(p);
            s=test_mc_layers.advance(u,mc.initial_state(p),p,8);
            testCase.verifyFalse(s.Calibrated);
            testCase.verifyNotEqual(bitand(s.FaultBits,uint16(1024)),uint16(0));
        end
        function calibrationFaultNeedsANewResetCommand(testCase)
            p=mc.defaults();p.CalibrationSamples=uint16(4);
            u=mc.default_input(p);
            u.CurrentRaw(1)=uint16(p.AdcOffset+p.CalibrationMaxOffset+single(1));
            s=test_mc_layers.advance(u,mc.initial_state(p),p,5);
            u.CurrentRaw(:)=uint16(p.AdcOffset);
            held=test_mc_layers.advance(u,s,p,10);
            testCase.verifyEqual(held.Mode,uint8(3));
            testCase.verifyFalse(held.Calibrated);
            u.CommandEvent=false;s=mc.step(u,held,p);
            u.CommandEvent=true;s=test_mc_layers.advance(u,s,p,8);
            testCase.verifyTrue(s.Calibrated);
            testCase.verifyEqual(s.FaultBits,uint16(0));
        end
        function completionWinsAtTheCalibrationDeadline(testCase)
            p=mc.defaults();p.CalibrationSamples=uint16(4);
            p.CalibrationTimeout=single(4)*p.Ts;u=mc.default_input(p);
            s=test_mc_layers.advance(u,mc.initial_state(p),p,6);
            testCase.verifyTrue(s.Calibrated);
            testCase.verifyEqual(s.FaultBits,uint16(0));
        end
        function completionAfterTheDeadlineIsRejected(testCase)
            p=mc.defaults();p.CalibrationSamples=uint16(2);
            p.CalibrationTimeout=single(1.5)*p.Ts;u=mc.default_input(p);
            s=test_mc_layers.advance(u,mc.initial_state(p),p,5);
            testCase.verifyFalse(s.Calibrated);
            testCase.verifyNotEqual(bitand(s.FaultBits,uint16(1024)),uint16(0));
        end
        function invalidCalibrationCannotGrantRunPermission(testCase,InvalidCalibration)
            p=test_mc_layers.invalidCalibration(InvalidCalibration);
            u=mc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(100);
            s=test_mc_layers.advance(u,mc.initial_state(p),p,70);
            testCase.verifyFalse(s.Calibrated);
            testCase.verifyNotEqual(bitand(s.FaultBits,uint16(1024)),uint16(0));
            testCase.verifyFalse(s.Core.GateEnable);
        end
        function stopDuringCalibrationNeverStartsTheCore(testCase)
            p=mc.defaults();p.CalibrationSamples=uint16(4);
            u=mc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(100);
            s=test_mc_layers.advance(u,mc.initial_state(p),p,3);
            u.Control=uint8(2);s=test_mc_layers.advance(u,s,p,10);
            testCase.verifyTrue(s.Calibrated);
            testCase.verifyFalse(s.Core.GateEnable);
            testCase.verifyEqual(s.Mode,uint8(2));
        end
        function missingFastTickDoesNotAdvanceCalibration(testCase)
            p=mc.defaults();u=mc.default_input(p);
            s=test_mc_layers.advance(u,mc.initial_state(p),p,3);
            before=s.CalibrationCount;u.DrivingEvent=false;
            s=test_mc_layers.advance(u,s,p,20);
            testCase.verifyEqual(s.CalibrationCount,before);
        end
        function rawRailCannotBeCalibratedAway(testCase)
            p=mc.defaults();u=mc.default_input(p);u.CurrentRaw(2)=uint16(0);
            s=mc.step(u,mc.initial_state(p),p);
            testCase.verifyFalse(s.Calibrated);
            testCase.verifyNotEqual(bitand(s.FaultBits,uint16(32)),uint16(0));
            testCase.verifyFalse(s.Core.GateEnable);
        end
        function startupReadinessFaultClearsUnderAnActiveSafeReset(testCase)
            p=mc.defaults();u=mc.default_input(p);u.Fault=true;
            s=mc.step(u,mc.initial_state(p),p);
            u.Fault=false;s=mc.step(u,s,p);
            testCase.verifyEqual(s.FaultBits,uint16(0));
            testCase.verifyFalse(s.Core.GateEnable);
            testCase.verifyEqual(s.Command,uint8(0));
        end
        function faultWithoutFastTickDisablesAndLatches(testCase)
            [s,p,u]=test_mc_layers.running();
            u.Fault=true;u.DrivingEvent=false;s=mc.step(u,s,p);
            testCase.verifyFalse(s.Core.GateEnable);
            testCase.verifyEqual(s.Mode,uint8(3));
            u.Fault=false;s=mc.step(u,s,p);
            testCase.verifyEqual(s.Mode,uint8(3));
            testCase.verifyFalse(s.Core.GateEnable);
            [counts,~,status]=mc.monitor(s,p);
            testCase.verifyEqual(counts,uint16([32768;32768;32768]));
            testCase.verifyFalse(status.GateEnable);
            testCase.verifyEqual(status.FaultBits,s.FaultBits);
        end
        function resetDoesNotAutomaticallyRestart(testCase)
            [s,p,u]=test_mc_layers.running();
            u.Fault=true;s=mc.step(u,s,p);
            u.Fault=false;u.Control=uint8(0);s=mc.step(u,s,p);
            u.CommandEvent=false;u.Control=uint8(1);
            s=test_mc_layers.advance(u,s,p,10);
            testCase.verifyEqual(s.Command,uint8(0));
            testCase.verifyFalse(s.Core.GateEnable);
            testCase.verifyEqual(s.FaultBits,uint16(0));
        end
        function calibrationIsNotRepeatedWhileRunning(testCase)
            [s,p,u]=test_mc_layers.running();offsets=s.AdcOffsets;
            u.CurrentRaw=uint16(single(u.CurrentRaw)+single([300;-100;-200]));
            s=mc.step(u,s,p);
            testCase.verifyEqual(s.AdcOffsets,offsets,AbsTol=single(0));
            testCase.verifyTrue(s.Calibrated);
        end
        function fullControllerUsesExactlyTheStandaloneCore(testCase,PositionMode)
            [s,p,u]=test_mc_layers.running();p.PositionMode=PositionMode;
            [coreInput,prepared]=mc.motor_prepare(u,s,p);
            core=mc.core_step(coreInput,prepared.Core,p);
            expected=mc.motor_finish(prepared,core);
            actual=mc.step(u,s,p);
            testCase.verifyEqual(actual,expected);
            testCase.verifyEqual(actual.Core,core);
        end
        function coreNumericalFaultIsContainedInTheSameStep(testCase)
            [s,p,u]=test_mc_layers.running();
            s.Core.Mode=uint8(14);s.Core.Observer.Flux(1)=single(NaN);
            s=mc.step(u,s,p);
            testCase.verifyEqual(s.Mode,uint8(3));
            testCase.verifyFalse(s.Core.GateEnable);
            testCase.verifyNotEqual(bitand(s.FaultBits,uint16(512)),uint16(0));
            testCase.verifyEqual(s.Core.Duty,single([.5;.5;.5]),AbsTol=single(0));
        end
    end
    methods (Static,Access=private)
        function p=invalidCalibration(kind)
            p=mc.defaults();
            switch kind
                case "samples",p.CalibrationSamples=uint16(0);
                case "offset",p.CalibrationMaxOffset=single(NaN);
                case "spread",p.CalibrationMaxSpread=single(Inf);
                case "timeout",p.CalibrationTimeout=single(NaN);
                case "clock",p.Ts=single(0);
            end
        end
        function s=advance(u,s,p,count)
            for index=1:count,s=mc.step(u,s,p);end
        end
        function [s,p,u]=calibrated()
            p=mc.defaults();p.CalibrationSamples=uint16(4);
            u=mc.default_input(p);u.CurrentRaw=uint16([32800;32750;32770]);
            s=test_mc_layers.advance(u,mc.initial_state(p),p,8);
        end
        function [s,p,u]=running()
            [s,p,u]=test_mc_layers.calibrated();
            u.Control=uint8(1);u.SpeedReq=single(100);
            s=test_mc_layers.advance(u,s,p,5);
        end
    end
end
