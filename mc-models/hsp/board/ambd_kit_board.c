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
// File:        ambd_kit_board.c
// Author:      autoMBD <tkung.lqk@foxmail.com>
// Date:        2026-10-07
// Version:     0.1.0
// Description: Acquire physical kit frames, qualify GD3000, and commit interlocked PWM outputs.
// =================================================================================

#include "ambd_kit_board.h"
#include <string.h>
#include <math.h>

volatile Ambd_KitStatus Ambd_Kit;
volatile uint8_t Ambd_KitControl;
volatile float Ambd_KitSpeedRequest;

#if defined(HSP_TARGET) && !defined(HSP_PIL)
#ifdef AMBD_KIT_HOST_TEST
#include "board_driver_test.h"
#else
#include "hsp_runtime.h"
#include "Adc.h"
#include "Bctu_Ip.h"
#include "CDD_Mcl.h"
#include "CDD_Uart.h"
#include "Dio.h"
#include "Pwm.h"
#include "Emios_Pwm_Ip.h"
#include "Emios_Pwm_Ip_HwAccess.h"
#include "Spi.h"
#include "Mcu.h"
#include "Icu.h"
#include "Gpt.h"
#include "FreeRTOS.h"
#include "task.h"
#endif

#ifndef AMBD_BLDC
#error AMBD_BLDC must identify the selected motor family.
#endif
#ifndef AMBD_CONTROL_BOARD_DIAGNOSTICS
#define AMBD_CONTROL_BOARD_DIAGNOSTICS 0
#endif
#define KIT_GD_FAULT 1U
#define KIT_ADC_FAULT 2U
#define KIT_FRAME_FAULT 4U
#define KIT_LATE_UPDATE 8U
#define KIT_COMMAND_FAULT 16U
#define KIT_CALIBRATION_SAMPLES 1024U
static uint8_t initialized, pending_wait, pending_sector, written_sector, active_sector;
static int8_t pending_direction=1,written_direction=1,active_direction=1;
static uint8_t adc_channel=1U;
static Ambd_PwmPlan pending_plan,written_plan,active_plan;
static float offset_sum[3];
static uint32_t tick_count;
static StaticTask_t background_control;
static StackType_t background_stack[768];
static const Pwm_ChannelType pwm_channels[3]={PwmConf_PwmChannel_Hsp_PhaseA,PwmConf_PwmChannel_Hsp_PhaseB,PwmConf_PwmChannel_Hsp_PhaseC};

static bool validate_pwm_mapping(void)
{
    unsigned index;
    if(Pwm_Config.PwmChannelsConfig==NULL)return false;
    for(index=0U;index<3U;index++){
        const Pwm_ChannelConfigType *logical;
        const Emios_Pwm_Ip_ChannelConfigType *physical;
        if(pwm_channels[index]>=Pwm_Config.NumChannels)return false;
        logical=&(*Pwm_Config.PwmChannelsConfig)[pwm_channels[index]];
        physical=logical->IpwChannelCfg.EmiosChConfig;
        if(logical->ChannelId!=pwm_channels[index]||logical->IpwChannelCfg.ChannelType!=PWM_CHANNEL_EMIOS
           ||logical->IpwChannelCfg.ChannelInstanceId!=0U||physical==NULL)return false;
        if(physical->ChannelId!=index+1U||physical->Mode!=EMIOS_PWM_IP_MODE_OPWMB_FLAG
           ||physical->Timebase!=EMIOS_PWM_IP_BUS_F||physical->PeriodCount!=10000U
           ||physical->OutputPolarity!=EMIOS_PWM_IP_ACTIVE_HIGH)return false;
    }
    return true;
}

