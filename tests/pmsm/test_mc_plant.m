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
% File:        test_mc_plant.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Test the PMSM host plant physical behavior.
% =================================================================================

classdef test_mc_plant < matlab.unittest.TestCase
    % Independent physical checks for the average-voltage host plant.
    methods (TestClassSetup)
        function sourcePath(testCase)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'mc-models','pmsm','algo')));
        end
    end
    methods (Test)
        function unenergizedRestIsAnEquilibrium(testCase)
            p=mc.defaults();x=zeros(4,1);
            y=mc.plant_step(x,[0.5;0.5;0.5],12,0,false,p,double(p.Ts));
            testCase.verifyEqual(y,x);
        end
        function disabledRotorCoastsWithMechanicalTimeConstant(testCase)
            p=mc.defaults();x=[0;0;100;0];dt=0.0001;
            y=mc.plant_step(x,[0.5;0.5;0.5],12,0,false,p,dt);
            expected=100*exp(-double(p.Friction)/double(p.Inertia)*dt);
            testCase.verifyEqual(y(3),expected,AbsTol=1e-9);
            testCase.verifyEqual(y(1:2),[0;0]);
        end
        function qVoltageProducesPositiveTorque(testCase)
            p=mc.defaults();x=zeros(4,1);
            duty=double(mc.svpwm(single([0;1]),single(12),true));
            y=mc.plant_step(x,duty,12,0,true,p,double(p.Ts));
            testCase.verifyGreaterThan(y(2),0);
            testCase.verifyGreaterThan(y(3),0);
        end
        function mechanicalLoadHasCorrectSign(testCase)
            p=mc.defaults();x=zeros(4,1);dt=1e-6;
            y=mc.plant_step(x,[0.5;0.5;0.5],12,0.01,false,p,dt);
            testCase.verifyLessThan(y(3),0);
            testCase.verifyEqual(y(3)/dt,-0.01/double(p.Inertia),RelTol=3e-5);
        end
        function stationaryRotorCurrentMatchesRlResponse(testCase)
            p=mc.defaults();p.Inertia=single(1e12);x=zeros(4,1);dt=0.0001;
            duty=double(mc.svpwm(single([1;0]),single(12),true));
            y=mc.plant_step(x,duty,12,0,true,p,dt);
            expected=(1-exp(-double(p.Rs)/double(p.Ld)*dt))/double(p.Rs);
            testCase.verifyEqual(y(1),expected,AbsTol=1e-8);
            testCase.verifyEqual(y(2:3),[0;0],AbsTol=1e-12);
        end
    end
end
