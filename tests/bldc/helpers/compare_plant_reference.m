function report = compare_plant_reference(attemptId)
% SPDX-License-Identifier: MIT
%COMPARE_PLANT_REFERENCE Compare the host plant with a physical BLDC bridge.
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root,'mc-models','bldc','algo'));
artifacts=fullfile(root,'.agent-env','bldc-plant');
model='bldc_native_reference';
names={'open_forward','open_reverse','locked_rotor','commutation','all_off', ...
    'bipolar_pwm','terminal_forward','terminal_reverse','bipolar_pwm_32k'};
results=cell(1,numel(names));
for k=1:numel(names)
    spec=plant_reference_case(names{k});
    input=Simulink.SimulationInput(model);
    input=input.setVariable('theta0',spec.theta);
    input=input.setVariable('shaftSpeed',spec.speed);
    input=input.setVariable('nativeStep',spec.nativeStep);
    input=input.setVariable('stopTime',spec.stop);
    for phase=1:3
        label=char('A'+phase-1);
        input=input.setVariable(['gateHigh' label],[spec.time spec.high(:,phase)]);
        input=input.setVariable(['gateLow' label],[spec.time spec.low(:,phase)]);
    end
    out=sim(input);
    t=out.currentA.Time;
    current=[out.currentA.Data out.currentB.Data out.currentC.Data];
    phaseV=[out.phaseVoltage.Data out.phaseVoltageB.Data out.phaseVoltageC.Data];
    terminal=[out.terminalVoltageA.Data out.terminalVoltageB.Data out.terminalVoltageC.Data];
    nativeKcl=max(abs(sum(current,2)));
    torqueNode=out.simlog.NativeBLDC.electrical_torque;
    nativeTorque=interp1(torqueNode.series.time,torqueNode.series.values('N*m'),t,'linear');
    phaseShape=zeros(size(current));
    phaseOffsets=[0 -2*pi/3 2*pi/3];
    for phase=1:3
        phaseShape(:,phase)=interp1([0 pi/6 5*pi/6 7*pi/6 11*pi/6 2*pi], ...
            [0 1 1 -1 -1 0],mod(spec.theta+2*spec.speed*t+phaseOffsets(phase),2*pi),'linear');
    end
    torqueError=max(abs(nativeTorque-.0078104522*sum(phaseShape.*current,2)));
    terminalAcceptance=struct('applicable',false,'pass',true);
    ripplePeakToPeak=NaN; hostTerminal=[];
    if startsWith(spec.name,'open')
        theta=spec.theta+2*spec.speed*t;
        % Independent piecewise interpolation; no production shape function.
        expected=zeros(size(phaseV));
        for phase=1:3
            offsets=[0 -2*pi/3 2*pi/3];
            angle=mod(theta+offsets(phase),2*pi);
            expected(:,phase)=spec.speed*.0078104522*interp1( ...
                [0 pi/6 5*pi/6 7*pi/6 11*pi/6 2*pi], ...
                [0 1 1 -1 -1 0],angle,'linear');
        end
        emfNode=out.simlog.NativeBLDC.back_emf;
        nativeEmf=emfNode.series.values('V');
        nativeEmfTime=emfNode.series.time;
        nativeEmf=interp1(nativeEmfTime,nativeEmf,t,'linear');
        emfError=max(abs(nativeEmf-expected),[],'all');
        % The finite off-state conductance makes zero initial winding current
        % an RL boundary layer. Validate that layer, including t=0, instead
        % of dropping the initial sample or comparing it to an ideal open.
        expectedTerminal=plant_open_leakage_voltage(t,expected);
        terminalError=max(abs(phaseV-expectedTerminal),[],'all');
        error=max(emfError,terminalError); limit=1e-4;
        host=[]; hostTime=[]; currentError=[];
    else
        [hostTime,host,hostTerminal]=plant_reference_host(spec);
        [uniqueT,index]=unique(t,'last');
        sampled=interp1(uniqueT,current(index,:),hostTime,'linear');
        if startsWith(spec.name,'bipolar_pwm')
            integral=cumtrapz(uniqueT,current(index,:));
            intervalMean=diff(interp1(uniqueT,integral,hostTime,'linear'))./diff(hostTime);
            hostMean=(host(1:end-1,1:3)+host(2:end,1:3))/2;
            after=hostTime(2:end)>.003;
            error=max(abs(intervalMean(after,:)-hostMean(after,:)),[],'all'); limit=.1;
            ripplePeakToPeak=plant_carrier_ripple(uniqueT,current(index,1),spec.carrierPeriod);
        else
            error=max(abs(sampled-host(:,1:3)),[],'all');
            limit=.03;
            if strcmp(spec.name,'locked_rotor'), limit=.01; end
        end
        currentError=max(abs(sampled-host(:,1:3)),[],'all');
        if startsWith(spec.name,'terminal')
            trace=struct('time',hostTime,'nativeTime',t,'hostCurrent',host(:,1:3), ...
                'nativeCurrent',current,'hostTerminal',hostTerminal,'nativeTerminal',terminal, ...
                'switchTime',.001,'expectedCrossing',.003, ...
                'expectedSlope',-6*.0078104522*2*spec.speed^2/pi, ...
                'rail',spec.releaseRail,'floatPhase',3,'sampleTime',1/16000, ...
                'nativeStep',spec.nativeStep);
            terminalAcceptance=plant_terminal_acceptance(trace);
        end
    end
    results{k}=struct('name',spec.name,'maxError',error,'limit',limit, ...
        'maxInstantaneousCurrentError',currentError,'maxNativeKcl',nativeKcl, ...
        'maxTorqueErrorNm',torqueError, ...
        'terminalAcceptance',terminalAcceptance,'ripplePeakToPeakA',ripplePeakToPeak, ...
        'pass',error<=limit && nativeKcl<1e-8 && torqueError<1e-6 && terminalAcceptance.pass);
    save(fullfile(artifacts,[spec.name '.mat']),'spec','t','current','phaseV','terminal', ...
        'hostTime','host','hostTerminal','terminalAcceptance');
