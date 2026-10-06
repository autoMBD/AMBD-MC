function [raw,hall,terminal,current,theta,omegaElectrical] = plant_measure(x,counts,phaseEnable,gate,vdc,p)
% SPDX-License-Identifier: MIT
%PLANT_MEASURE Sample ADC, Hall and actual inverter terminal voltages.
state=double(x(:));
shape=bldc.trapezoid(state(4)+[0;-2*pi/3;2*pi/3]);
bemf=double(p.Ke)*state(5)*shape;
[pole,~,~]=bldc.phase_network(state(1:3),bemf,counts,phaseEnable,gate,vdc,p);
raw=uint16(min(65535,max(0,round(double(p.AdcOffset)+double(p.AdcCountsPerAmp)*state(1:3)))));
hall=bldc.hall_signal(state(4)); terminal=single(pole);
current=single(state(1:3)); theta=single(state(4));
omegaElectrical=single(double(p.PolePairs)*state(5));
end
