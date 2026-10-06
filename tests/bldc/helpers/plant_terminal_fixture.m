function trace=plant_terminal_fixture(mode)
% SPDX-License-Identifier: MIT
Ts=1/16000; t=(0:Ts:.004)'; released=t>=.001375;
current=repmat([.5 .5 -1],numel(t),1);
current(released,:)=repmat([2 -2 0],sum(released),1);
terminal=repmat([12 0 12],numel(t),1);
terminal(released,3)=6-300*(t(released)-.003);
nativeTime=(0:Ts/100:.004)'; nativeReleased=nativeTime>=.001375;
nativeCurrent=repmat([.5 .5 -1],numel(nativeTime),1);
nativeCurrent(nativeReleased,:)=repmat([2 -2 0],sum(nativeReleased),1);
nativeTerminal=repmat([12 0 12],numel(nativeTime),1);
nativeTerminal(nativeReleased,3)=6-300*(nativeTime(nativeReleased)-.003);
trace=struct('time',t,'nativeTime',nativeTime,'hostCurrent',current, ...
    'nativeCurrent',nativeCurrent,'hostTerminal',terminal,'nativeTerminal',nativeTerminal, ...
    'switchTime',.001,'expectedCrossing',.003,'expectedSlope',-300, ...
    'rail',12,'floatPhase',3,'sampleTime',Ts,'nativeStep',Ts/100);
switch mode
    case 'biasedVoltage'
        trace.hostTerminal(released,3)=trace.hostTerminal(released,3)+.02;
    case 'reversedSlope'
        trace.hostTerminal(released,3)=12-trace.hostTerminal(released,3);
    case {'delayedCrossing','sharedDelay'}
        trace.hostTerminal(released,3)=trace.hostTerminal(released,3)+300*2*Ts;
        if strcmp(mode,'sharedDelay')
            trace.nativeTerminal(nativeReleased,3)=trace.nativeTerminal(nativeReleased,3)+300*2*Ts;
        end
    case 'delayedRelease'
        late=t>=.001375 & t<.001375+2*Ts;
        trace.hostCurrent(late,3)=-1; trace.hostTerminal(late,3)=12;
    case 'noUsableSamples'
        trace.hostCurrent(:,3)=-.1;
    case 'nanHostCurrent'
        trace.hostCurrent(end-2,3)=NaN;
    case 'nanNativeCurrent'
        trace.nativeCurrent(end-2,3)=NaN;
    case 'nanHostTerminal'
        trace.hostTerminal(1,1)=NaN;
    case 'infNativeTerminal'
        trace.nativeTerminal(1,2)=Inf;
    case 'nanTime'
        trace.time(end-2)=NaN;
    case 'nanNativeTime'
        trace.nativeTime(2)=NaN;
    case 'duplicateNativeTime'
        trace.nativeTime(2)=trace.nativeTime(1);
    case 'nonmonotonicTime'
        trace.time(end-1:end)=flipud(trace.time(end-1:end));
    case 'shapeMismatch'
        trace.hostCurrent=trace.hostCurrent(:,1:2);
    case 'outOfRangeTime'
        trace.time(1)=-Ts;
    case 'complexCurrent'
        trace.hostCurrent(end,1)=1+1i;
end
end
