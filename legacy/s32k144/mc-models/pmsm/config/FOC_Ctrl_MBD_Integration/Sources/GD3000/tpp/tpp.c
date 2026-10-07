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
 * @file tpp.c
 *
 * Three Phase FET Pre-driver driver based on AML layer.
 * Supports boards based on HB2000, HB2001 and GD3000.
 *
 * This module is common for all supported models.
 */

/*******************************************************************************
 * Includes
 ******************************************************************************/

#include "tpp.h"

/*******************************************************************************
 * Prototypes of internal functions
 ******************************************************************************/

/*
 * @brief This function toggles CS pin with specified delay (used for deadtime calibration).
 *
 * Minimal delay is one TPP predriver internal time base clock cycle duration (typically
 * 58.82 ns for 17 Mhz) * 16 = 940ns.
 *
 * @param drvConfig Pointer to driver instance configuration.
 * @param delay Delay time in ns.
 *
 * @return status_t Error code.
 */
static void TPP_ToggleCs(tpp_drv_config_t* const drvConfig, uint32_t delay);

/*******************************************************************************
 * Internal function
 ******************************************************************************/

/*FUNCTION**********************************************************************
 *
 * Function Name : TPP_ToggleCs
 * Description   : This function toggles CS pin with specified delay (used for deadtime calibration).
 *
 *END**************************************************************************/
static void TPP_ToggleCs(tpp_drv_config_t* const drvConfig, uint32_t delay)
{
    uint32_t f = WAIT_AML_SYSTEM_CLOCK_FREQ;
    uint32_t cycles;

    cycles = (uint32_t) WAIT_AML_GET_CYCLES_FOR_NS(delay, f); /* The needed cycles count. */

    /* GPIO toggle delay correction (setting and clearing CS pin value functions held CS longer at logic 0). */
    cycles = (cycles >= 56) ? cycles - 56 : 0;

    /* Advance to next multiple of 4. Value 0x04U ensures that the number is not zero. */
    cycles = (cycles & 0xFFFFFFFCU) | 0x04U;

    DISABLE_INTERRUPTS();
    GPIO_AML_ClearOutput(drvConfig->csPinInstance, drvConfig->csPinIndex);
    WAIT_AML_WAIT_FOR_MUL4_CYCLES(cycles);
    GPIO_AML_SetOutput(drvConfig->csPinInstance, drvConfig->csPinIndex);
    ENABLE_INTERRUPTS();
}

/******************************************************************************
 * API
 ******************************************************************************/

/*FUNCTION**********************************************************************
 *
 * Function Name : TPP_ConfigureGpio
 * Description   : This function configures GPIO for usage with this driver.
 *
 *END**************************************************************************/
status_t TPP_ConfigureGpio(tpp_drv_config_t *drvConfig)
{
    AML_ASSERT(drvConfig != NULL);

    /* EN1 pin. */
    GPIO_AML_SetDirection(drvConfig->en1PinInstance, drvConfig->en1PinIndex, gpioDirDigitalOutput);
    /* EN2 pin. */
    GPIO_AML_SetDirection(drvConfig->en2PinInstance, drvConfig->en2PinIndex, gpioDirDigitalOutput);
    /* RST pin. */
    GPIO_AML_SetDirection(drvConfig->rstPinInstance, drvConfig->rstPinIndex, gpioDirDigitalOutput);

    return kStatus_Success;
}

/*FUNCTION**********************************************************************
 *
 * Function Name : TPP_ConfigureSpi
 * Description   : This function configures SPI for usage with this driver.
 *
 *END**************************************************************************/
