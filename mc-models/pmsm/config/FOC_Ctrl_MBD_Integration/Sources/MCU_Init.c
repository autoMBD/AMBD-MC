/* ************************************************************************
 *  autoMBD: Motor Control <https://github.com/autoMBD/AMBD-MC>
 *  File: MCU_Init.c
 *  Author: autoMBD
 *  Date: 2026-01-27
 *  Version: 0.1.0
 *  Description: MCU Initialization for the Motor Control System
 *//* *********************************************************************
 * The MIT License 
 * MIT许可证
 * <https://opensource.org/license/mit>
 * 
 * SPDX short identifier / SPDX 短标识符：MIT 
 * 
 * Copyright (c) 2026 autoMBD
 * 版权所有 (c) 2026 autoMBD
 * 
 * Permission is hereby granted, free of charge, to any person obtaining 
 * a copy of this software and associated documentation files (the 
 * "Software"), to deal in the Software without restriction, including 
 * without limitation the rights to use, copy, modify, merge, publish, 
 * distribute, sublicense, and/or sell copies of the Software, and to 
 * permit persons to whom the Software is furnished to do so, subject to 
 * the following conditions:
 * 特此向获得本软件及相关文档（合称"本软件"）副本的任何人免费授予不受限制地利用
 * 本软件的许可，包括而不限于：使用、复制、修改、合并、发布、分发、分许可和/或销售
 * 本软件副本，并允许本软件的接收者也获得前述许可，但须遵守以下条件：
 * 
 * The above copyright notice and this permission notice shall be included 
 * in all copies or substantial portions of the Software.
 * 以上版权声明及本许可声明应包含在本软件的所有副本或主要部分中。
 * 
 * THE SOFTWAREISPROVIDED"ASIS",WITHOUT WARRANTYOFANYKIND, EXPRESS OR 
 * IMPLIED, INCLUDING BUT NOT LIMITEDTO THEWARRANTIESOF MERCHANTABILITY, 
 * FITNESS FOR APARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO 
 * EVENTSHALLTHEAUTHORSORCOPYRIGHT HOLDERSBELIABLE FORANYCLAIM, 
 * DAMAGESOROTHERLIABILITY,WHETHER IN ANACTIONOFCONTRACT,TORTOROTHERWISE,
 * ARISINGFROM,OUTOFORIN CONNECTIONWITHTHESOFTWAREORTHEUSEOROTHERDEALINGSINTHE 
 * SOFTWARE.
 * 本软件系"按原样"提供，不包含任何形式的明示或默示保证，包括但不限于适销性、
 * 特定目的适用性及不侵权的保证。在任何情况下，无论是在合同、侵权或其他案件中，
 * 作者或版权持有人均不对因本软件、或因本软件的使用或其他利用而引起的、引发的或与
 * 之相关的任何权利主张、损害赔偿或其他责任承担责任。
 ****************************************************************************/

#include "MCU_Init.h"

static status_t  MCU_Clock_Init (void)
{
    /* Initialize and configure clocks */
    CLOCK_SYS_Init(g_clockManConfigsArr, CLOCK_MANAGER_CONFIG_CNT,
                          g_clockManCallbacksArr, CLOCK_MANAGER_CALLBACK_CNT);
    CLOCK_SYS_UpdateConfiguration(0U, CLOCK_MANAGER_POLICY_AGREEMENT);

    /* Enable Cache !
     * Flush and enable I cache and write buffer */
    LMEM->PCCCR = LMEM_PCCCR_ENCACHE_MASK | LMEM_PCCCR_INVW1_MASK
                | LMEM_PCCCR_INVW0_MASK   | LMEM_PCCCR_GO_MASK;

    return STATUS_SUCCESS;
}

static status_t MCU_Pwr_Init (void)
{
    /* Initialize PWR */
    POWER_SYS_Init(&powerConfigsArr, POWER_MANAGER_CONFIG_CNT,
            &powerStaticCallbacksConfigsArr, POWER_MANAGER_CALLBACK_CNT);
    /* Entry HSRUN mode*/
    POWER_SYS_SetMode(1, POWER_MANAGER_POLICY_AGREEMENT);

    return STATUS_SUCCESS;
}

static status_t MCU_Pit_Init (void)
{
    /* Initialize LPIT */
    LPIT_DRV_Init(INST_LPIT1, &lpit1_InitConfig);
    LPIT_DRV_InitChannel(INST_LPIT1, 0, &lpit1_ChnConfig0);

    return STATUS_SUCCESS;
}

