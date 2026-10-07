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
% File:        test_mc_algorithms.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Test PMSM controller transformation and modulation algorithms.
% =================================================================================

classdef test_mc_algorithms < matlab.unittest.TestCase
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
