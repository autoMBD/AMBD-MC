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
// File:        ambd_kit_board.h
// Author:      autoMBD <tkung.lqk@foxmail.com>
// Date:        2026-10-07
// Version:     0.1.0
// Description: Expose kit runtime state and model capture/output hooks.
// =================================================================================

#ifndef AMBD_KIT_BOARD_H
#define AMBD_KIT_BOARD_H
#include "ambd_kit_core.h"

typedef struct {
    uint32_t captures, faults, gd_errors, calibration_samples, late_updates;
    uint32_t commits, max_commit_cycles;
    uint16_t raw[4];
    uint8_t driver_ready, calibrated, sample_valid, hall;
    uint8_t applied_mask, sample_sector, floating_phase, gd_status[4];
    uint8_t model_mode, model_gate, requested_armed;
    uint16_t model_faults;
    int8_t sample_direction;
    float offsets[3], current[3], dc_current, vdc, floating_voltage;
    float voltage_alpha, voltage_beta;
} Ambd_KitStatus;
extern volatile Ambd_KitStatus Ambd_Kit;
extern volatile uint8_t Ambd_KitControl;
extern volatile float Ambd_KitSpeedRequest;
void Ambd_KitStart(void);
void Ambd_KitStop(void);
bool Ambd_KitCapture(void);
void Ambd_KitCaptureModelInputs(void);
void Ambd_KitPrimeModel(void);
void Ambd_KitFaultIrq(void);
void Ambd_KitTick(void);
void Ambd_KitCommit(const uint16_t counts[3], const uint8_t phases[3], uint8_t gate, uint8_t armed, uint8_t sector, int8_t direction);
#endif