static uint32_t lock_interrupts(void)
{
#ifdef AMBD_KIT_HOST_TEST
    return 0U;
#else
    uint32_t value;
    __asm__ volatile ("mrs %0, primask\n\tcpsid i" : "=r"(value) :: "memory");
    return value;
#endif
}
static void unlock_interrupts(uint32_t value)
{
#ifdef AMBD_KIT_HOST_TEST
    (void)value;
#else
    __asm__ volatile ("msr primask, %0" :: "r"(value) : "memory");
#endif
}
static void output_mask(uint8_t mask)
{
    Mcl_LcuSyncOutputValueType values[6];unsigned index;
    for(index=0U;index<6U;index++){
        values[index].LogicOutputId=(uint8_t)index;
        values[index].Value=(uint32_t)((mask>>(index/2U))&1U);
    }
    Mcl_SetLcuSyncOutputEnable(values,6U);
    Ambd_Kit.applied_mask=mask;
}
static void outputs_off(void)
{
    /* OUTEN gates the LUT before the configured high-side pin inversion. */
    output_mask(0U);Dio_WriteChannel(DioConf_DioChannel_Hsp_GateEnable,STD_LOW);
    pending_plan.enable_mask=0U;written_plan.enable_mask=0U;active_plan.enable_mask=0U;pending_wait=0U;active_sector=0U;
}
static void latch_fault(uint32_t reason)
{
    uint32_t key=lock_interrupts();Ambd_Kit.faults|=reason;
    if(initialized!=0U){outputs_off();}
    unlock_interrupts(key);
}
static bool write_pwm_plan(const Ambd_PwmPlan *plan)
{
    uint32_t counter=IP_EMIOS_0->CH.UC[22U].CNT;
    uint32_t started,finished,elapsed;unsigned index;
    if(counter>=8400U||counter<(AMBD_BLDC?5000U:100U)){
        Ambd_Kit.late_updates++;return false;
    }
    started=Hsp_ReadCycleCounter();
    Emios_Pwm_Ip_ComparatorTransferDisable(0U,0x0EU);
    for(index=0U;index<3U;index++){
        uint32_t ticks,shift;
        /* Zero physical duty is forced at the LCU input. Keep the unused
         * eMIOS channel in a normal non-degenerate PWM mode. */
        if(plan->duty[index]==0U){ticks=5000U;shift=2500U;}
        else{ticks=((uint32_t)plan->duty[index]*10000U+16384U)/32768U;shift=plan->shift[index];}
        Emios_Pwm_Ip_UpdateUCRegA(0U,(uint8_t)(index+1U),shift);
        Emios_Pwm_Ip_UpdateUCRegB(0U,(uint8_t)(index+1U),shift+ticks);
    }
    Emios_Pwm_Ip_ComparatorTransferEnable(0U,0x0EU);
    finished=IP_EMIOS_0->CH.UC[22U].CNT;elapsed=Hsp_ReadCycleCounter()-started;
    if(elapsed>Ambd_Kit.max_commit_cycles)Ambd_Kit.max_commit_cycles=elapsed;
    if(!Ambd_CommitWindowValid(counter,finished,elapsed)){
        Ambd_Kit.late_updates++;return false;
    }
    Ambd_Kit.commits++;return true;
}
static void wait_us(uint32_t microseconds)
{
    uint32_t start=Hsp_ReadCycleCounter();uint32_t cycles=(Hsp_CoreClockHz/1000000U)*microseconds;
    while((uint32_t)(Hsp_ReadCycleCounter()-start)<cycles){ }
}
static bool spi_transfer(uint8_t tx,uint8_t *rx,void *context)
{
    Std_ReturnType status;(void)context;
    Dio_WriteChannel(DioConf_DioChannel_Ambd_GdCs,STD_LOW);
    status=Spi_WriteIB(0U,&tx);
    if(status==E_OK)status=Spi_SyncTransmit(0U);
    if(status==E_OK)status=Spi_ReadIB(0U,rx);
    Dio_WriteChannel(DioConf_DioChannel_Ambd_GdCs,STD_HIGH);
    return status==E_OK;
}
static void select_adc_channel(uint8_t channel)
{
    Adc_CtuListItemType list[4];unsigned index;
    const uint8_t channels[4]={AMBD_BLDC?0U:2U,channel,1U,channel};
    for(index=0U;index<4U;index++){
        list[index].NextChanWaitOnTrig=FALSE;list[index].AdcChanIndex=channels[index];
    }
    Adc_CtuSetList(0U,list,4U,0U);adc_channel=channel;
}
static uint8_t read_hall(void)
{
    uint8_t raw=(uint8_t)Dio_ReadChannel(DioConf_DioChannel_Ambd_HallA);
    raw|=(uint8_t)(Dio_ReadChannel(DioConf_DioChannel_Ambd_HallB)<<1U);
    raw|=(uint8_t)(Dio_ReadChannel(DioConf_DioChannel_Ambd_HallC)<<2U);
    return Ambd_HallCanonical(raw);
}
static void put32(uint8_t *bytes,uint32_t value)
{
    bytes[0]=(uint8_t)value;bytes[1]=(uint8_t)(value>>8U);bytes[2]=(uint8_t)(value>>16U);bytes[3]=(uint8_t)(value>>24U);
}
static uint32_t crc32(const uint8_t *bytes,unsigned length)
{
    uint32_t crc=0xFFFFFFFFU;unsigned i,b;
    for(i=0U;i<length;i++){
        crc^=bytes[i];for(b=0U;b<8U;b++)crc=(crc>>1U)^(0xEDB88320U&(0U-(crc&1U)));
    }
    return ~crc;
}
static void background(void *argument)
{
    uint32_t sequence=0U;uint8_t frame[112];(void)argument;
    for(;;){
        uint32_t key;unsigned index;uint8_t status=0xFFU;
        vTaskDelay(pdMS_TO_TICKS(100U));
        if(Ambd_Kit.driver_ready!=0U){
            if(!Ambd_GdReadRegister(spi_transfer,NULL,0U,&status)||status!=0U){
                Ambd_Kit.gd_errors++;latch_fault(KIT_GD_FAULT);
            }
            Ambd_Kit.gd_status[0]=status;
        }
        memset(frame,0,sizeof(frame));memcpy(frame,"AMBK",4U);
        key=lock_interrupts();
        put32(&frame[4],++sequence);put32(&frame[8],Ambd_Kit.captures);
        put32(&frame[12],Hsp_ModelStepCount);put32(&frame[16],Ambd_Kit.faults);
        put32(&frame[20],Ambd_Kit.driver_ready);put32(&frame[24],Ambd_Kit.calibrated);
        put32(&frame[28],Ambd_Kit.sample_valid);put32(&frame[32],Ambd_Kit.applied_mask);
        put32(&frame[36],Ambd_Kit.commits);put32(&frame[40],Hsp_FailureCode);
        put32(&frame[44],Hsp_MaxStepCycles);put32(&frame[48],Hsp_CoreClockHz);
        put32(&frame[52],Hsp_EventCount);
        for(index=0U;index<4U;index++){
            frame[56U+index*2U]=(uint8_t)Ambd_Kit.raw[index];frame[57U+index*2U]=(uint8_t)(Ambd_Kit.raw[index]>>8U);
        }
        put32(&frame[64],Dio_ReadChannel(DioConf_DioChannel_Hsp_GateEnable));
        put32(&frame[68],Dio_ReadChannel(DioConf_DioChannel_Hsp_GateReset));
        put32(&frame[72],IP_LCU_0->OUTEN);put32(&frame[76],Ambd_Kit.late_updates);
        put32(&frame[80],tick_count);put32(&frame[84],Hsp_LastEventIntervalCycles);
        put32(&frame[88],Ambd_Kit.gd_errors);put32(&frame[92],Ambd_Kit.max_commit_cycles);
        put32(&frame[96],Ambd_Kit.model_mode);put32(&frame[100],Ambd_Kit.model_faults);
        put32(&frame[104],Ambd_Kit.requested_armed);
        unlock_interrupts(key);
        put32(&frame[108],crc32(frame,108U));
        (void)Uart_SyncSend(0U,frame,sizeof(frame),20000U);
    }
}

