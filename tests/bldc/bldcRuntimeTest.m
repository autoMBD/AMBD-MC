classdef bldcRuntimeTest < matlab.unittest.TestCase
    % Behavioral tests for BLDC feedback, lifecycle and fault containment.
    % SPDX-License-Identifier: MIT
    % Copyright (c) 2026 autoMBD
    properties (TestParameter)
        StopMode = num2cell(uint8([4,5,6,7,8,9,10,11,12,13,14]))
        InvalidHall = {uint8(0),uint8(7)}
        FeedbackMode = {uint8(11),uint8(12),uint8(13),uint8(14)}
    end
    methods (TestClassSetup)
        function sourcePath(testCase)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'mc-models','bldc','algo')));
        end
    end
    methods (Test)
        function initializationIsExplicitAndSafe(testCase)
            p=bldc.defaults();s=bldc.initial_state(p);
            testCase.verifyEqual(s.Mode,uint8(0));
            testCase.verifyFalse(s.GateEnable);
            testCase.verifyFalse(any(s.PhaseEnable));
            testCase.verifyEqual(s.DutyCounts,zeros(3,1,'uint16'));
            testCase.verifyClass(s.CurrentIntegrator,'single');
            testCase.verifyEqual(s.Parameters,p);
        end
        function fastTickAndSpeedDividerAreExplicit(testCase)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            flags=false(32,1);
            for k=1:32, s=bldc.kernel(u,s,p);flags(k)=s.SpeedTick;end
            testCase.verifyEqual(find(flags),[16;32]);
            frozen=s;u.DrivingEvent=false;s=bldc.kernel(u,s,p);
            testCase.verifyEqual(s.Tick,frozen.Tick);
            testCase.verifyFalse(s.FastTick);
        end
        function hallEdgeTimingProducesSignedElectricalSpeed(testCase)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            s.FastTick=true;s=bldc.feedback(u,s,p);
            s.HallAge=uint32(99);u.Hall=uint8(4);s=bldc.feedback(u,s,p);
            testCase.verifyTrue(s.FeedbackReady);
            testCase.verifyEqual(s.SpeedEstimate,single(pi/3)/(single(100)*p.Ts),AbsTol=single(1e-4));
            s.HallAge=uint32(99);u.Hall=uint8(5);s=bldc.feedback(u,s,p);
            testCase.verifyEqual(s.RawSpeed,-single(pi/3)/(single(100)*p.Ts),AbsTol=single(1e-4));
        end
        function hallNonadjacentChangeFaults(testCase)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            s.FastTick=true;s=bldc.feedback(u,s,p);
            u.Hall=uint8(6);s=bldc.feedback(u,s,p);
            testCase.verifyEqual(bitand(s.SensorFault,uint16(1024)),uint16(1024));
        end
        function invalidHallDisablesRunningDrive(testCase,InvalidHall)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            s.Mode=uint8(14);s.GateEnable=true;s.CurrentRef=single(2);
            u.Control=uint8(1);u.SpeedReq=single(100);u.Hall=InvalidHall;
            s=bldc.step(u,s,p);
            testCase.verifyEqual(s.Mode,uint8(3));
            testCase.verifyFalse(s.GateEnable);
            testCase.verifyEqual(bitand(s.FaultBits,uint16(1024)),uint16(1024));
        end
        function externalFaultWinsWithoutFastTick(testCase)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            s.Mode=uint8(14);s.GateEnable=true;u.DrivingEvent=false;u.Fault=true;
            u.Control=uint8(1);s=bldc.step(u,s,p);
            testCase.verifyEqual(s.FaultBits,uint16(1));
            testCase.verifyFalse(s.GateEnable);
            testCase.verifyEqual(s.Tick,uint32(0));
        end
        function resetCannotClearActiveFault(testCase)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            u.Fault=true;u.Control=uint8(0);s=bldc.step(u,s,p);
            testCase.verifyEqual(s.FaultBits,uint16(1));
            u.Fault=false;s=bldc.step(u,s,p);
            testCase.verifyEqual(s.FaultBits,uint16(0));
            testCase.verifyEqual(s.Mode,uint8(0));
            testCase.verifyFalse(s.GateEnable);
        end
        function stopPreemptsEveryActiveBridge(testCase,StopMode)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            s.Mode=StopMode;s.Command=uint8(2);s.FastTick=true;
            s.SpeedEstimate=single(100);s.ControlSpeed=single(100);
            s=bldc.supervisor(u,s,p);
            testCase.verifyTrue(s.Mode==uint8(15) || s.Mode==uint8(2));
        end
        function reversalDoesNotImmediatelyReverseOrientation(testCase)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            s.Mode=uint8(14);s.Command=uint8(1);s.SpeedRequest=single(-100);
            s.FastTick=true;s.Direction=int8(1);s.ControlSpeed=single(100);
            s=bldc.supervisor(u,s,p);
            testCase.verifyEqual(s.Mode,uint8(15));
            testCase.verifyEqual(s.Direction,int8(1));
        end
        function calibrationsLatchOnlyDisarmed(testCase)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            changed=p;changed.KpSpeed=p.KpSpeed*single(2);
            s=bldc.tuning(u,s,changed);
            testCase.verifyEqual(s.Parameters.KpSpeed,changed.KpSpeed,AbsTol=single(1e-8));
            s.Mode=uint8(14);s=bldc.tuning(u,s,p);
            testCase.verifyEqual(s.Parameters.KpSpeed,changed.KpSpeed,AbsTol=single(1e-8));
        end
        function sensorlessIgnoresHallAndSchedulesThirtyDegrees(testCase)
            p=bldc.defaults();p.PositionMode=uint8(1);p.ZcRequired=uint16(1);
            s=bldc.initial_state(p);u=bldc.default_input(p);s.FastTick=true;
            s.Mode=uint8(8);s.Direction=int8(1);s.OmegaOpen=single(100);
            s.AppliedLastSector=uint8(1);s.AppliedAge=uint32(100);
            s.ZcAge=uint32(158);s.ZcCount=uint16(1);s.ZcPeriod=single(160);
            u.Hall=uint8(0);u.AppliedSector=uint8(1);u.TerminalVoltage=single([9;3;6.1]);
            s=bldc.feedback(u,s,p);
            u.TerminalVoltage(3)=single(5.9);s=bldc.feedback(u,s,p);
            testCase.verifyEqual(s.SensorFault,uint16(0));
            testCase.verifyEqual(s.ZcCountdown,int32(80));
            testCase.verifyEqual(s.ZcNextSector,uint8(2));
            testCase.verifyTrue(s.ZcFound);
        end
        function blankingAndWrongSlopeRejectSpuriousCrossings(testCase)
            p=bldc.defaults();p.PositionMode=uint8(1);
            s=bldc.initial_state(p);u=bldc.default_input(p);s.FastTick=true;
            s.Mode=uint8(8);u.AppliedSector=uint8(1);
            u.TerminalVoltage=single([9;3;6.1]);s=bldc.feedback(u,s,p);
            u.TerminalVoltage(3)=single(5.9);s=bldc.feedback(u,s,p);
            testCase.verifyFalse(s.ZcFound);
            s.AppliedAge=uint32(100);s=bldc.feedback(u,s,p);
            u.TerminalVoltage(3)=single(6.1);s=bldc.feedback(u,s,p);
            testCase.verifyFalse(s.ZcFound);
        end
        function invalidTerminalSamplesFaultAfterClosedLoopTimeout(testCase)
            p=bldc.defaults();p.PositionMode=uint8(1);
            s=bldc.initial_state(p);u=bldc.default_input(p);s.Mode=uint8(14);
            s.FeedbackReady=true;s.ZcPeriod=single(160);s.ZcAge=uint32(1000);
            s.GateEnable=true;u.Control=uint8(1);u.SpeedReq=single(100);u.VoltageValid=false;
            s=bldc.step(u,s,p);
            testCase.verifyEqual(bitand(s.FaultBits,uint16(4096)),uint16(4096));
            testCase.verifyFalse(s.GateEnable);
        end
        function nonfiniteInputNeverReachesDuty(testCase)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            s.Mode=uint8(14);u.Control=uint8(1);u.Vdc=single(NaN);
            s=bldc.step(u,s,p);
            testCase.verifyEqual(bitand(s.FaultBits,uint16(16)),uint16(16));
            testCase.verifyFalse(s.GateEnable);
            testCase.verifyEqual(s.DutyCounts,zeros(3,1,'uint16'));
        end
        function currentSlewContinuesBetweenSpeedTicks(testCase)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            s.Mode=uint8(14);s.PreviousMode=uint8(14);s.FastTick=true;
            s.SpeedTick=false;s.HallSector=uint8(1);s.CurrentDemand=single(2);
            s=bldc.dataflow(u,s,p);
            testCase.verifyEqual(s.CurrentRef,p.CurrentSlew*p.Ts,AbsTol=single(1e-8));
            s=bldc.dataflow(u,s,p);
            testCase.verifyEqual(s.CurrentRef,single(2)*p.CurrentSlew*p.Ts,AbsTol=single(1e-8));
        end
        function monitorPreservesTypedControlEvidence(testCase)
            p=bldc.defaults();s=bldc.initial_state(p);s.Mode=uint8(14);
            s.CurrentRef=single(2);s.Sector=uint8(3);s.ZcCount=uint16(9);
            [counts,enabled,gate,debug,m]=bldc.monitor(s,p);
            testCase.verifyEqual(m.Mode,s.Mode);
            testCase.verifyEqual(m.CurrentReference,s.CurrentRef,AbsTol=single(1e-7));
            testCase.verifyEqual(m.ZcCount,s.ZcCount);
            testCase.verifyEqual(counts,s.DutyCounts);
            testCase.verifyEqual(enabled,s.PhaseEnable);
            testCase.verifyEqual(gate,s.GateEnable);
            testCase.verifySize(debug.Data,[16,1]);
        end
        function runningHallTimeoutUsesTheRunningLimit(testCase)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            s.FastTick=true;s.Mode=uint8(14);s.GateEnable=true;
            s.CurrentRef=single(2);s.HallValid=true;s.HallLast=uint8(1);
            s.HallAge=uint32(ceil(double(p.HallTimeout/p.Ts)));
            s=bldc.feedback(u,s,p);
            testCase.verifyEqual(bitand(s.SensorFault,uint16(2048)),uint16(2048));
        end
        function rejectedCrossingCannotDisableLossWatchdog(testCase,FeedbackMode)
            p=bldc.defaults();p.PositionMode=uint8(1);s=bldc.initial_state(p);
            u=bldc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(100);
            u.AppliedSector=uint8(1);u.TerminalVoltage=single([9;3;5.9]);
            s.Mode=FeedbackMode;s.GateEnable=true;s.Sector=uint8(1);
            s.AppliedLastSector=uint8(1);s.AppliedAge=uint32(100);
            s.ZcArmed=true;s.ZcAge=uint32(10);s.ZcCount=uint16(6);
            s.ZcPeriod=single(160);s.AcquisitionReady=true;
            s.SpeedEstimate=single(100);s.SpeedRamped=single(100);
            s=bldc.step(u,s,p);u.VoltageValid=false;
            for k=1:500,s=bldc.step(u,s,p);end
            testCase.verifyEqual(bitand(s.FaultBits,uint16(4096)),uint16(4096));
            testCase.verifyFalse(s.GateEnable);
        end
        function resetDoesNotClearPersistentInvalidHall(testCase,InvalidHall)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            u.Hall=InvalidHall;u.Control=uint8(1);s=bldc.step(u,s,p);
            u.Control=uint8(0);s=bldc.step(u,s,p);
            testCase.verifyEqual(bitand(s.FaultBits,uint16(1024)),uint16(1024));
            testCase.verifyFalse(s.GateEnable);
        end
        function trackingCannotWaitForeverWithoutQualifiedFeedback(testCase)
            p=bldc.defaults();p.PositionMode=uint8(1);s=bldc.initial_state(p);
            u=bldc.default_input(p);s.Mode=uint8(11);s.Command=uint8(1);
            s.SpeedRequest=single(100);s.FastTick=true;s.ModeTicks=uint32(32000);
            s=bldc.supervisor(u,s,p);
            testCase.verifyEqual(bitand(s.FaultBits,uint16(64)),uint16(64));
            testCase.verifyEqual(s.Mode,uint8(3));
        end
        function absentTimerEventInhibitsSpeedUpdate(testCase)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            u.TimerEvent=false;s.SlowCounter=p.SpeedDivider-uint16(1);
            s=bldc.kernel(u,s,p);
            testCase.verifyFalse(s.SpeedTick);
            testCase.verifyTrue(s.FastTick);
        end
        function stopDuringCoastAcquisitionDoesNotReenergize(testCase)
            p=bldc.defaults();p.PositionMode=uint8(1);s=bldc.initial_state(p);
            u=bldc.default_input(p);s.Mode=uint8(15);s.PreviousMode=uint8(9);
            s.FastTick=true;s.Sector=uint8(1);s.Current=single([1;-1;0]);
            s=bldc.dataflow(u,s,p);
            testCase.verifyFalse(s.GateEnable);
            testCase.verifyFalse(any(s.PhaseEnable));
            testCase.verifyGreaterThan(s.CoastTicks,uint32(0));
        end
        function discardedAcquisitionPeriodCannotCauseDivisionByZero(testCase)
            p=bldc.defaults();p.PositionMode=uint8(1);s=bldc.initial_state(p);
            u=bldc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(100);
            u.AppliedSector=uint8(1);u.TerminalVoltage=single([9;3;5.9]);
            s.Mode=uint8(8);s.AcquisitionReady=true;s.ZcPeriod=single(0);
            s.ZcCount=uint16(0);s.ZcAge=uint32(100);s.ZcArmed=true;
            s.AppliedLastSector=uint8(1);s.AppliedAge=uint32(100);
            s=bldc.step(u,s,p);
            testCase.verifyEqual(bitand(s.FaultBits,uint16(512)),uint16(0));
            testCase.verifyTrue(isfinite(s.SpeedEstimate));
            testCase.verifyGreaterThan(s.ZcPeriod,single(0));
        end
        function disarmedAdcRetuneUsesOneCalibrationPerFrame(testCase)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            s.Mode=uint8(2);p.AdcOffset=single(20000);u.CurrentRaw=uint16([20000;20000;20000]);
            u.Control=uint8(1);u.SpeedReq=single(100);s=bldc.step(u,s,p);
            testCase.verifyEqual(s.FaultBits,uint16(0));
            testCase.verifyEqual(s.Current,zeros(3,1,'single'),AbsTol=single(1e-8));
        end
        function disarmedModeRetuneDoesNotReuseOldHallFault(testCase)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            s.Mode=uint8(2);p.PositionMode=uint8(1);u.Hall=uint8(0);
            u.Control=uint8(1);u.SpeedReq=single(100);s=bldc.step(u,s,p);
            testCase.verifyEqual(s.FaultBits,uint16(0));
            testCase.verifyEqual(s.Parameters.PositionMode,uint8(1));
        end
    end
end