status_t TPP_ConfigureSpi(tpp_drv_config_t* const drvConfig, spi_sdk_master_config_t* const spiSdkMasterConfig)
{
    spi_sdk_master_config_t tppSpiSdkMasterConfig;
    const spi_sdk_master_config_t *spiMasterConfig;
    spi_aml_master_config_t spiAmlMasterConfig;

    AML_ASSERT(drvConfig != NULL);

    if (spiSdkMasterConfig == NULL)
    {
        if (drvConfig->spiTppConfig.baudRateHz > 4000000)
        {
            return kStatus_TPP_SpiInit;
        }

        spiAmlMasterConfig.baudRateHz = drvConfig->spiTppConfig.baudRateHz;
        spiAmlMasterConfig.bitCount = 8U;
        spiAmlMasterConfig.clkPhase = spiClockPhaseSecondEdge;
        spiAmlMasterConfig.clkPolarity = spiClockPolarityActiveHigh;
        spiAmlMasterConfig.lsbFirst = false;
        spiAmlMasterConfig.pcsPolarity = spiPcsActiveLow;
        spiAmlMasterConfig.sourceClockHz = drvConfig->spiTppConfig.sourceClockHz;

        SPI_AML_MasterFillSdkConfig(&spiAmlMasterConfig, &tppSpiSdkMasterConfig);

        spiMasterConfig = &tppSpiSdkMasterConfig;
    }
    else
    {
        spiMasterConfig = spiSdkMasterConfig;
    }

    SPI_AML_MasterInit(drvConfig->spiInstance, spiMasterConfig, drvConfig->spiTppConfig.sourceClockHz);

    /* PCS pin. */
    GPIO_AML_SetDirection(drvConfig->csPinInstance, drvConfig->csPinIndex, gpioDirDigitalOutput);
    GPIO_AML_SetOutput(drvConfig->csPinInstance, drvConfig->csPinIndex);

    return kStatus_Success;
}

/*FUNCTION**********************************************************************
 *
 * Function Name : TPP_Init
 * Description   : This function initializes the device.
 *
 *END**************************************************************************/
status_t TPP_Init(tpp_drv_config_t* const initConfig, tpp_device_mode_t mode)
{
    status_t error = kStatus_Success;

    AML_ASSERT(initConfig != NULL);
    AML_ASSERT(mode == tppModeEnable || mode == tppModeStandby);

    initConfig->deviceConfig.opMode = tppModeInitialization;
    initConfig->deviceConfig.statusRegister[tppSR0_deviceEvents] = 0x00U;
    initConfig->deviceConfig.statusRegister[tppSR1_generalSettings] = 0x00U;
    initConfig->deviceConfig.statusRegister[tppSR2_interruptSettings] = 0x00U;
    initConfig->deviceConfig.statusRegister[tppSR3_Deadtime] = 0x00U;

    /* Configuration of interrupts and deadtime is required before entering standby mode
     * otherwise they would be unspecified after return to active mode */
    error = TPP_SetOperationalMode(initConfig, tppModeEnable);

    if (error == kStatus_Success && mode == tppModeStandby)
    {
        error = TPP_SetOperationalMode(initConfig, tppModeStandby);
    }

    return error;
}

/*FUNCTION**********************************************************************
 *
 * Function Name : TPP_Deinit
 * Description   : This function deinitialized the device.
 *
 *END**************************************************************************/
status_t TPP_Deinit(tpp_drv_config_t* const drvConfig)
{
    AML_ASSERT(drvConfig != NULL);

    return TPP_SetOperationalMode(drvConfig, tppModeSleep); /* Erases internal device configuration. */
}

/*FUNCTION**********************************************************************
 *
 * Function Name : TPP_SetOperationalMode
 * Description   : This function sets the operational mode of the device.
 *
 *END**************************************************************************/