void Ambd_KitStart(void)
{
    Adc_CalibrationStatusType calibration;uint8_t status[4];unsigned unit,attempt;
    initialized=1U;memset((void*)&Ambd_Kit,0,sizeof(Ambd_Kit));
    Bctu_Ip_SetGlobalTriggerEn(0U,FALSE);
    Ambd_Kit.offsets[0]=8192.0F;Ambd_Kit.offsets[1]=8192.0F;Ambd_Kit.offsets[2]=8192.0F;
    outputs_off();Dio_WriteChannel(DioConf_DioChannel_Hsp_GateReset,STD_LOW);
    /* HSP initializes MCAL before this callback. Verify the fixed physical
     * mapping once before using its official eMIOS fast-update API. */
    if(!validate_pwm_mapping()){Hsp_Fail(74U);return;}
    Dio_WriteChannel(DioConf_DioChannel_Ambd_GdCs,STD_HIGH);wait_us(1000U);
    Dio_WriteChannel(DioConf_DioChannel_Hsp_GateReset,STD_HIGH);wait_us(1000U);
    if(Ambd_GdConfigure(spi_transfer,NULL,status))Ambd_Kit.driver_ready=1U;
    else{
        Ambd_Kit.gd_errors++;Ambd_Kit.faults|=KIT_GD_FAULT;
        Dio_WriteChannel(DioConf_DioChannel_Hsp_GateReset,STD_LOW);
    }
    for(unit=0U;unit<4U;unit++)Ambd_Kit.gd_status[unit]=status[unit];
    for(unit=0U;unit<2U;unit++){
        for(attempt=0U;attempt<6U;attempt++){
            Adc_Calibrate((Adc_HwUnitType)unit,&calibration);
            if(calibration.AdcUnitSelfTestStatus==E_OK)break;
        }
        if(calibration.AdcUnitSelfTestStatus!=E_OK){latch_fault(KIT_ADC_FAULT);Hsp_Fail(71U);return;}
        Adc_EnableCtuControlMode((Adc_HwUnitType)unit);
    }
    /* Entering CTU control initializes shared BCTU and enables its global
     * trigger gate. Close it again before starting the PWM timebase. */
    Bctu_Ip_SetGlobalTriggerEn(0U,FALSE);
    if(Hsp_CoreClockHz!=160000000U){Hsp_Fail(73U);return;}
    Bctu_Ip_DisableHwTrigger(0U,4U);
    select_adc_channel(1U);
    /* Low-side zero vector for PMSM; active-pulse center for BLDC. */
    Pwm_SetDutyPhaseShift(PwmConf_PwmChannel_Hsp_AdcTrigger,16U,AMBD_BLDC?5000U:100U,TRUE);
    Pwm_SyncUpdate(0U);
    Icu_EnableNotification(0U);Icu_EnableEdgeDetection(0U);
    if(Dio_ReadChannel(DioConf_DioChannel_Ambd_GdInt)!=STD_LOW)latch_fault(KIT_GD_FAULT);
    Gpt_EnableNotification(0U);Gpt_StartTimer(0U,(Gpt_ValueType)(Mcu_GetClockFrequency(PIT0_CLK)/1000U));
    if(xTaskCreateStatic(background,"kit-status",768U,NULL,1U,background_stack,&background_control)==NULL){Hsp_Fail(72U);return;}
    /* Prime code/data caches while every power output is disabled. */
    Ambd_KitPrimeModel();
    Emios_Pwm_Ip_ComparatorTransferDisable(0U,0x0EU);
    for(unit=0U;unit<3U;unit++){
        Emios_Pwm_Ip_UpdateUCRegA(0U,(uint8_t)(unit+1U),2500U);
        Emios_Pwm_Ip_UpdateUCRegB(0U,(uint8_t)(unit+1U),7500U);
    }
    Emios_Pwm_Ip_ComparatorTransferEnable(0U,0x0EU);
    /* Drain the initial buffered trigger phase before acquiring any frame.
     * Otherwise the default 50% pulse followed by the early PMSM trigger
     * produces a shortened first interval instead of the declared 62.5 us. */
    Mcl_EmiosConfigureGlobalTimebase(0U,STD_ON);
    wait_us(126U);
    Emios_Pwm_Ip_ClearFlagEvent(IP_EMIOS_0,4U);
    if(Bctu_Ip_GetFifoCount(0U,0U)!=0U){latch_fault(KIT_FRAME_FAULT);Hsp_Fail(75U);return;}
    Adc_CtuEnableHwTrigger(BctuHwUnit_0_BctuTriggerList);
    Bctu_Ip_SetGlobalTriggerEn(0U,TRUE);
}

