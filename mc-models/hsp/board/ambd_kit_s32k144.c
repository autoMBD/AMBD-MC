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
// File:        ambd_kit_s32k144.c
// Author:      autoMBD <tkung.lqk@foxmail.com>
// Date:        2026-10-08
// Version:     0.1.0
// Description: Acquire physical kit frames, qualify GD3000, and commit interlocked PWM outputs.
// =================================================================================

#include "ambd_kit_board.h"
#include "ambd_kit_s32k144.h"
#include <string.h>
#include <math.h>

volatile Ambd_KitStatus Ambd_Kit;
volatile uint8_t Ambd_KitControl;
volatile float Ambd_KitSpeedRequest;

#if defined(HSP_TARGET) && !defined(HSP_PIL)
#ifdef AMBD_KIT_HOST_TEST
#include "s32k144_driver_test.h"
#else
#include "hsp_runtime.h"
#include "Adc.h"
#include "Adc_Ip.h"
#include "Pdb_Adc_Ip.h"
#include "Trgmux_Ip.h"
#include "IntCtrl_Ip.h"
#include "CDD_Mcl.h"
#include "CDD_Uart.h"
#include "Dio.h"
#include "Pwm.h"
#include "Ftm_Pwm_Ip.h"
#include "Ftm_Pwm_Ip_HwAccess.h"
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
extern void Hsp_ModelEvent(void);
#define KIT_GD_FAULT 1U
#define KIT_ADC_FAULT 2U
#define KIT_FRAME_FAULT 4U
#define KIT_LATE_UPDATE 8U
#define KIT_COMMAND_FAULT 16U
#define KIT_CALIBRATION_SAMPLES 1024U
static uint8_t initialized, pending_wait, pending_sector, written_sector, active_sector;
static int8_t pending_direction=1,written_direction=1,active_direction=1;
static uint8_t stopped=1U;
static Ambd_PwmPlan pending_plan,written_plan,active_plan;
static float offset_sum[3];
static uint32_t tick_count;
static StaticTask_t background_control;
static StackType_t background_stack[768];

static bool validate_pwm_mapping(void)
{
    return IP_FTM3->MOD==AMBD_K144_PWM_PERIOD/2U && IP_FTM3->CNTIN==0U
        && (IP_FTM3->SC&FTM_SC_CPWMS_MASK)!=0U
        && (IP_FTM3->POL&0x3FU)==0x15U
        && (IP_FTM3->DEADTIME&FTM_DEADTIME_DTVAL_MASK)==48U
        && (IP_FTM3->COMBINE&0x00323232U)==0x00323232U;
}

