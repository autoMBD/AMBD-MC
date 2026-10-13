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
// File:        pil_init_test.c
// Author:      autoMBD <tkung.lqk@foxmail.com>
// Date:        2026-10-13
// Version:     0.1.0
// Description: Provide deterministic RTD peers for host tests of the actual board state machine.
// =================================================================================

#include "pil_init_test.h"
#include <assert.h>
#include <setjmp.h>
#include <stdlib.h>
#include <stdio.h>
const int Mcu_Config=0,Uart_xConfig=0;
TestPin g_pin_mux_InitConfigArr[26];
TestPit test_pit;
TestLpit test_lpit;
TestRegisters test_regs;
uint32_t Hsp_CoreClockHz;
static jmp_buf failed;
static int scenario,uart,configured,platform,pin_calls;
static uint32_t disabled,cleared;
void Ambd_PilTargetInit(void);
void Hsp_Fail(uint32_t code){assert(code==74U);longjmp(failed,1);}
void Mcu_Init(const void* p){(void)p;}
int Mcu_InitClock(int s){(void)s;return scenario==2?1:0;}
int Mcu_GetPllStatus(void){return scenario==3?0:1;}
int Mcu_DistributePllClock(void){return scenario==13?1:0;}
void Mcu_SetMode(int s){(void)s;}
uint64 Mcu_GetClockFrequency(int s){(void)s;return scenario==4?0U:(scenario==14?(uint64)UINT32_MAX+1U:80000000U);}
uint32_t Hsp_InitializeCycleCounter(void){return scenario==5?0U:1U;}
void OsIf_Timer_Custom_SetTimerFrequency(uint32_t f){assert(f==80000000U);}
static int pins(uint32_t n,const TestPin* p){
 size_t index=(size_t)(p-g_pin_mux_InitConfigArr);
 assert((n==2U&&index==1U)||(n==2U&&index==11U)||(n==2U&&index==3U));
 configured+=(int)n;pin_calls++;return (scenario==6||(scenario==15&&pin_calls==2))?1:0;
}
int Siul2_Port_Ip_Init(uint32_t n,const TestPin* p){return pins(n,p);}
int Port_Ci_Port_Ip_Init(uint32_t n,const TestPin* p){return pins(n,p);}
void Platform_Init(const void* p){(void)p;platform=1;}
void IntCtrl_Ip_DisableIrq(int irq){assert(platform);disabled|=1U<<(unsigned)irq;}
void IntCtrl_Ip_ClearPending(int irq){cleared|=1U<<(unsigned)irq;}
void Clock_Ip_EnableModuleClock(int c){(void)c;}
void Uart_Init(const void* p){(void)p;assert(configured==4);assert(disabled==cleared);
#if defined(AMBD_TARGET_S32K344)
 assert(disabled==((1U<<ADC0_IRQn)|(1U<<BCTU_IRQn)|(1U<<SIUL_0_IRQn)|(1U<<PIT0_IRQn)|(1U<<PIT1_IRQn)|(1U<<LPSPI1_IRQn)|(1U<<EMIOS2_3_IRQn)|(1U<<EMIOS2_5_IRQn)));
#else
 assert(disabled==((1U<<ADC0_IRQn)|(1U<<ADC1_IRQn)|(1U<<LPIT0_Ch0_IRQn)|(1U<<LPIT0_Ch1_IRQn)|(1U<<PORTE_IRQn)));
#endif
 uart++;}
int main(int argc,char** argv){
 assert(argc==2);scenario=atoi(argv[1]);
 test_regs.OUTEN=0xFFFFU;test_regs.OUTMASK=0U;
 test_regs.PRTN0_COFB1_STAT=1U;test_regs.PCCn[0]=1U;test_regs.PCCn[1]=1U;
#if defined(AMBD_TARGET_S32K344)
 g_pin_mux_InitConfigArr[1].pinPortIdx=15U;g_pin_mux_InitConfigArr[2].pinPortIdx=16U;
 g_pin_mux_InitConfigArr[3].pinPortIdx=45U;g_pin_mux_InitConfigArr[4].pinPortIdx=44U;
#else
 g_pin_mux_InitConfigArr[1]=(TestPin){.portBase=IP_PORTC,.pinPortIdx=6U};g_pin_mux_InitConfigArr[2]=(TestPin){.portBase=IP_PORTC,.pinPortIdx=7U};
 g_pin_mux_InitConfigArr[11]=(TestPin){.portBase=IP_PORTA,.pinPortIdx=2U};g_pin_mux_InitConfigArr[12]=(TestPin){.portBase=IP_PORTA,.pinPortIdx=3U};
#endif
 for(unsigned i=0U;i<26U;i++){
  g_pin_mux_InitConfigArr[i].base=IP_SIUL2;g_pin_mux_InitConfigArr[i].gpioBase=IP_PTA;
  g_pin_mux_InitConfigArr[i].mux=PORT_MUX_AS_GPIO;
  g_pin_mux_InitConfigArr[i].outputBuffer=PORT_OUTPUT_BUFFER_ENABLED;
  g_pin_mux_InitConfigArr[i].direction=PORT_CI_PORT_PIN_OUT;
 }
 for(unsigned i=0U;i<4U;i++){test_pit.TIMER[i].TCTRL=1U;test_lpit.TMR[i].TCTRL=1U;}
 test_lpit.MIER=0xFU;
#if defined(AMBD_TARGET_S32K344)
 TestPin* gate=&g_pin_mux_InitConfigArr[4];TestPin* reset=&g_pin_mux_InitConfigArr[3];
#else
 TestPin* gate=&g_pin_mux_InitConfigArr[11];TestPin* reset=&g_pin_mux_InitConfigArr[12];
#endif
 if(scenario==7)gate->initValue=1U;
 if(scenario==8)reset->initValue=2U;
 if(scenario==9)gate->mux=99U;
 if(scenario==10){gate->outputBuffer=0U;gate->direction=0U;}
 if(scenario==11){gate->base=NULL;gate->portBase=NULL;}
 if(scenario==12){gate->inputBuffer=1U;gate->gpioBase=NULL;}
 if(scenario==16){reset->base=NULL;reset->gpioBase=NULL;}
 if(scenario==17){
#if defined(AMBD_TARGET_S32K344)
  gate->invert=1U;
#else
  test_regs.PCCn[PCC_LPIT_INDEX]=0U;
#endif
 }
 if(scenario==1)g_pin_mux_InitConfigArr[1].pinPortIdx=31U;
 if(setjmp(failed)==0){Ambd_PilTargetInit();assert(scenario==0);assert(uart==1);
#if defined(AMBD_TARGET_S32K344)
 assert(test_regs.OUTEN==0U);
 for(unsigned i=0;i<4U;i++){assert(test_pit.TIMER[i].TCTRL==0U);assert(test_pit.TIMER[i].TFLG==1U);}
#else
 assert(test_regs.OUTMASK==0xFFU);assert(test_lpit.CLRTEN==0xFU);assert(test_lpit.MIER==0U);
 for(unsigned i=0;i<4U;i++){assert(test_lpit.TMR[i].TCTRL==0U);}
#endif
 }
 else {assert(scenario!=0);assert(uart==0);}
 puts("PIL_INIT_PASS");return 0;
}
