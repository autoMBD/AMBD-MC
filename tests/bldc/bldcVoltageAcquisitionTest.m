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
% File:        bldcVoltageAcquisitionTest.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Measured terminal phase acquisition without motor truth or R/L/Ke.
% =================================================================================

classdef bldcVoltageAcquisitionTest < matlab.unittest.TestCase
    % Measured terminal phase acquisition without motor truth or R/L/Ke.
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
