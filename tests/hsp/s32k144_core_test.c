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
// File:        s32k144_core_test.c
// Author:      autoMBD <tkung.lqk@foxmail.com>
// Date:        2026-10-08
// Version:     0.1.0
// Description: Check six-step mapping, sample identities, scaling, and absent-GD3000 rejection.
// =================================================================================

#include "ambd_kit_s32k144.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
int main(void)
{
    const float offsets[3]={2048.0F,2048.0F,2048.0F};
    uint16_t raw[3]={1948U,2148U,1092U};
    Ambd_Measurement m;
    assert(Ambd_K144Decode(raw,0U,offsets,&m));
    assert(fabsf(m.phase_a-100.0F*62.5F/4095.0F)<1e-6F);
    assert(fabsf(m.phase_b+100.0F*62.5F/4095.0F)<1e-6F);
    assert(m.phase_c==0.0F&&m.dc_current==0.0F);
    assert(fabsf(m.vdc-12.0F)<1e-5F);
    assert(Ambd_K144Decode(raw,1U,offsets,&m));
    assert(m.phase_a==0.0F&&m.phase_b==0.0F&&m.phase_c==0.0F);
    assert(fabsf(m.dc_current-100.0F*50.0F/4095.0F)<1e-6F);
    assert(fabsf(m.floating_voltage-1948.0F*45.0F/4095.0F)<1e-5F);
    raw[1]=4096U;assert(!Ambd_K144Decode(raw,1U,offsets,&m));
    raw[1]=0U;assert(!Ambd_K144Decode(raw,0U,offsets,&m));
    assert(!Ambd_K144Decode(raw,2U,offsets,&m));
    assert(!Ambd_K144Decode(NULL,0U,offsets,&m));
    assert(Ambd_K144OutputMask(0U)==0x3FU);
    assert(Ambd_K144OutputMask(7U)==0U);
    assert(Ambd_K144OutputMask(3U)==0x30U);
    assert(Ambd_K144OutputMask(8U)==0x3FU);
    assert(Ambd_K144CommitWindow(1U,200U,600U,400U));
    assert(!Ambd_K144CommitWindow(1U,4500U,4900U,400U));
    assert(!Ambd_K144CommitWindow(1U,200U,600U,801U));
    assert(Ambd_K144CommitWindow(0U,2300U,1900U,400U));
    assert(!Ambd_K144CommitWindow(0U,200U,600U,400U));
    puts("K144_CORE_PASS");return 0;
}
