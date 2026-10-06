classdef bldcAlgorithmsTest < matlab.unittest.TestCase
    % Analytic tests for the BLDC control primitives.
    % SPDX-License-Identifier: MIT
    % Copyright (c) 2026 autoMBD
    properties (TestParameter)
        Sector = num2cell(uint8(1:6))
        Direction = {int8(1),int8(-1)}
    end
    methods (TestClassSetup)
        function sourcePath(testCase)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'mc-models','bldc','algo')));
        end
    end
    methods (Test)
        function hallCodesAreNotSectorIndices(testCase)
            actual=zeros(1,6,'uint8');
            codes=uint8([5,4,6,2,3,1]);
            for k=1:6, actual(k)=bldc.hall_decode(codes(k)); end
            testCase.verifyEqual(actual,uint8(1:6));
            testCase.verifyEqual(bldc.hall_decode(uint8(0)),uint8(0));
            testCase.verifyEqual(bldc.hall_decode(uint8(7)),uint8(0));
            testCase.verifyEqual(bldc.hall_decode(uint8(255)),uint8(0));
        end
        function complementaryLegsPreserveFloatingPhase(testCase,Sector,Direction)
            pairs=uint8([1,2;1,3;2,3;2,1;3,1;3,2]);
            pair=pairs(Sector,:);
            if Direction<0, pair=fliplr(pair); end
            [counts,enabled]=bldc.commutate(Sector,Direction,single(.6),uint16(65535));
            expected=zeros(3,1,'uint16');
            expected(pair(1))=uint16(52428);expected(pair(2))=uint16(13107);
            testCase.verifyEqual(counts,expected);
            testCase.verifyEqual(enabled,expected>uint16(0));
            testCase.verifyEqual(sum(uint32(counts),'native'),uint32(65535));
        end
        function zeroDutyActivePairIsDifferentFromDisable(testCase)
            [counts,enabled]=bldc.commutate(uint8(1),int8(1),single(0),uint16(65535));
            testCase.verifyEqual(counts,uint16([32768;32767;0]));
            testCase.verifyEqual(enabled,[true;true;false]);
            [off,mask]=bldc.commutate(uint8(0),int8(1),single(1),uint16(65535));
            testCase.verifyEqual(off,zeros(3,1,'uint16'));
            testCase.verifyFalse(any(mask));
        end
        function modulationIsClamped(testCase)
            [counts,~]=bldc.commutate(uint8(1),int8(1),single(2),uint16(65535));
            testCase.verifyEqual(counts,uint16([65535;0;0]));
        end
        function invalidDirectionDisablesAllLegs(testCase)
            [counts,mask]=bldc.commutate(uint8(1),int8(0),single(.5),uint16(65535));
            testCase.verifyEqual(counts,zeros(3,1,'uint16'));
            testCase.verifyFalse(any(mask));
        end
        function sectorCentersFollowElectricalAngle(testCase)
            angles=(1:6)*pi/3;
            actual=zeros(1,6,'uint8');
            for k=1:6, actual(k)=bldc.sector(single(angles(k))); end
            testCase.verifyEqual(actual,uint8(1:6));
            testCase.verifyEqual(bldc.sector(single(-pi/3)),uint8(5));
        end
        function sectorBoundarySidesAndPeriodWrapAreCorrect(testCase,Sector)
            boundary=pi/6+(double(Sector)-1)*pi/3;
            previous=uint8(mod(double(Sector)-2,6)+1);
            testCase.verifyEqual(bldc.sector(single(boundary-1e-4)),previous);
            testCase.verifyEqual(bldc.sector(single(boundary+1e-4)),Sector);
            testCase.verifyEqual(bldc.sector(single(boundary+2*pi+1e-4)),Sector);
            testCase.verifyEqual(bldc.sector(single(boundary-2*pi-1e-4)),previous);
            testCase.verifyEqual(bldc.sector(single(NaN)),uint8(0));
        end
        function piDoesNotWindUpOutward(testCase)
            [output,state]=bldc.pi_step(single(5),single(.3),single(2), ...
                single(10),single(.001),single(0),single(1));
            testCase.verifyEqual(output,single(1),AbsTol=single(1e-7));
            testCase.verifyEqual(state,single(.3),AbsTol=single(1e-7));
        end
        function piCanRecoverFromSaturation(testCase)
            [output,state]=bldc.pi_step(single(-.2),single(1.1),single(1), ...
                single(10),single(.01),single(0),single(1));
            testCase.verifyEqual(output,single(.88),AbsTol=single(2e-7));
            testCase.verifyEqual(state,single(1.08),AbsTol=single(2e-7));
        end
        function hallLowSpeedGainsMatchAvailableEdgeRate(testCase)
            p=bldc.defaults();[kp,ki]=bldc.speed_gains(single(20),p);
            testCase.verifyEqual(kp,p.KpSpeed*single(.25),AbsTol=single(1e-8));
            testCase.verifyEqual(ki,p.KiSpeed*single(.0625),AbsTol=single(1e-8));
            [kp,ki]=bldc.speed_gains(single(-100),p);
            testCase.verifyEqual(kp,p.KpSpeed,AbsTol=single(1e-8));
            testCase.verifyEqual(ki,p.KiSpeed,AbsTol=single(1e-8));
        end
        function sensorlessKeepsItsQualifiedSpeedGains(testCase)
            p=bldc.defaults();p.PositionMode=uint8(1);
            [kp,ki]=bldc.speed_gains(single(20),p);
            testCase.verifyEqual(kp,p.KpSpeed,AbsTol=single(1e-8));
            testCase.verifyEqual(ki,p.KiSpeed,AbsTol=single(1e-8));
        end
    end
end
