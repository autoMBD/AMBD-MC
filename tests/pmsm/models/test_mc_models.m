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
% File:        test_mc_models.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Test PMSM runtime control and safety behavior.
% =================================================================================

classdef test_mc_models < matlab.unittest.TestCase
    %test_mc_models - Verify shared model behavior and native plant timing
    properties
        Info
    end
    properties (TestParameter)
        FaultSource = {"external","rail"}
    end
    methods (TestClassSetup)
        function project(testCase)
            root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            testCase.Info=ambd_mc("setup","pmsm");
        end
    end
    methods (Test)
        function bothModelPathsExecuteTheSameCore(testCase)
            p=mc.defaults();p.PositionMode=uint8(1);p.AlignTime=single(4)*p.Ts;
            r=test_mc_models.recording(p,40);
            r.DrivingEvent([7 11 15])=false;
            r.CommandEvent(5:9)=false;r.SpeedReq(5:end)=single(150);
            motor=mc.initial_state(p);motor.Mode=uint8(5);motor.Calibrated=true;
            motor.CalibrationCount=p.CalibrationSamples;
            raw=test_mc_models.component("FOC_PIL_StateMch_model",r,p,motor);
            physical=test_mc_models.physical(r,p);
            core=test_mc_models.component("FOC_PIL_Algth_model",physical,p,mc.core_initial_state(p));
            a=raw.yout{6}.Values;b=core.yout{6}.Values;
            testCase.verifyEqual(a.CoreMode.Data,b.CoreMode.Data);
            testCase.verifyEqual(a.Tick.Data,b.Tick.Data);
            testCase.verifyEqual(a.Current.Data,b.Current.Data);
            testCase.verifyEqual(a.CurrentDq.Data,b.CurrentDq.Data);
            testCase.verifyEqual(a.ReferenceDq.Data,b.ReferenceDq.Data);
            testCase.verifyEqual(a.Voltage.Data,b.Voltage.Data);
            testCase.verifyEqual(a.Duty.Data,b.Duty.Data);
            testCase.verifyEqual(a.Omega.Data,b.Omega.Data);
            testCase.verifyEqual(raw.yout{1}.Values.Data, ...
                uint16(round(core.yout{1}.Values.Data*single(p.PwmPeriod))));
        end
        function motorFaultCutsOutputsOnTheSameSample(testCase,FaultSource)
            p=mc.defaults();p.PositionMode=uint8(1);p.AlignTime=single(4)*p.Ts;
            r=test_mc_models.recording(p,25);
            [r,mask]=test_mc_models.inject(r,FaultSource,12);
            r.DrivingEvent(12)=false;
            motor=mc.initial_state(p);motor.Mode=uint8(5);motor.Calibrated=true;
            out=test_mc_models.component("FOC_PIL_StateMch_model",r,p,motor);
            status=out.yout{6}.Values;
            testCase.verifyFalse(out.yout{5}.Values.Data(12));
            testCase.verifyEqual(out.yout{1}.Values.Data(12),uint16(32768));
            testCase.verifyEqual(out.yout{2}.Values.Data(12),uint16(32768));
            testCase.verifyEqual(out.yout{3}.Values.Data(12),uint16(32768));
            testCase.verifyNotEqual(bitand(status.FaultBits.Data(12),mask),uint16(0));
            testCase.verifyEqual(status.ApplicationMode.Data(12),uint8(3));
        end
        function corePortPreservesSubAdcResolution(testCase)
            p=mc.defaults();r=test_mc_models.physical(test_mc_models.recording(p,5),p);
            r.Current=repmat(single([.0004 -.0001 -.0003]),5,1);
            out=test_mc_models.component("FOC_PIL_Algth_model",r,p,mc.core_initial_state(p));
            status=out.yout{6}.Values;
            actual=test_mc_models.rows(status.Current);
            testCase.verifyEqual(actual,r.Current);
        end
        function nativePlantDisabledMeansZeroVoltageBraking(testCase)
            p=mc.defaults();
            [trace,recording]=test_mc_models.plant(p,.03,false);
            coast=-.005/double(p.Friction)*(1-exp(-double(p.Friction)/double(p.Inertia)*.03)) ...
                *double(p.PolePairs);
            testCase.verifyFalse(any(trace.GateOutput));
            testCase.verifyEqual(recording.AppliedVoltage,zeros(size(recording.AppliedVoltage),'single'));
            testCase.verifyLessThan(trace.OmegaTruth(end),single(0));
            testCase.verifyLessThan(abs(double(trace.OmegaTruth(end))),abs(coast)*.99);
        end
        function actualVoltageTracksTheCompletedInterval(testCase)
            p=mc.defaults();p.AlignTime=single(.002);
            [trace,recording]=test_mc_models.plant(p,.012,true);
            expected=test_mc_models.intervalVoltage(trace,recording,p);
            testCase.verifyEqual(recording.AppliedVoltage,expected,AbsTol=single(2e-6));
            testCase.verifyTrue(any(recording.Vdc==single(10)));
            testCase.verifyEqual(numel(trace.Time),193);
        end
    end
    methods (Static,Access=private)
        function value=rows(signal)
            count=numel(signal.Time);value=signal.Data;
            if size(value,1)==count
                value=reshape(value,count,[]);
            else
                value=reshape(permute(value,[ndims(value),1:ndims(value)-1]),count,[]);
            end
        end
        function r=recording(p,count)
            u=mc.default_input(p);r.Time=(0:count-1)'/16000;
            r.CurrentRaw=repmat(uint16([32893 32518 32893]),count,1);
            r.Control=ones(count,1,'uint8');r.Fault=false(count,1);
            r.CommandEvent=true(count,1);r.DrivingEvent=true(count,1);r.TimerEvent=true(count,1);
            r.SpeedReq=repmat(single(100),count,1);r.Vdc=repmat(single(12),count,1);
            r.Position=zeros(count,1,'single');r.AppliedVoltage=zeros(count,2,'single');
            for field=fieldnames(u.Tuning)'
                r.Tuning.(field{1})=repmat(u.Tuning.(field{1}),count,1);
            end
        end
        function r=physical(r,p)
            r.Current=(single(r.CurrentRaw)-p.AdcOffset)/p.AdcCountsPerAmp;
            r=rmfield(r,'CurrentRaw');r.Disable=false(size(r.Time));
        end
        function [r,mask]=inject(r,source,index)
            if source=="external",r.Fault(index:end)=true;mask=uint16(1);
            else,r.CurrentRaw(index:end,1)=uint16(0);mask=uint16(32);end
        end
        function out=component(model,recording,p,state)
            open_system(model);
            in=Simulink.SimulationInput(model);
            in=in.setExternalInput(mc_recording_dataset(recording));
            in=in.setModelParameter('StopTime',num2str(recording.Time(end),17), ...
                'SimulationMode','normal','SaveOutput','on','OutputSaveName','yout', ...
                'SaveFormat','Dataset','ReturnWorkspaceOutputs','on','LimitDataPoints','off');
            in=in.setVariable('McControl_Params',test_mc_models.parameter(p,'tMcControlParams'));
            if contains(model,"Algth")
                in=in.setVariable('McCoreRuntime_Init',test_mc_models.parameter(state,'tMcCoreRuntime'));
            else
                in=in.setVariable('McRuntime_Init',test_mc_models.parameter(state,'tMcRuntime'));
            end
            out=sim(in);
        end
        function [trace,recording]=plant(p,duration,enabled)
            model='FOC_PIL_Algth_top';open_system(model);
            time=(0:round(duration*16000))'/16000;count=numel(time);
            voltage=repmat(single(12),count,1);voltage(time>=.006)=single(10);
            control=repmat(uint8(enabled),count,1);
            loadTorque=repmat(.005*double(~enabled),count,1);
            data={repmat(single(100),count,1),control,false(count,1),loadTorque,voltage};
            names={'SpeedReq','Control','Fault','LoadTorque','Vdc'};
            inputs=Simulink.SimulationData.Dataset;
            for index=1:numel(data)
                inputs=addElement(inputs,setinterpmethod(timeseries(data{index},time),'zoh'),names{index});
            end
            in=Simulink.SimulationInput(model);in=in.setExternalInput(inputs);
            in=in.setVariable('McControl_Params',test_mc_models.parameter(p,'tMcControlParams'));
            in=in.setVariable('McPlant_Params',test_mc_models.parameter(p,'tMcControlParams'));
            in=in.setVariable('McCoreRuntime_Init',test_mc_models.parameter(mc.core_initial_state(p),'tMcCoreRuntime'));
            in=in.setModelParameter('StopTime',num2str(duration,17),'SimulationMode','normal', ...
                'SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset', ...
                'ReturnWorkspaceOutputs','on','LimitDataPoints','off','Decimation','1');
            out=sim(in);[trace,recording]=mc_read_host_trace(out);
        end
        function expected=intervalVoltage(trace,recording,p)
            expected=zeros(numel(trace.Time),2,'single');
            for index=3:numel(trace.Time)
                if trace.GateOutput(index-1) && trace.GateOutput(index-2)
                    duty=double(single(trace.DutyCounts(index-2,:))/single(p.PwmPeriod));
                    phase=double(recording.Vdc(index-1))*(duty-mean(duty));
                    expected(index,:)=mc.clarke(single(phase(:)))';
                end
            end
        end
        function value=parameter(data,type)
            value=Simulink.Parameter(data);value.DataType=['Bus: ',type];
        end
    end
end
