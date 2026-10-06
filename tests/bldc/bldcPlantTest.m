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
% File:        bldcPlantTest.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Test the BLDC phase-domain plant and diode transitions.
% =================================================================================

classdef bldcPlantTest < matlab.unittest.TestCase
    properties (TestParameter)
        invalidTrace = {'nanNativeCurrent','nanHostTerminal','infNativeTerminal', ...
            'nanTime','nanNativeTime','duplicateNativeTime','nonmonotonicTime', ...
            'shapeMismatch','outOfRangeTime','complexCurrent'}
    end
    methods (TestClassSetup)
        function paths(t)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'mc-models','bldc','algo')));
            t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tests','bldc','helpers')));
        end
    end
    methods (Test)
        function phaseShape(t)
            t.verifyEqual(bldc.trapezoid([0 pi/6 pi/2 5*pi/6 pi 7*pi/6 3*pi/2 11*pi/6]), ...
                [0 1 1 1 0 -1 -1 -1],AbsTol=1e-14);
        end
        function hallCodes(t)
            t.verifyEqual(bldc.hall_signal((1:6)*pi/3),uint8([5 4 6 2 3 1]));
        end
        function lockedRotorRL(t)
            p=plant_parameters(); p.Inertia=1e30;
            y=bldc.plant_step(zeros(5,1),uint16([65535;0;0]),logical([1;1;0]),true,12,0,p,.001);
            expected=12/(2*p.Rs)*(1-exp(-p.Rs*.001/p.Ls));
            t.verifyEqual(y(1:3),[expected;-expected;0],AbsTol=1e-11);
        end
        function freeCoast(t)
            p=plant_parameters(); x=[0;0;0;0;100];
            y=bldc.plant_step(x,zeros(3,1,'uint16'),false(3,1),false,12,0,p,.001);
            t.verifyEqual(y(5),100*exp(-p.Friction*.001/p.Inertia),AbsTol=1e-11);
            t.verifyEqual(y(1:3),zeros(3,1),AbsTol=1e-12);
        end
        function disabledDiodes(t)
            p=plant_parameters(); x=[3;-3;0;0;0]; p.Inertia=1e30;
            [~,~,v]=bldc.plant_measure(x,zeros(3,1,'uint16'),false(3,1),false,12,p);
            y=bldc.plant_step(x,zeros(3,1,'uint16'),false(3,1),false,12,0,p,.01);
            t.verifyEqual(v(1:2),single([0;12]),AbsTol=1e-6);
            t.verifyEqual(y(1:3),zeros(3,1),AbsTol=1e-12);
        end
        function commutationContinuity(t)
            p=plant_parameters(); x=[3;-3;0;pi/2;100];
            y=bldc.plant_step(x,uint16([50000;0;15535]),logical([1;0;1]),true,12,0,p,1e-9);
            t.verifyLessThan(max(abs(y(1:3)-x(1:3))),1e-4);
            t.verifyEqual(sum(y(1:3)),0,AbsTol=1e-12);
        end
        function energyAndConvergence(t)
            r=plant_physical_checks();
            t.verifyLessThan(r.maxKcl,1e-12);
            t.verifyLessThanOrEqual(r.maxOffEnergyGain,1e-10);
            t.verifyLessThan(r.fineError,r.coarseError*.7);
            t.verifyGreaterThan(r.minForwardTorque,0);
            t.verifyLessThan(r.maxReverseTorque,0);
            t.verifyLessThan(r.maxPowerError,1e-12);
            t.verifyLessThan(r.maxCrossError,1e-5);
            t.verifyGreaterThan(r.minCorrectCrossingSlope,0);
        end
        function overspeedRectifiesWithAllGatesOff(t)
            p=plant_parameters(); x=[0;0;0;pi/2;1000];
            y=bldc.plant_step(x,zeros(3,1,'uint16'),false(3,1),false,12,0,p,1e-5);
            t.verifyLessThan(y(1),0);
            t.verifyGreaterThan(y(2:3),zeros(2,1));
            t.verifyEqual(sum(y(1:3)),0,AbsTol=1e-12);
            t.verifyLessThan(.5*p.Ls*sum(y(1:3).^2)+.5*p.Inertia*y(5)^2,.5*p.Inertia*x(5)^2);
        end
        function measurementTypesAndAdcSaturation(t)
            p=plant_parameters();
            [raw,hall,v,i,theta,w]=bldc.plant_measure([40;-40;0;0;10], ...
                zeros(3,1,'uint16'),false(3,1),false,12,p);
            t.verifyEqual(raw,uint16([65535;0;32768]));
            t.verifyClass(hall,'uint8'); t.verifyClass(v,'single');
            t.verifyClass(i,'single'); t.verifyClass(theta,'single');
            t.verifyEqual(w,single(20),AbsTol=single(1e-6));
        end
        function electromagneticTorqueDrivesMechanicalState(t)
            result=plant_torque_checks();
            t.verifyLessThan(result.maxError,1e-12);
            t.verifyGreaterThan(result.minimumSignedAcceleration,0);
        end
        function nativeTerminalAcceptanceValidTrace(t)
            result=plant_terminal_acceptance(plant_terminal_fixture('good'));
            t.verifyTrue(result.pass);
        end
        function nativeTerminalAcceptanceRejectsBias(t)
            result=plant_terminal_acceptance(plant_terminal_fixture('biasedVoltage'));
            t.verifyFalse(result.voltagePass);
            t.verifyFalse(result.pass);
        end
        function nativeTerminalAcceptanceRejectsSlope(t)
            result=plant_terminal_acceptance(plant_terminal_fixture('reversedSlope'));
            t.verifyFalse(result.slopePass);
            t.verifyFalse(result.pass);
        end
        function nativeTerminalAcceptanceRejectsDelayedCrossing(t)
            result=plant_terminal_acceptance(plant_terminal_fixture('delayedCrossing'));
            t.verifyFalse(result.crossingPass);
            t.verifyFalse(result.pass);
        end
        function nativeTerminalAcceptanceRejectsSharedDelay(t)
            result=plant_terminal_acceptance(plant_terminal_fixture('sharedDelay'));
            t.verifyFalse(result.crossingPass);
            t.verifyFalse(result.pass);
        end
        function nativeTerminalAcceptanceRejectsReleaseDelay(t)
            result=plant_terminal_acceptance(plant_terminal_fixture('delayedRelease'));
            t.verifyFalse(result.releasePass);
            t.verifyFalse(result.pass);
        end
        function nativeTerminalAcceptanceRejectsEmptyWindow(t)
            result=plant_terminal_acceptance(plant_terminal_fixture('noUsableSamples'));
            t.verifyFalse(result.coveragePass);
            t.verifyFalse(result.pass);
        end
        function nativeTerminalAcceptanceRejectsMaskedNaN(t)
            result=plant_terminal_acceptance(plant_terminal_fixture('nanHostCurrent'));
            t.verifyFalse(result.pass);
        end
        function nativeTerminalAcceptanceRejectsInvalidTrace(t,invalidTrace)
            result=plant_terminal_acceptance(plant_terminal_fixture(invalidTrace));
            t.verifyFalse(result.pass);
        end
    end
end