status_t TPP_SetOperationalMode(tpp_drv_config_t* const drvConfig, tpp_device_mode_t mode)
{
    uint8_t modeMask; /* Temporary mode mask */
    status_t error = kStatus_Success;

    AML_ASSERT(drvConfig != NULL);
    AML_ASSERT(mode == tppModeEnable || mode == tppModeStandby || mode == tppModeSleep || mode == tppModeFaultProtection);

    if (mode == drvConfig->deviceConfig.opMode)
    {
        return kStatus_Success;
    }

    if (mode == tppModeEnable)
    {
        /* new mode depends on previous mode */
        if (drvConfig->deviceConfig.opMode == tppModeInitialization || drvConfig->deviceConfig.opMode == tppModeSleep)
        {
            /* Sleep wake up. */

            /* Temporary disables the lock mode. */
            modeMask = drvConfig->deviceConfig.modeMask;
            drvConfig->deviceConfig.modeMask &= ~TPP_MODE_LOCK_MASK;

            /* ^RST <- 1. */
            GPIO_AML_SetOutput(drvConfig->rstPinInstance, drvConfig->rstPinIndex);
            WAIT_AML_WaitUs(TPP_RESET_DELAY);

            /* Sets interrupt masks. */
            error = TPP_SetInterruptMasks(drvConfig, drvConfig->deviceConfig.intMask0, drvConfig->deviceConfig.intMask1);
            if (error != kStatus_Success)
            {
                return kStatus_TPP_InternalError;
            }

            /* Sets Deadtime if FULLON mode is disabled. */
            if ((drvConfig->deviceConfig.modeMask & TPP_MODE_FULL_MASK) == TPP_MODE_FULL_DISABLED)
            {
                error = TPP_SetDeadtime(drvConfig, drvConfig->deviceConfig.deadtime);
                if (error != kStatus_Success)
                {
                    return kStatus_TPP_InternalError;
                }
            }

            /* Sets mode register (with previous lock mode value). */
            error = TPP_SetModeRegister(drvConfig, modeMask);
            if (error != kStatus_Success)
            {
                return kStatus_TPP_InternalError;
            }
        }

        /* Standby wake up and recovery from fault protection mode starts here. */

        /* Clear all interrupts. */
        error = TPP_ClearInterrupts(drvConfig, TPP_CLINT0_MASK, TPP_CLINT1_MASK);
        if (error != kStatus_Success)
        {
            return kStatus_TPP_InternalError;
        }

        if (drvConfig->deviceConfig.opMode != tppModeFaultProtection)
        {
            /* This part is not needed for recovery from fault protection mode. */
            /* EN1 <- 1, EN2 <- 1. */
            GPIO_AML_SetOutput(drvConfig->en1PinInstance, drvConfig->en1PinIndex);
            GPIO_AML_SetOutput(drvConfig->en2PinInstance, drvConfig->en2PinIndex);
            WAIT_AML_WaitUs(TPP_ENABLE_DELAY);
        }

        TPP_InitializeOutputs();
    }
    else if (mode == tppModeSleep)
    {
        /* Clears all errors and SPI registers! */

        if (drvConfig->deviceConfig.opMode != tppModeEnable)
        {
            return kStatus_TPP_OpMode;
        }

        /* ^RST <- 0 */
        GPIO_AML_ClearOutput(drvConfig->rstPinInstance, drvConfig->rstPinIndex);

        /* EN <- 0 */
        GPIO_AML_ClearOutput(drvConfig->en1PinInstance, drvConfig->en1PinIndex);
        GPIO_AML_ClearOutput(drvConfig->en2PinInstance, drvConfig->en2PinIndex);
    }
    else if (mode == tppModeStandby)
    {
        if (drvConfig->deviceConfig.opMode != tppModeEnable)
        {
            return kStatus_TPP_OpMode;
        }

        /* EN1 <- 0. EN2 <- 0. RST remains 1. */
        GPIO_AML_ClearOutput(drvConfig->en1PinInstance, drvConfig->en1PinIndex);
        GPIO_AML_ClearOutput(drvConfig->en2PinInstance, drvConfig->en2PinIndex);
    }
    else
    {
        /* Mode is tppModeFaultProtection. */

        /* User is responsible for interrupts and related faults handling which include transition to this state. */
        if (drvConfig->deviceConfig.opMode != tppModeEnable)
        {
            return kStatus_TPP_OpMode;
        }

    }

    drvConfig->deviceConfig.opMode = mode;
    return kStatus_Success;
}



/*FUNCTION**********************************************************************
 *
 * Function Name : TPP_SendCommand
 * Description   : This function sends a command to the device.
 *
 *END**************************************************************************/
