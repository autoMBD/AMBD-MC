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
// File:        board_driver_test.c
// Author:      autoMBD <tkung.lqk@foxmail.com>
// Date:        2026-10-07
// Version:     0.1.0
// Description: Exercise calibration publication, held-high faults, and PWM reload races.
// =================================================================================

#include "ambd_kit_board.h"
#include "board_driver_test.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
FakeEmios fake_emios;FakeLcu fake_lcu;
static Emios_Pwm_Ip_ChannelConfigType pwm_hw[3]={{1,1,2,10000,1},{2,1,2,10000,1},{3,1,2,10000,1}};
static const Pwm_ChannelConfigType pwm_config[3]={{0,{0,0,&pwm_hw[0]}},{1,{0,0,&pwm_hw[1]}},{2,{0,0,&pwm_hw[2]}}};
Pwm_ConfigType Pwm_Config={3,&pwm_config};
uint32_t Hsp_CoreClockHz=160000000U,Hsp_ModelStepCount,Hsp_FailureCode,Hsp_MaxStepCycles,Hsp_EventCount,Hsp_LastEventIntervalCycles;
static uint8_t pins[128],tx,rx,selected,mode,masks,events;
static uint32_t cycles,cost=100U;
static uint32_t timer_started;
static uint8_t timer_running,triggers_enabled,trigger_cleared;
static int scenario;
uint32_t Hsp_ReadCycleCounter(void){cycles+=10U;return cycles;}
void Ambd_KitPrimeModel(void){}
void Hsp_Fail(uint32_t reason){Hsp_FailureCode=reason;}
void Hsp_ReportModelEventFaultFromISR(void){Hsp_FailureCode=99U;}
void Mcl_SetLcuSyncOutputEnable(const Mcl_LcuSyncOutputValueType *v,uint8_t n){unsigned i;fake_lcu.OUTEN=0U;for(i=0U;i<n;i++)fake_lcu.OUTEN|=v[i].Value<<v[i].LogicOutputId;}
void Mcl_SetLcuSyncInputSwOverrideValue(const Mcl_LcuSyncInputValueType *v,uint8_t n){(void)v;(void)n;}
void Mcl_SetLcuSyncInputSwOverrideEnable(const Mcl_LcuSyncInputValueType *v,uint8_t n){(void)v;(void)n;}
void Mcl_EmiosConfigureGlobalTimebase(uint8_t a,uint8_t b){(void)a;timer_running=b;if(b!=0U){assert(triggers_enabled==0U);timer_started=cycles;}}
void Dio_WriteChannel(uint16_t c,uint8_t v){assert(c<128U);pins[c]=v;}
uint8_t Dio_ReadChannel(uint16_t c){assert(c<128U);return pins[c];}
Std_ReturnType Spi_WriteIB(uint8_t c,const uint8_t *d){(void)c;tx=*d;return 0U;}
Std_ReturnType Spi_SyncTransmit(uint8_t s){(void)s;
 rx=selected==1U?mode:(selected==2U?masks:events);selected=0U;
 switch(tx&0xF0U){case 0U:selected=tx&3U;break;case 0x20U:masks=(masks&0xF0U)|(tx&15U);break;
 case 0x30U:masks=(masks&15U)|((tx&15U)<<4U);break;case 0x40U:mode=(tx&3U)|((tx&8U)<<3U);break;
 case 0x60U:events&=(uint8_t)~(tx&15U);break;case 0x70U:events&=(uint8_t)~((tx&15U)<<4U);break;default:assert(0);}
 return 0U;}
