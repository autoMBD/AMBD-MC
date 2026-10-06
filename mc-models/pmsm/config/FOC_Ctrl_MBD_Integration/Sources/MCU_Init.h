/* ************************************************************************
 *  autoMBD: Motor Control <https://github.com/autoMBD/AMBD-MC>
 *  File: MCU_Init.h
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

#ifndef MCU_INIT_H_
#define MCU_INIT_H_

#include "Cpu.h"

extern void LPIT_ISR(void);
extern void Motor_ISR (void);
extern void PDB0_ISR (void);
extern void PDB1_ISR (void);
extern void Button_ISR (void);

status_t MCU_Init (void);
status_t MCU_Start (void);

#endif /* MCU_INIT_H_ */