status_t TPP_SendCommand(tpp_drv_config_t* const drvConfig, tpp_spi_command_t cmd, uint8_t subcmd, uint8_t* rxData)
{
    status_t error = kStatus_Success;
    spi_aml_transfer_t spiAmlTransfer;
    uint8_t txData;

    AML_ASSERT(drvConfig != NULL);
    AML_ASSERT(cmd == tppCommandNull     || cmd == tppCommandMask0  ||
               cmd == tppCommandMask1    || cmd == tppCommandMode   ||
               cmd == tppCommandClint0   || cmd == tppCommandClint1 ||
               cmd == tppCommandDeadtime);
    AML_ASSERT(rxData != NULL);

    txData = ((uint8_t) cmd) | subcmd;

    SPI_AML_MasterSelectDevice(drvConfig->csPinInstance, drvConfig->csPinIndex, spiPcsActiveLow);

    spiAmlTransfer.txBuffer = &txData;
    spiAmlTransfer.rxBuffer = rxData;
    spiAmlTransfer.dataSize = 1;
    spiAmlTransfer.configFlags = drvConfig->spiTppConfig.configFlags;
    error = SPI_AML_MasterTransfer(drvConfig->spiInstance, &spiAmlTransfer);

    SPI_AML_MasterUnselectDevice(drvConfig->csPinInstance, drvConfig->csPinIndex, spiPcsActiveLow);

    return error;
}

/*FUNCTION**********************************************************************
 *
 * Function Name : TPP_GetStatusRegister
 * Description   : This function reads selected status register of the device.
 *
 *END**************************************************************************/
status_t TPP_GetStatusRegister(tpp_drv_config_t* const drvConfig, tpp_status_register_t statusRegister, uint8_t* const rxData)
{
    status_t error = kStatus_Success;

    AML_ASSERT(drvConfig != NULL);
    AML_ASSERT(statusRegister == tppSR0_deviceEvents || statusRegister == tppSR1_generalSettings ||
               statusRegister == tppSR2_interruptSettings || statusRegister == tppSR3_Deadtime);
    AML_ASSERT(rxData != NULL);

    /* First time receive data are ignored. */
    error = TPP_SendCommand(drvConfig, tppCommandNull, statusRegister, rxData);
    if (error != kStatus_Success)
    {
        return error;
    }

    drvConfig->deviceConfig.statusRegister[tppSR0_deviceEvents] = *rxData;

    error = TPP_SendCommand(drvConfig, tppCommandNull, tppSR0_deviceEvents, rxData);
    if (error != kStatus_Success)
    {
        return error;
    }

    drvConfig->deviceConfig.statusRegister[statusRegister] = *rxData;

    return kStatus_Success;
}

/*FUNCTION**********************************************************************
 *
 * Function Name : TPP_SetInterruptMasks
 * Description   : This function sets device interrupts mask.
 *
 *END**************************************************************************/
status_t TPP_SetInterruptMasks(tpp_drv_config_t* const drvConfig, uint8_t mask0, uint8_t mask1)
{
    status_t error = kStatus_Success;

    AML_ASSERT(drvConfig != NULL);

    mask0 &= TPP_MASK0_MASK;
    mask1 &= TPP_MASK1_MASK;

    error = TPP_SendCommand(drvConfig, tppCommandMask0, mask0, &(drvConfig->deviceConfig.statusRegister[tppSR0_deviceEvents]));
    if (error != kStatus_Success)
    {
        return error;
    }

    error = TPP_SendCommand(drvConfig, tppCommandMask1, mask1, &(drvConfig->deviceConfig.statusRegister[tppSR0_deviceEvents]));
    if (error != kStatus_Success)
    {
        return error;
    }

    /* Checks if lock mode is enabled. */
    if (drvConfig->deviceConfig.modeMask & TPP_MODE_LOCK_MASK)
    {
        return kStatus_TPP_LockMode;
    }

    /* Checks if interrupt mask was correctly set */
    error = TPP_GetStatusRegister(drvConfig, tppSR2_interruptSettings, &(drvConfig->deviceConfig.statusRegister[tppSR2_interruptSettings]));
    if (error != kStatus_Success)
    {
        return error;
    }

    if (drvConfig->deviceConfig.statusRegister[tppSR2_interruptSettings] != ((mask1 << 4) | mask0))
    {
        return kStatus_TPP_ResultCheck;
    }

    drvConfig->deviceConfig.intMask0 = mask0;
    drvConfig->deviceConfig.intMask1 = mask1;

    return kStatus_Success;
}

