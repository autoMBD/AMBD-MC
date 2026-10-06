classdef bldcAcceptanceTest < matlab.unittest.TestCase
    % Negative tests for physical and replay acceptance, independent of SIL.
    % SPDX-License-Identifier: MIT
    % Copyright (c) 2026 autoMBD
    properties (TestParameter)
        Corruption = {'truncated','nan','wrong_state','bad_mask','bad_pwm', ...
            'false_saturation','lost_qualification','late_disable'}
    end
    methods (TestClassSetup)
        function paths(t)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'mc-models','bldc','algo')));
            t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'mc-models','bldc','platform','pil')));
        end
    end
    methods (Test)
        function consistentTraceIsAccepted(t)
            [trace,scenario]=fixture();
            result=bldc_assess_host_trace(trace,scenario);
            t.verifyTrue(result.Passed);
        end
        function invalidPhysicalTraceIsRejected(t,Corruption)
            [trace,scenario]=fixture();
            switch Corruption
                case 'truncated'
                    trace.Time(end)=trace.Time(end)-1/16000;
                case 'nan'
                    trace.CurrentTruth(20,3)=single(NaN);
                case 'wrong_state'
                    trace.Mode(:)=uint8(8);
                case 'bad_mask'
                    trace.PhaseMask(20,3)=true;
                case 'bad_pwm'
                    trace.DutyCounts(20,1)=trace.DutyCounts(20,1)+uint16(1);
                case 'false_saturation'
                    scenario.SaturationWindows=[0,scenario.Duration,.002];
                case 'lost_qualification'
                    trace.FeedbackReady(:)=false;
                case 'late_disable'
                    scenario.ExpectedFaultMask=uint16(1);
                    scenario.FaultWindows=[.005,.005+1/16000,.01,1];
                    trace.FaultBits(trace.Time>=.005)=uint16(1);
            end
            result=bldc_assess_host_trace(trace,scenario);
            t.verifyFalse(result.Passed);
        end
        function exactReplayIsAccepted(t)
            [trace,~]=fixture();
            result=bldc_compare_outputs(trace,trace);
            t.verifyTrue(result.Passed);
            t.verifyTrue(result.StrictBitwisePassed);
        end
        function replayRejectsChangedIntegerCount(t)
            [trace,~]=fixture();actual=trace;
            actual.DutyCounts(20,1)=actual.DutyCounts(20,1)+uint16(1);
            result=bldc_compare_outputs(trace,actual);
            t.verifyFalse(result.Passed);
        end
        function replayRejectsChangedState(t)
            [trace,~]=fixture();actual=trace;actual.Mode(20)=uint8(11);
            result=bldc_compare_outputs(trace,actual);
            t.verifyFalse(result.Passed);
        end
        function replayRejectsHiddenNonfiniteData(t)
            [trace,~]=fixture();actual=trace;actual.SpeedEstimate(20)=single(NaN);
            result=bldc_compare_outputs(trace,actual);
            t.verifyFalse(result.Passed);
        end
        function scenarioHasAllNineMeasuredInputChannels(t)
            scenario=bldc_host_scenario("hall_steps");
            t.verifyEqual(scenario.Inputs.numElements,9);
            t.verifyEqual(scenario.Time(1),0,AbsTol=eps);
            t.verifyEqual(scenario.Time(end),scenario.Duration,AbsTol=1e-12);
            t.verifyEqual(scenario.Control.PositionMode,uint8(0));
            t.verifyFalse(isempty(scenario.SteadyWindows));
        end
        function parameterScenarioDoesNotRetuneController(t)
            scenario=bldc_host_scenario("sensorless_parameters_low_flux");
            defaults=bldc.defaults();
            t.verifyEqual(scenario.Control.Ke,defaults.Ke,AbsTol=single(1e-9));
            t.verifyEqual(scenario.Plant.Ke,defaults.Ke*single(.9),AbsTol=single(1e-9));
        end
        function unknownScenarioIsAnError(t)
            t.verifyError(@()bldc_host_scenario("unreviewed"),'bldc:UnknownScenario');
        end
        function zeroRequestStartsAtItsDeclaredIntegerSample(t)
            scenario=bldc_host_scenario("hall_zero_request");
            index=round(1.6*16000)+1;
            t.verifyEqual(scenario.Speed(index-1),single(200),AbsTol=single(1e-7));
            t.verifyEqual(scenario.Speed(index),single(0),AbsTol=single(1e-7));
        end
        function expectedFaultCannotAppearBeforeInjection(t)
            [trace,scenario]=fixture();scenario.ExpectedFaultMask=uint16(1);
            scenario.FaultWindows=[.005,.005+1/16000,.01,1];
            scenario.ClosedWindows=zeros(0,2);scenario.RequiredModes=uint8(3);
            trace.FaultBits(:)=uint16(1);trace.Mode(:)=uint8(3);
            trace.GateOutput(:)=false;trace.GateEnable(:)=false;
            trace.PhaseMask(:)=false;trace.PhaseEnable(:)=false;trace.DutyCounts(:)=uint16(0);
            result=bldc_assess_host_trace(trace,scenario);
            t.verifyFalse(result.Passed);
        end
        function faultBitsMustRemainLatched(t)
            [trace,scenario]=fixture();scenario.ExpectedFaultMask=uint16(1);
            scenario.FaultWindows=[0,0,.004,1];scenario.LatchWindows=[.005,.01];
            scenario.ClosedWindows=zeros(0,2);scenario.RequiredModes=uint8(3);
            trace.Mode(:)=uint8(3);trace.FaultBits(trace.Time<.004)=uint16(1);
            trace.GateOutput(:)=false;trace.GateEnable(:)=false;
            trace.PhaseMask(:)=false;trace.PhaseEnable(:)=false;trace.DutyCounts(:)=uint16(0);
            result=bldc_assess_host_trace(trace,scenario);
            t.verifyFalse(result.Passed);
        end
        function oppositeDirectionCannotArmBeforeStandstill(t)
            [trace,scenario]=fixture();scenario.ReversalWindows=[.004,1,-1];
            scenario.ClosedWindows=zeros(0,2);scenario.RequiredModes=uint8(14);
            ix=trace.Time>=.004;trace.Direction(ix)=int8(-1);
            % Retain the old phase orientation: even pre-arming the new
            % direction before the old motion stops violates the guard.
            result=bldc_assess_host_trace(trace,scenario);
            t.verifyFalse(result.Passed);
        end
        function stopMustActuallyReturnToIdleWithinDeadline(t)
            [trace,scenario]=fixture();scenario.StopWindows=[0,.01];
            scenario.ClosedWindows=zeros(0,2);scenario.RequiredModes=uint8(15);
            trace.Mode(:)=uint8(15);trace.OmegaTruth(:)=single(0);
            scenario.SteadyWindows=[0,.01,0];trace.GateOutput(:)=false;trace.GateEnable(:)=false;
            trace.PhaseMask(:)=false;trace.PhaseEnable(:)=false;trace.DutyCounts(:)=uint16(0);
            result=bldc_assess_host_trace(trace,scenario);
            t.verifyFalse(result.Passed);
        end
    end
