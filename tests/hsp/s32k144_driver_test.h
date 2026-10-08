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
// File:        s32k144_driver_test.h
// Author:      autoMBD <tkung.lqk@foxmail.com>
// Date:        2026-10-08
// Version:     0.1.0
// Description: Check six-step mapping, sample identities, scaling, and absent-GD3000 rejection.
// =================================================================================

#ifndef S32K144_DRIVER_TEST_H
#define S32K144_DRIVER_TEST_H
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
typedef uint8_t boolean,Std_ReturnType,Adc_HwUnitType;
typedef uint32_t Gpt_ValueType,StackType_t,StaticTask_t;
typedef struct { uint8_t AdcUnitSelfTestStatus; } Adc_CalibrationStatusType;
typedef enum { ADC_IP_INPUTCHAN_EXT4=4,ADC_IP_INPUTCHAN_EXT6=6,ADC_IP_INPUTCHAN_EXT7=7,ADC_IP_INPUTCHAN_EXT15=15 } Adc_Ip_InputChannelType;
typedef struct {uint8_t ChnIdx;Adc_Ip_InputChannelType Channel;boolean InterruptEnable;} Adc_Ip_ChanConfigType;
typedef struct {uint8_t EnableMask,EnableDelayMask,BackToBackEnableMask;} Pdb_Adc_Ip_PretriggersConfigType;
typedef struct {uint32_t MOD,CNTIN,SC,POL,DEADTIME,COMBINE,CNT,OUTMASK;} TestFtm;
typedef struct {struct {uint32_t S;}CH[1];} TestPdb;
typedef struct {uint32_t PCR[32],ISFR;} TestPort;
typedef struct {uint32_t CHIPCTL;} TestSim;
extern TestFtm test_ftm;
extern TestPdb test_pdb[2];
extern TestPort test_port;
extern TestSim test_sim;
#define IP_FTM3 (&test_ftm)
#define IP_PDB0 (&test_pdb[0])
#define IP_PDB1 (&test_pdb[1])
#define IP_PORTE (&test_port)
#define IP_SIM (&test_sim)
#define FTM_SC_CPWMS_MASK 0x20U
#define FTM_DEADTIME_DTVAL_MASK 0x3FU
#define PDB_S_ERR_MASK 0xFFU
#define PORT_PCR_IRQC_MASK 0xF0000U
#define PORT_PCR_IRQC(x) ((uint32_t)(x)<<16U)
#define SIM_CHIPCTL_ADC_INTERLEAVE_EN(x) ((uint32_t)(x)<<4U)
#define TRUE true
#define FALSE false
#define E_OK 0U
#define STD_LOW 0U
#define STD_HIGH 1U
#define ADC_IP_TRIGGER_HARDWARE 1U
#define PDB_ADC_IP_TRIGGER_IN0 0U
#define AMBD_ADC0_TRIGGER 0U
#define AMBD_ADC1_TRIGGER 1U
#define TRGMUX_IP_STATUS_SUCCESS 0U
#define TRGMUX_IP_INPUT_LOGIC0_VSS 0U
#define TRGMUX_IP_INPUT_FTM3_EXT_TRIG 29U
#define FTM_PWM_IP_OUTPUT_STATE_LOW 0U
#define FTM_PWM_IP_OUTPUT_STATE_HIGH 1U
#define ADC1_IRQn 1U
#define LPIT0_CLK 0U
#define pdMS_TO_TICKS(x) (x)
enum {DioConf_DioChannel_Hsp_GateEnable,DioConf_DioChannel_Hsp_GateReset,DioConf_DioChannel_Ambd_GdCs,DioConf_DioChannel_Ambd_GdInt,DioConf_DioChannel_Ambd_HallA,DioConf_DioChannel_Ambd_HallB,DioConf_DioChannel_Ambd_HallC};
extern uint32_t Hsp_CoreClockHz;
extern volatile uint32_t Hsp_ModelStepCount,Hsp_FailureCode,Hsp_MaxStepCycles,Hsp_EventCount,Hsp_LastEventIntervalCycles;
uint32_t Ambd_K144TestLock(void);
void Ambd_K144TestUnlock(uint32_t prior);
uint32_t Hsp_ReadCycleCounter(void);
void Hsp_Fail(uint32_t code);
void Hsp_ReportModelEventFaultFromISR(void);
uint8_t Dio_ReadChannel(unsigned channel);
void Dio_WriteChannel(unsigned channel,unsigned value);
void Ftm_Pwm_Ip_MaskOutputChannels(unsigned instance,uint32_t mask,bool sync);
void Ftm_Pwm_Ip_UnMaskOutputChannels(unsigned instance,uint32_t mask,bool sync);
void Ftm_Pwm_Ip_SetOutmaskPwmSyncModeCmd(TestFtm *base,bool sync);
void Ftm_Pwm_Ip_UpdatePwmDutyCycleChannel(unsigned instance,unsigned channel,uint16_t duty,bool sync);
void Ftm_Pwm_Ip_FastUpdatePwmDuty(unsigned instance,unsigned count,const uint8_t *channels,const uint16_t *compare,bool sync);
void Ftm_Pwm_Ip_SyncUpdate(unsigned instance);
void Ftm_Pwm_Ip_SetChnCountVal(TestFtm *base,unsigned channel,uint32_t value);
void Ftm_Pwm_Ip_ClearChnEventFlag(TestFtm *base,unsigned channel);
void Ftm_Pwm_Ip_SwOutputControl(unsigned instance,unsigned channel,unsigned level,bool enable);
void Adc_Calibrate(unsigned unit,Adc_CalibrationStatusType *result);
void Adc_Ip_SetTriggerMode(unsigned unit,unsigned mode);
void Adc_Ip_SetSampleTime(unsigned unit,unsigned sample);
void Adc_Ip_ConfigChannel(unsigned unit,const Adc_Ip_ChanConfigType *cfg);
bool Adc_Ip_GetConvCompleteFlag(unsigned unit,unsigned slot);
uint16_t Adc_Ip_GetConvData(unsigned unit,unsigned slot);
void Pdb_Adc_Ip_Disable(unsigned unit);
void Pdb_Adc_Ip_Enable(unsigned unit);
void Pdb_Adc_Ip_SetTriggerInput(unsigned unit,unsigned source);
void Pdb_Adc_Ip_SetContinuousMode(unsigned unit,bool continuous);
void Pdb_Adc_Ip_SetModulus(unsigned unit,uint16_t value);
void Pdb_Adc_Ip_SetAdcPretriggerDelayValue(unsigned unit,unsigned channel,unsigned slot,uint16_t value);
void Pdb_Adc_Ip_ConfigAdcPretriggers(unsigned unit,unsigned channel,const Pdb_Adc_Ip_PretriggersConfigType *cfg);
void Pdb_Adc_Ip_LoadRegValues(unsigned unit);
void Pdb_Adc_Ip_ClearAdcPretriggerFlags(unsigned unit,unsigned channel,uint16_t mask);
uint8_t Trgmux_Ip_SetInput(unsigned channel,uint32_t source);
void IntCtrl_Ip_ClearPending(unsigned irq);
void Gpt_EnableNotification(unsigned channel);
void Gpt_StartTimer(unsigned channel,Gpt_ValueType ticks);
void Gpt_StopTimer(unsigned channel);
uint32_t Mcu_GetClockFrequency(unsigned clock);
uint8_t Spi_WriteIB(unsigned channel,const uint8_t *value);
uint8_t Spi_SyncTransmit(unsigned sequence);
uint8_t Spi_ReadIB(unsigned channel,uint8_t *value);
void *xTaskCreateStatic(void (*fn)(void*),const char *name,unsigned words,void *arg,unsigned priority,StackType_t *stack,StaticTask_t *control);
void vTaskDelay(unsigned ticks);
unsigned Uart_SyncSend(unsigned channel,const uint8_t *data,unsigned length,unsigned timeout);
#endif