/*FUNCTION**********************************************************************
 *
 * Function Name : TPP_ClearInterrupts
 * Description   : This function clears device interrupt flags.
 *
 *END**************************************************************************/
status_t TPP_ClearInterrupts(tpp_drv_config_t* const drvConfig, uint8_t mask0, uint8_t mask1)
{
    status_t error = kStatus_Success;

    AML_ASSERT(drvConfig != NULL);

    mask0 &= TPP_MASK0_MASK;
    mask1 &= TPP_MASK1_MASK;

    error = TPP_SendCommand(drvConfig, tppCommandClint0, mask0, &(drvConfig->deviceConfig.statusRegister[tppSR0_deviceEvents]));
    if (error != kStatus_Success)
    {
        return error;
    }

    error = TPP_SendCommand(drvConfig, tppCommandClint1, mask1, &(drvConfig->deviceConfig.statusRegister[tppSR0_deviceEvents]));
    if (error != kStatus_Success)
    {
        return error;
    }

    /* Checks if interrupt flags were really cleared. */
    error = TPP_GetStatusRegister(drvConfig, tppSR0_deviceEvents, &(drvConfig->deviceConfig.statusRegister[tppSR0_deviceEvents]));
    if (error != kStatus_Success)
    {
        return error;
    }

    if ((drvConfig->deviceConfig.statusRegister[tppSR0_deviceEvents] & ((mask1 << 4) | mask0)) != 0)
    {
        return kStatus_TPP_ResultCheck;
    }

    return kStatus_Success;
}

/*FUNCTION**********************************************************************
 *
 * Function Name : TPP_SetModeRegister
 * Description   : This function sets the device mode register.
 *
 *END**************************************************************************/
status_t TPP_SetModeRegister(tpp_drv_config_t* const drvConfig, uint8_t modeMask)
{
    status_t error = kStatus_Success;

    AML_ASSERT(drvConfig != NULL);

    error = TPP_SendCommand(drvConfig, tppCommandMode, modeMask & TPP_MODE_MASK, &(drvConfig->deviceConfig.statusRegister[tppSR0_deviceEvents]));
    if (error != kStatus_Success)
    {
        return error;
    }

    /* Checks if lock mode is enabled. */
    if (drvConfig->deviceConfig.modeMask & TPP_MODE_LOCK_MASK)
    {
        return kStatus_TPP_LockMode;
    }

    /* Checks if device mode register was correctly set. */
    error = TPP_GetStatusRegister(drvConfig, tppSR1_generalSettings, &(drvConfig->deviceConfig.statusRegister[tppSR1_generalSettings]));
    if (error != kStatus_Success)
    {
        return error;
    }
    else if (((drvConfig->deviceConfig.statusRegister[tppSR1_generalSettings] & TPP_STATUS1_LOCK_MASK) >> (TPP_STATUS1_LOCK_SHIFT - TPP_MODE_LOCK_SHIFT)) != (modeMask & TPP_MODE_LOCK_MASK) ||
             ((drvConfig->deviceConfig.statusRegister[tppSR1_generalSettings] & TPP_STATUS1_FULL_MASK) >> (TPP_STATUS1_FULL_SHIFT - TPP_MODE_FULL_SHIFT)) != (modeMask & TPP_MODE_FULL_MASK) ||
             ((drvConfig->deviceConfig.statusRegister[tppSR1_generalSettings] & TPP_STATUS1_DESF_MASK) >> (TPP_STATUS1_DESF_SHIFT - TPP_MODE_DESF_SHIFT)) != (modeMask & TPP_MODE_DESF_MASK))
    {
        return kStatus_TPP_ResultCheck;
    }

    drvConfig->deviceConfig.modeMask = modeMask;

    return kStatus_Success;
}