end

function [trace,scenario]=fixture()
p=bldc.defaults();p.PositionMode=uint8(1);
time=(0:1/16000:.01)';n=numel(time);
s=bldc.initial_state(p);s.Mode=uint8(14);s.CurrentRef=single(3.2);
s.CurrentDemand=s.CurrentRef;s.Sector=uint8(1);s.GateEnable=true;
s.FeedbackReady=true;s.AcquisitionReady=true;s.ZcCount=uint16(8);
s.SpeedEstimate=single(200);s.SpeedRequest=single(200);s.SpeedRamped=single(200);
s.Current=single([3.2;-3.2;0]);s.Modulation=single(.5);
[s.DutyCounts,s.PhaseEnable]=bldc.commutate(s.Sector,s.Direction,s.Modulation,p.PwmPeriod);
[~,~,~,debug,m]=bldc.monitor(s,p);
trace.Time=time;trace.OmegaTruth=repmat(single(200),n,1);
trace.CurrentTruth=repmat(s.Current',n,1);trace.ThetaTruth=single(time*200+pi/3);
names=fieldnames(m);
for k=1:numel(names),trace.(names{k})=repmat(m.(names{k})(:)',n,1);end
trace.DutyCounts=repmat(s.DutyCounts',n,1);
trace.PhaseMask=repmat(s.PhaseEnable',n,1);trace.GateOutput=true(n,1);
trace.DebugData=repmat(debug.Data',n,1);trace.DebugEnabled=true(n,1);
scenario=struct('Name',"fixture",'Duration',.01,'Control',p, ...
    'PositionMode',uint8(1),'SteadyWindows',[0,.01,200], ...
    'OvershootWindows',[0,.01,200],'DisabledWindows',zeros(0,2), ...
    'ClosedWindows',[0,.01],'LowForcedWindows',zeros(0,2), ...
    'FaultWindows',zeros(0,4),'LatchWindows',zeros(0,2), ...
    'SaturationWindows',zeros(0,3),'UnsaturatedWindows',zeros(0,2), ...
    'RequiredModes',uint8(14),'ExpectedFaultMask',uint16(0), ...
    'PeakCurrentLimit',9.9,'PeakSpeedLimit',300,'StopOrigins',zeros(0,2), ...
    'StopWindows',zeros(0,2),'ReversalWindows',zeros(0,3));
end
