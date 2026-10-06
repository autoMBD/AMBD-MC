classdef bldcVoltageAcquisitionTest < matlab.unittest.TestCase
    % Measured terminal phase acquisition without motor truth or R/L/Ke.
    % SPDX-License-Identifier: MIT
    % Copyright (c) 2026 autoMBD
    properties (TestParameter)
        Sector = num2cell(uint8(1:6))
        Direction = {int8(1),int8(-1)}
    end
    methods (TestClassSetup)
        function sourcePath(t)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            t.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'mc-models','bldc','algo')));
        end
    end
    methods (Test)
        function terminalRatiosRecoverPhase(t,Sector,Direction)
            pairs=uint8([1,2;1,3;2,3;2,1;3,1;3,2]);
            floating=uint8([3,2,1,3,2,1]);v=single(6)*ones(3,1,'single');
            v(pairs(Sector,1))=v(pairs(Sector,1))+single(Direction)*single(.5);
            v(pairs(Sector,2))=v(pairs(Sector,2))-single(Direction)*single(.5);
            v(floating(Sector))=v(floating(Sector))+single(Direction)*single(.25);
            [theta,sector,valid]=bldc.voltage_angle(v,Direction,single(12),single(.2));
            slope=single([-1,1,-1,1,-1,1]);
            expected=mod(single(Sector)*single(pi/3)+slope(Sector)*single(pi/12),single(2*pi));
            t.verifyTrue(valid);t.verifyEqual(sector,Sector);
            t.verifyEqual(theta,expected,AbsTol=single(2e-6));
        end
        function zeroOrRailClampedSpanIsRejected(t)
            [~,~,zero]=bldc.voltage_angle(single([6;6;6]),int8(1),single(12),single(.2));
            [~,~,rail]=bldc.voltage_angle(single([12;0;6]),int8(1),single(12),single(.2));
            t.verifyFalse(zero);t.verifyFalse(rail);
        end
        function freshSnapshotsSeedOnlyProvisionalCommutation(t)
            p=bldc.defaults();p.PositionMode=uint8(1);
            s=bldc.initial_state(p);u=bldc.default_input(p);
            s.Mode=uint8(9);s.Direction=int8(1);s.OmegaOpen=single(70);
            u.TerminalVoltage=single([6.5;5.5;6.25]);
            s=bldc.coast_acquire(u,s,p);
            for k=1:double(p.AcquireSpacing)
                u.TerminalVoltage(3)=single(6.25-.5/30*k/double(p.AcquireSpacing));
                s=bldc.coast_acquire(u,s,p);
            end
            t.verifyTrue(s.AcquisitionReady);
            t.verifyEqual(s.SpeedEstimate,single(pi/180)/(single(p.AcquireSpacing)*p.Ts),AbsTol=single(.002));
            t.verifyEqual(s.ZcCount,uint16(0));
            t.verifyFalse(s.FeedbackReady);
            t.verifyGreaterThan(s.ZcCountdown,int32(0));
        end
        function residualCurrentPreventsSnapshotQualification(t)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            s.Mode=uint8(9);s.Current=single([.1;-.1;0]);
            u.TerminalVoltage=single([6.5;5.5;6.25]);
            s=bldc.coast_acquire(u,s,p);
            t.verifyEqual(s.AcquireStage,uint8(0));
            t.verifyFalse(s.AcquisitionReady);
        end
        function unchangedVoltagesCannotPretendToRotate(t)
            p=bldc.defaults();s=bldc.initial_state(p);u=bldc.default_input(p);
            s.Mode=uint8(9);s.OmegaOpen=single(100);
            u.TerminalVoltage=single([6.5;5.5;6.25]);
            for k=1:20,s=bldc.coast_acquire(u,s,p);end
            t.verifyFalse(s.AcquisitionReady);
            t.verifyEqual(s.ZcCount,uint16(0));
        end
    end
end