end

ripple16=results{strcmp(names,'bipolar_pwm')}.ripplePeakToPeakA;
ripple32=results{strcmp(names,'bipolar_pwm_32k')}.ripplePeakToPeakA;
rippleRatio=ripple32/ripple16;
rippleConvergence=struct('frequencyHz',[16000 32000], ...
    'meanCyclePeakToPeakA',[ripple16 ripple32],'ratio',rippleRatio, ...
    'allowedRatio',[.4 .6],'pass',rippleRatio>=.4 && rippleRatio<=.6);
report=struct('pass',all(cellfun(@(x)x.pass,results)) && rippleConvergence.pass, ...
    'status','PROVISIONAL','attempt',attemptId, ...
    'cases',[results{:}],'reference','Simscape Electrical BLDC + six physical switches + six diodes', ...
    'switchResistanceOhm',1e-4,'diodeForwardVoltageV',1e-4,'offConductanceS',1e-8, ...
    'pwmRippleConvergence',rippleConvergence);
fid=fopen(fullfile(artifacts,'native-results.json'),'w');
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));
disp(report);
end

function voltage=plant_open_leakage_voltage(time,emf)
G=4e-8; R=.56; L=.0004;
tau=L/(R+1/G); gain=1/(R+1/G);
voltage=zeros(size(emf)); current=zeros(1,3);
meanEmf=mean(emf,2); forcing=emf-meanEmf;
voltage(1,:)=meanEmf(1);
for k=2:numel(time)
    h=time(k)-time(k-1);
    slope=(forcing(k,:)-forcing(k-1,:))/h;
    current=-gain*(forcing(k,:)-slope*tau)+ ...
        (current+gain*(forcing(k-1,:)-slope*tau))*exp(-h/tau);
    voltage(k,:)=meanEmf(k)-current/G;
