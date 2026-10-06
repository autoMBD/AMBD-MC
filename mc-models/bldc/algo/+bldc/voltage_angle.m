function [theta,sector,valid] = voltage_angle(voltage,direction,vdc,minSpan)
%voltage_angle - Infer trapezoidal rotor phase from open-circuit voltages
%   THETA = voltage_angle(VOLTAGE,DIRECTION,VDC,minSpan) removes common
%   mode through voltage ratios and returns electrical radians.
%
%   [THETA,SECTOR,VALID] = voltage_angle(...) also returns the sector and
%   whether the finite voltage span is usable and clearly below the rails.
%   The caller must separately verify current decay and all-gates-off.

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
%#codegen
theta=single(0);sector=uint8(0);valid=false;
if any(~isfinite(voltage)) || ~isfinite(vdc) || abs(direction)~=int8(1)
    return
end
v=single(direction)*voltage;
[high,source]=max(v);[low,sink]=min(v);span=high-low;
if span<minSpan || span>=single(.5)*vdc,return;end
pairs=uint8([1,2;1,3;2,3;2,1;3,1;3,2]);
for k=1:6
    if source==pairs(k,1) && sink==pairs(k,2),sector=uint8(k);end
end
if sector==uint8(0),return;end
middle=6-source-sink;
ratio=(single(2)*v(middle)-high-low)/span;
slopes=single([-1,1,-1,1,-1,1]);
theta=single(mod((double(sector)*60+double(slopes(sector))*30*double(ratio))*pi/180,2*pi));
valid=true;
end