void Ambd_KitStop(void)
{
    if(initialized!=0U){
        uint32_t key=lock_interrupts();outputs_off();
        Bctu_Ip_SetGlobalTriggerEn(0U,FALSE);Bctu_Ip_DisableNotifications(0U,BCTU_IP_NOTIF_FIFO1);
        Mcl_EmiosConfigureGlobalTimebase(0U,STD_OFF);Gpt_StopTimer(0U);
        Dio_WriteChannel(DioConf_DioChannel_Hsp_GateReset,STD_LOW);unlock_interrupts(key);
    }
}
void Ambd_KitFaultIrq(void)
{
    if(initialized!=0U&&Dio_ReadChannel(DioConf_DioChannel_Ambd_GdInt)!=STD_LOW)latch_fault(KIT_GD_FAULT);
}
void Ambd_KitTick(void){tick_count++;}

bool Ambd_KitCapture(void)
{
    Adc_CtuFifoResultType fifo[4];Ambd_AdcWord words[4];Ambd_Measurement measured;
    float offsets[3];unsigned index;bool valid;
    Ambd_PwmPlan interval_plan=active_plan;
    active_plan=written_plan;
    if(Bctu_Ip_GetFifoCount(0U,0U)!=4U){latch_fault(KIT_FRAME_FAULT);Hsp_ReportModelEventFaultFromISR();return false;}
    Adc_CtuReadFifoResult(BctuHwUnit_0_BctuResultFifos_0,fifo,4U);
    for(index=0U;index<4U;index++){
        words[index].trigger=fifo[index].TriggerIdx;words[index].channel=fifo[index].ChanIdx;
        words[index].adc=fifo[index].AdcNum;words[index].data=fifo[index].AdcData;
        Ambd_Kit.raw[index]=fifo[index].AdcData;
    }
    if(!Ambd_FrameIdentity(words,AMBD_BLDC,adc_channel)){
        latch_fault(KIT_FRAME_FAULT);Hsp_ReportModelEventFaultFromISR();return false;
    }
    for(index=0U;index<3U;index++)offsets[index]=Ambd_Kit.offsets[index];
    valid=Ambd_DecodeFrame(words,AMBD_BLDC,adc_channel,offsets,&measured);
    if(!valid&&Ambd_Kit.calibrated!=0U)latch_fault(KIT_ADC_FAULT);
    Ambd_Kit.captures++;Ambd_Kit.hall=read_hall();Ambd_Kit.vdc=measured.vdc;
    Ambd_Kit.floating_phase=active_plan.floating;Ambd_Kit.sample_sector=active_sector;
    Ambd_Kit.sample_direction=active_direction;
    if(Ambd_Kit.driver_ready!=0U&&Ambd_Kit.calibrated==0U&&Ambd_Kit.applied_mask==0U&&Ambd_KitControl==0U&&valid){
        float a=(float)measured.current_raw[1],b=(float)measured.current_raw[0];
        bool centered=b>7000.0F&&b<9400.0F&&(AMBD_BLDC||(a>7000.0F&&a<9400.0F));
        if(centered){
            offset_sum[0]+=a;offset_sum[1]+=b;offset_sum[2]+=b;Ambd_Kit.calibration_samples++;
            if(Ambd_Kit.calibration_samples==KIT_CALIBRATION_SAMPLES){
                for(index=0U;index<3U;index++)Ambd_Kit.offsets[index]=offset_sum[index]/(float)KIT_CALIBRATION_SAMPLES;
                Ambd_Kit.calibrated=1U;
                for(index=0U;index<3U;index++)offsets[index]=Ambd_Kit.offsets[index];
                valid=Ambd_DecodeFrame(words,AMBD_BLDC,adc_channel,offsets,&measured);
            }
        }else{memset(offset_sum,0,sizeof(offset_sum));Ambd_Kit.calibration_samples=0U;}
    }
    Ambd_Kit.current[0]=measured.phase_a;Ambd_Kit.current[1]=measured.phase_b;Ambd_Kit.current[2]=measured.phase_c;
    Ambd_Kit.dc_current=measured.dc_current;Ambd_Kit.floating_voltage=measured.floating_voltage;
    if(Dio_ReadChannel(DioConf_DioChannel_Ambd_GdInt)!=STD_LOW)latch_fault(KIT_GD_FAULT);
    Ambd_Kit.sample_valid=(uint8_t)(valid&&Ambd_Kit.calibrated!=0U);
    if(AMBD_BLDC){
        Ambd_Kit.sample_valid=(uint8_t)(Ambd_Kit.sample_valid!=0U&&Ambd_Kit.applied_mask!=0U&&active_plan.duty[active_plan.source]>=3277U);
    }else{
        float duty[3];
        for(index=0U;index<3U;index++){
            duty[index]=(float)interval_plan.duty[index]/32768.0F;
            if(Ambd_Kit.current[index]>.05F)duty[index]-=.0096F;
            else if(Ambd_Kit.current[index]<-.05F)duty[index]+=.0096F;
        }
        Ambd_Kit.voltage_alpha=Ambd_Kit.applied_mask==7U?measured.vdc*(2.0F*duty[0]-duty[1]-duty[2])/3.0F:0.0F;
        Ambd_Kit.voltage_beta=Ambd_Kit.applied_mask==7U?measured.vdc*(duty[1]-duty[2])*.5773502691896258F:0.0F;
    }
    /* Only the plan submitted by the previous capture can have latched.
     * The model task queues requests; bounded fast API writes belong here. */
    if(pending_wait>0U){
        pending_wait--;
        if(pending_wait==0U&&active_plan.enable_mask==pending_plan.enable_mask
           &&written_sector==pending_sector&&written_direction==pending_direction
           &&Ambd_Kit.faults==0U&&Ambd_Kit.driver_ready!=0U&&Ambd_Kit.calibrated!=0U){
            static const uint8_t channels[3]={1U,3U,2U};
            active_sector=pending_sector;active_direction=pending_direction;
            if(AMBD_BLDC)select_adc_channel(channels[pending_plan.floating]);
            {
                Mcl_LcuSyncInputValueType values[3];unsigned phase;
                for(phase=0U;phase<3U;phase++){values[phase].LogicInputId=(uint8_t)phase;values[phase].Value=0U;}
                Mcl_SetLcuSyncInputSwOverrideValue(values,3U);
                for(phase=0U;phase<3U;phase++)values[phase].Value=pending_plan.duty[phase]==0U?1U:0U;
                Mcl_SetLcuSyncInputSwOverrideEnable(values,3U);
            }
            if(Dio_ReadChannel(DioConf_DioChannel_Ambd_GdInt)!=STD_LOW)latch_fault(KIT_GD_FAULT);
            else{output_mask(pending_plan.enable_mask);Dio_WriteChannel(DioConf_DioChannel_Hsp_GateEnable,STD_HIGH);}
        }
    }
    if(pending_plan.enable_mask!=0U&&Ambd_Kit.faults==0U){
        if(write_pwm_plan(&pending_plan)){
            written_plan=pending_plan;written_sector=pending_sector;written_direction=pending_direction;
        }else{latch_fault(KIT_LATE_UPDATE);}
    }
#if AMBD_CONTROL_BOARD_DIAGNOSTICS
    if(Ambd_Kit.driver_ready==0U&&Ambd_Kit.applied_mask==0U){
        const uint16_t counts[3]={6554U,32768U,58982U};const uint8_t phase[3]={1U,1U,1U};
        Ambd_PwmPlan diagnostic;
        if(Dio_ReadChannel(DioConf_DioChannel_Hsp_GateEnable)!=STD_LOW||IP_LCU_0->OUTEN!=0U){
            latch_fault(KIT_COMMAND_FAULT);
        }else if(Ambd_MapBridge(0U,counts,phase,1U,1U,&diagnostic)){
            if(!write_pwm_plan(&diagnostic))latch_fault(KIT_LATE_UPDATE);
        }
    }
#endif
    return true;
}