end
end

function spec=plant_reference_case(name)
Ts=1/16000;
spec=struct('name',name,'theta',1,'speed',0,'stop',.004,'nativeStep',Ts/100, ...
    'carrierPeriod',Ts,'releaseRail',NaN);
spec.time=(0:Ts:spec.stop)'; n=numel(spec.time);
spec.high=zeros(n,3); spec.low=zeros(n,3);
switch name
    case {'open_forward','open_reverse'}
        spec.theta=0; spec.speed=100;
        if strcmp(name,'open_reverse'), spec.speed=-100; end
        spec.stop=.032; spec.time=[0;spec.stop];
        spec.high=zeros(2,3); spec.low=zeros(2,3); spec.nativeStep=1e-5;
    case 'locked_rotor'
        spec.high(:,1)=1; spec.low(:,2)=1;
    case 'commutation'
        spec.speed=80;
        first=spec.time<.001; second=spec.time>=.001 & spec.time<.002;
        third=spec.time>=.002 & spec.time<.003;
        spec.high(first|second,1)=1; spec.low(first,2)=1;
        spec.low(second|third,3)=1; spec.high(third,2)=1;
    case 'all_off'
        spec.high(spec.time<.001,1)=1; spec.low(spec.time<.001,2)=1;
    case {'terminal_forward','terminal_reverse'}
        spec.speed=100;
        if strcmp(name,'terminal_reverse'), spec.speed=-100; end
        spec.theta=pi/3-2*spec.speed*.003;
        pre=spec.time<.001; post=~pre;
        if spec.speed>0
            spec.high(:,1)=1; spec.low(pre,3)=1; spec.low(post,2)=1;
            spec.releaseRail=12;
        else
            spec.high(pre,3)=1; spec.high(post,2)=1; spec.low(:,1)=1;
            spec.releaseRail=0;
        end
    case {'bipolar_pwm','bipolar_pwm_32k'}
        spec.stop=.01; duty=49151/65535;
        if strcmp(name,'bipolar_pwm_32k'), spec.carrierPeriod=Ts/2; end
        period=spec.carrierPeriod;
        starts=(0:period:spec.stop-period)';
        spec.time=sort([starts;starts+duty*period;spec.stop]);
        % Use event parity to avoid floating-point mod ambiguity at edges.
        high=repmat([1;0],numel(starts),1); high=[high;1];
        spec.high=[high 1-high zeros(size(high))];
        spec.low=[1-high high zeros(size(high))];
        spec.nativeStep=period/100;
end
end

function [time,history,terminal]=plant_reference_host(spec)
p=plant_parameters(); p.Inertia=1e30; p.Friction=0;
Ts=1/16000; time=(0:Ts:spec.stop)';
x=[0;0;0;spec.theta;spec.speed]; history=zeros(numel(time),5); history(1,:)=x';
terminal=zeros(numel(time),3);
for n=1:numel(time)
    if startsWith(spec.name,'bipolar_pwm')
        q=uint16([49151;16384;0]); enabled=logical([1;1;0]);
    else
        ix=find(spec.time<=time(n)+1e-14,1,'last');
        q=uint16(spec.high(ix,:)'*65535);
        enabled=logical(spec.high(ix,:)'+spec.low(ix,:)');
    end
    [~,~,measured]=bldc.plant_measure(x,q,enabled,true,12,p);
    terminal(n,:)=double(measured)';
    if n<numel(time)
        x=bldc.plant_step(x,q,enabled,true,12,0,p,Ts);
        history(n+1,:)=x';
    end
end
end

function ripple=plant_carrier_ripple(t,current,period)
starts=(.003:period:.01-period)'; peaks=zeros(size(starts));
for k=1:numel(starts)
    selected=t>=starts(k)-1e-12 & t<=starts(k)+period+1e-12;
    peaks(k)=max(current(selected))-min(current(selected));
end
ripple=mean(peaks);
end
