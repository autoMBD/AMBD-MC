function [raw,current,theta,omega] = plant_measure(x,p)
%PLANT_MEASURE Convert plant truth to ADC and optional position signals.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
alpha=cos(x(4))*x(1)-sin(x(4))*x(2);
beta=sin(x(4))*x(1)+cos(x(4))*x(2);
current=single([alpha;-0.5*alpha+sqrt(3)/2*beta;-0.5*alpha-sqrt(3)/2*beta]);
counts=double(p.AdcOffset)+double(p.AdcCountsPerAmp)*double(current);
raw=uint16(min(max(round(counts),0),65535));
theta=single(x(4));omega=single(double(p.PolePairs)*x(3));
end