/*FUNCTION**********************************************************************
 *
 * Function Name : TPP_SetDeadtime
 * Description   : This function sets deadtime value.
 *
 *END**************************************************************************/
status_t TPP_SetDeadtime(tpp_drv_config_t* const drvConfig, uint16_t deadtime)
{
    status_t error = kStatus_Success;

    AML_ASSERT(drvConfig != NULL);

    if (deadtime == 0)
    {
        /* ZERO DEADTIME command is sent. */
        error = TPP_SendCommand(drvConfig, tppCommandDeadtime, TPP_DEADTIME_CALIB_ZERO, &(drvConfig->deviceConfig.statusRegister[tppSR0_deviceEvents]));
        if (error != kStatus_Success)
        {
            return error;
        }

        /* Checks if lock mode is enabled. */
        if (drvConfig->deviceConfig.modeMask & TPP_MODE_LOCK_MASK)
        {
            return kStatus_TPP_LockMode;
        }

        /* Checks deadtime setting result status */
        error = TPP_GetStatusRegister(drvConfig, tppSR1_generalSettings, &(drvConfig->deviceConfig.statusRegister[tppSR1_generalSettings]));
        if (error != kStatus_Success)
        {
            return error;
        }

        if (!(drvConfig->deviceConfig.statusRegister[tppSR1_generalSettings] & TPP_STATUS1_DTCAL_MASK))
        {
            /* dead time calibration was not successful */
            return kStatus_TPP_DeadCalibration;
        }

        if (!(drvConfig->deviceConfig.statusRegister[tppSR1_generalSettings] & TPP_STATUS1_DTZER_MASK))
        {
            /* zero dead time command was not successful */
            return kStatus_TPP_DeadZero;
        }

        drvConfig->deviceConfig.deadtime = deadtime;
        return error;
    }
    else
    {
        /* CS pulse width deadtime calibration */

        /* Correction to minimum admissible value with respect to 3PP internal time base period */
        deadtime = (deadtime < TPP_INTERNAL_TIME_BASE_PERIOD) ? TPP_INTERNAL_TIME_BASE_PERIOD : deadtime;
        if (deadtime > TPP_DEADTIME_MAX_VALUE)
        {
            /* checks if maximum admissible value is not exceeded (this value also depends on 3PP internal time base period) */
            return kStatus_InvalidArgument;
        }

        error = TPP_SendCommand(drvConfig, tppCommandDeadtime, TPP_DEADTIME_CALIB_DEADTIME, &(drvConfig->deviceConfig.statusRegister[tppSR0_deviceEvents]));
        if (error != kStatus_Success)
        {
            return error;
        }

        TPP_ToggleCs(drvConfig, deadtime * TPP_PULSE_WIDTH_CAL_COEF);

        /* Checks if lock mode is enabled. */
        if (drvConfig->deviceConfig.modeMask & TPP_MODE_LOCK_MASK)
        {
            return kStatus_TPP_LockMode;
        }

        /* Checks deadtime calibration result status */
        error = TPP_GetStatusRegister(drvConfig, tppSR1_generalSettings, &(drvConfig->deviceConfig.statusRegister[tppSR1_generalSettings]));
        if (error != kStatus_Success)
        {
            return error;
        }

        if (!(drvConfig->deviceConfig.statusRegister[tppSR1_generalSettings] & TPP_STATUS1_DTCAL_MASK))
        {
            /* Deadtime calibration was not successful. */
            return kStatus_TPP_DeadCalibration;
        }

        if (drvConfig->deviceConfig.statusRegister[tppSR1_generalSettings] & TPP_STATUS1_DTOVF_MASK)
        {
            /* Calibration overflow occurred. */
            return kStatus_TPP_DeadOverflow;
        }

        drvConfig->deviceConfig.deadtime = deadtime;
        return error;
    }
}
