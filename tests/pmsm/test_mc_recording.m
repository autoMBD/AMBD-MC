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
% File:        test_mc_recording.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Test PMSM runtime control and safety behavior.
% =================================================================================

classdef test_mc_recording < matlab.unittest.TestCase
    %test_mc_recording - Preserve the measured controller replay boundary
    methods (TestClassSetup)
        function sourcePath(testCase)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'mc-models','pmsm','algo')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'mc-models','pmsm','platform','pil')));
        end
    end
    methods (Test)
        function recordingInterfaceExists(testCase)
            testCase.verifyNotEmpty(which('mc_recording_dataset'));
        end
        function replayPreservesActualEventsAndVoltage(testCase)
            r=test_mc_recording.recording(false);
            dataset=mc_recording_dataset(r);
            testCase.verifyEqual(dataset.getElement('McDrivingEvent').Values.Data,r.DrivingEvent);
            testCase.verifyEqual(dataset.getElement('McCtrlEvent').Values.Data,r.CommandEvent);
            testCase.verifyEqual(dataset.getElement('AppliedVoltageAlpha').Values.Data, ...
                r.AppliedVoltage(:,1),AbsTol=single(0));
            testCase.verifyEqual(dataset.getElement('DcBusVoltage').Values.Data,r.Vdc);
        end
        function coreReplayPreservesPhysicalUnitsAndDisable(testCase)
            r=test_mc_recording.recording(true);
            dataset=mc_recording_dataset(r);
            testCase.verifyClass(dataset.getElement('Ia').Values.Data,'single');
            testCase.verifyEqual(dataset.getElement('Ia').Values.Data,r.Current(:,1));
            testCase.verifyEqual(dataset.getElement('Disable').Values.Data,r.Disable);
        end
        function rawReplayPreservesAdcCounts(testCase)
            r=test_mc_recording.recording(false);
            dataset=mc_recording_dataset(r);
            testCase.verifyClass(dataset.getElement('Ia').Values.Data,'uint16');
            testCase.verifyEqual(dataset.getElement('Ib').Values.Data,r.CurrentRaw(:,2));
        end
        function timeVaryingTuningIsNotReplacedByDefaults(testCase)
            r=test_mc_recording.recording(false);
            r.Tuning.IdKp=uint16([2000;3000;4000]);
            dataset=mc_recording_dataset(r);
            testCase.verifyEqual(dataset.getElement('McTuningPort').Values.IdKp.Data, ...
                r.Tuning.IdKp);
        end
        function missingActualEventCannotBeInvented(testCase)
            r=rmfield(test_mc_recording.recording(false),'DrivingEvent');
            testCase.verifyError(@()mc_recording_dataset(r),'mc:RecordingContract');
        end
    end
    methods (Static,Access=private)
        function r=recording(core)
            p=mc.defaults();u=mc.default_input(p);
            r.Time=(0:2)'*double(p.Ts);
            if core
                r.Current=single([.1 -.05 -.05;.2 -.1 -.1;.3 -.1 -.2]);
                r.Disable=logical([0;1;0]);
            else
                r.CurrentRaw=uint16([32868 32718 32718;32968 32668 32668;33068 32668 32568]);
            end
            r.Control=uint8([1;1;2]);r.Fault=false(3,1);
            r.CommandEvent=logical([1;0;1]);
            r.DrivingEvent=logical([1;0;1]);r.TimerEvent=logical([0;1;0]);
            r.SpeedReq=single([100;100;0]);r.Vdc=single([12;10;10]);
            r.Position=single([0;.1;.2]);
            r.AppliedVoltage=single([0 0;.7 -.2;.5 -.1]);
            r.Tuning=struct;
            for name=fieldnames(u.Tuning)'
                r.Tuning.(name{1})=repmat(u.Tuning.(name{1}),3,1);
            end
        end
    end
end