static uint32_t lock_interrupts(void)
{
#ifdef AMBD_KIT_HOST_TEST
    return Ambd_K144TestLock();
#else
    uint32_t value;
    __asm__ volatile ("mrs %0, primask\n\tcpsid i" : "=r"(value) :: "memory");
    return value;
#endif
}
static void unlock_interrupts(uint32_t value)
{
#ifdef AMBD_KIT_HOST_TEST
    Ambd_K144TestUnlock(value);
#else
    __asm__ volatile ("msr primask, %0" :: "r"(value) : "memory");
#endif
}
static void output_mask(uint8_t mask)
{
    /* Immediate masking is independent of the buffered duty transfer.
     * POL=0x15 makes every masked high side high and low side low. */
    Ftm_Pwm_Ip_MaskOutputChannels(3U,0x3FU,FALSE);
    Ftm_Pwm_Ip_UnMaskOutputChannels(3U,(uint32_t)(0x3FU^Ambd_K144OutputMask(mask)),FALSE);
    Ambd_Kit.applied_mask=mask;
}
static void outputs_off(void)
{
    /* Deassert driver EN before altering any timer output. */
    Dio_WriteChannel(DioConf_DioChannel_Hsp_GateEnable,STD_LOW);output_mask(0U);
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
    uint32_t counter=IP_FTM3->CNT,started=Hsp_ReadCycleCounter(),finished,elapsed;unsigned index;
    static const uint8_t channels[3]={0U,2U,4U};uint16_t compare[3];
    if(!Ambd_K144CommitWindow(AMBD_BLDC,counter,counter,0U)){
        Ambd_Kit.late_updates++;return false;
    }
    for(index=0U;index<3U;index++){
        /* Keep unused pairs nondegenerate; sink/freewheel is set by a
         * separate software override only while the entire bridge is off. */
        uint16_t duty=plan->duty[index]==0U?16384U:plan->duty[index];
        /* FastUpdate consumes raw CV values: center-aligned compare ticks,
         * not Q15 and not the full-period ticks of the single-channel API. */
        compare[index]=(uint16_t)(((uint32_t)duty*(AMBD_K144_PWM_PERIOD/2U)+16384U)/32768U);
    }
    Ftm_Pwm_Ip_FastUpdatePwmDuty(3U,3U,channels,compare,TRUE);
    finished=IP_FTM3->CNT;elapsed=Hsp_ReadCycleCounter()-started;
    if(elapsed>Ambd_Kit.max_commit_cycles)Ambd_Kit.max_commit_cycles=elapsed;
    if(!Ambd_K144CommitWindow(AMBD_BLDC,counter,finished,elapsed)){
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
    Adc_Ip_ChanConfigType config={0U,(Adc_Ip_InputChannelType)channel,FALSE};
    Adc_Ip_ConfigChannel(0U,&config);
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
        put32(&frame[72],IP_FTM3->OUTMASK);put32(&frame[76],Ambd_Kit.late_updates);
        put32(&frame[80],tick_count);put32(&frame[84],Hsp_LastEventIntervalCycles);
        put32(&frame[88],Ambd_Kit.gd_errors);put32(&frame[92],Ambd_Kit.max_commit_cycles);
        put32(&frame[96],Ambd_Kit.model_mode);put32(&frame[100],Ambd_Kit.model_faults);
        put32(&frame[104],Ambd_Kit.requested_armed);
        unlock_interrupts(key);
        put32(&frame[108],crc32(frame,108U));
        (void)Uart_SyncSend(0U,frame,sizeof(frame),20000U);
    }
}

static bool route_trigger(uint32_t source)
{
    return Trgmux_Ip_SetInput(AMBD_ADC0_TRIGGER,source)==TRGMUX_IP_STATUS_SUCCESS
        && Trgmux_Ip_SetInput(AMBD_ADC1_TRIGGER,source)==TRGMUX_IP_STATUS_SUCCESS;
}

