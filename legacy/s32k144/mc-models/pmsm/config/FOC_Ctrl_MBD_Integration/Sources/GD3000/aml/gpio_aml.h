/*
 * Copyright (c) 2013 - 2017, NXP Semiconductors, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * o Redistributions of source code must retain the above copyright notice, this list
 *   of conditions and the following disclaimer.
 *
 * o Redistributions in binary form must reproduce the above copyright notice, this
 *   list of conditions and the following disclaimer in the documentation and/or
 *   other materials provided with the distribution.
 *
 * o Neither the name of NXP Semiconductors, Inc. nor the names of its
 *   contributors may be used to endorse or promote products derived from this
 *   software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*!
 * @file gpio_aml.h
 *
 * This driver creates abstraction for GPIO for KSDK 2.0 and S32 SDK.
 */

#ifndef SOURCE_MIDDLEWARE_GPIO_H_
#define SOURCE_MIDDLEWARE_GPIO_H_

/*******************************************************************************
 * Includes
 ******************************************************************************/
#include "common_aml.h"

#if (SDK_VERSION == SDK_S32)
#include "Cpu.h"
#include "pin_mux.h"
#include "device_registers.h"
#elif (SDK_VERSION == SDK_2_0)
#include "fsl_common.h"
#include "fsl_gpio.h"
#endif

/*******************************************************************************
 * Definitions
 ******************************************************************************/
/*!
 * @addtogroup enum_group
 * @{
 */
 /*! @brief Instance of GPIO peripheral (GPIO A = instanceA). */ 
typedef enum 
{
    instanceA = 0U,                 /*!< GPIO A. */
    instanceB,                      /*!< GPIO B. */
    instanceC,                      /*!< GPIO C. */
    instanceD,                      /*!< GPIO D. */
    instanceE,                      /*!< GPIO E. */
    instanceF,                      /*!< GPIO F. */
    instanceG,                      /*!< GPIO G. */
    instanceH,                      /*!< GPIO H. */
    instanceI                       /*!< GPIO I. */
} gpio_aml_instance_t;

/*! @brief GPIO peripheral direction. */
typedef enum 
{
    gpioDirDigitalInput = 0U,  /*!< Set current pin as digital input. */
    gpioDirDigitalOutput = 1U  /*!< Set current pin as digital output. */
} gpio_aml_pin_direction_t;
 /*! @} */

/*******************************************************************************
 * Variables
 ******************************************************************************/
/*! @brief Pointers to GPIO bases for each instance. */
static GPIO_Type *const g_gpioBases[] = GPIO_BASE_PTRS;
/*! @brief Pointers to port bases for each instance. */
static PORT_Type *const g_portBases[] = PORT_BASE_PTRS;

/*******************************************************************************
 * API
 ******************************************************************************/
/*!
 * @addtogroup function_group
 * @{
 */  
#if (SDK_VERSION == SDK_S32)
/*!
 * @brief   Installs user defined interrupt handler.
 *
 * @param   irq         Interrupt request number.
 * @param   irqHandler  Pointer to user defined  interrupt handler.
 */
static inline void AML_GPIO_InstallHandler(IRQn_Type irq, void (*irqHandler)(void))
{
    INT_SYS_EnableIRQ(irq);
    INT_SYS_InstallHandler(irq, irqHandler, NULL);
}
#elif (SDK_VERSION == SDK_2_0)
/*!
 * @brief   Installs user defined interrupt handler.
 *
 * @param   irq         Interrupt request number.
 * @param   irqHandler  Address of user defined interrupt handler.
 */
void AML_GPIO_InstallHandler(IRQn_Type irq, uint32_t irqHandler)
{
    EnableIRQ(irq);
    InstallIRQHandler(irq, irqHandler);
}
#endif

/*!
 * @brief   Sets output pin to '1' or '0'.
 *
 * @param   instance    Instance of GPIO peripheral, e.g. 0 for GPIOA, 1 for GPIOB, ....
 *                      Options are available in enumeration gpio_aml_instance_t.
 * @param   pinIndex    Number of GPIO pin to be set.
 * @param   outputValue Value to be written to GPIO output pin, '1' or '0'.
 */
static inline void GPIO_AML_WriteOutput(aml_instance_t instance, uint8_t pinIndex, uint8_t outputValue)
{
    (outputValue == 0U) ? (g_gpioBases[instance]->PCOR = 1U << pinIndex) : 
            (g_gpioBases[instance]->PSOR = 1U << pinIndex);
}

