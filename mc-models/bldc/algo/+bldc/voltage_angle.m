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
% File:        voltage_angle.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Infer trapezoidal rotor phase from open-circuit voltages
% =================================================================================

function [theta,sector,valid] = voltage_angle(voltage,direction,vdc,minSpan)
%voltage_angle - Infer trapezoidal rotor phase from open-circuit voltages
%   THETA = voltage_angle(VOLTAGE,DIRECTION,VDC,minSpan) removes common
%   mode through voltage ratios and returns electrical radians.
%
%   [THETA,SECTOR,VALID] = voltage_angle(...) also returns the sector and
%   whether the finite voltage span is usable and clearly below the rails.
%   The caller must separately verify current decay and all-gates-off.

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
