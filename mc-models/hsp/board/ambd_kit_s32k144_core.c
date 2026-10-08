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
// File:        ambd_kit_s32k144_core.c
// Author:      autoMBD <tkung.lqk@foxmail.com>
// Date:        2026-10-08
// Version:     0.1.0
// Description: Implement kit scaling, synchronous six-step mapping, and bounded GD3000 readback.
// =================================================================================

#include "ambd_kit_s32k144.h"
#include <stddef.h>
#include <string.h>
#include <math.h>

bool Ambd_K144Decode(const uint16_t raw[3],uint8_t dc_link_mode,const float offsets[3],Ambd_Measurement *m)
{
    unsigned i;
    if(m==NULL)return false;
    memset(m,0,sizeof(*m));
    if(raw==NULL||offsets==NULL||dc_link_mode>1U)return false;
    for(i=0U;i<3U;i++)if(raw[i]>AMBD_K144_ADC_MAX||!isfinite(offsets[i]))return false;
    m->vdc=(float)raw[2]*(45.0F/4095.0F);
    m->current_raw[0]=raw[1];m->current_raw[1]=raw[0];
    if(raw[1]==0U||raw[1]>=AMBD_K144_ADC_MAX)return false;
    if(dc_link_mode!=0U){
        m->dc_current=((float)raw[1]-offsets[2])*(50.0F/4095.0F);
        m->floating_voltage=(float)raw[0]*(45.0F/4095.0F);
    }else{
        if(raw[0]==0U||raw[0]>=AMBD_K144_ADC_MAX)return false;
        m->phase_a=(offsets[0]-(float)raw[0])*(62.5F/4095.0F);
        m->phase_b=(offsets[1]-(float)raw[1])*(62.5F/4095.0F);
        m->phase_c=-m->phase_a-m->phase_b;
    }
    return true;
}

uint8_t Ambd_K144OutputMask(uint8_t enabled_phases)
{
    uint8_t enabled=0U;unsigned i;
    if(enabled_phases>7U)return 0x3FU;
    for(i=0U;i<3U;i++)if((enabled_phases&(1U<<i))!=0U)enabled|=(uint8_t)(3U<<(2U*i));
    return (uint8_t)((~enabled)&0x3FU);
}

bool Ambd_K144CommitWindow(uint8_t dc_link_mode,uint32_t start,uint32_t end,uint32_t cycles)
{
    if(cycles>800U||start>AMBD_K144_PWM_PERIOD/2U||end>AMBD_K144_PWM_PERIOD/2U)return false;
    /* Trigger endpoints give a known counting direction. Reject a crossing
     * of the reload/turning point and reserve 10 us before the next reload. */
    if(dc_link_mode==1U)return start<AMBD_K144_PWM_PERIOD/2U-800U&&end>=start&&end<AMBD_K144_PWM_PERIOD/2U;
    if(dc_link_mode==0U)return start>800U&&end<=start&&end>0U;
    return false;
}
