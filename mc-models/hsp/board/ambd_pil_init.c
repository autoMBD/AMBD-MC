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
// File:        ambd_pil_init.c
// Author:      TkungL <tkung.lqk@foxmail.com>
// Date:        2026-10-13
// Version:     0.1.0
// Description: Initialize motor-kit PIL without application I/O or scheduling.
// =================================================================================

// Adapted from autoMBD HSP examples/s32k{1,3}/xil/hsp_replay_pil_init.c.
// https://github.com/autoMBD/autombd-hsp (Apache-2.0)
#if (defined(AMBD_TARGET_S32K344) + defined(AMBD_TARGET_S32K144)) != 1
#error "Select exactly one AMBD PIL target"
#endif
#ifdef AMBD_PIL_INIT_TEST
#include "pil_init_test.h"
#else
#include "hsp_runtime.h"
#include "hsp_target_config.h"
#include "Mcu.h"
#include "Platform.h"
#include "CDD_Uart.h"
#include "IntCtrl_Ip.h"
#include "OsIf_Timer_Custom.h"
#define AMBD_DISABLE_IRQ() __asm volatile ("cpsid i" ::: "memory")
#if defined(AMBD_TARGET_S32K344)
#include "Clock_Ip.h"
#include "Siul2_Port_Ip.h"
#include "Siul2_Port_Ip_PBcfg.h"
#include "S32K344_MC_ME.h"
#include "S32K344_LCU.h"
#include "S32K344_PIT.h"
#elif defined(AMBD_TARGET_S32K144)
#include "Port_Ci_Port_Ip.h"
#include "Port_Ci_Port_Ip_PBcfg.h"
#include "S32K144_PCC.h"
#include "S32K144_FTM.h"
#include "S32K144_LPIT.h"
#else
#error "Select exactly one supported AMBD PIL target"
#endif
#endif

/* The caller enters this routine during startup, before scheduling or XIL.
 * No application initializer, capture callback or output writer is invoked. */
