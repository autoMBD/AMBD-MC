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
// File:        board_core_test.c
// Author:      autoMBD <tkung.lqk@foxmail.com>
// Date:        2026-10-07
// Version:     0.1.0
// Description: Check six-step mapping, sample identities, scaling, and absent-GD3000 rejection.
// =================================================================================

#include "ambd_kit_core.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

typedef struct { uint8_t selected, mode, masks, events, stuck; unsigned calls; } Peer;
static bool transfer(uint8_t tx, uint8_t *rx, void *context)
{
    Peer *p=(Peer*)context;p->calls++;
    if(p->stuck==3U)return false;
    if(p->stuck!=0U){*rx=p->stuck==1U?0U:255U;return true;}
    *rx=p->selected==1U?p->mode:(p->selected==2U?p->masks:p->events);
    p->selected=0U;
    switch(tx&0xF0U){
    case 0x00U:p->selected=tx&3U;break;
    case 0x20U:p->masks=(uint8_t)((p->masks&0xF0U)|(tx&15U));break;
    case 0x30U:p->masks=(uint8_t)((p->masks&15U)|((tx&15U)<<4U));break;
    case 0x40U:p->mode=(uint8_t)((tx&3U)|((tx&8U)<<3U));break;
    case 0x60U:p->events=(uint8_t)(p->events&~(tx&15U));break;
    case 0x70U:p->events=(uint8_t)(p->events&~((tx&15U)<<4U));break;
    default:assert(false);break;
    }
    return true;
}
int main(void)
{
    const uint8_t hall[8]={0,4,2,6,1,5,3,7};
    const uint8_t pairs[6][2]={{0,1},{0,2},{1,2},{1,0},{2,0},{2,1}};
    unsigned i,sector,reverse,mask;Ambd_PwmPlan plan;
    assert(Ambd_CommitWindowValid(7000U,7600U,600U));
    assert(!Ambd_CommitWindowValid(9000U,9300U,300U));
    assert(!Ambd_CommitWindowValid(8000U,100U,2100U));
    assert(!Ambd_CommitWindowValid(7000U,7100U,10100U));
    uint16_t counts[3]={32768,32768,32768};uint8_t enabled[3]={1,1,1};
    for(i=0;i<8U;i++)assert(Ambd_HallCanonical((uint8_t)i)==hall[i]);
    for(mask=0;mask<8U;mask++){
        for(i=0;i<3U;i++)enabled[i]=(uint8_t)((mask>>i)&1U);
        assert(Ambd_MapBridge(0U,counts,enabled,1U,1U,&plan));
        assert(plan.enable_mask==(uint8_t)mask);
        assert(Ambd_MapBridge(0U,counts,enabled,1U,0U,&plan)&&plan.enable_mask==0U);
    }
    for(sector=0;sector<6U;sector++)for(reverse=0;reverse<2U;reverse++){
        unsigned source=pairs[sector][reverse],sink=pairs[sector][1U-reverse];
        memset(enabled,0,sizeof(enabled));memset(counts,0,sizeof(counts));
        enabled[source]=1U;enabled[sink]=1U;counts[source]=49151U;counts[sink]=16384U;
        assert(Ambd_MapBridge(1U,counts,enabled,1U,1U,&plan));
        assert(plan.source==source&&plan.sink==sink);
        assert(plan.duty[source]==16384U&&plan.duty[sink]==0U);
        assert(plan.enable_mask==((1U<<source)|(1U<<sink)));
        assert(plan.shift[source]==2500U);
    }
    enabled[0]=1U;enabled[1]=0U;enabled[2]=0U;
    assert(!Ambd_MapBridge(1U,counts,enabled,1U,1U,&plan));assert(plan.enable_mask==0U);
    {Ambd_AdcWord frame[4]={{4,2,0,8000},{4,1,1,8200},{4,1,0,4369},{4,1,1,8200}};
     Ambd_Measurement m;float offsets[3]={8192,8192,8192};
     assert(Ambd_DecodeFrame(frame,0U,1U,offsets,&m));
     assert(fabsf(m.phase_a-((8192.0F-8200.0F)*62.5F/16383.0F))<1e-5F);
     assert(fabsf(m.phase_b-((8192.0F-8000.0F)*62.5F/16383.0F))<1e-5F);
     assert(fabsf(m.vdc-12.0F)<.01F);
     frame[1].adc=0U;assert(!Ambd_DecodeFrame(frame,0U,1U,offsets,&m));frame[1].adc=1U;
     frame[2].trigger=3U;assert(!Ambd_DecodeFrame(frame,0U,1U,offsets,&m));frame[2].trigger=4U;
     frame[0].channel=0U;frame[0].data=8500;assert(Ambd_DecodeFrame(frame,1U,1U,offsets,&m));
     assert(fabsf(m.dc_current-(8500.0F-8192.0F)*50.0F/16383.0F)<1e-5F);
     frame[0].data=16383U;assert(!Ambd_DecodeFrame(frame,1U,1U,offsets,&m));
    }
    for(i=0;i<4U;i++){Peer p={0};uint8_t status[4]={0};p.stuck=(uint8_t)i;
      assert(Ambd_GdConfigure(transfer,&p,status)==(i==0U));assert(p.calls<=16U);
    }
    puts("BOARD_CORE_PASS");return 0;
}
