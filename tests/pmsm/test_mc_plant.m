classdef test_mc_plant < matlab.unittest.TestCase
    % SPDX-License-Identifier: MIT
    % Copyright (c) 2026 autoMBD
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
