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
% File:        FOC_Config.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-01-27
% Version:     0.1.0
% Description: FOC Configuration for the Motor Control System
% =================================================================================

clear;clc;

%% Load Structures
load('struct_FOC_Crtl.mat');

%% Model parameters
Ts = 0.0001;
Tctr = 0.0000625;
Ts_PIL = 0.0000125;
Fpwm = 16000;
Ts_simscape = 1/40000000*25;

%% Motor parameters
motor.DC = 12;                      % [V]
motor.Rs = 0.56;                    % [ohm]
motor.Ld = 0.000375;                % [H]
motor.Lq = 0.000435;                % [H]
motor.L0 = (motor.Ld + motor.Ld)/2; % [H]
motor.Prs = 2;                      % [-]
motor.Flux = 0.0039052261;          % [Wb]
motor.J = 0.12e-4;                  % [Kg.m^2]
motor.B = 0.0005;                   % [N.m.s/rad]
motor.Tf = 0;                       % [N.m]
motor.Kt = 1.5*motor.Flux*motor.Prs;                      % Torque constant [N.m/A]
motor.Ke = sqrt(3)*1000*motor.Prs*2*pi/60*motor.Flux;     % Back-emf [V/krpm]

%% Current Controller
% D axis PI design
innerPI.iD.f0 = 200;
innerPI.iD.w0 = 2*pi*innerPI.iD.f0;
innerPI.iD.ksi = 1;

innerPI.iD.Continuous.Kp = 2*innerPI.iD.ksi*innerPI.iD.w0*motor.Ld - motor.Rs;
innerPI.iD.Continuous.Ki = innerPI.iD.w0^2*motor.Ld;
innerPI.iD.Continuous.Kzc = innerPI.iD.Continuous.Kp/innerPI.iD.Continuous.Ki;

innerPI.iD.Discrete.Kp = 10;
innerPI.iD.Discrete.Ki = 480;
innerPI.iD.Discrete.KiTctr = innerPI.iD.Discrete.Ki*Tctr;

% Q axis PI design
innerPI.iQ.f0 = 200;
innerPI.iQ.w0 = 2*pi*innerPI.iQ.f0;
innerPI.iQ.ksi = 1;

innerPI.iQ.Continuous.Kp = 2*innerPI.iQ.ksi*innerPI.iQ.w0*motor.Lq - motor.Rs;
innerPI.iQ.Continuous.Ki = innerPI.iQ.w0^2*motor.Lq;
innerPI.iQ.Continuous.Kzc = innerPI.iQ.Continuous.Kp/innerPI.iQ.Continuous.Ki;

innerPI.iQ.Discrete.Kp = 10;
innerPI.iQ.Discrete.Ki = 640;
innerPI.iQ.Discrete.KiTctr = innerPI.iQ.Discrete.Ki*Tctr;

%% Speed Controller
outerPI.Spd.f0 = 4;
outerPI.Spd.w0 = 2*pi*outerPI.Spd.f0;
outerPI.Spd.ksi = 1;

outerPI.Spd.Continuous.Kp = (2*outerPI.Spd.ksi*outerPI.Spd.w0*motor.J - motor.B)/motor.Kt;
outerPI.Spd.Continuous.Ki = outerPI.Spd.w0^2*motor.J/motor.Kt;
outerPI.Spd.Continuous.Kzc = outerPI.Spd.Continuous.Kp/outerPI.Spd.Continuous.Ki;

outerPI.Spd.Discrete.Kp = 0.07;
outerPI.Spd.Discrete.Ki = 0.32;
outerPI.Spd.Discrete.KiTctr = outerPI.Spd.Discrete.Ki*Tctr;

