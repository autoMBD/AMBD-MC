classdef test_mc_algorithms < matlab.unittest.TestCase
    % SPDX-License-Identifier: MIT
    % Copyright (c) 2026 autoMBD
    % Analytic component tests independent of the closed-loop controller.
    properties (TestParameter)
        Angle = {single(0), single(pi/3), single(-pi/2), single(2*pi)}
        Direction = {single(1), single(-1)}
    end
    methods (TestClassSetup)
        function sourcePath(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'mc-models','pmsm','algo')));
        end
    end
    methods (Test)
        function balancedClarkeHasCorrectAmplitude(testCase)
            ab = mc.clarke(single([2;-1;-1]));
            testCase.verifyEqual(ab,single([2;0]),AbsTol=single(1e-6));
        end
        function parkAndInverseAreReciprocal(testCase,Angle)
            ab = single([1.25;-2.75]);
            actual = mc.invpark(mc.park(ab,Angle),Angle);
            testCase.verifyEqual(actual,ab,AbsTol=single(8e-7));
        end
        function quadratureCurrentHasCorrectSign(testCase)
            dq = mc.park(single([0;2]),single(0));
            testCase.verifyEqual(dq,single([0;2]),AbsTol=single(1e-6));
        end
        function adcConversionIsCentered(testCase)
            p=mc.defaults();
            actual=mc.acquire(uint16([32768;33768;31768]),p);
            testCase.verifyEqual(actual,single([0;1;-1]),AbsTol=single(1e-7));
        end
        function pwmReconstructsRequestedVoltage(testCase,Angle)
            v=single(3)*single([cos(Angle);sin(Angle)]);
            duty=mc.svpwm(v,single(12),true);
            phase=single(12)*(duty-mean(duty));
            testCase.verifyEqual(mc.clarke(phase),v,AbsTol=single(2e-6));
            testCase.verifyGreaterThanOrEqual(duty,single(0));
            testCase.verifyLessThanOrEqual(duty,single(1));
        end
        function disabledPwmIsDeterministic(testCase)
            duty=mc.svpwm(single([100;-100]),single(0),false);
            testCase.verifyEqual(duty,single([0.5;0.5;0.5]));
        end
        function appliedVoltageMatchesAnalyticPolePattern(testCase)
            actual=mc.applied_voltage(uint16([60000;0;0]),single(12),true,uint16(60000));
            testCase.verifyEqual(actual,single([8;0]),AbsTol=single(1e-6));
            common=mc.applied_voltage(uint16([40000;40000;40000]),single(12),true,uint16(60000));
            testCase.verifyEqual(common,single([0;0]));
        end
        function appliedVoltageIsZeroWithDisabledGate(testCase)
            actual=mc.applied_voltage(uint16([65535;0;100]),single(12),false,uint16(65535));
            testCase.verifyEqual(actual,single([0;0]));
        end
        function saturatedPiDoesNotWindUp(testCase)
            [out,z]=test_mc_algorithms.exercisePi(single(10),1000,single(0));
            testCase.verifyEqual(out,single(1));
            testCase.verifyLessThanOrEqual(abs(z),single(1));
            [recovered,~]=mc.pi_step(single(-0.5),z,single(1), ...
                single(20),single(0.001),single(1),false);
            testCase.verifyLessThan(recovered,single(0));
        end
        function piResetClearsIntegrator(testCase)
            [out,z]=mc.pi_step(single(10),single(0.8),single(1), ...
                single(20),single(0.001),single(1),true);
            testCase.verifyEqual([out,z],single([0,0]));
        end
        function currentRegulatorLimitsVoltageVector(testCase)
            p=mc.defaults();
            [v,z,dq]=mc.current_control(single([0;0;0]),single(0), ...
                single(0),single([100;100]),single([0;0]),p,single(12),true);
            testCase.verifyLessThanOrEqual(norm(v),single(12/sqrt(3))*p.VoltageMargin+single(1e-5));
            testCase.verifyTrue(all(isfinite(z)));
            testCase.verifyEqual(dq,single([0;0]));
        end
        function observerTracksSyntheticFluxWithoutPositionInput(testCase,Direction)
            [angleError,speedError]=test_mc_algorithms.observerTrajectory(Direction);
            testCase.verifyLessThan(abs(angleError),single(0.06));
            testCase.verifyLessThan(abs(speedError),single(4));
        end
    end
    methods (Static, Access=private)
        function [out,z]=exercisePi(error,count,z)
            out=single(0);
            for k=1:count
                [out,z]=mc.pi_step(error,z,single(1),single(20), ...
                    single(0.001),single(1),false);
            end
        end
        function [angleError,speedError]=observerTrajectory(direction)
            p=mc.defaults();
            q=mc.observer_initial(p,single(0),single([0;0]));
            omega=direction*single(200);
            theta=single(0);
            for k=1:8000
                midpoint=theta+single(0.5)*p.Ts*omega;
                voltage=p.Flux*omega*single([-sin(midpoint);cos(midpoint)]);
                theta=mc.wrap_angle(theta+p.Ts*omega);
                q=mc.observer_step(single([0;0]),voltage,q,p);
            end
            angleError=mc.wrap_angle(q.Theta-theta);
            speedError=q.Omega-omega;
        end
    end
end
