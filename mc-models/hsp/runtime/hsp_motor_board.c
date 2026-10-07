// =================================================================================
// Apache License, Version 2.0
// Apache许可证，版本2.0
//
// <https://www.apache.org/licenses/LICENSE-2.0>
//
// SPDX short identifier / SPDX 短标识符：Apache-2.0
//
// Copyright 2026 autoMBD
// 版权所有 2026 autoMBD
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// =================================================================================
// Project:     autoMBD HSP <https://github.com/autoMBD/autombd-hsp>
// File:        hsp_motor_board.c
// Author:      TkungL <tkung.lqk@foxmail.com>
// Date:        2026-09-28
// Version:     0.1.0
// Description: Board-only MCSPTE1AK344 acquisition and bounded start/stop hooks.
// =================================================================================

#include "hsp_motor_board.h"
#include "hsp_runtime.h"
#include "Adc.h"
#include "Bctu_Ip.h"
#include "CDD_Mcl.h"
#include "Dio.h"
#include "Pwm.h"
#include "Mcu.h"
#include "Gpt.h"
#include "Icu.h"

volatile uint16_t Hsp_MotorSamples[4];
volatile uint32_t Hsp_MotorCaptureCount;
volatile uint32_t Hsp_MotorIcuEdges;
volatile uint32_t Hsp_MotorGptTicks;
volatile uint32_t Hsp_MotorCalibrationStatus;
static volatile uint32_t Hsp_MotorInitialized;
/* The official linker places this section in DTCM. Debug reads therefore do
 * not depend on Cortex-M7 D-cache eviction. Magic is published last. */
volatile Hsp_MotorFaultSnapshotType Hsp_MotorFaultSnapshot
    __attribute__((section(".dtcm_bss.hsp_motor_fault"), aligned(8)));

static void Hsp_MotorRecordFault(void)
{
    uint32_t index;
    if (Hsp_MotorFaultSnapshot.magic == 0U)
    {
        Hsp_MotorFaultSnapshot.version = 1U;
        Hsp_MotorFaultSnapshot.faultCode = Hsp_FailureCode;
        Hsp_MotorFaultSnapshot.timestampCycles = Hsp_ReadCycleCounter();
        Hsp_MotorFaultSnapshot.coreClockHz = Hsp_CoreClockHz;
        Hsp_MotorFaultSnapshot.eventCount = Hsp_EventCount;
        Hsp_MotorFaultSnapshot.stepCount = Hsp_ModelStepCount;
        Hsp_MotorFaultSnapshot.captureCount = Hsp_MotorCaptureCount;
        Hsp_MotorFaultSnapshot.unconsumedCaptureHint =
            (Hsp_MotorCaptureCount > Hsp_ModelStepCount) ? 1U : 0U;
        Hsp_MotorFaultSnapshot.eventOverruns = Hsp_EventOverruns;
        Hsp_MotorFaultSnapshot.eventSourceFaults = Hsp_EventSourceFaults;
        Hsp_MotorFaultSnapshot.eventTimeouts = Hsp_EventTimeouts;
        Hsp_MotorFaultSnapshot.eventReady = Hsp_EventReady;
        Hsp_MotorFaultSnapshot.lastEventCycles = Hsp_LastEventCycles;
        Hsp_MotorFaultSnapshot.lastEventIntervalCycles = Hsp_LastEventIntervalCycles;
        Hsp_MotorFaultSnapshot.lastCaptureCycles = Hsp_LastCaptureCycles;
        Hsp_MotorFaultSnapshot.lastStepStartCycles = Hsp_LastStepStartCycles;
        Hsp_MotorFaultSnapshot.lastDispatchLatencyCycles = Hsp_LastDispatchLatencyCycles;
        Hsp_MotorFaultSnapshot.lastStepCycles = Hsp_LastStepCycles;
        Hsp_MotorFaultSnapshot.maxStepCycles = Hsp_MaxStepCycles;
        Hsp_MotorFaultSnapshot.fifoCount = Bctu_Ip_GetFifoCount(0U, 0U);
        Hsp_MotorFaultSnapshot.fifoError = IP_BCTU->FIFOERR;
        Hsp_MotorFaultSnapshot.fifoStatus = IP_BCTU->FIFOSR;
        Hsp_MotorFaultSnapshot.bctuMcr = IP_BCTU->MCR;
        Hsp_MotorFaultSnapshot.bctuTrigger4 = IP_BCTU->TRGCFG[4U];
        Hsp_MotorFaultSnapshot.emiosMcr = IP_EMIOS_0->MCR;
        Hsp_MotorFaultSnapshot.emiosGlobalFlags = IP_EMIOS_0->GFLAG;
        Hsp_MotorFaultSnapshot.emiosTriggerStatus = IP_EMIOS_0->CH.UC[4U].S;
        Hsp_MotorFaultSnapshot.emiosMasterCounter = IP_EMIOS_0->CH.UC[22U].CNT;
        for (index = 0U; index < 4U; index++)
        {
            Hsp_MotorFaultSnapshot.adcSamples[index] = Hsp_MotorSamples[index];
        }
        Hsp_MotorFaultSnapshot.magic = 0x48535046U;
    }
}