static status_t MCU_Uart_Init (void)
{
    /* Initialize LPUART */
    LPUART_DRV_Init(INST_LPUART1, &lpuart1_State, &lpuart1_InitConfig0);

    return STATUS_SUCCESS;
}

static status_t MCU_Adc_Init (void)
{
    /* Enable interleaved mode for ADC0_SE5 and ADC1_SE15 channels on PTB1 pin */
    //SIM_HAL_SetAdcInterleaveSel(SIM, 0b0010);
//    SIM->CHIPCTL |= SIM_CHIPCTL_ADC_INTERLEAVE_EN(0x2);

    /* ADC0 module initialization */
    ADC_DRV_ConfigConverter(INST_ADCONV1, &adConv1_ConvConfig0);
    /* ADC1 module initialization */
    ADC_DRV_ConfigConverter(INST_ADCONV2, &adConv2_ConvConfig0);

    /* ADC0 Channels */
    ADC_DRV_ConfigChan(INST_ADCONV1, 0, &adConv1_ChnConfig0);
    ADC_DRV_ConfigChan(INST_ADCONV1, 1, &adConv1_ChnConfig1);
    ADC_DRV_ConfigChan(INST_ADCONV1, 2, &adConv1_ChnConfig2);
    ADC_DRV_ConfigChan(INST_ADCONV1, 3, &adConv1_ChnConfig3);
    /* ADC1 Channels */
    ADC_DRV_ConfigChan(INST_ADCONV2, 0, &adConv2_ChnConfig0);
    ADC_DRV_ConfigChan(INST_ADCONV2, 1, &adConv2_ChnConfig1);
    ADC_DRV_ConfigChan(INST_ADCONV2, 2, &adConv2_ChnConfig2);
    ADC_DRV_ConfigChan(INST_ADCONV2, 3, &adConv2_ChnConfig3);

    return STATUS_SUCCESS;
}

static status_t MCU_Pdb_Init (void)
{
    /* PDB0 module initialization */
    PDB_DRV_Init(INST_PDB1, &pdb1_InitConfig0);
    /* PDB1 module initialization */
    PDB_DRV_Init(INST_PDB2, &pdb2_InitConfig0);

    /* PDB0 pre-trigger initialization */
    PDB_DRV_ConfigAdcPreTrigger(INST_PDB1, 0, &pdb1_AdcTrigInitConfig0);
    PDB_DRV_ConfigAdcPreTrigger(INST_PDB1, 0, &pdb1_AdcTrigInitConfig1);
    PDB_DRV_ConfigAdcPreTrigger(INST_PDB1, 0, &pdb1_AdcTrigInitConfig2);
    PDB_DRV_ConfigAdcPreTrigger(INST_PDB1, 0, &pdb1_AdcTrigInitConfig3);
    /* PDB1 pre-trigger initialization */
    PDB_DRV_ConfigAdcPreTrigger(INST_PDB2, 0, &pdb2_AdcTrigInitConfig0);
    PDB_DRV_ConfigAdcPreTrigger(INST_PDB2, 0, &pdb2_AdcTrigInitConfig1);
    PDB_DRV_ConfigAdcPreTrigger(INST_PDB2, 0, &pdb2_AdcTrigInitConfig2);
    PDB_DRV_ConfigAdcPreTrigger(INST_PDB2, 0, &pdb2_AdcTrigInitConfig3);

    /* Set PDB0 modulus value */
    PDB_DRV_SetTimerModulusValue(INST_PDB1, 6900);
    /* Set PDB1 modulus value */
    PDB_DRV_SetTimerModulusValue(INST_PDB2, 6900);

    /* PDB0 pre-trigger delay set */
    PDB_DRV_SetAdcPreTriggerDelayValue(INST_PDB1, 0, 0, 0);
    PDB_DRV_SetAdcPreTriggerDelayValue(INST_PDB1, 0, 1, 1000);
    PDB_DRV_SetAdcPreTriggerDelayValue(INST_PDB1, 0, 2, 3500);
    PDB_DRV_SetAdcPreTriggerDelayValue(INST_PDB1, 0, 3, 4000);
    /* PDB1 pre-trigger delay set */
    PDB_DRV_SetAdcPreTriggerDelayValue(INST_PDB2, 0, 0, 0);
    PDB_DRV_SetAdcPreTriggerDelayValue(INST_PDB2, 0, 1, 1000);
    PDB_DRV_SetAdcPreTriggerDelayValue(INST_PDB2, 0, 2, 3500);
    PDB_DRV_SetAdcPreTriggerDelayValue(INST_PDB2, 0, 3, 4000);

    /* enable PDB before LDOK */
    PDB_DRV_Enable(INST_PDB1);
    /* enable PDB before LDOK */
    PDB_DRV_Enable(INST_PDB2);

    /* Load PDB0 configuration */
    PDB_DRV_LoadValuesCmd(INST_PDB1);
    /* Load PDB1 configuration */
    PDB_DRV_LoadValuesCmd(INST_PDB2);

    return STATUS_SUCCESS;
}