void Ambd_KitStart(void)
{
    Adc_CalibrationStatusType calibration;uint8_t status[4];unsigned unit,attempt;
    const Pdb_Adc_Ip_PretriggersConfigType pre0={1U,1U,0U},pre1={3U,1U,2U};
    const Adc_Ip_ChanConfigType current={0U,AMBD_BLDC?ADC_IP_INPUTCHAN_EXT6:ADC_IP_INPUTCHAN_EXT15,FALSE};
    const Adc_Ip_ChanConfigType voltage={1U,ADC_IP_INPUTCHAN_EXT7,TRUE};
    uint32_t key=lock_interrupts();
    initialized=1U;stopped=1U;memset((void*)&Ambd_Kit,0,sizeof(Ambd_Kit));
    memset(offset_sum,0,sizeof(offset_sum));
    Dio_WriteChannel(DioConf_DioChannel_Hsp_GateEnable,STD_LOW);
    Ftm_Pwm_Ip_SetOutmaskPwmSyncModeCmd(IP_FTM3,FALSE);
    outputs_off();Dio_WriteChannel(DioConf_DioChannel_Hsp_GateReset,STD_LOW);
    Pdb_Adc_Ip_Disable(0U);Pdb_Adc_Ip_Disable(1U);
    if(!route_trigger(TRGMUX_IP_INPUT_LOGIC0_VSS)||!validate_pwm_mapping()){
        unlock_interrupts(key);Hsp_Fail(74U);return;
    }
    unlock_interrupts(key);
    if(Hsp_CoreClockHz!=80000000U){Hsp_Fail(73U);return;}
    Ambd_Kit.offsets[0]=2048.0F;Ambd_Kit.offsets[1]=2048.0F;Ambd_Kit.offsets[2]=2048.0F;
    Dio_WriteChannel(DioConf_DioChannel_Ambd_GdCs,STD_HIGH);wait_us(1000U);
    Dio_WriteChannel(DioConf_DioChannel_Hsp_GateReset,STD_HIGH);wait_us(1000U);
    if(Ambd_GdConfigure(spi_transfer,NULL,status))Ambd_Kit.driver_ready=1U;
    else{
        Ambd_Kit.gd_errors++;Ambd_Kit.faults|=KIT_GD_FAULT;
        Dio_WriteChannel(DioConf_DioChannel_Hsp_GateReset,STD_LOW);
    }
    for(unit=0U;unit<4U;unit++)Ambd_Kit.gd_status[unit]=status[unit];
    /* RTD MCAL owns initialization; after calibration the application owns
     * both ADC/PDB instances through RTD IP APIs. No MCAL conversions run. */
    for(unit=0U;unit<2U;unit++){
        for(attempt=0U;attempt<6U;attempt++){
            Adc_Calibrate((Adc_HwUnitType)unit,&calibration);
            if(calibration.AdcUnitSelfTestStatus==E_OK)break;
        }
        if(calibration.AdcUnitSelfTestStatus!=E_OK){latch_fault(KIT_ADC_FAULT);Hsp_Fail(71U);return;}
        Adc_Ip_SetTriggerMode(unit,ADC_IP_TRIGGER_HARDWARE);
        Adc_Ip_SetSampleTime(unit,8U);
        Pdb_Adc_Ip_Disable(unit);Pdb_Adc_Ip_SetTriggerInput(unit,PDB_ADC_IP_TRIGGER_IN0);
        Pdb_Adc_Ip_SetContinuousMode(unit,FALSE);Pdb_Adc_Ip_SetModulus(unit,(uint16_t)(AMBD_K144_PWM_PERIOD/2U-1U));
        Pdb_Adc_Ip_SetAdcPretriggerDelayValue(unit,0U,0U,40U);
    }
    /* PTB1 shares ADC0_SE5 and ADC1_SE15. Board jumpers choose Vb or Ib. */
    IP_SIM->CHIPCTL|=SIM_CHIPCTL_ADC_INTERLEAVE_EN(2U);
    select_adc_channel(4U);Adc_Ip_ConfigChannel(1U,&current);Adc_Ip_ConfigChannel(1U,&voltage);
    Pdb_Adc_Ip_ConfigAdcPretriggers(0U,0U,&pre0);Pdb_Adc_Ip_ConfigAdcPretriggers(1U,0U,&pre1);
    for(unit=0U;unit<2U;unit++){
        Pdb_Adc_Ip_Enable(unit);Pdb_Adc_Ip_LoadRegValues(unit);
    }
    IP_PORTE->ISFR=(1UL<<10U);
    IP_PORTE->PCR[10]=(IP_PORTE->PCR[10]&~PORT_PCR_IRQC_MASK)|PORT_PCR_IRQC(9U);
    if(Dio_ReadChannel(DioConf_DioChannel_Ambd_GdInt)!=STD_LOW)latch_fault(KIT_GD_FAULT);
    Gpt_EnableNotification(0U);Gpt_StartTimer(0U,(Gpt_ValueType)(Mcu_GetClockFrequency(LPIT0_CLK)/1000U));
    if(xTaskCreateStatic(background,"kit-status",768U,NULL,1U,background_stack,&background_control)==NULL){Hsp_Fail(72U);return;}
    Ambd_KitPrimeModel();
    /* Endpoint matches occur once per full up/down period. BLDC samples
     * around active-pulse center (CNT=0); PMSM at the low-side zero vector. */
    Ftm_Pwm_Ip_SetChnCountVal(IP_FTM3,6U,AMBD_BLDC?0U:AMBD_K144_PWM_PERIOD/2U);
    Ftm_Pwm_Ip_SyncUpdate(3U);wait_us(251U);
    Ftm_Pwm_Ip_ClearChnEventFlag(IP_FTM3,6U);
    IntCtrl_Ip_ClearPending(ADC1_IRQn);
    stopped=0U;
    if(!route_trigger(TRGMUX_IP_INPUT_FTM3_EXT_TRIG)){Ambd_KitStop();Hsp_Fail(75U);}
}