void Hsp_MotorIcuEdge(void) { Hsp_MotorIcuEdges++; }
void Hsp_MotorGptTick(void) { Hsp_MotorGptTicks++; }

void Hsp_MotorCapture(void)
{
    Adc_ValueGroupType frame[4];
    uint32_t index;
    /* One list is exactly four words. Reject stale/overflowed frames. */
    if (Bctu_Ip_GetFifoCount(0U, 0U) != 4U)
    {
        Hsp_ReportModelEventFaultFromISR();
        return;
    }
    Adc_CtuReadFifoData(BctuHwUnit_0_BctuResultFifos_0, frame, 4U);
    for (index = 0U; index < 4U; index++) { Hsp_MotorSamples[index] = frame[index]; }
    Hsp_MotorCaptureCount++;
}

void Hsp_MotorStop(void)
{
    if (Hsp_MotorInitialized != 0U)
    {
        Hsp_MotorRecordFault();
        /* Idempotent and bounded; no serial transfer or wait in the fault path. */
        Bctu_Ip_DisableNotifications(0U, BCTU_IP_NOTIF_FIFO1);
        Bctu_Ip_SetGlobalTriggerEn(0U, FALSE);
        Mcl_EmiosConfigureGlobalTimebase(0U, STD_OFF);
        Mcl_EmiosConfigureGlobalTimebase(2U, STD_OFF);
        Gpt_StopTimer(0U);
        Adc_CtuDisableHwTrigger(BctuHwUnit_0_BctuTriggerList);
        Pwm_SetOutputToIdle(PwmConf_PwmChannel_Hsp_PhaseA);
        Pwm_SetOutputToIdle(PwmConf_PwmChannel_Hsp_PhaseB);
        Pwm_SetOutputToIdle(PwmConf_PwmChannel_Hsp_PhaseC);
        Pwm_SetOutputToIdle(PwmConf_PwmChannel_Hsp_AdcTrigger);
        Dio_WriteChannel(DioConf_DioChannel_Hsp_GateEnable, STD_LOW);
        Dio_WriteChannel(DioConf_DioChannel_Hsp_GateReset, STD_LOW);
    }
}

void Hsp_MotorStart(void)
{
    Adc_CalibrationStatusType calibration;
    uint32_t attempt;
    Hsp_MotorInitialized = 1U;
    Dio_WriteChannel(DioConf_DioChannel_Hsp_GateEnable, STD_LOW);
    Dio_WriteChannel(DioConf_DioChannel_Hsp_GateReset, STD_LOW);
    for (attempt = 0U; attempt < 6U; attempt++)
    {
        Adc_Calibrate(AdcHwUnit_0, &calibration);
        if (calibration.AdcUnitSelfTestStatus == E_OK) { break; }
    }
    Hsp_MotorCalibrationStatus = (uint32_t)calibration.AdcUnitSelfTestStatus;
    if (calibration.AdcUnitSelfTestStatus != E_OK) { Hsp_Fail(45U); return; }
    Adc_EnableCtuControlMode(AdcHwUnit_0);
    Adc_CtuEnableHwTrigger(BctuHwUnit_0_BctuTriggerList);
    Bctu_Ip_SetGlobalTriggerEn(0U, TRUE);
    Icu_EnableNotification(0U);
    Icu_EnableEdgeDetection(0U);
    Icu_StartSignalMeasurement(1U);
    Icu_EnableEdgeCount(2U);
    Mcl_EmiosConfigureGlobalTimebase(2U, STD_ON);
    Gpt_EnableNotification(0U);
    Gpt_StartTimer(0U, (Gpt_ValueType)(Mcu_GetClockFrequency(PIT0_CLK) / 1000U));
    Mcl_EmiosConfigureGlobalTimebase(0U, STD_ON);
}