/*!
 * @brief   Sets output pin to '1'.
 *
 * @param   instance    Instance of GPIO peripheral, e.g. 0 for GPIOA, 1 for GPIOB, ....
 *                      Options are available in enumeration gpio_aml_instance_t.
 * @param   pinIndex    Number of GPIO pin to be set.
 */
static inline void GPIO_AML_SetOutput(aml_instance_t instance, uint8_t pinIndex)
{
    g_gpioBases[instance]->PSOR = (uint32_t)(1U << pinIndex);
}

/*!
 * @brief   Clears output pin. Sets it to '0'.
 *
 * @param   instance    Instance of GPIO peripheral, e.g. 0 for GPIOA, 1 for GPIOB, ....
 *                      Options are available in enumeration gpio_aml_instance_t.
 * @param   pinIndex    Number of GPIO pin to be cleared.
 */
static inline void GPIO_AML_ClearOutput(aml_instance_t instance, uint8_t pinIndex)
{
    g_gpioBases[instance]->PCOR = (uint32_t)(1U << pinIndex);
}

/*!
 * @brief   Toggles output pin.
 *
 * @param   instance    Instance of GPIO peripheral, e.g. 0 for GPIOA, 1 for GPIOB, ....
 *                      Options are available in enumeration gpio_aml_instance_t.
 * @param   pinIndex    Number of GPIO pin to be toggled.
 */
static inline void GPIO_AML_ToggleOutput(aml_instance_t instance, uint8_t pinIndex)
{
    g_gpioBases[instance]->PTOR = (uint32_t)(1U << pinIndex);
}

/*!
 * @brief   Returns value of input pin.
 *
 * @param   instance    Instance of GPIO peripheral, e.g. 0 for GPIOA, 1 for GPIOB, ....
 *                      Options are available in enumeration gpio_aml_instance_t.
 * @param   pinIndex    Number of GPIO pin to be read.
 *
 * @return  Value of input pin (0 - low, 1 - high).
 */
static inline uint32_t GPIO_AML_ReadInput(aml_instance_t instance, uint8_t pinIndex)
{
    return (((g_gpioBases[instance]->PDIR) >> pinIndex) & 1U);
}

/*!
 * @brief   Returns interrupt flags of whole port, e.g. PORTA. Returned value
 *          needs to be masked in order to find out the interrupt source.
 *          If configured for a level sensitive interrupt that remains asserted,
 *          the flag is set again immediately.
 *
 * @param   instance    Instance of PORT, e.g. 0 for PORTA, 1 for PORTB, ....
 *                      Options are available in enumeration gpio_aml_instance_t.
 *
 * @return  Interrupt flags of desired port.
 */
static inline uint32_t GPIO_AML_GetInterruptFlags(aml_instance_t instance)
{
    return g_portBases[instance]->ISFR;
}

/*!
 * @brief   Clears interrupt.
 *
 * @param   instance    Instance of PORT, e.g. 0 for PORTA, 1 for PORTB, ....
 *                      Options are available in enumeration gpio_aml_instance_t.
 * @param   pinIndex    Number of GPIO input pin which asserted interrupt.
 */
static inline void GPIO_AML_ClearInterruptFlags(aml_instance_t instance, uint8_t pinIndex)
{
    g_portBases[instance]->ISFR = (uint32_t)(1U << pinIndex);
}

/*!
 * @brief   Changes pin direction.
 *
 * @param   instance    Instance of PORT, e.g. 0 for PORTA, 1 for PORTB,... 
 *                      Options are available in enumeration gpio_aml_instance_t.
 * @param   pinIndex    Pin index in context of selected port.
 * @param   pinDir      Pin direction.
 */
static inline void GPIO_AML_SetDirection(aml_instance_t instance, uint8_t pinIndex, 
        gpio_aml_pin_direction_t pinDir)
{
#if (SDK_VERSION == SDK_2_0)
    gpio_pin_config_t gpioPinConfig = {
            ((pinDir == gpioDirDigitalInput) ? kGPIO_DigitalInput : kGPIO_DigitalOutput), 
            0U
    };
        
    GPIO_PinInit(g_gpioBases[instance], pinIndex, &gpioPinConfig);
#elif (SDK_VERSION == SDK_S32)
    uint32_t direction = PINS_DRV_GetPinsDirection(g_gpioBases[instance]);

    direction &= ~(1U << pinIndex);
    direction |= (pinDir == gpioDirDigitalInput) ? (0U << pinIndex) : (1U << pinIndex);
    PINS_DRV_SetPinsDirection(g_gpioBases[instance], direction);
#endif
}
/*! @} */

#endif /* SOURCE_MIDDLEWARE_GPIO_H_ */

 /*******************************************************************************
 * EOF
 ******************************************************************************/
