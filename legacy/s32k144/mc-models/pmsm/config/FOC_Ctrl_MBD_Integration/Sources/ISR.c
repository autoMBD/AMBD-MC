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
// File:        ISR.c
// Author:      autoMBD <tkung.lqk@foxmail.com>
// Date:        2026-01-27
// Version:     0.1.0
// Description: Interrupt Service Routines for the Motor Control System
// =================================================================================

#include "Cpu.h"
#include "FOC_Ctrl_CodeModel.h"              /* Model's header file */
#include "freemaster.h"

#define FULL_DUTY 2800U
const uint8_t pwmChannels[3] = {0, 2, 4};
uint16_t pwmDuty[3] = {0, 0, 0};

uint16_t adcResult[2][4];
bool motorSwitch = false;
bool faultSwitch = false;

void rt_OneStep(void);
void rt_OneStep(void)
{
  static boolean_T OverrunFlag = false;

  /* Check for overrun */
  if (OverrunFlag) {
    rtmSetErrorStatus(FOC_Ctrl_CodeModel_M, "Overrun");
    return;
  }

  OverrunFlag = true;

  /* Step the model */
  FOC_Ctrl_CodeModel_step();

  /* Indicate task complete */
  OverrunFlag = false;
}

void Motor_ISR (void)
{
    /* Read ADC*/
    ADC_DRV_GetChanResult(INST_ADCONV1, 0, &adcResult[0][0]); /* V_REFSH */
    ADC_DRV_GetChanResult(INST_ADCONV1, 1, &adcResult[0][1]); /* Pot     */
    ADC_DRV_GetChanResult(INST_ADCONV1, 2, &adcResult[0][2]); /* iA      */
    ADC_DRV_GetChanResult(INST_ADCONV1, 3, &adcResult[0][3]); /* Temp    */
    ADC_DRV_GetChanResult(INST_ADCONV2, 0, &adcResult[1][0]); /* V_REFSL */
    ADC_DRV_GetChanResult(INST_ADCONV2, 1, &adcResult[1][1]); /* uDC     */
    ADC_DRV_GetChanResult(INST_ADCONV2, 2, &adcResult[1][2]); /* iB      */
    ADC_DRV_GetChanResult(INST_ADCONV2, 3, &adcResult[1][3]); /* iDC     */

    /* Set model inputs here */
    FOC_Ctrl_CodeModel_U.ADCinput[0] = adcResult[0][2];
    FOC_Ctrl_CodeModel_U.ADCinput[1] = adcResult[1][2];
    FOC_Ctrl_CodeModel_U.ADCinput[2] = adcResult[1][3];
    FOC_Ctrl_CodeModel_U.ADCinput[3] = adcResult[1][1];
    FOC_Ctrl_CodeModel_U.ADCinput[4] = adcResult[0][1];
    FOC_Ctrl_CodeModel_U.FaultSwitch = faultSwitch;
    FOC_Ctrl_CodeModel_U.MotorSwitch = motorSwitch;
    /* Calculate one-step for the modle */
    rt_OneStep();
    /* Get model output here */
    pwmDuty[0] = (uint16_t)(FULL_DUTY * FOC_Ctrl_CodeModel_Y.DUTY[0]);
    pwmDuty[1] = (uint16_t)(FULL_DUTY * FOC_Ctrl_CodeModel_Y.DUTY[1]);
    pwmDuty[2] = (uint16_t)(FULL_DUTY * FOC_Ctrl_CodeModel_Y.DUTY[2]);

    /* Set PWM duty */
    FTM_DRV_FastUpdatePwmChannels(INST_FLEXTIMER_PWM1, 3, pwmChannels, pwmDuty, true);

    /* Clear FTM flag */
    FTM_DRV_ClearStatusFlags(3, FTM_TIME_OVER_FLOW_FLAG|FTM_RELOAD_FLAG);
}

void Button_ISR (void)
{
    uint16_t pinFlag;
    pinFlag = PINS_DRV_GetPortIntFlag(PORTC);
    if ((pinFlag & (1 << 12)) >> 12)
    {
        PINS_DRV_ClearPinIntFlagCmd(PORTC, 12);
        motorSwitch = motorSwitch ? false : true;
    }
    else if ((pinFlag & (1 << 13)) >> 13)
    {
        PINS_DRV_ClearPinIntFlagCmd(PORTC, 13);
        faultSwitch = faultSwitch ? false : true;
    }
    else
    {
        PINS_DRV_ClearPortIntFlagCmd(PORTC);
    }
}

void LPIT_ISR(void)
{
    /* Clear LPIT channel flag */
    LPIT_DRV_ClearInterruptFlagTimerChannels(INST_LPIT1, (1 << 0));
    /* Toggle LED0 */
    PINS_DRV_WritePins(PTD, (FOC_Ctrl_CodeModel_Y.LED[0] << 15)
                          | (FOC_Ctrl_CodeModel_Y.LED[1] << 16)
                          | (FOC_Ctrl_CodeModel_Y.LED[2] << 0));

    /* Send the message */
    LPUART_DRV_SendDataBlocking(INST_LPUART1, (uint8_t *)"Hello World\n", 12, 100);
}

void PDB0_ISR (void)
{
    PDB_DRV_ClearTimerIntFlag(INST_PDB1);
    PDB_DRV_ClearAdcPreTriggerSeqErrFlags(INST_PDB1, 0, (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3));
}

void PDB1_ISR (void)
{
    PDB_DRV_ClearTimerIntFlag(INST_PDB2);
    PDB_DRV_ClearAdcPreTriggerSeqErrFlags(INST_PDB2, 0, (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3));
}

/*******************************************************************************
*    Callback Functions
*******************************************************************************/
void TPP_InitializeOutputs(void)
{
    /* Do nothing */
}
