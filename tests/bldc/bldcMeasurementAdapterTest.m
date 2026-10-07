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
% File:        bldcMeasurementAdapterTest.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Test the explicit-state BLDC sensor fault adapter.
% =================================================================================

classdef bldcMeasurementAdapterTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(t)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'mc-models','bldc','algo')));
            t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'mc-models','bldc','platform','pil')));
        end
    end
    methods (Test)
        function offsetsAndClamp(t)
            p=bldc.defaults();s=initial();
            [raw,h,v]=bldc_measurement_adapter(single([0;0;0]),uint8(5),single([1;2;3]),uint8(0),single([1;-1;10000]),single([2;3;4]),p,s);
            t.verifyEqual(raw,uint16([p.AdcOffset+p.AdcCountsPerAmp;p.AdcOffset-p.AdcCountsPerAmp;65535]));
            t.verifyEqual(h,uint8(5));t.verifyEqual(v,single([3;5;7]));
        end
        function hallModes(t)
            p=bldc.defaults();s=initial();z=zeros(3,1,'single');
            [~,h0]=bldc_measurement_adapter(z,uint8(5),z,uint8(1),z,z,p,s);
            [~,h7]=bldc_measurement_adapter(z,uint8(5),z,uint8(2),z,z,p,s);
            [~,jump]=bldc_measurement_adapter(z,uint8(5),z,uint8(4),z,z,p,s);
            t.verifyEqual(h0,uint8(0));t.verifyEqual(h7,uint8(7));t.verifyEqual(jump,uint8(6));
        end
        function hallFreezeAndRecovery(t)
            p=bldc.defaults();s=initial();z=zeros(3,1,'single');
            [~,~,~,s]=bldc_measurement_adapter(z,uint8(4),z,uint8(0),z,z,p,s);
            [~,first,~,s]=bldc_measurement_adapter(z,uint8(6),z,uint8(3),z,z,p,s);
            [~,second,~,s]=bldc_measurement_adapter(z,uint8(2),z,uint8(3),z,z,p,s);
            [~,normal]=bldc_measurement_adapter(z,uint8(3),z,uint8(0),z,z,p,s);
            t.verifyEqual(first,uint8(4));t.verifyEqual(second,uint8(4));t.verifyEqual(normal,uint8(3));
        end
        function terminalFreezeAndRecovery(t)
            p=bldc.defaults();s=initial();z=zeros(3,1,'single');v=single([1;2;3]);
            [~,~,~,s]=bldc_measurement_adapter(z,uint8(5),v,uint8(0),z,z,p,s);
            [~,~,first,s]=bldc_measurement_adapter(z,uint8(5),v+1,uint8(5),z,z,p,s);
            [~,~,second,s]=bldc_measurement_adapter(z,uint8(5),v+2,uint8(5),z,z,p,s);
            [~,~,normal]=bldc_measurement_adapter(z,uint8(5),v+3,uint8(0),z,z,p,s);
            t.verifyEqual(first,v);t.verifyEqual(second,v);t.verifyEqual(normal,v+3);
        end
        function invalidHallDoesNotReplaceLastValidSample(t)
            p=bldc.defaults();s=initial();z=zeros(3,1,'single');
            [~,~,~,s]=bldc_measurement_adapter(z,uint8(4),z,uint8(0),z,z,p,s);
            [~,~,~,s]=bldc_measurement_adapter(z,uint8(6),z,uint8(1),z,z,p,s);
            [~,frozen]=bldc_measurement_adapter(z,uint8(2),z,uint8(3),z,z,p,s);
            t.verifyEqual(frozen,uint8(4));
        end
        function nanVoltage(t)
            p=bldc.defaults();s=initial();z=zeros(3,1,'single');
            [~,~,v]=bldc_measurement_adapter(z,uint8(5),z,uint8(6),z,z,p,s);
            t.verifyTrue(all(isnan(v)));
        end
    end
end
function s=initial()
s=struct('Hall',uint8(5),'Terminal',zeros(3,1,'single'));
end
