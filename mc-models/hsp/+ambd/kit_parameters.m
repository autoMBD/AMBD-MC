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
% File:        kit_parameters.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-07
% Version:     0.1.0
% Description: Create separate initial calibrations for the official MCSPTE1AK344 motor.
% =================================================================================

function p = kit_parameters(family,target)
%kit_parameters - Return initial kit motor calibrations
%   P = kit_parameters(FAMILY) returns settings for the supplied Sunrise
%   motor and the official BLDC or PMSM jumper arrangement. Parameters
%   are initial engineering calibrations; physical tuning is separate.
%
%   P = kit_parameters(FAMILY,TARGET) selects the explicit kit profile.
%   Both profiles initially select the documented Sunrise motor.
%
%   See also ambd_mc, target_profile, bldc.defaults, mc.defaults
if nargin<2,target='s32k344';end
profile=ambd.target_profile(target);motor=profile.motor;
family=string(family);
assert(isscalar(family)&&ismember(family,["bldc","pmsm"]),'ambd:Family','Select bldc or pmsm.');
if family=="bldc",p=bldc.defaults();else,p=mc.defaults();end
p.Rs=single(motor.resistance);p.PolePairs=uint8(motor.polePairs);p.Inertia=single(motor.inertia);
p.Ts=single(profile.samplePeriod);
p.SpeedDivider=uint16(round(.001/profile.samplePeriod));
p.Friction=single(0); % No measured friction value is supplied by the kit.
p.NominalVdc=single(12);p.VdcMin=single(9);p.VdcMax=single(18);
p.SpeedLimit=single(5000*2*pi*2/60);
wc=single(2*pi*500);ws=single(2*pi*8);
if family=="bldc"
    p.Ls=single((motor.ld+motor.lq)/2);
    p.Ke=single(2*motor.flux); % MCAT Emax=ke*electrical_speed; this field uses mechanical speed.
    p.CurrentSenseMode=uint8(1);p.MinModulation=single(.1);p.MaxModulation=single(.9);
    p.ActuationDelayTicks=uint16(2);
    p.CurrentLimit=single(3);p.TripCurrent=single(5);p.AlignCurrent=single(3);p.OpenCurrent=single(1);
    p.KpCurrent=single(2)*p.Ls*wc;p.KiCurrent=single(2)*p.Rs*wc;
    kt=single(2)*p.Ke;
    p.OpenSpeed=single(200);p.LowSpeedThreshold=single(800*2*pi*2/60);p.ZcMinSpeed=single(150);
    p.ZcMinTicks=uint32(round(.0005/profile.samplePeriod));
    p.ZcBlankTicks=uint16(max(1,round(.00025/profile.samplePeriod)));
    p.ZcMaxTicks=uint32(round(.5/profile.samplePeriod));
    p.OpenAccel=single(150);p.PositionMode=uint8(0);
else
    p.Ld=single(motor.ld);p.Lq=single(motor.lq);p.Flux=single(motor.flux);
    p.CurrentLimit=single(6);p.TripCurrent=single(8);p.VoltageMargin=single(.8);
    p.KpD=p.Ld*wc;p.KpQ=p.Lq*wc;p.KiD=p.Rs*wc;p.KiQ=p.Rs*wc;
    kt=single(1.5)*single(p.PolePairs)*p.Flux;p.PositionMode=uint8(0);
end
p.KpSpeed=(single(2)*p.Inertia*ws-p.Friction)/(kt*single(p.PolePairs));
p.KiSpeed=p.Inertia*ws*ws/(kt*single(p.PolePairs));
end
