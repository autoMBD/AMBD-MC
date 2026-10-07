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
% File:        bldcDcLinkTest.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-07
% Version:     0.1.0
% Description: Verify DC-link current observability and measured zero-cross handoff.
% =================================================================================

classdef bldcDcLinkTest < matlab.unittest.TestCase
    methods(TestClassSetup)
        function addProjectPaths(test)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            test.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'mc-models','bldc','algo')));
            test.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'mc-models','hsp')));
        end
    end
    methods(Test)
        function reverseOrSkippedCrossingCannotQualify(test)
            p=ambd.kit_parameters('bldc');p.PositionMode=uint8(1);
            for actual=uint8([1,3,4,5,6])
                s=bldc.initial_state(p);s.Mode=uint8(11);s.FastTick=true;
                s.AppliedLastSector=actual;s.AppliedAge=uint32(100);
                s.ZcUnclampedCount=uint16(3);s.ZcArmed=true;
                s.ZcAge=uint32(99);s.ZcPeriod=single(100);
                s.ZcCount=uint16(5);s.ZcNextSector=uint8(2);
                u=bldc.default_input(p);u.AppliedSector=actual;
                floats=[3,2,1,3,2,1];slopes=single([-1,1,-1,1,-1,1]);
                u.TerminalVoltage=single([6;6;6]);
                u.TerminalVoltage(floats(actual))=single(6)+slopes(actual)*single(.1);
                s=bldc.feedback(u,s,p);
                test.verifyEqual(s.ZcCount,uint16(5));test.verifyFalse(s.FeedbackReady);
                test.verifyNotEqual(bitand(s.SensorFault,uint16(4096)),uint16(0));
            end
        end
        function unbracketedSignalsCannotStartRun(test)
            p=ambd.kit_parameters('bldc');p.PositionMode=uint8(1);
            p.StartTimeout=single(.03);
            for signal=1:4
                s=bldc.initial_state(p);s.Mode=uint8(8);s.PreviousMode=s.Mode;
                s.Command=uint8(1);s.SpeedRequest=single(200);s.OmegaOpen=single(200);
                u=bldc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(200);
                for tick=1:600
                    u.AppliedSector=bldc.sector(s.ThetaOpen);
                    floats=[3,2,1,3,2,1];slopes=single([-1,1,-1,1,-1,1]);
                    if signal==1,residual=single(1);
                    elseif signal==2,residual=single(-1);
                    elseif signal==3,residual=single(6);
                    else,residual=p.ZcHysteresis*single(.25*(-1)^tick);end
                    u.TerminalVoltage=single([6;6;6]);
                    u.TerminalVoltage(floats(u.AppliedSector))=single(6)+slopes(u.AppliedSector)*residual;
                    s=bldc.step(u,s,p);
                    test.verifyNotEqual(s.Mode,uint8(14));test.verifyFalse(s.FeedbackReady);
                end
                test.verifyEqual(s.Mode,uint8(3));
                test.verifyNotEqual(bitand(s.FaultBits,uint16(64)),uint16(0));
                test.verifyEqual(s.ZcCount,uint16(0));
            end
        end
        function lateStartupPolarityOnlyRequestsPhaseCatchup(test)
            p=ambd.kit_parameters('bldc');p.PositionMode=uint8(1);
            s=bldc.initial_state(p);s.Mode=uint8(8);s.FastTick=true;s.OmegaOpen=single(200);
            s.ThetaOpen=single(pi/3);
            s.AppliedLastSector=uint8(1);s.AppliedAge=uint32(100);s.ZcUnclampedCount=uint16(3);
            u=bldc.default_input(p);u.AppliedSector=uint8(1);u.TerminalVoltage=single([12;0;5]);
            s=bldc.feedback(u,s,p);
            test.verifyEqual(bldc.sector(s.ThetaOpen),uint8(2));
            test.verifyEqual(s.ZcCount,uint16(0));test.verifyFalse(s.FeedbackReady);
        end
        function firstMeasuredCrossStartsProvisionalTracking(test)
            p=ambd.kit_parameters('bldc');p.PositionMode=uint8(1);
            s=bldc.initial_state(p);s.Mode=uint8(8);s.PreviousMode=s.Mode;s.FastTick=true;
            s.OmegaOpen=single(200);s.SpeedRequest=single(200);s.Command=uint8(1);
            s.AppliedLastSector=uint8(1);s.AppliedAge=uint32(100);s.ZcUnclampedCount=uint16(3);
            s.ZcArmed=true;s.ZcAge=uint32(5000);
            u=bldc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(200);
            u.AppliedSector=uint8(1);u.TerminalVoltage=single([12;0;5.9]);
            s=bldc.feedback(u,s,p);test.verifyEqual(s.ZcCount,uint16(1));
            test.verifyEqual(s.ZcPeriod,single(pi/3)/(s.OmegaOpen*p.Ts),'AbsTol',single(.001));
            s=bldc.supervisor(u,s,p);test.verifyEqual(s.Mode,uint8(11));test.verifyFalse(s.FeedbackReady);
            s.ModeTicks=uint32(4000);s=bldc.supervisor(u,s,p);test.verifyEqual(s.Mode,uint8(11));
        end
        function forcedVoltageAccountsForBackEmf(test)
            p=ambd.kit_parameters('bldc');p.PositionMode=uint8(1);
            u=bldc.default_input(p);s=bldc.initial_state(p);
            s.Mode=uint8(8);s.PreviousMode=s.Mode;s.FastTick=true;
            s.SpeedRequest=single(200);s.CurrentRef=single(3);s.DcCurrent=single(3);s.DcCurrentValid=true;
            slow=bldc.dataflow(u,s,p);s.OmegaOpen=single(200);fast=bldc.dataflow(u,s,p);
            test.verifyGreaterThan(fast.Modulation,slow.Modulation+single(.1));
        end
        function staleDcFaultRequiresDisarmedCooldownThenReset(test)
            p=bldc.defaults();p.CurrentSenseMode=uint8(1);
            u=bldc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(120);
            u.CurrentRaw(1)=uint16(44768);u.AppliedSector=uint8(1);
            s=bldc.initial_state(p);s.Mode=uint8(14);s.Command=uint8(1);s.GateEnable=true;
            s=bldc.step(u,s,p);test.verifyNotEqual(bitand(s.FaultBits,uint16(2)),uint16(0));
            u.CurrentRaw(1)=uint16(32768);u.VoltageValid=false;u.AppliedSector=uint8(0);
            s=bldc.step(u,s,p);test.verifyEqual(bitand(s.ActiveFaults,uint16(2)),uint16(0));
            test.verifyNotEqual(s.FaultBits,uint16(0));
            u.Control=uint8(0);s=bldc.step(u,s,p);test.verifyNotEqual(s.FaultBits,uint16(0));
            s.CoastTicks=uint32(ceil(double(p.StopCoastTime/p.Ts)));
            s=bldc.step(u,s,p);test.verifyEqual(s.FaultBits,uint16(0));test.verifyFalse(s.GateEnable);
        end
        function zeroCrossCompensatesActuationDelay(test)
            p=bldc.defaults();p.CurrentSenseMode=uint8(1);p.PositionMode=uint8(1);
            p.ActuationDelayTicks=uint16(2);p.DemagReleaseTicks=uint16(1);
            s=bldc.initial_state(p);s.Mode=uint8(11);s.FastTick=true;
            s.AppliedLastSector=uint8(1);s.AppliedAge=uint32(1000);s.ZcArmed=true;
            s.ZcAge=uint32(159);s.ZcPeriod=single(160);s.ZcCount=uint16(2);
            s.ZcNextSector=uint8(1);
            u=bldc.default_input(p);u.AppliedSector=uint8(1);u.TerminalVoltage=single([12;0;5.9]);
            s=bldc.feedback(u,s,p);test.verifyEqual(s.ZcCountdown,int32(78));
        end
        function invalidSampleBreaksRailReleaseQualification(test)
            p=bldc.defaults();p.CurrentSenseMode=uint8(1);p.PositionMode=uint8(1);
            s=bldc.initial_state(p);s.Mode=uint8(8);s.FastTick=true;
            s.ZcArmed=true;s.ZcUnclampedCount=uint16(10);
            u=bldc.default_input(p);u.VoltageValid=false;
            s=bldc.feedback(u,s,p);
            test.verifyFalse(s.ZcArmed);
            test.verifyEqual(s.ZcUnclampedCount,uint16(0));
        end
        function doesNotInventPhaseCurrents(test)
            p=bldc.defaults();p.CurrentSenseMode=uint8(1);
            u=bldc.default_input(p);u.CurrentRaw=uint16([34768;32768;32768]);
            s=bldc.kernel(u,bldc.initial_state(p),p);
            test.verifyEqual(s.Current,zeros(3,1,'single'));
            test.verifyFalse(s.PhaseCurrentsValid);
            test.verifyEqual(s.DcCurrent,single(2));
        end
        function cannotEnterCoastAcquisitionFromUnobservedCurrent(test)
            p=bldc.defaults();p.CurrentSenseMode=uint8(1);p.PositionMode=uint8(1);
            s=bldc.initial_state(p);s.Mode=uint8(8);s.PreviousMode=uint8(8);
            s.FastTick=true;s.Command=uint8(1);s.SpeedRequest=single(120);s.OmegaOpen=p.OpenSpeed;
            u=bldc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(120);
            s=bldc.supervisor(u,s,p);
            test.verifyEqual(s.Mode,uint8(8));
            test.verifyFalse(s.AcquisitionReady);
        end
        function qualifiesHandoffOnlyAfterMeasuredZeroCrossings(test)
            p=bldc.defaults();p.CurrentSenseMode=uint8(1);p.PositionMode=uint8(1);
            s=bldc.initial_state(p);s.Mode=uint8(8);s.PreviousMode=uint8(8);
            s.FastTick=true;s.Command=uint8(1);s.SpeedRequest=single(120);s.OmegaOpen=p.OpenSpeed;
            s.FeedbackReady=true;s.ZcCount=p.ZcRequired;s.SpeedEstimate=single(120);
            s.ZcPeriod=single(pi/3)/(abs(s.SpeedEstimate)*p.Ts);
            u=bldc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(120);u.AppliedSector=uint8(2);
            s=bldc.supervisor(u,s,p);
            test.verifyEqual(s.Mode,uint8(11));
            test.verifyEqual(s.Sector,uint8(2));
            test.verifyTrue(s.AcquisitionReady);
        end
        function currentRegulationUsesDcSampleAcrossSectors(test)
            p=bldc.defaults();p.CurrentSenseMode=uint8(1);
            s=bldc.initial_state(p);s.Mode=uint8(14);s.PreviousMode=s.Mode;
            s.FastTick=true;s.HallSector=uint8(4);s.DcCurrent=single(2);s.DcCurrentValid=true;
            s.CurrentDemand=single(3);s.CurrentRef=single(3);
            u=bldc.default_input(p);s=bldc.dataflow(u,s,p);
            test.verifyEqual(s.CurrentMeasured,single(2));
        end
        function rejectsClampedFloatingVoltageAsDemagnetization(test)
            p=bldc.defaults();p.CurrentSenseMode=uint8(1);p.PositionMode=uint8(1);
            s=bldc.initial_state(p);s.Mode=uint8(8);s.FastTick=true;s.OmegaOpen=single(120);
            u=bldc.default_input(p);u.AppliedSector=uint8(1);u.TerminalVoltage=single([12;0;12]);
            s.AppliedLastSector=uint8(1);s.AppliedAge=uint32(1000);
            s=bldc.feedback(u,s,p);
            test.verifyFalse(s.ZcArmed);
            test.verifyEqual(s.ZcCount,uint16(0));
        end
    end
end