void Ambd_PilTargetInit(void)
{
    uint32_t attempts=0U;
    uint64 frequency;
    AMBD_DISABLE_IRQ();
#if defined(AMBD_TARGET_S32K344)
    if ((IP_MC_ME->PRTN0_COFB1_STAT&MC_ME_PRTN0_COFB1_STAT_BLOCK38_MASK)!=0U) {
        IP_LCU_0->OUTEN=0U;
    }
#else
    if ((IP_PCC->PCCn[PCC_FTM3_INDEX]&PCC_PCCn_CGC_MASK)!=0U) {
        IP_FTM3->OUTMASK=0xFFU;
    }
#endif
    Mcu_Init(&Mcu_Config);
    if (Mcu_InitClock(McuConf_McuClockSettingConfig_McuClockSettingConfig_0)!=E_OK) { Hsp_Fail(74U); }
#if (MCU_NO_PLL == STD_OFF)
    while (Mcu_GetPllStatus()!=MCU_PLL_LOCKED) {
        if (++attempts>=1000000U) { Hsp_Fail(74U); }
    }
    if (Mcu_DistributePllClock()!=E_OK) { Hsp_Fail(74U); }
#else
    (void)attempts;
#endif
    Mcu_SetMode(McuConf_McuModeSettingConf_McuModeSettingConf_0);
    frequency=Mcu_GetClockFrequency(CORE_CLK);
    if (frequency==0U || frequency>UINT32_MAX) { Hsp_Fail(74U); }
    Hsp_CoreClockHz=(uint32_t)frequency;
    if (Hsp_InitializeCycleCounter()==0U) { Hsp_Fail(74U); }
    OsIf_Timer_Custom_SetTimerFrequency(Hsp_CoreClockHz);
#if defined(AMBD_TARGET_S32K344)
    /* Pinned EB inventory: UART at 1/2; GD reset/enable at 3/4, both low.
     * Configure neither PWM nor ADC nor fault pins. */
    if (NUM_OF_CONFIGURED_PINS<5U || g_pin_mux_InitConfigArr[1].pinPortIdx!=15U ||
        g_pin_mux_InitConfigArr[2].pinPortIdx!=16U || g_pin_mux_InitConfigArr[3].pinPortIdx!=45U ||
        g_pin_mux_InitConfigArr[4].pinPortIdx!=44U) { Hsp_Fail(74U); }
    for (uint32_t i=3U;i<5U;++i) {
        if (g_pin_mux_InitConfigArr[i].base!=IP_SIUL2 ||
            g_pin_mux_InitConfigArr[i].mux!=PORT_MUX_AS_GPIO ||
            g_pin_mux_InitConfigArr[i].outputBuffer!=PORT_OUTPUT_BUFFER_ENABLED ||
            g_pin_mux_InitConfigArr[i].inputBuffer!=PORT_INPUT_BUFFER_DISABLED ||
            g_pin_mux_InitConfigArr[i].invert!=PORT_INVERT_DISABLED ||
            g_pin_mux_InitConfigArr[i].initValue!=0U) { Hsp_Fail(74U); }
    }
    if (Siul2_Port_Ip_Init(2U,&g_pin_mux_InitConfigArr[3])!=SIUL2_PORT_SUCCESS ||
        Siul2_Port_Ip_Init(2U,&g_pin_mux_InitConfigArr[1])!=SIUL2_PORT_SUCCESS) { Hsp_Fail(74U); }
#else
    if (NUM_OF_CONFIGURED_PINS<13U || g_pin_mux_InitConfigArr[1].portBase!=IP_PORTC ||
        g_pin_mux_InitConfigArr[2].portBase!=IP_PORTC || g_pin_mux_InitConfigArr[1].pinPortIdx!=6U ||
        g_pin_mux_InitConfigArr[2].pinPortIdx!=7U || g_pin_mux_InitConfigArr[11].portBase!=IP_PORTA ||
        g_pin_mux_InitConfigArr[12].portBase!=IP_PORTA || g_pin_mux_InitConfigArr[11].pinPortIdx!=2U ||
        g_pin_mux_InitConfigArr[12].pinPortIdx!=3U) { Hsp_Fail(74U); }
    for (uint32_t i=11U;i<13U;++i) {
        if (g_pin_mux_InitConfigArr[i].gpioBase!=IP_PTA ||
            g_pin_mux_InitConfigArr[i].mux!=PORT_MUX_AS_GPIO ||
            g_pin_mux_InitConfigArr[i].direction!=PORT_CI_PORT_PIN_OUT ||
            g_pin_mux_InitConfigArr[i].initValue!=0U) { Hsp_Fail(74U); }
    }
    if (Port_Ci_Port_Ip_Init(2U,&g_pin_mux_InitConfigArr[11])!=PORT_CI_PORT_SUCCESS ||
        Port_Ci_Port_Ip_Init(2U,&g_pin_mux_InitConfigArr[1])!=PORT_CI_PORT_SUCCESS) { Hsp_Fail(74U); }
#endif
    Platform_Init(NULL_PTR);
#if defined(AMBD_TARGET_S32K344)
    const int interrupts[]={ADC0_IRQn,BCTU_IRQn,SIUL_0_IRQn,PIT0_IRQn,PIT1_IRQn,
        LPSPI1_IRQn,EMIOS2_3_IRQn,EMIOS2_5_IRQn};
#else
    const int interrupts[]={ADC0_IRQn,ADC1_IRQn,LPIT0_Ch0_IRQn,LPIT0_Ch1_IRQn,PORTE_IRQn};
#endif
    for (uint32_t i=0U;i<sizeof(interrupts)/sizeof(interrupts[0]);++i) {
        IntCtrl_Ip_DisableIrq(interrupts[i]);
        IntCtrl_Ip_ClearPending(interrupts[i]);
    }
#if defined(AMBD_TARGET_S32K344)
    Clock_Ip_EnableModuleClock(PIT0_CLK);
    for (uint32_t i=0U;i<4U;++i) {
        IP_PIT_0->TIMER[i].TCTRL=0U;IP_PIT_0->TIMER[i].TFLG=1U;
    }
#else
    if ((IP_PCC->PCCn[PCC_LPIT_INDEX]&PCC_PCCn_CGC_MASK)==0U) { Hsp_Fail(74U); }
    IP_LPIT0->MCR|=LPIT_MCR_M_CEN_MASK;
    IP_LPIT0->CLRTEN=0xFU;IP_LPIT0->MIER=0U;IP_LPIT0->MSR=0xFU;
    for (uint32_t i=0U;i<4U;++i) { IP_LPIT0->TMR[i].TCTRL=0U; }
#endif
    Uart_Init(&Uart_xConfig);
}
