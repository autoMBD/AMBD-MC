// =================================================================================
// The MIT License
// MIT许可证
//
// <https://opensource.org/license/mit>
//
// SPDX short identifier / SPDX 短标识符：MIT
//
// Copyright (c) 2026 autoMBD
// 版权所有 (c) 2026 autoMBD
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the “Software”),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 特此向获得本软件及相关文档（合称“本软件”）副本的任何人免费授予不受限制地利用本软
// 件的许可，包括而不限于：使用、复制、修改、合并、发布、分发、分许可和/或销售本软
// 件副本，并允许本软件的接收者也获得前述许可，但须遵守以下条件：
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
// 以上版权声明及本许可声明应包含在本软件的所有副本或主要部分中。
//
// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALLTHE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// 本软件系“按原样”提供，不包含任何形式的明示或默示保证，包括但不限于适销性、特定
// 目的适用性及不侵权的保证。在任何情况下，无论是在合同、侵权或其他案件中，作者或版
// 权持有人均不对因本软件、或因本软件的使用或其他利用而引起的、引发的或与之相关的任
// 何权利主张、损害赔偿或其他责任承担责任。
// =================================================================================
// Project:     autoMBD Motor Control <https://github.com/autoMBD/AMBD-MC>
// File:        ambd_kit_bridge.c
// Author:      autoMBD <tkung.lqk@foxmail.com>
// Date:        2026-10-07
// Version:     0.1.0
// Description: Bind validated physical kit frames to each generated model root input.
// =================================================================================

#include "ambd_kit_board.h"
#include <math.h>
#if defined(HSP_TARGET) && !defined(HSP_PIL)
#define AMBD_TEXT_INNER(x) #x
#define AMBD_TEXT(x) AMBD_TEXT_INNER(x)
#define AMBD_JOIN_INNER(a,b) a##b
#define AMBD_JOIN(a,b) AMBD_JOIN_INNER(a,b)
#include AMBD_TEXT(AMBD_MODEL.h)
#define MODEL_INPUT AMBD_JOIN(AMBD_MODEL,_U)
#define MODEL_OUTPUT AMBD_JOIN(AMBD_MODEL,_Y)
#include <string.h>

void Ambd_KitPrimeModel(void)
{
    unsigned index;
    /* Fault-qualified synthetic inputs prime the explicit-state model before
     * hardware triggers start. Reinitialize afterwards; no sample is skipped. */
    memset(&MODEL_INPUT,0,sizeof(MODEL_INPUT));
#if AMBD_BLDC
    MODEL_INPUT.CurrentRaw[0]=32768U;MODEL_INPUT.CurrentRaw[1]=32768U;MODEL_INPUT.CurrentRaw[2]=32768U;
    MODEL_INPUT.Hall=5U;MODEL_INPUT.Vdc=12.0F;MODEL_INPUT.Fault=1U;
    MODEL_INPUT.CommandEvent=1U;MODEL_INPUT.DrivingEvent=1U;MODEL_INPUT.TimerEvent=1U;
    MODEL_INPUT.AppliedDirection=1;
#else
#if defined(AMBD_FOC_CORE) && AMBD_FOC_CORE
    MODEL_INPUT.Ia=0.0F;MODEL_INPUT.Ib=0.0F;MODEL_INPUT.Ic=0.0F;MODEL_INPUT.Disable=true;
#else
    MODEL_INPUT.Ia=32768U;MODEL_INPUT.Ib=32768U;MODEL_INPUT.Ic=32768U;
#endif
    MODEL_INPUT.DcBusVoltage=12.0F;MODEL_INPUT.FaultEvent=1U;
    MODEL_INPUT.McCtrlEvent=1U;MODEL_INPUT.McDrivingEvent=1U;MODEL_INPUT.McTimerEvent=1U;
#endif
    for(index=0U;index<32U;index++)AMBD_JOIN(AMBD_MODEL,_step)();
    AMBD_JOIN(AMBD_MODEL,_initialize)();
    memset(&MODEL_INPUT,0,sizeof(MODEL_INPUT));
}

