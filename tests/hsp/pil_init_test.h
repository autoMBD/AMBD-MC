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
// File:        pil_init_test.h
// Author:      autoMBD <tkung.lqk@foxmail.com>
// Date:        2026-10-13
// Version:     0.1.0
// Description: Provide deterministic RTD peers for host tests of the actual board state machine.
// =================================================================================

#ifndef AMBD_PIL_INIT_TEST_H
#define AMBD_PIL_INIT_TEST_H
#include <stdint.h>
#include <stddef.h>
typedef uint64_t uint64;
#define STD_OFF 0
#define MCU_NO_PLL 0
#define MCU_PLL_LOCKED 1
#define E_OK 0
#define CORE_CLK 0
#define NULL_PTR NULL
#define McuConf_McuClockSettingConfig_McuClockSettingConfig_0 0
#define McuConf_McuModeSettingConf_McuModeSettingConf_0 0
extern const int Mcu_Config,Uart_xConfig;
#define NUM_OF_CONFIGURED_PINS 26
#define SIUL2_PORT_SUCCESS 0
#define PORT_CI_PORT_SUCCESS 0
#define MC_ME_PRTN0_COFB1_STAT_BLOCK38_MASK 1U
#define PCC_PCCn_CGC_MASK 1U
#define PCC_FTM3_INDEX 0
#define PCC_LPIT_INDEX 1
#define LPIT_MCR_M_CEN_MASK 1U
#define PIT0_CLK 0
#define IP_PORTA ((void*)1)
#define IP_PORTC ((void*)3)
#define AMBD_DISABLE_IRQ() do {} while(0)
#define IP_SIUL2 ((void*)4)
#define IP_PTA ((void*)5)
#if defined(AMBD_TARGET_S32K344)
#define PORT_MUX_AS_GPIO 0U
#else
#define PORT_MUX_AS_GPIO 1U
#endif
#define PORT_OUTPUT_BUFFER_ENABLED 1U
#define PORT_INPUT_BUFFER_DISABLED 0U
#define PORT_INVERT_DISABLED 0U
#define PORT_CI_PORT_PIN_OUT 1U
typedef struct {void* portBase;uint32_t pinPortIdx;void* base;void* gpioBase;
 uint32_t mux,outputBuffer,inputBuffer,invert,initValue,direction;} TestPin;
extern TestPin g_pin_mux_InitConfigArr[26];
typedef struct {uint32_t TCTRL,TFLG;} TestTimer;
typedef struct {TestTimer TIMER[4];} TestPit;
typedef struct {TestTimer TMR[4];uint32_t MCR,CLRTEN,MIER,MSR;} TestLpit;
typedef struct {uint32_t OUTEN,OUTMASK,PRTN0_COFB1_STAT,PCCn[2];} TestRegisters;
extern TestPit test_pit;
extern TestLpit test_lpit;
extern TestRegisters test_regs;
#define IP_LCU_0 (&test_regs)
#define IP_MC_ME (&test_regs)
#define IP_FTM3 (&test_regs)
#define IP_PCC (&test_regs)
#define IP_PIT_0 (&test_pit)
#define IP_LPIT0 (&test_lpit)
enum {ADC0_IRQn,ADC1_IRQn,BCTU_IRQn,SIUL_0_IRQn,PIT0_IRQn,PIT1_IRQn,LPSPI1_IRQn,EMIOS2_3_IRQn,EMIOS2_5_IRQn,LPIT0_Ch0_IRQn,LPIT0_Ch1_IRQn,PORTE_IRQn};
extern uint32_t Hsp_CoreClockHz;
void Hsp_Fail(uint32_t code);
void Mcu_Init(const void* config);
int Mcu_InitClock(int setting);
int Mcu_GetPllStatus(void);
int Mcu_DistributePllClock(void);
void Mcu_SetMode(int mode);
uint64 Mcu_GetClockFrequency(int clock);
uint32_t Hsp_InitializeCycleCounter(void);
void OsIf_Timer_Custom_SetTimerFrequency(uint32_t frequency);
int Siul2_Port_Ip_Init(uint32_t count,const TestPin* pins);
int Port_Ci_Port_Ip_Init(uint32_t count,const TestPin* pins);
void Platform_Init(const void* config);
void IntCtrl_Ip_DisableIrq(int irq);
void IntCtrl_Ip_ClearPending(int irq);
void Clock_Ip_EnableModuleClock(int clock);
void Uart_Init(const void* config);
#endif
