% SPDX-License-Identifier: MIT
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
