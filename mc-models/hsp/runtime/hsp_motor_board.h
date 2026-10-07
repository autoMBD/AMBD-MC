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
// File:        hsp_motor_board.h
// Author:      TkungL <tkung.lqk@foxmail.com>
// Date:        2026-09-28
// Version:     0.1.0
// Description: Board-only MCSPTE1AK344 acquisition hook declarations.
// =================================================================================

#ifndef HSP_MOTOR_BOARD_H
#define HSP_MOTOR_BOARD_H
#include <stdint.h>
typedef struct
{
    uint32_t magic;
    uint32_t version;
    uint32_t faultCode;
    uint32_t timestampCycles;
    uint32_t coreClockHz;
    uint32_t eventCount;
    uint32_t stepCount;
    uint32_t captureCount;
    uint32_t unconsumedCaptureHint;
    uint32_t eventOverruns;
    uint32_t eventSourceFaults;
    uint32_t eventTimeouts;
    uint32_t eventReady;
    uint32_t lastEventCycles;
    uint32_t lastEventIntervalCycles;
    uint32_t lastCaptureCycles;
    uint32_t lastStepStartCycles;
    uint32_t lastDispatchLatencyCycles;
    uint32_t lastStepCycles;
    uint32_t maxStepCycles;
    uint32_t fifoCount;
    uint32_t fifoError;
    uint32_t fifoStatus;
    uint32_t bctuMcr;
    uint32_t bctuTrigger4;
    uint32_t emiosMcr;
    uint32_t emiosGlobalFlags;
    uint32_t emiosTriggerStatus;
    uint32_t emiosMasterCounter;
    uint32_t adcSamples[4];
} Hsp_MotorFaultSnapshotType;
extern volatile Hsp_MotorFaultSnapshotType Hsp_MotorFaultSnapshot;
extern volatile uint16_t Hsp_MotorSamples[4];
extern volatile uint32_t Hsp_MotorCaptureCount;
extern volatile uint32_t Hsp_MotorIcuEdges;
extern volatile uint32_t Hsp_MotorGptTicks;
extern volatile uint32_t Hsp_MotorCalibrationStatus;
void Hsp_MotorCapture(void);
void Hsp_MotorStart(void);
void Hsp_MotorStop(void);
void Hsp_MotorIcuEdge(void);
void Hsp_MotorGptTick(void);
#endif