void Ambd_KitCommit(const uint16_t counts[3],const uint8_t phases[3],uint8_t gate,uint8_t armed,uint8_t sector,int8_t direction)
{
    Ambd_PwmPlan plan;uint32_t key;
    if(initialized==0U)return;
    Ambd_Kit.requested_armed=armed;
    if(!Ambd_MapBridge(AMBD_BLDC,counts,phases,gate,armed,&plan)){latch_fault(KIT_COMMAND_FAULT);return;}
    key=lock_interrupts();
    if(Dio_ReadChannel(DioConf_DioChannel_Ambd_GdInt)!=STD_LOW)latch_fault(KIT_GD_FAULT);
    if(plan.enable_mask==0U||Ambd_Kit.faults!=0U||Ambd_Kit.driver_ready==0U||Ambd_Kit.calibrated==0U){outputs_off();unlock_interrupts(key);return;}
    if(AMBD_BLDC&&(sector<1U||sector>6U||(direction!=1&&direction!=-1))){
        latch_fault(KIT_COMMAND_FAULT);unlock_interrupts(key);return;
    }
    if(plan.enable_mask!=pending_plan.enable_mask||sector!=pending_sector||direction!=pending_direction){
        output_mask(0U);Dio_WriteChannel(DioConf_DioChannel_Hsp_GateEnable,STD_LOW);
        active_sector=0U;pending_wait=2U;
    }
    pending_plan=plan;pending_sector=sector;pending_direction=direction;
    unlock_interrupts(key);
}
#else
void Ambd_KitStart(void){}
void Ambd_KitStop(void){}
bool Ambd_KitCapture(void){return false;}
void Ambd_KitFaultIrq(void){}
void Ambd_KitTick(void){}
void Ambd_KitCommit(const uint16_t counts[3],const uint8_t phases[3],uint8_t gate,uint8_t armed,uint8_t sector,int8_t direction)
{(void)counts;(void)phases;(void)gate;(void)armed;(void)sector;(void)direction;}
#endif
