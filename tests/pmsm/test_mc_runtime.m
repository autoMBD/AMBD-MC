classdef test_mc_runtime < matlab.unittest.TestCase
    % SPDX-License-Identifier: MIT
    % Copyright (c) 2026 autoMBD
    % Lifecycle, protection, scheduling and tuning requirements.
    properties (TestParameter)
        PreEnableMode={uint8(4),uint8(5)}
        TransitionMode={uint8(7),uint8(9),uint8(10),uint8(12),uint8(13)}
        BadFlux={single(NaN),single(1e20)}
        NearZeroBoundary={single(-1),single(1)}
    end
    methods (TestClassSetup)
        function sourcePath(testCase)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'mc-models','pmsm','algo')));
        end
    end
    methods (Test)
        function offlineCalibrationSeedsStoredRuntimeWhileDisarmed(testCase)
            defaults=mc.defaults();s=mc.initial_state(defaults);
            p=defaults;p.KpSpeed=p.KpSpeed*single(2);p.AlignTime=single(0.4);
            u=mc.default_input(p);s=mc.step(u,s,p);
            testCase.verifyEqual(s.Gains(1),p.KpSpeed);
            testCase.verifyEqual(s.Startup(2),p.AlignTime);
        end
        function boundarySpeedRequestStaysDisarmed(testCase,NearZeroBoundary)
            p=mc.defaults();p.AlignTime=single(4)*p.Ts;
            u=mc.default_input(p);u.Control=uint8(1);u.SpeedReq=NearZeroBoundary;
            s=mc.initial_state(p);
            for index=1:20,s=mc.step(u,s,p);end
            testCase.verifyEqual(s.Mode,uint8(2));
            testCase.verifyFalse(s.GateEnable);
        end
        function boundaryReverseRequestStopsFirst(testCase,NearZeroBoundary)
            p=mc.defaults();u=mc.default_input(p);u.Control=uint8(1);
            u.SpeedReq=NearZeroBoundary;
            s=mc.initial_state(p);s.Mode=uint8(8);s.Command=uint8(1);
            s.Direction=-sign(NearZeroBoundary);
            s.SpeedRequest=single(20)*s.Direction;
            s.OmegaOpen=s.SpeedRequest;s.OmegaControl=s.SpeedRequest;
            s=mc.step(u,s,p);
            testCase.verifyEqual(s.Mode,uint8(15));
        end
        function resetStartsDisabled(testCase)
            p=mc.defaults();u=mc.default_input(p);s=mc.initial_state(p);
            s=mc.step(u,s,p);
            testCase.verifyEqual(s.Mode,uint8(0));
            testCase.verifyFalse(s.GateEnable);
            testCase.verifyEqual(s.CurrentIntegral,single([0;0]));
        end
        function sensoredStartReachesRun(testCase)
            [s,modes]=test_mc_runtime.startSensored();
            testCase.verifyEqual(s.Mode,uint8(14));
            testCase.verifyTrue(s.GateEnable);
            testCase.verifyTrue(all(ismember(uint8([1 2 4 5 6 12 14]),modes)));
        end
        function faultDisablesImmediatelyAndLatches(testCase)
            [s,~,p,u]=test_mc_runtime.startSensored();
            u.Fault=true;s=mc.step(u,s,p);
            testCase.verifyFalse(s.GateEnable);
            testCase.verifyEqual(s.Mode,uint8(3));
            u.Fault=false;s=mc.step(u,s,p);
            testCase.verifyEqual(s.Mode,uint8(3));
            testCase.verifyNotEqual(s.FaultBits,uint16(0));
        end
        function explicitSafeResetClearsLatch(testCase)
            [s,~,p,u]=test_mc_runtime.startSensored();
            u.Fault=true;s=mc.step(u,s,p);
            u.Fault=false;u.Control=uint8(0);s=mc.step(u,s,p);
            testCase.verifyEqual(s.FaultBits,uint16(0));
            testCase.verifyEqual(s.Mode,uint8(0));
            testCase.verifyFalse(s.GateEnable);
        end
        function continuingFaultCannotBeReset(testCase)
            p=mc.defaults();u=mc.default_input(p);s=mc.initial_state(p);
            u.Fault=true;s=mc.step(u,s,p);
            testCase.verifyEqual(s.Mode,uint8(3));
            testCase.verifyFalse(s.GateEnable);
        end
        function overcurrentAndInvalidVoltageAreProtected(testCase)
            p=mc.defaults();u=mc.default_input(p);s=mc.initial_state(p);
            u.Control=uint8(1);u.CurrentRaw=uint16([52768;22768;22768]);
            u.Vdc=single(18);s=mc.step(u,s,p);
            testCase.verifyNotEqual(bitand(s.FaultBits,uint16(2)),uint16(0));
            testCase.verifyNotEqual(bitand(s.FaultBits,uint16(8)),uint16(0));
            testCase.verifyFalse(s.GateEnable);
        end
        function nonfiniteCommandCannotReachActuator(testCase)
            p=mc.defaults();u=mc.default_input(p);s=mc.initial_state(p);
            u.SpeedReq=single(NaN);s=mc.step(u,s,p);
            testCase.verifyNotEqual(bitand(s.FaultBits,uint16(16)),uint16(0));
            testCase.verifyTrue(all(isfinite(s.Duty)));
            testCase.verifyFalse(s.GateEnable);
        end
        function fastTickGateAndSlowDividerAreExplicit(testCase)
            p=mc.defaults();u=mc.default_input(p);s=mc.initial_state(p);
            u.DrivingEvent=false;s=mc.step(u,s,p);
            testCase.verifyEqual(s.Tick,uint32(0));
            testCase.verifyFalse(s.SlowTick);
            u.DrivingEvent=true;
            [s,slowCount]=test_mc_runtime.advance(u,s,p,32);
            testCase.verifyEqual(s.Tick,uint32(32));
            testCase.verifyEqual(slowCount,2);
        end
        function tuningIsLatchedOnlyWhileDisarmed(testCase)
            p=mc.defaults();p.TuningEnable=true;
            u=mc.default_input(p);s=mc.initial_state(p);
            u.Tuning.IdKp=uint16(2000);s=mc.step(u,s,p);
            testCase.verifyEqual(s.Gains(3),single(2));
            s.Mode=uint8(14);s.Command=uint8(1);u.Control=uint8(1);
            u.Tuning.IdKp=uint16(4000);s=mc.step(u,s,p);
            testCase.verifyEqual(s.Gains(3),single(2));
        end
        function stopAtRestReturnsToIdle(testCase)
            [s,~,p,u]=test_mc_runtime.startSensored();
            u.Control=uint8(2);
            [s,~]=test_mc_runtime.advance(u,s,p,4);
            testCase.verifyEqual(s.Mode,uint8(2));
            testCase.verifyFalse(s.GateEnable);
        end
        function stopNeverEnergizesPreEnableStates(testCase,PreEnableMode)
            p=mc.defaults();p.PositionMode=uint8(1);
            u=mc.default_input(p);u.Control=uint8(2);u.SpeedReq=single(100);
            s=mc.initial_state(p);s.Mode=PreEnableMode;
            s=mc.step(u,s,p);
            testCase.verifyEqual(s.Mode,uint8(2));
            testCase.verifyFalse(s.GateEnable);
        end
        function stopPreemptsIntermediateTransitions(testCase,TransitionMode)
            p=mc.defaults();p.PositionMode=uint8(1);
            u=mc.default_input(p);u.Control=uint8(2);u.SpeedReq=single(100);
            s=mc.initial_state(p);s.Mode=TransitionMode;
            s.OmegaControl=single(100);s.PositionSpeed=single(100);
            s=mc.step(u,s,p);
            testCase.verifyEqual(s.Mode,uint8(15));
        end
        function observerFallbackStartsFromLastAppliedFrame(testCase)
            p=mc.defaults();u=mc.default_input(p);
            u.Control=uint8(1);u.SpeedReq=single(200);
            s=mc.initial_state(p);s.Mode=uint8(14);s.Command=uint8(1);
            s.ObserverReady=false;s.ThetaControl=single(1.2);s.OmegaControl=single(200);
            s.ThetaOpen=single(-2);s.ReferenceDq=single([0;2]);
            s.Observer=mc.observer_initial(p,single(1.2),single([0;0]));
            first=mc.step(u,s,p);second=mc.step(u,first,p);
            testCase.verifyLessThan(abs(mc.wrap_angle(first.ThetaControl-s.ThetaControl)),single(0.03));
            testCase.verifyLessThan(abs(mc.wrap_angle(second.ThetaControl-first.ThetaControl)),single(0.03));
            testCase.verifyLessThan(abs(first.ReferenceDq(2)-s.ReferenceDq(2)),single(0.01));
        end
        function handoverUsesActualStartupSpeed(testCase)
            p=mc.defaults();u=mc.default_input(p);
            s=mc.initial_state(p);s.Mode=uint8(8);s.PreviousMode=s.Mode;
            s.Command=uint8(1);s.FastTick=true;s.SpeedRequest=single(100);
            s.OmegaOpen=single(100);s.ObserverReady=true;
            s=mc.supervisor(u,s,p);
            testCase.verifyEqual(s.Mode,uint8(9));
        end
        function failedEstimatorIsContainedInSameTick(testCase,BadFlux)
            p=mc.defaults();u=mc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(200);
            s=mc.initial_state(p);s.Mode=uint8(14);s.ObserverReady=true;
            s.GateEnable=true;s.Observer.Flux(1)=BadFlux;
            s=mc.step(u,s,p);
            testCase.verifyNotEqual(bitand(s.FaultBits,uint16(512)),uint16(0));
            testCase.verifyFalse(s.GateEnable);
            testCase.verifyEqual(s.Duty,single([0.5;0.5;0.5]));
            testCase.verifyTrue(all(isfinite(s.Observer.Flux)));
            u.Control=uint8(0);s=mc.step(u,s,p);
            testCase.verifyEqual(s.FaultBits,uint16(0));
        end
        function lowSpeedIfCanRequestClosedLoopAfterLongDwell(testCase)
            p=mc.defaults();u=mc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(100);
            s=mc.initial_state(p);s.Mode=uint8(8);s.Command=uint8(1);
            s.SpeedRequest=single(20);s.OmegaOpen=single(20);s.ModeTicks=uint32(64000);
            s=mc.step(u,s,p);
            testCase.verifyEqual(s.Mode,uint8(8));
            testCase.verifyEqual(s.FaultBits,uint16(0));
            testCase.verifyLessThan(s.ModeTicks,uint32(100));
        end
        function stoppingIfDoesNotSelectUnqualifiedObserver(testCase)
            p=mc.defaults();u=mc.default_input(p);u.Control=uint8(2);u.SpeedReq=single(20);
            s=mc.initial_state(p);s.Mode=uint8(8);s.Command=uint8(1);
            s.ThetaControl=single(1.2);s.OmegaControl=single(20);
            s.ThetaOpen=single(1.2);s.OmegaOpen=single(20);s.ReferenceDq=single([0;2]);
            s.Observer=mc.observer_initial(p,single(-2),single([0;0]));
            actual=mc.step(u,s,p);
            testCase.verifyEqual(actual.Mode,uint8(15));
            testCase.verifyLessThan(abs(mc.wrap_angle(actual.ThetaControl-s.ThetaControl)),single(0.02));
            testCase.verifyLessThanOrEqual(actual.OmegaControl,s.OmegaControl);
        end
        function invalidPositionThenResetRecoversFiniteState(testCase)
            p=mc.defaults();p.PositionMode=uint8(1);p.AlignTime=single(4)*p.Ts;
            u=mc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(100);u.Position=single(NaN);
            s=mc.initial_state(p);s.Mode=uint8(14);
            s=mc.step(u,s,p);
            testCase.verifyFalse(s.GateEnable);
            u.Position=single(0.4);u.Control=uint8(0);s=mc.step(u,s,p);
            testCase.verifyTrue(isfinite(s.PositionPrev)&&isfinite(s.PositionSpeed));
            testCase.verifyEqual(s.PositionSpeed,single(0));
            u.Control=uint8(1);[s,~]=test_mc_runtime.advance(u,s,p,20);
            testCase.verifyEqual(s.Mode,uint8(14));
            testCase.verifyEqual(s.FaultBits,uint16(0));
        end
        function stopSwitchesToLastFrameWhenObserverLosesQualification(testCase)
            p=mc.defaults();u=mc.default_input(p);u.Control=uint8(2);u.SpeedReq=single(100);
            s=mc.initial_state(p);s.Mode=uint8(15);s.Command=uint8(2);
            s.ObserverReady=true;s.ThetaControl=single(1.2);s.OmegaControl=single(65);
            s.Observer=mc.observer_initial(p,single(1.2),single([0;0]));
            s.Observer.Omega=single(50);s.ObserverGoodTicks=uint32(10000);
            s.Voltage=p.Flux*single(50)*single([-sin(1.2);cos(1.2)]);
            actual=mc.step(u,s,p);
            testCase.verifyTrue(actual.StopOpenLoop);
            testCase.verifyLessThan(abs(mc.wrap_angle(actual.ThetaControl-s.ThetaControl)),single(0.02));
        end
        function observerHandoverSlewsCurrentReference(testCase)
            p=mc.defaults();u=mc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(100);
            s=mc.initial_state(p);s.Mode=uint8(9);s.Command=uint8(1);
            s.ObserverReady=true;s.OmegaOpen=single(100);s.ReferenceDq=single([0;3.5]);
            s.Observer=mc.observer_initial(p,single(0),single([0;0]));
            s.Observer.Omega=single(100);s.ObserverGoodTicks=uint32(10000);
            s.Voltage=single([0;p.Flux*single(100)]);
            actual=mc.step(u,s,p);
            testCase.verifyLessThanOrEqual(abs(actual.ReferenceDq(2)-s.ReferenceDq(2)), ...
                p.CurrentSlew*p.Ts*single(p.SpeedDivider)+single(1e-6));
        end
        function stopDuringTrackingPreservesBlendedFrame(testCase)
            p=mc.defaults();u=mc.default_input(p);u.Control=uint8(2);u.SpeedReq=single(100);
            s=mc.initial_state(p);s.Mode=uint8(11);s.Command=uint8(1);
            s.ObserverReady=true;s.ObserverGoodTicks=uint32(10000);
            s.ThetaControl=single(1.2);s.OmegaControl=single(100);
            s.Observer=mc.observer_initial(p,single(-2),single([0;0]));
            s.Observer.Omega=single(100);
            s.Voltage=p.Flux*single(100)*single([-sin(-2);cos(-2)]);
            actual=mc.step(u,s,p);
            testCase.verifyTrue(actual.StopOpenLoop);
            testCase.verifyLessThan(abs(mc.wrap_angle(actual.ThetaControl-s.ThetaControl)),single(0.02));
        end
    end
    methods (Test)
        function lowSpeedIfUsesBoundedStartupCurrent(testCase)
            p=mc.defaults();u=mc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(20);
            s=mc.initial_state(p);s.Mode=uint8(8);s.Command=uint8(1);
            s.OmegaOpen=single(20);
            for index=1:200,s=mc.step(u,s,p);end
            testCase.verifyEqual(s.Mode,uint8(8));
            testCase.verifyGreaterThan(s.ReferenceDq(2),single(0.5));
            testCase.verifyLessThan(s.ReferenceDq(2),single(1));
        end
        function observerUsesAppliedVoltageFeedback(testCase)
            p=mc.defaults();u=mc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(100);
            u.AppliedVoltage=single([0.2;0.4]);
            a=mc.initial_state(p);a.Mode=uint8(14);a.Command=uint8(1);
            a.Observer=mc.observer_initial(p,single(0.7),single([0;0]));
            a.Observer.Omega=single(100);a.ObserverReady=true;
            a.ObserverGoodTicks=uint32(10000);b=a;
            a.Voltage=single([1;0]);b.Voltage=single([-1;0]);
            expected=mc.observer_step(single([0;0]),u.AppliedVoltage,a.Observer,p);
            a=mc.step(u,a,p);b=mc.step(u,b,p);
            testCase.verifyEqual(a.Observer,expected);
            testCase.verifyEqual(a.Observer,b.Observer);
            testCase.verifyEqual(a.Duty,b.Duty);
        end
        function nonfiniteAppliedVoltageDisablesGate(testCase)
            p=mc.defaults();u=mc.default_input(p);u.Control=uint8(1);
            u.AppliedVoltage=single([NaN;0]);
            s=mc.initial_state(p);s.Mode=uint8(14);s.GateEnable=true;
            s=mc.step(u,s,p);
            testCase.verifyFalse(s.GateEnable);
            testCase.verifyNotEqual(bitand(s.FaultBits,uint16(16)),uint16(0));
        end
        function sensorlessOutputsIgnorePositionTruth(testCase)
            p=mc.defaults();u=mc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(100);
            for mode=uint8([0 2 6 8 11 14 15])
                a=mc.initial_state(p);a.Mode=mode;a.Command=uint8(1);
                a.Observer=mc.observer_initial(p,single(0.7),single([0;0]));
                a.Observer.Omega=single(100);a.ObserverReady=true;
                a.ObserverGoodTicks=uint32(10000);b=a;
                for index=1:20
                    u.Position=single(NaN);a=mc.step(u,a,p);
                    u.Position=single(0.25*index);b=mc.step(u,b,p);
                    [countsA,debugA,monitorA]=mc.monitor(a,p);
                    [countsB,debugB,monitorB]=mc.monitor(b,p);
                    testCase.verifyEqual(countsA,countsB);
                    testCase.verifyEqual(debugA,debugB);
                    testCase.verifyEqual(monitorA,monitorB);
                end
            end
        end
    end
    methods (Static,Access=private)
        function [s,modes,p,u]=startSensored()
            p=mc.defaults();p.PositionMode=uint8(1);p.AlignTime=p.Ts*single(4);
            u=mc.default_input(p);u.Control=uint8(1);u.SpeedReq=single(100);
            s=mc.initial_state(p);modes=zeros(20,1,'uint8');
            for k=1:20
                s=mc.step(u,s,p);modes(k)=s.Mode;
            end
        end
        function [s,count]=advance(u,s,p,n)
            count=0;
            for k=1:n
                s=mc.step(u,s,p);count=count+double(s.SlowTick);
            end
        end
    end
end