Std_ReturnType Spi_ReadIB(uint8_t c,uint8_t *d){(void)c;*d=rx;return 0U;}
void Adc_CtuSetList(uint8_t u,const Adc_CtuListItemType *l,uint8_t n,uint8_t p){(void)u;(void)l;(void)n;(void)p;}
void Adc_Calibrate(uint8_t u,Adc_CalibrationStatusType *r){(void)u;r->AdcUnitSelfTestStatus=0U;}
void Adc_EnableCtuControlMode(uint8_t u){(void)u;triggers_enabled=1U;}
void Adc_CtuEnableHwTrigger(uint8_t t){(void)t;}
void Adc_CtuReadFifoResult(uint8_t f,Adc_CtuFifoResultType *w,uint8_t n){
 const Adc_CtuFifoResultType data[4]={{4,2,0,9300},{4,1,1,9300},{4,1,0,4369},{4,1,1,9300}};
 (void)f;assert(n==4U);memcpy(w,data,sizeof(data));fake_emios.CH.UC[22].CNT=500U;
}
uint32_t Bctu_Ip_GetFifoCount(uint8_t u,uint8_t f){(void)u;(void)f;return triggers_enabled!=0U?4U:0U;}
void Bctu_Ip_SetGlobalTriggerEn(uint8_t u,uint8_t o){(void)u;if(o!=0U){assert(timer_running!=0U);assert(cycles-timer_started>=20000U);assert(trigger_cleared!=0U);}triggers_enabled=o;}
void Bctu_Ip_DisableHwTrigger(uint32_t u,uint8_t t){assert(u==0U&&t==4U);}
void Bctu_Ip_DisableNotifications(uint8_t u,uint8_t m){(void)u;(void)m;}
void Pwm_SetDutyPhaseShift(uint8_t c,uint16_t d,uint16_t p,uint8_t s){(void)c;(void)d;(void)p;(void)s;cycles+=cost;fake_emios.CH.UC[22].CNT=(fake_emios.CH.UC[22].CNT+cost)%10000U;}
void Pwm_SyncUpdate(uint8_t i){(void)i;cycles+=10U;fake_emios.CH.UC[22].CNT=(fake_emios.CH.UC[22].CNT+10U)%10000U;}
void Pwm_FastUpdateDisableOU(uint8_t i,uint32_t m){(void)i;(void)m;}
void Pwm_FastUpdateEnableOU(uint8_t i,uint32_t m){(void)m;Pwm_SyncUpdate(i);}
void Pwm_FastUpdateSetUCRegA(uint8_t c,uint32_t v){Pwm_SetDutyPhaseShift(c,0U,(uint16_t)v,1U);}
void Pwm_FastUpdateSetUCRegB(uint8_t c,uint32_t v){Pwm_SetDutyPhaseShift(c,0U,(uint16_t)v,1U);}
void Emios_Pwm_Ip_ComparatorTransferDisable(uint8_t i,uint32_t m){assert(i==0U&&m==14U);}
void Emios_Pwm_Ip_ComparatorTransferEnable(uint8_t i,uint32_t m){assert(i==0U&&m==14U);Pwm_SyncUpdate(i);}
void Emios_Pwm_Ip_UpdateUCRegA(uint8_t i,uint8_t c,uint32_t v){assert(i==0U&&c>=1U&&c<=3U);Pwm_SetDutyPhaseShift(c,0U,(uint16_t)v,1U);}
void Emios_Pwm_Ip_UpdateUCRegB(uint8_t i,uint8_t c,uint32_t v){assert(i==0U&&c>=1U&&c<=3U);Pwm_SetDutyPhaseShift(c,0U,(uint16_t)v,1U);}
void Emios_Pwm_Ip_ClearFlagEvent(FakeEmios *base,uint8_t channel){assert(base==IP_EMIOS_0&&channel==4U);trigger_cleared=1U;}
void Icu_EnableNotification(uint8_t c){(void)c;}
void Icu_EnableEdgeDetection(uint8_t c){(void)c;if(scenario==1)pins[71]=1U;}
void Gpt_EnableNotification(uint8_t c){(void)c;}
void Gpt_StartTimer(uint8_t c,uint32_t v){(void)c;(void)v;}
void Gpt_StopTimer(uint8_t c){(void)c;}
uint32_t Mcu_GetClockFrequency(uint32_t c){(void)c;return 40000000U;}
void vTaskDelay(uint32_t d){(void)d;}
void *xTaskCreateStatic(void (*f)(void *),const char *n,uint32_t s,void *a,uint32_t p,StackType_t *m,StaticTask_t *c){(void)f;(void)n;(void)s;(void)a;(void)p;(void)m;return c;}
Std_ReturnType Uart_SyncSend(uint8_t c,const uint8_t *b,uint32_t s,uint32_t t){(void)c;(void)b;(void)s;(void)t;return 0U;}
int main(int argc,char **argv){
 unsigned i;uint16_t counts[3]={32768U,32768U,32768U};uint8_t phases[3]={1U,1U,1U};
 assert(argc==2);scenario=atoi(argv[1]);
 if(scenario==4)pwm_hw[1].ChannelId=4U;
 if(scenario==5)pwm_hw[2].PeriodCount=9999U;
 if(scenario==6)Pwm_Config.PwmChannelsConfig=NULL;
 Ambd_KitStart();
 if(scenario>=4){assert(Hsp_FailureCode==74U);assert(pins[44]==0U);assert(fake_lcu.OUTEN==0U);puts("BOARD_RUNTIME_PASS");return 0;}
 assert(Hsp_FailureCode==0U);
 if(scenario==1){assert(Ambd_Kit.faults!=0U);assert(pins[44]==0U);puts("BOARD_RUNTIME_PASS");return 0;}
 for(i=0U;i<1024U;i++)assert(Ambd_KitCapture());
 assert(Ambd_Kit.calibrated!=0U);assert(fabsf(Ambd_Kit.current[0])<.001F);assert(fabsf(Ambd_Kit.current[1])<.001F);assert(fabsf(Ambd_Kit.current[2])<.001F);
 Ambd_KitControl=1U;fake_emios.CH.UC[22].CNT=scenario==3?8200U:2000U;if(scenario==3)cost=800U;
 Ambd_KitCommit(counts,phases,1U,1U,0U,1);
 if(scenario==3){assert(Ambd_KitCapture());assert(Ambd_Kit.late_updates==1U);assert(Ambd_Kit.commits==0U);assert(pins[44]==0U);}
 else{
   assert(Ambd_KitCapture());if(scenario==2)pins[71]=1U;assert(Ambd_KitCapture());
   if(scenario==2){assert(Ambd_Kit.faults!=0U);assert(pins[44]==0U);assert(fake_lcu.OUTEN==0U);}
   else{assert(Ambd_Kit.faults==0U);assert(pins[44]==1U);assert(fake_lcu.OUTEN==63U);}
 }
 puts("BOARD_RUNTIME_PASS");return 0;
}
