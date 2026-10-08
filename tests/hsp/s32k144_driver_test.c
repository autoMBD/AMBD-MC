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
// File:        s32k144_driver_test.c
// Author:      autoMBD <tkung.lqk@foxmail.com>
// Date:        2026-10-08
// Version:     0.1.0
// Description: Check six-step mapping, sample identities, scaling, and absent-GD3000 rejection.
// =================================================================================

#include "ambd_kit_board.h"
#include "ambd_kit_s32k144.h"
#include "s32k144_driver_test.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

TestFtm test_ftm;
TestPdb test_pdb[2];
TestPort test_port;
TestSim test_sim;
uint32_t Hsp_CoreClockHz=80000000U;
volatile uint32_t Hsp_ModelStepCount,Hsp_FailureCode,Hsp_MaxStepCycles,Hsp_EventCount,Hsp_LastEventIntervalCycles;
static unsigned gpio[7],pdb_on[2],trigger[2],configured[2][2],calibrations[2];
static unsigned scenario,late,levels[8],overrides[8],irq_masked,irq_pending;
uint32_t Ambd_K144TestLock(void){uint32_t prior=irq_masked;irq_masked=1U;return prior;}
void Ambd_K144TestUnlock(uint32_t prior){irq_masked=prior;if(!irq_masked&&irq_pending){irq_pending=0U;Ambd_KitFaultIrq();}}
static bool complete[2][2];
static uint16_t samples[2][2],duty_ticks[3];
static uint8_t tx,reply,selected,mode,masks;
static uint32_t cycles;
uint32_t Hsp_ReadCycleCounter(void){cycles+=80U;return cycles;}
void Hsp_Fail(uint32_t code){Hsp_FailureCode=code;Ambd_KitStop();}
void Hsp_ReportModelEventFaultFromISR(void){Hsp_Fail(42U);}
void Hsp_ModelEvent(void){Hsp_EventCount++;(void)Ambd_KitCapture();}
void Ambd_KitPrimeModel(void){}
void Ambd_KitCaptureModelInputs(void){(void)Ambd_KitCapture();}
uint8_t Dio_ReadChannel(unsigned channel){return (uint8_t)gpio[channel];}
void Dio_WriteChannel(unsigned channel,unsigned value){gpio[channel]=value;}
void Ftm_Pwm_Ip_MaskOutputChannels(unsigned instance,uint32_t mask,bool sync){assert(instance==3U&&!sync);test_ftm.OUTMASK|=mask;}
void Ftm_Pwm_Ip_UnMaskOutputChannels(unsigned instance,uint32_t mask,bool sync){assert(instance==3U&&!sync);if(scenario==7U&&mask!=0U){gpio[DioConf_DioChannel_Ambd_GdInt]=1U;if(irq_masked)irq_pending=1U;else Ambd_KitFaultIrq();}test_ftm.OUTMASK&=~mask;}
void Ftm_Pwm_Ip_SetOutmaskPwmSyncModeCmd(TestFtm *base,bool sync){assert(base==IP_FTM3&&!sync);}
void Ftm_Pwm_Ip_UpdatePwmDutyCycleChannel(unsigned instance,unsigned channel,uint16_t duty,bool sync){assert(instance==3U&&channel%2U==0U&&duty<=AMBD_K144_PWM_PERIOD&&!sync);duty_ticks[channel/2U]=duty;test_ftm.CNT=AMBD_BLDC?test_ftm.CNT+10U:test_ftm.CNT-10U;}
void Ftm_Pwm_Ip_FastUpdatePwmDuty(unsigned instance,unsigned count,const uint8_t *channels,const uint16_t *compare,bool sync){unsigned i;assert(instance==3U&&count==3U&&sync);for(i=0U;i<count;i++){assert(channels[i]==2U*i&&compare[i]<=AMBD_K144_PWM_PERIOD/2U);duty_ticks[i]=(uint16_t)(2U*compare[i]);test_ftm.CNT=AMBD_BLDC?test_ftm.CNT+10U:test_ftm.CNT-10U;}Ftm_Pwm_Ip_SyncUpdate(instance);}
void Ftm_Pwm_Ip_SyncUpdate(unsigned instance){assert(instance==3U);if(late)test_ftm.CNT=AMBD_BLDC?50U:4900U;}
void Ftm_Pwm_Ip_SetChnCountVal(TestFtm *base,unsigned channel,uint32_t value){assert(base==IP_FTM3&&channel==6U&&value==(AMBD_BLDC?0U:5000U));}
void Ftm_Pwm_Ip_ClearChnEventFlag(TestFtm *base,unsigned channel){assert(base==IP_FTM3&&channel==6U);}
void Ftm_Pwm_Ip_SwOutputControl(unsigned instance,unsigned channel,unsigned level,bool enable){assert(instance==3U&&channel<6U);levels[channel]=level;overrides[channel]=enable;}
void Adc_Calibrate(unsigned unit,Adc_CalibrationStatusType *result){calibrations[unit]++;result->AdcUnitSelfTestStatus=scenario==5U?1U:0U;}
void Adc_Ip_SetTriggerMode(unsigned unit,unsigned value){assert(unit<2U&&value==ADC_IP_TRIGGER_HARDWARE);}
void Adc_Ip_SetSampleTime(unsigned unit,unsigned value){assert(unit<2U&&value>=2U);}
void Adc_Ip_ConfigChannel(unsigned unit,const Adc_Ip_ChanConfigType *cfg){configured[unit][cfg->ChnIdx]=(unsigned)cfg->Channel;}
bool Adc_Ip_GetConvCompleteFlag(unsigned unit,unsigned slot){return complete[unit][slot];}
uint16_t Adc_Ip_GetConvData(unsigned unit,unsigned slot){complete[unit][slot]=false;return samples[unit][slot];}
void Pdb_Adc_Ip_Disable(unsigned unit){pdb_on[unit]=0U;}
void Pdb_Adc_Ip_Enable(unsigned unit){pdb_on[unit]=1U;}
void Pdb_Adc_Ip_SetTriggerInput(unsigned unit,unsigned source){assert(unit<2U&&source==0U);}
void Pdb_Adc_Ip_SetContinuousMode(unsigned unit,bool continuous){assert(unit<2U&&!continuous);}
void Pdb_Adc_Ip_SetModulus(unsigned unit,uint16_t value){assert(unit<2U&&value==4999U);}
void Pdb_Adc_Ip_SetAdcPretriggerDelayValue(unsigned unit,unsigned channel,unsigned slot,uint16_t value){assert(unit<2U&&channel==0U&&slot==0U&&value>0U);}
void Pdb_Adc_Ip_ConfigAdcPretriggers(unsigned unit,unsigned channel,const Pdb_Adc_Ip_PretriggersConfigType *cfg){assert(channel==0U&&cfg->EnableMask==(unit==0U?1U:3U));}
void Pdb_Adc_Ip_LoadRegValues(unsigned unit){assert(pdb_on[unit]);}
void Pdb_Adc_Ip_ClearAdcPretriggerFlags(unsigned unit,unsigned channel,uint16_t mask){(void)unit;(void)channel;(void)mask;}
uint8_t Trgmux_Ip_SetInput(unsigned channel,uint32_t source){if(source!=0U){assert(pdb_on[channel]&&calibrations[channel]>0U&&gpio[DioConf_DioChannel_Hsp_GateEnable]==0U);assert(configured[0][0]==4U&&configured[1][1]==7U);}trigger[channel]=source;return 0U;}
void IntCtrl_Ip_ClearPending(unsigned irq){assert(irq==ADC1_IRQn);}
void Gpt_EnableNotification(unsigned channel){(void)channel;}
void Gpt_StartTimer(unsigned channel,Gpt_ValueType ticks){assert(channel==0U&&ticks==24000U);}
void Gpt_StopTimer(unsigned channel){(void)channel;}
uint32_t Mcu_GetClockFrequency(unsigned clock){(void)clock;return 24000000U;}
uint8_t Spi_WriteIB(unsigned channel,const uint8_t *value){(void)channel;tx=*value;return 0U;}
uint8_t Spi_SyncTransmit(unsigned sequence){(void)sequence;reply=selected==1U?mode:(selected==2U?masks:0U);if(scenario==1U)reply=255U;if(tx<=3U)selected=tx;else if(tx==0x2FU)masks|=15U;else if(tx==0x3FU)masks|=240U;else if(tx==0x4BU)mode=0x43U;return 0U;}
uint8_t Spi_ReadIB(unsigned channel,uint8_t *value){(void)channel;*value=reply;return 0U;}
void *xTaskCreateStatic(void (*fn)(void*),const char *name,unsigned words,void *arg,unsigned priority,StackType_t *stack,StaticTask_t *control){(void)fn;(void)name;(void)words;(void)arg;(void)priority;(void)stack;return control;}
void vTaskDelay(unsigned ticks){(void)ticks;}
unsigned Uart_SyncSend(unsigned channel,const uint8_t *data,unsigned length,unsigned timeout){(void)channel;(void)data;(void)length;(void)timeout;return 0U;}
static void sample(void){memset(complete,1,sizeof(complete));samples[0][0]=2048U;samples[1][0]=2048U;samples[1][1]=1092U;test_ftm.CNT=AMBD_BLDC?320U:4680U;assert(Ambd_KitCapture());}
static void off(void){assert(gpio[DioConf_DioChannel_Hsp_GateEnable]==0U&&(test_ftm.OUTMASK&0x3FU)==0x3FU);}
int main(int argc,char **argv)
{
    unsigned i;const uint16_t counts[3]={50000U,15535U,0U};
    const uint8_t phases[3]={1U,1U,AMBD_BLDC?0U:1U};
    assert(argc==2);scenario=(unsigned)atoi(argv[1]);
    test_ftm.MOD=scenario==6U?2500U:5000U;test_ftm.SC=FTM_SC_CPWMS_MASK;
    test_ftm.POL=0x15U;test_ftm.COMBINE=0x323232U;test_ftm.DEADTIME=48U;
    Ambd_KitStart();off();
    if(scenario==5U||scenario==6U){assert(Hsp_FailureCode==(scenario==5U?71U:74U));assert(trigger[0]==0U&&trigger[1]==0U);puts("K144_RUNTIME_PASS");return 0;}
    assert(Hsp_FailureCode==0U&&trigger[0]==29U&&trigger[1]==29U);
    if(scenario==1U){assert(!Ambd_Kit.driver_ready);sample();Ambd_KitCommit(counts,phases,1U,1U,1U,1);off();puts("K144_RUNTIME_PASS");return 0;}
    assert(Ambd_Kit.driver_ready);
    for(i=0U;i<1024U;i++)sample();
    assert(Ambd_Kit.calibrated);off();
    Ambd_KitCommit(counts,phases,1U,1U,1U,1);off();sample();off();sample();
    if(scenario==7U){off();assert(Ambd_Kit.faults!=0U);Ambd_KitCommit(counts,phases,1U,1U,1U,1);off();puts("K144_RUNTIME_PASS");return 0;}
    assert(gpio[DioConf_DioChannel_Hsp_GateEnable]==1U);
    assert((test_ftm.OUTMASK&0x3FU)==(AMBD_BLDC?0x30U:0U));
    assert(duty_ticks[0]==(AMBD_BLDC?5260U:7630U));
    assert(duty_ticks[1]==(AMBD_BLDC?5000U:2370U));
    if(AMBD_BLDC){assert(overrides[2]&&overrides[3]);assert(levels[2]==1U&&levels[3]==1U);}
    if(scenario==8U){gpio[DioConf_DioChannel_Ambd_GdInt]=0U;test_port.ISFR=(1UL<<10U);Ambd_KitFaultIrq();off();assert(Ambd_Kit.faults!=0U);}
    if(scenario==2U){gpio[DioConf_DioChannel_Ambd_GdInt]=1U;Ambd_KitFaultIrq();off();Ambd_KitCommit(counts,phases,1U,1U,1U,1);off();}
    if(scenario==3U){complete[0][0]=false;assert(!Ambd_KitCapture());assert(Hsp_FailureCode==42U);off();}
    if(scenario==4U){late=1U;sample();assert(Ambd_Kit.late_updates>0U);off();}
    Ambd_KitStop();off();assert(!pdb_on[0]&&!pdb_on[1]&&!trigger[0]&&!trigger[1]);
    Ambd_KitCommit(counts,phases,1U,1U,1U,1);off();assert(!Ambd_KitCapture());
    puts("K144_RUNTIME_PASS");return 0;
}
