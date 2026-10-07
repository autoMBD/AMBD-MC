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
// File:        ambd_kit_core.c
// Author:      autoMBD <tkung.lqk@foxmail.com>
// Date:        2026-10-07
// Version:     0.1.0
// Description: Implement kit scaling, synchronous six-step mapping, and bounded GD3000 readback.
// =================================================================================

#include "ambd_kit_core.h"
#include <stddef.h>
#include <string.h>
#include <math.h>

bool Ambd_CommitWindowValid(uint32_t start_counter,uint32_t end_counter,uint32_t elapsed_cycles)
{
    return start_counter<8400U&&end_counter>=start_counter&&end_counter<AMBD_KIT_PERIOD_TICKS
        &&elapsed_cycles<=1600U;
}

uint8_t Ambd_HallCanonical(uint8_t raw)
{
    return (uint8_t)(((raw&1U)<<2U)|(raw&2U)|((raw&4U)>>2U));
}

bool Ambd_MapBridge(uint8_t dc_link_mode, const uint16_t counts[3], const uint8_t phases[3], uint8_t gate, uint8_t armed, Ambd_PwmPlan *plan)
{
    uint32_t raw[3]={0U,0U,0U};unsigned index,count=0U;uint8_t source=0U,sink=0U;
    if(plan==NULL)return false;
    memset(plan,0,sizeof(*plan));
    if(counts==NULL||phases==NULL||dc_link_mode>1U||gate>1U||armed>1U)return false;
    if(gate==0U||armed==0U)return true;
    for(index=0U;index<3U;index++){
        if(phases[index]>1U)return false;
        if(phases[index]!=0U){
            plan->enable_mask|=(uint8_t)(1U<<index);count++;
            if(count==1U){source=(uint8_t)index;sink=(uint8_t)index;}
            if(counts[index]>counts[source])source=(uint8_t)index;
            if(counts[index]<counts[sink])sink=(uint8_t)index;
        }
        raw[index]=counts[index];
    }
    if(dc_link_mode!=0U){
        if(count!=2U||source==sink||(uint32_t)counts[source]+counts[sink]!=65535U){
            memset(plan,0,sizeof(*plan));return false;
        }
        raw[0]=0U;raw[1]=0U;raw[2]=0U;
        raw[source]=(uint32_t)counts[source]-counts[sink];
        if(raw[source]>58982U)raw[source]=58982U;
        plan->source=source;plan->sink=sink;plan->floating=(uint8_t)(3U-source-sink);
    }else{
        for(index=0U;index<3U;index++){
            if(raw[index]<6554U)raw[index]=6554U;
            if(raw[index]>58982U)raw[index]=58982U;
        }
    }
    for(index=0U;index<3U;index++){
        uint32_t ticks;
        plan->duty[index]=(uint16_t)((raw[index]*32768U+32767U)/65535U);
        ticks=((uint32_t)plan->duty[index]*AMBD_KIT_PERIOD_TICKS+16384U)/32768U;
        plan->shift[index]=(uint16_t)((AMBD_KIT_PERIOD_TICKS-ticks)/2U);
    }
    return true;
}

bool Ambd_FrameIdentity(const Ambd_AdcWord words[4], uint8_t dc_link_mode, uint8_t floating_channel)
{
    unsigned index,current=0U,voltage=0U,adc1=0U;
    if(words==NULL||dc_link_mode>1U||floating_channel<1U||floating_channel>3U)return false;
    for(index=0U;index<4U;index++){
        const Ambd_AdcWord *word=&words[index];
        if(word->trigger!=4U||word->data>AMBD_KIT_ADC_MAX)return false;
        if(word->adc==0U&&word->channel==(dc_link_mode!=0U?0U:2U))current++;
        else if(word->adc==0U&&word->channel==1U)voltage++;
        else if(word->adc==1U&&word->channel==(dc_link_mode!=0U?floating_channel:1U))adc1++;
        else return false;
    }
    return current==1U&&voltage==1U&&adc1==2U;
}

bool Ambd_DecodeFrame(const Ambd_AdcWord words[4], uint8_t dc_link_mode, uint8_t floating_channel, const float offsets[3], Ambd_Measurement *measurement)
{
    unsigned index;bool first=true;uint16_t adc0=0U,adc1=0U,vdc=0U;
    if(measurement==NULL)return false;
    memset(measurement,0,sizeof(*measurement));
    if(offsets==NULL||!Ambd_FrameIdentity(words,dc_link_mode,floating_channel))return false;
    for(index=0U;index<3U;index++)if(!isfinite(offsets[index]))return false;
    for(index=0U;index<4U;index++){
        if(words[index].adc==0U){
            if(words[index].channel==1U)vdc=words[index].data;else adc0=words[index].data;
        }else if(first){adc1=words[index].data;first=false;}
    }
    measurement->current_raw[0]=adc0;measurement->current_raw[1]=adc1;
    measurement->vdc=(float)vdc*(45.0F/16383.0F);
    if(adc0==0U||adc0>=AMBD_KIT_ADC_MAX)return false;
    if(dc_link_mode!=0U){
        measurement->dc_current=((float)adc0-offsets[2])*(50.0F/16383.0F);
        measurement->floating_voltage=(float)adc1*(45.0F/16383.0F);
    }else{
        if(adc1==0U||adc1>=AMBD_KIT_ADC_MAX)return false;
        measurement->phase_a=(offsets[0]-(float)adc1)*(62.5F/16383.0F);
        measurement->phase_b=(offsets[1]-(float)adc0)*(62.5F/16383.0F);
        measurement->phase_c=-measurement->phase_a-measurement->phase_b;
    }
    return true;
}

bool Ambd_GdReadRegister(Ambd_SpiTransfer transfer, void *context, uint8_t reg, uint8_t *value)
{
    uint8_t ignored;
    if(transfer==NULL||value==NULL||reg>3U)return false;
    /* The selected status register is shifted out by the following frame. */
    return transfer(reg,&ignored,context)&&transfer(0U,value,context);
}

bool Ambd_GdConfigure(Ambd_SpiTransfer transfer, void *context, uint8_t status[4])
{
    uint8_t ignored;
    if(transfer==NULL||status==NULL)return false;
    memset(status,0,4U);
    /* FULLON uses the external LCU deadtime. Lock only after masks are written. */
    if(!transfer(0x2FU,&ignored,context)||!transfer(0x3FU,&ignored,context))return false;
    if(!Ambd_GdReadRegister(transfer,context,2U,&status[2])||status[2]!=0xFFU)return false;
    if(!transfer(0x4BU,&ignored,context))return false;
    if(!Ambd_GdReadRegister(transfer,context,1U,&status[1])||(status[1]&0xC7U)!=0x43U)return false;
    if(!transfer(0x6FU,&ignored,context)||!transfer(0x7FU,&ignored,context))return false;
    if(!Ambd_GdReadRegister(transfer,context,0U,&status[0])||status[0]!=0U)return false;
    return true;
}