void Ambd_KitStop(void)
{
    if(initialized!=0U){
        uint32_t key=lock_interrupts();stopped=1U;outputs_off();
        (void)route_trigger(TRGMUX_IP_INPUT_LOGIC0_VSS);
        Pdb_Adc_Ip_Disable(0U);Pdb_Adc_Ip_Disable(1U);Gpt_StopTimer(0U);
        Dio_WriteChannel(DioConf_DioChannel_Hsp_GateReset,STD_LOW);unlock_interrupts(key);
    }
}
void Ambd_KitFaultIrq(void)
{
    uint32_t occurred=IP_PORTE->ISFR&(1UL<<10U);
    IP_PORTE->ISFR=(1UL<<10U);
    /* Retain a pending edge even if the physical INT pulse has ended. */
    if(initialized!=0U&&(occurred!=0U||Dio_ReadChannel(DioConf_DioChannel_Ambd_GdInt)!=STD_LOW))latch_fault(KIT_GD_FAULT);
}
void Ambd_KitAdcIrq(void)
{
    if(initialized!=0U&&stopped==0U)Hsp_ModelEvent();
    else{(void)Adc_Ip_GetConvData(1U,1U);}
}
void Ambd_KitTick(void){tick_count++;}

bool Ambd_KitCapture(void)
{
    uint16_t raw[3];Ambd_Measurement measured;
    float offsets[3];unsigned index;bool valid;
    Ambd_PwmPlan interval_plan=active_plan;
    active_plan=written_plan;
    if(stopped!=0U)return false;
    if(!Adc_Ip_GetConvCompleteFlag(0U,0U)||!Adc_Ip_GetConvCompleteFlag(1U,0U)
       ||!Adc_Ip_GetConvCompleteFlag(1U,1U)
       ||((IP_PDB0->CH[0].S|IP_PDB1->CH[0].S)&PDB_S_ERR_MASK)!=0U){
        latch_fault(KIT_FRAME_FAULT);Hsp_ReportModelEventFaultFromISR();return false;
    }
    raw[0]=Adc_Ip_GetConvData(0U,0U);raw[1]=Adc_Ip_GetConvData(1U,0U);raw[2]=Adc_Ip_GetConvData(1U,1U);
    Pdb_Adc_Ip_ClearAdcPretriggerFlags(0U,0U,1U);Pdb_Adc_Ip_ClearAdcPretriggerFlags(1U,0U,3U);
    for(index=0U;index<3U;index++)Ambd_Kit.raw[index]=raw[index];
    for(index=0U;index<3U;index++)offsets[index]=Ambd_Kit.offsets[index];
    valid=Ambd_K144Decode(raw,AMBD_BLDC,offsets,&measured);
    if(!valid&&Ambd_Kit.calibrated!=0U)latch_fault(KIT_ADC_FAULT);
    Ambd_Kit.captures++;Ambd_Kit.hall=read_hall();Ambd_Kit.vdc=measured.vdc;
    Ambd_Kit.floating_phase=active_plan.floating;Ambd_Kit.sample_sector=active_sector;
    Ambd_Kit.sample_direction=active_direction;
    if(Ambd_Kit.driver_ready!=0U&&Ambd_Kit.calibrated==0U&&Ambd_Kit.applied_mask==0U&&Ambd_KitControl==0U&&valid){
        float a=(float)measured.current_raw[1],b=(float)measured.current_raw[0];
        bool centered=b>1750.0F&&b<2350.0F&&(AMBD_BLDC||(a>1750.0F&&a<2350.0F));
        if(centered){
            offset_sum[0]+=a;offset_sum[1]+=b;offset_sum[2]+=b;Ambd_Kit.calibration_samples++;
            if(Ambd_Kit.calibration_samples==KIT_CALIBRATION_SAMPLES){
                for(index=0U;index<3U;index++)Ambd_Kit.offsets[index]=offset_sum[index]/(float)KIT_CALIBRATION_SAMPLES;
                Ambd_Kit.calibrated=1U;
                for(index=0U;index<3U;index++)offsets[index]=Ambd_Kit.offsets[index];
                valid=Ambd_K144Decode(raw,AMBD_BLDC,offsets,&measured);
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
            if(Ambd_Kit.current[index]>.05F)duty[index]-=(48.0F/(float)AMBD_K144_PWM_PERIOD);
            else if(Ambd_Kit.current[index]<-.05F)duty[index]+=(48.0F/(float)AMBD_K144_PWM_PERIOD);
        }
        Ambd_Kit.voltage_alpha=Ambd_Kit.applied_mask==7U?measured.vdc*(2.0F*duty[0]-duty[1]-duty[2])/3.0F:0.0F;
        Ambd_Kit.voltage_beta=Ambd_Kit.applied_mask==7U?measured.vdc*(duty[1]-duty[2])*.5773502691896258F:0.0F;
    }
    /* Only the plan submitted by the previous capture can have latched.
     * The model task queues requests; bounded fast API writes belong here. */
    {
    uint32_t key=lock_interrupts();
    if(pending_wait>0U){
        pending_wait--;
        if(pending_wait==0U&&active_plan.enable_mask==pending_plan.enable_mask
           &&written_sector==pending_sector&&written_direction==pending_direction
           &&stopped==0U&&Ambd_Kit.faults==0U&&Ambd_Kit.driver_ready!=0U&&Ambd_Kit.calibrated!=0U){
            static const uint8_t channels[3]={4U,5U,2U};
            active_sector=pending_sector;active_direction=pending_direction;
            if(AMBD_BLDC)select_adc_channel(channels[pending_plan.floating]);
            {
                unsigned phase;
                for(phase=0U;phase<3U;phase++){
                    bool force=AMBD_BLDC&&pending_plan.duty[phase]==0U;
                    /* RTD accepts the physical pin level and compensates POL. */
                    Ftm_Pwm_Ip_SwOutputControl(3U,(uint8_t)(phase*2U),FTM_PWM_IP_OUTPUT_STATE_HIGH,force);
                    Ftm_Pwm_Ip_SwOutputControl(3U,(uint8_t)(phase*2U+1U),FTM_PWM_IP_OUTPUT_STATE_HIGH,force);
                }
            }
            if(Dio_ReadChannel(DioConf_DioChannel_Ambd_GdInt)!=STD_LOW)latch_fault(KIT_GD_FAULT);
            else{output_mask(pending_plan.enable_mask);Dio_WriteChannel(DioConf_DioChannel_Hsp_GateEnable,STD_HIGH);}
        }
    }
    unlock_interrupts(key);
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
        if(Dio_ReadChannel(DioConf_DioChannel_Hsp_GateEnable)!=STD_LOW||(IP_FTM3->OUTMASK&0x3FU)!=0x3FU){
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
    if(initialized==0U||stopped!=0U)return;
    Ambd_Kit.requested_armed=armed;
    if(!Ambd_MapBridge(AMBD_BLDC,counts,phases,gate,armed,&plan)){latch_fault(KIT_COMMAND_FAULT);return;}
    key=lock_interrupts();
    if(Dio_ReadChannel(DioConf_DioChannel_Ambd_GdInt)!=STD_LOW)latch_fault(KIT_GD_FAULT);
    if(plan.enable_mask==0U||Ambd_Kit.faults!=0U||Ambd_Kit.driver_ready==0U||Ambd_Kit.calibrated==0U){outputs_off();unlock_interrupts(key);return;}
    if(AMBD_BLDC&&(sector<1U||sector>6U||(direction!=1&&direction!=-1))){
        latch_fault(KIT_COMMAND_FAULT);unlock_interrupts(key);return;
    }
    if(plan.enable_mask!=pending_plan.enable_mask||sector!=pending_sector||direction!=pending_direction){
        Dio_WriteChannel(DioConf_DioChannel_Hsp_GateEnable,STD_LOW);output_mask(0U);
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
void Ambd_KitAdcIrq(void){}
void Ambd_KitTick(void){}
void Ambd_KitCommit(const uint16_t counts[3],const uint8_t phases[3],uint8_t gate,uint8_t armed,uint8_t sector,int8_t direction)
{(void)counts;(void)phases;(void)gate;(void)armed;(void)sector;(void)direction;}
#endif