static status_t MCU_Trgmux_Init (void)
{
    /* Initialize TRGMUX */
    TRGMUX_DRV_Init(INST_TRGMUX1, &trgmux1_InitConfig0);

    return STATUS_SUCCESS;
}

static status_t MCU_Ftm_Init (void)
{
    ftm_state_t ftmState;

    /* Initialize FTM */
    FTM_DRV_Init(INST_FLEXTIMER_PWM1, &flexTimer_pwm1_InitConfig, &ftmState);
    FTM_DRV_InitPwm(INST_FLEXTIMER_PWM1, &flexTimer_pwm1_PwmConfig);

    FTM_DRV_MaskOutputChannels(INST_FLEXTIMER_PWM1, 0x3F, true);

    return STATUS_SUCCESS;
}

static status_t MCU_Pin_Init (void)
{
    /* Initialize pins */
    PINS_DRV_Init(NUM_OF_CONFIGURED_PINS, g_pin_mux_InitConfigArr);

    return STATUS_SUCCESS;
}

static status_t MCU_ISR_Init (void)
{
    /* Initialize ISRs */
    /* FTM ISR. FTM int will be enabled in MCU_Start(). */
    INT_SYS_InstallHandler(FTM3_Ovf_Reload_IRQn, &Motor_ISR, (isr_t *)0);
    INT_SYS_SetPriority(FTM3_Ovf_Reload_IRQn, 0);
    /* PDB ISR. PDB int was enabled in PDB_DRV_Init(). */
    INT_SYS_InstallHandler(PDB0_IRQn, &PDB0_ISR, (isr_t *)0);
    INT_SYS_SetPriority(PDB0_IRQn, 2);
    INT_SYS_InstallHandler(PDB1_IRQn, &PDB1_ISR, (isr_t *)0);
    INT_SYS_SetPriority(PDB1_IRQn, 2);
    /* UART ISR. LPUART int was enabled and installed  in LPUART_DRV_Init(). */
    INT_SYS_SetPriority(LPUART1_RxTx_IRQn, 5);
    /* PIT ISR. LPIT int was enabled in LPIT_DRV_InitChannel(). */
    INT_SYS_InstallHandler(LPIT0_Ch0_IRQn, &LPIT_ISR, (isr_t *)0);
    INT_SYS_SetPriority(LPIT0_Ch0_IRQn, 10);
    /* PORTC_IRQn */
    INT_SYS_InstallHandler(PORTC_IRQn, &Button_ISR, (isr_t *)0);
    INT_SYS_SetPriority(PORTC_IRQn, 15);
    INT_SYS_EnableIRQ(PORTC_IRQn);

    return STATUS_SUCCESS;
}

status_t MCU_Init (void)
{
    MCU_Clock_Init();
    MCU_Pwr_Init();
    MCU_Pit_Init();
    MCU_Uart_Init();
    MCU_Adc_Init();
    MCU_Pdb_Init();
    MCU_Trgmux_Init();
    MCU_Ftm_Init();
    MCU_Pin_Init();
    MCU_ISR_Init();

    return STATUS_SUCCESS;
}

status_t MCU_Start (void)
{

    /* Start LPIT */
    LPIT_DRV_StartTimerChannels(INST_LPIT1, (1 << 0));

    FTM_DRV_MaskOutputChannels(INST_FLEXTIMER_PWM1, 0x00, true);
    FTM_DRV_EnableInterrupts(3, FTM_RELOAD_INT_ENABLE);
    INT_SYS_EnableIRQ(FTM3_Ovf_Reload_IRQn);

    OSIF_TimeDelay(50);

    FTM_RMW_EXTTRIG_REG(FTM3, 0x00, 1 << 6);

    return STATUS_SUCCESS;
}
