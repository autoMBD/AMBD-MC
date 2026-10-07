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
// File:        board_driver_test.h
// Author:      autoMBD <tkung.lqk@foxmail.com>
// Date:        2026-10-07
// Version:     0.1.0
// Description: Provide deterministic RTD peers for host tests of the actual board state machine.
// =================================================================================

#ifndef BOARD_DRIVER_TEST_H
#define BOARD_DRIVER_TEST_H
#include <stdint.h>
#include <stddef.h>
#define STD_LOW 0U
#define STD_HIGH 1U
#define STD_OFF 0U
#define STD_ON 1U
#define TRUE 1U
#define FALSE 0U
#define E_OK 0U
#define PIT0_CLK 0U
#define BCTU_IP_NOTIF_FIFO1 1U
#define BctuHwUnit_0_BctuTriggerList 4U
#define BctuHwUnit_0_BctuResultFifos_0 0U
#define PwmConf_PwmChannel_Hsp_PhaseA 0U
#define PwmConf_PwmChannel_Hsp_PhaseB 1U
#define PwmConf_PwmChannel_Hsp_PhaseC 2U
#define PwmConf_PwmChannel_Hsp_AdcTrigger 3U
#define DioConf_DioChannel_Hsp_GateEnable 44U
#define DioConf_DioChannel_Hsp_GateReset 45U
#define DioConf_DioChannel_Ambd_GdCs 49U
#define DioConf_DioChannel_Ambd_GdInt 71U
#define DioConf_DioChannel_Ambd_HallA 19U
#define DioConf_DioChannel_Ambd_HallB 20U
#define DioConf_DioChannel_Ambd_HallC 21U
#define pdMS_TO_TICKS(x) (x)
typedef uint8_t Std_ReturnType;
typedef uint8_t Pwm_ChannelType;
#define PWM_CHANNEL_EMIOS 0U
#define EMIOS_PWM_IP_MODE_OPWMB_FLAG 1U
#define EMIOS_PWM_IP_BUS_F 2U
#define EMIOS_PWM_IP_ACTIVE_HIGH 1U
typedef struct {uint8_t ChannelId,Mode,Timebase;uint32_t PeriodCount;uint8_t OutputPolarity;} Emios_Pwm_Ip_ChannelConfigType;
typedef struct {uint8_t ChannelType,ChannelInstanceId;const Emios_Pwm_Ip_ChannelConfigType *EmiosChConfig;} Pwm_IpwChannelConfigType;
typedef struct {uint8_t ChannelId;Pwm_IpwChannelConfigType IpwChannelCfg;} Pwm_ChannelConfigType;
typedef struct {uint8_t NumChannels;const Pwm_ChannelConfigType (*PwmChannelsConfig)[];} Pwm_ConfigType;
extern Pwm_ConfigType Pwm_Config;
typedef uint8_t Adc_HwUnitType;
typedef uint32_t Gpt_ValueType;
typedef uint32_t StackType_t;
typedef struct {unsigned unused;} StaticTask_t;
typedef struct {uint8_t LogicOutputId;uint32_t Value;} Mcl_LcuSyncOutputValueType;
typedef struct {uint8_t LogicInputId;uint32_t Value;} Mcl_LcuSyncInputValueType;
typedef struct {uint8_t NextChanWaitOnTrig,AdcChanIndex;} Adc_CtuListItemType;
typedef struct {uint8_t AdcUnitSelfTestStatus;} Adc_CalibrationStatusType;
typedef struct {uint8_t TriggerIdx,ChanIdx,AdcNum;uint16_t AdcData;} Adc_CtuFifoResultType;
typedef struct {struct {struct {uint32_t CNT;} UC[32];} CH;} FakeEmios;
typedef struct {uint32_t OUTEN;} FakeLcu;
extern FakeEmios fake_emios;
extern FakeLcu fake_lcu;
#define IP_EMIOS_0 (&fake_emios)
#define IP_LCU_0 (&fake_lcu)
extern uint32_t Hsp_CoreClockHz,Hsp_ModelStepCount,Hsp_FailureCode,Hsp_MaxStepCycles,Hsp_EventCount,Hsp_LastEventIntervalCycles;
uint32_t Hsp_ReadCycleCounter(void);
void Hsp_Fail(uint32_t reason);
void Hsp_ReportModelEventFaultFromISR(void);
void Mcl_SetLcuSyncOutputEnable(const Mcl_LcuSyncOutputValueType *values,uint8_t count);
void Mcl_SetLcuSyncInputSwOverrideValue(const Mcl_LcuSyncInputValueType *values,uint8_t count);
void Mcl_SetLcuSyncInputSwOverrideEnable(const Mcl_LcuSyncInputValueType *values,uint8_t count);
void Mcl_EmiosConfigureGlobalTimebase(uint8_t instance,uint8_t on);
void Dio_WriteChannel(uint16_t channel,uint8_t value);
uint8_t Dio_ReadChannel(uint16_t channel);
Std_ReturnType Spi_WriteIB(uint8_t channel,const uint8_t *data);
Std_ReturnType Spi_SyncTransmit(uint8_t sequence);
Std_ReturnType Spi_ReadIB(uint8_t channel,uint8_t *data);
void Adc_CtuSetList(uint8_t unit,const Adc_CtuListItemType *list,uint8_t count,uint8_t start);
void Adc_Calibrate(uint8_t unit,Adc_CalibrationStatusType *result);
void Adc_EnableCtuControlMode(uint8_t unit);
void Adc_CtuEnableHwTrigger(uint8_t trigger);
void Adc_CtuReadFifoResult(uint8_t fifo,Adc_CtuFifoResultType *words,uint8_t count);
uint32_t Bctu_Ip_GetFifoCount(uint8_t unit,uint8_t fifo);
void Bctu_Ip_SetGlobalTriggerEn(uint8_t unit,uint8_t on);
void Bctu_Ip_DisableHwTrigger(uint32_t unit,uint8_t index);
void Bctu_Ip_DisableNotifications(uint8_t unit,uint8_t mask);
void Pwm_SetDutyPhaseShift(uint8_t channel,uint16_t duty,uint16_t shift,uint8_t sync);
void Pwm_SyncUpdate(uint8_t instance);
void Pwm_FastUpdateDisableOU(uint8_t instance,uint32_t mask);
void Pwm_FastUpdateEnableOU(uint8_t instance,uint32_t mask);
void Pwm_FastUpdateSetUCRegA(uint8_t channel,uint32_t value);
void Pwm_FastUpdateSetUCRegB(uint8_t channel,uint32_t value);
void Emios_Pwm_Ip_ComparatorTransferDisable(uint8_t instance,uint32_t mask);
void Emios_Pwm_Ip_ComparatorTransferEnable(uint8_t instance,uint32_t mask);
void Emios_Pwm_Ip_UpdateUCRegA(uint8_t instance,uint8_t channel,uint32_t value);
void Emios_Pwm_Ip_UpdateUCRegB(uint8_t instance,uint8_t channel,uint32_t value);
void Emios_Pwm_Ip_ClearFlagEvent(FakeEmios *base,uint8_t channel);
void Icu_EnableNotification(uint8_t channel);
void Icu_EnableEdgeDetection(uint8_t channel);
void Gpt_EnableNotification(uint8_t channel);
void Gpt_StartTimer(uint8_t channel,uint32_t value);
void Gpt_StopTimer(uint8_t channel);
uint32_t Mcu_GetClockFrequency(uint32_t clock);
void vTaskDelay(uint32_t delay);
void *xTaskCreateStatic(void (*function)(void *),const char *name,uint32_t stack,void *argument,uint32_t priority,StackType_t *memory,StaticTask_t *control);
Std_ReturnType Uart_SyncSend(uint8_t channel,const uint8_t *bytes,uint32_t size,uint32_t timeout);
#endif
