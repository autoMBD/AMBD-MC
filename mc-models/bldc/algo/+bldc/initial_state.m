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
% File:        initial_state.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-06
% Version:     0.1.0
% Description: Return explicit typed BLDC controller memory
% =================================================================================

function s = initial_state(p)
%initial_state - Return explicit typed BLDC controller memory
%   S = initial_state(P) resets every state and stores calibrations P.

%#codegen
s.Parameters=p;
s.Mode=uint8(0);s.PreviousMode=uint8(0);s.ModeTicks=uint32(0);
s.Tick=uint32(0);s.SlowCounter=uint16(0);s.FastTick=false;s.SpeedTick=false;
s.Command=uint8(0);s.SpeedRequest=single(0);s.SpeedRamped=single(0);
s.CoastTicks=uint32(0);
s.Direction=int8(1);s.OutputDirection=int8(1);s.Sector=uint8(0);
s.GateEnable=false;s.PhaseEnable=false(3,1);s.DutyCounts=zeros(3,1,'uint16');
s.Modulation=single(0);s.Current=zeros(3,1,'single');
s.CurrentRef=single(0);s.CurrentDemand=single(0);s.CurrentMeasured=single(0);
s.CurrentIntegrator=single(0);s.SpeedIntegrator=single(0);
s.SpeedEstimate=single(0);s.ControlSpeed=single(0);s.RawSpeed=single(0);
s.HallLast=uint8(0);s.HallSector=uint8(0);s.HallAge=uint32(0);
s.HallValid=false;s.HallDirection=int8(0);s.FeedbackReady=false;
s.OmegaOpen=single(0);s.ThetaOpen=single(5*pi/6);
s.AppliedLastSector=uint8(0);s.AppliedAge=uint32(0);
s.ZcAge=uint32(0);s.ZcPeriod=single(0);s.ZcCount=uint16(0);
s.ZcFound=false;s.ZcArmed=false;s.ZcValue=single(0);
s.ZcCountdown=int32(-1);s.ZcNextSector=uint8(0);
s.AcquireStage=uint8(0);s.AcquireTheta=single(0);s.AcquireAge=uint32(0);
s.AcquisitionReady=false;
s.SensorFault=uint16(0);s.ActiveFaults=uint16(0);s.FaultBits=uint16(0);
s.PhaseCurrentsValid=p.CurrentSenseMode==uint8(0);
s.DcCurrent=single(0);s.DcCurrentValid=false;s.ZcUnclampedCount=uint16(0);
end