#if AMBD_BLDC || !defined(AMBD_FOC_CORE) || (AMBD_FOC_CORE == 0)
static uint16_t normalized_adc(float current)
{
    float encoded=32768.0F+1000.0F*current;
    if(!isfinite(encoded)||encoded<=0.0F)return 0U;
    if(encoded>=65535.0F)return 65535U;
    return (uint16_t)(encoded+0.5F);
}
#endif
void Ambd_KitCaptureModelInputs(void)
{
    uint8_t ready;
    if(!Ambd_KitCapture())return;
    Ambd_Kit.model_mode=MODEL_OUTPUT.Monitor.Mode;
    Ambd_Kit.model_faults=MODEL_OUTPUT.Monitor.FaultBits;
    Ambd_Kit.model_gate=MODEL_OUTPUT.GateEnable;
    ready=(uint8_t)(Ambd_Kit.driver_ready!=0U&&Ambd_Kit.calibrated!=0U&&Ambd_Kit.faults==0U);
#if AMBD_BLDC
    MODEL_INPUT.CurrentRaw[0]=normalized_adc(Ambd_Kit.dc_current);
    MODEL_INPUT.CurrentRaw[1]=32768U;MODEL_INPUT.CurrentRaw[2]=32768U;
    MODEL_INPUT.Hall=Ambd_Kit.hall;
    MODEL_INPUT.TerminalVoltage[0]=0.0F;MODEL_INPUT.TerminalVoltage[1]=0.0F;MODEL_INPUT.TerminalVoltage[2]=0.0F;
    MODEL_INPUT.TerminalVoltage[Ambd_Kit.floating_phase]=Ambd_Kit.floating_voltage;
    MODEL_INPUT.Control=ready!=0U?Ambd_KitControl:0U;
    MODEL_INPUT.Fault=(ready==0U);
    MODEL_INPUT.CommandEvent=1U;MODEL_INPUT.DrivingEvent=1U;MODEL_INPUT.TimerEvent=1U;
    MODEL_INPUT.SpeedReq=Ambd_KitSpeedRequest;MODEL_INPUT.Vdc=Ambd_Kit.vdc;
    MODEL_INPUT.AppliedSector=Ambd_Kit.sample_sector;
    MODEL_INPUT.AppliedDirection=Ambd_Kit.sample_direction==0?1:Ambd_Kit.sample_direction;
    MODEL_INPUT.VoltageValid=Ambd_Kit.sample_valid;
#else
#if defined(AMBD_FOC_CORE) && AMBD_FOC_CORE
    MODEL_INPUT.Ia=Ambd_Kit.current[0];MODEL_INPUT.Ib=Ambd_Kit.current[1];
    MODEL_INPUT.Ic=Ambd_Kit.current[2];MODEL_INPUT.Disable=(ready==0U);
#else
    MODEL_INPUT.Ia=normalized_adc(Ambd_Kit.current[0]);MODEL_INPUT.Ib=normalized_adc(Ambd_Kit.current[1]);
    MODEL_INPUT.Ic=normalized_adc(Ambd_Kit.current[2]);
#endif
    MODEL_INPUT.McControl=ready!=0U?Ambd_KitControl:0U;
    MODEL_INPUT.FaultEvent=(ready==0U||Ambd_Kit.sample_valid==0U);
    MODEL_INPUT.McCtrlEvent=1U;MODEL_INPUT.McDrivingEvent=1U;MODEL_INPUT.McTimerEvent=1U;
    MODEL_INPUT.SpeedReq=Ambd_KitSpeedRequest;MODEL_INPUT.DcBusVoltage=Ambd_Kit.vdc;
    /* The supplied motor has no quadrature encoder. The native kit profile
     * selects the voltage/current observer; position-sensor cases remain PIL inputs. */
    MODEL_INPUT.RotorAngle=0.0F;
    MODEL_INPUT.AppliedVoltageAlpha=Ambd_Kit.voltage_alpha;
    MODEL_INPUT.AppliedVoltageBeta=Ambd_Kit.voltage_beta;
#endif
}
#else
void Ambd_KitCaptureModelInputs(void){}
void Ambd_KitPrimeModel(void){}
#endif
