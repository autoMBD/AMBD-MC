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
 * @file tpp.h
 *
 * Three Phase FET Pre-driver driver based on AML layer.
 * Supports boards based on HB2000, HB2001 and GD3000.
 *
 * This module is common for all supported models.
 */

#ifndef __TPP_H__
#define __TPP_H__

/*******************************************************************************
 * Includes
 ******************************************************************************/

#include "tpp_mc33937.h"

#include "../aml/gpio_aml.h"
#include "../aml/spi_aml/spi_aml.h"
#include "../aml/wait_aml/wait_aml.h"


/*!
 * @brief Enable interrupts.
 */
#define ENABLE_INTERRUPTS()       __asm volatile ("cpsie i" : : : "memory");

/*!
 * @brief Disable interrupts.
 */
#define DISABLE_INTERRUPTS()       __asm volatile ("cpsid i" : : : "memory");


/*******************************************************************************
 * Definitions
 ******************************************************************************/

/* Enum types definition. */
/*!
 * @addtogroup enum_group
 * @{
 */
/*! @brief Error codes. */
enum _tpp_status
{
    kStatus_TPP_SpiInit         = MAKE_STATUS(kStatusGroup_TPP, 0), /*!< Wrong parameter in spi_tpp_config_t or wrong SPI initialization. */
    kStatus_TPP_OpMode          = MAKE_STATUS(kStatusGroup_TPP, 1), /*!< Unexpected operational mode. */
    kStatus_TPP_LockMode        = MAKE_STATUS(kStatusGroup_TPP, 2), /*!< Lock mode is enabled. */
    kStatus_TPP_DeadCalibration = MAKE_STATUS(kStatusGroup_TPP, 3), /*!< Deadtime calibration was not successful. */
    kStatus_TPP_DeadOverflow    = MAKE_STATUS(kStatusGroup_TPP, 4), /*!< Deadtime calibration overflow. */
    kStatus_TPP_DeadZero        = MAKE_STATUS(kStatusGroup_TPP, 5), /*!< Deadtime zero command failed. */
    kStatus_TPP_ResultCheck     = MAKE_STATUS(kStatusGroup_TPP, 6), /*!< Result check failed. */
    kStatus_TPP_InternalError   = MAKE_STATUS(kStatusGroup_TPP, 7)  /*!< Unexpected internal result code. */
};

/*! @brief Device operational mode. */
typedef enum
{
    tppModeSleep           = 0x0U,          /*!< Sleep mode - erases the device internal configuration and turns off output stages. */
    tppModeStandby         = 0x1U,          /*!< Standby mode - device configuration remains intact, output stages turned off only.  */
    tppModeInitialization  = 0x2U,          /*!< Initialization mode - internal mode not accessible by user, used at device initialization only. */
    tppModeEnable          = 0x3U,          /*!< Enable mode - device is properly configured and output stages are prepared. */
    tppModeFaultProtection = 0x4U           /*!< Fault Protection mode - reflects situation when the device disables output stages because of internal fault. */
} tpp_device_mode_t;

/*! @brief Device status registers. */
typedef enum
{
    tppSR0_deviceEvents      = TPP_NULL_STATUS0,       /*!< Device status register with internal events. */
    tppSR1_generalSettings   = TPP_NULL_STATUS1,       /*!< Device status register with general settings (lock, full-on, desaturation, dead time). */
    tppSR2_interruptSettings = TPP_NULL_STATUS2,       /*!< Device status register with interrupt settings (internal events possibly causing interrupts). */
    tppSR3_Deadtime          = TPP_NULL_STATUS3        /*!< Device status register with measured dead time value. */
} tpp_status_register_t;

/*! @brief Device SPI commands. */
typedef enum
{
    tppCommandNull     = TPP_NULL_CMD,      /*!< Command for reading the IC status. */
    tppCommandMask0    = TPP_MASK0_CMD,     /*!< Command for setting a MASK0 portion of the interrupt mask. */
    tppCommandMask1    = TPP_MASK1_CMD,     /*!< Command for setting a MASK1 portion of the interrupt mask. */
    tppCommandMode     = TPP_MODE_CMD,      /*!< Command for setting the FULLON, Lock and Desaturation Fault modes. */
    tppCommandClint0   = TPP_CLINT0_CMD,    /*!< Command for clearing a portion of the fault latch corresponding to MASK0. */
    tppCommandClint1   = TPP_CLINT1_CMD,    /*!< Command for clearing a portion of the fault latch corresponding to MASK1. */
    tppCommandDeadtime = TPP_DEADTIME_CMD   /*!< Command for setting the deadtime with calibration technique. */
} tpp_spi_command_t;
/*! @} */

/* Configure struct types definition. */
/*!
 * @addtogroup struct_group
 * @{
 */
/*!
 * @brief Driver specific SPI configuration.
 */
typedef struct
{
    uint32_t sourceClockHz;                 /*!< Peripheral source clock frequency in Hz. */
    uint32_t baudRateHz;                    /*!< Baudrate in Hz. */
    uint32_t configFlags;                   /*!< SPI control flags, only for DSPI, ignored for SPI and LPSPI. */
} spi_tpp_config_t;

/*!
 * @brief Device configuration.
 *
 * This structure contains device control and interrupt configuration and state of status registers.
 */
typedef struct
{
    tpp_device_mode_t opMode;               /*!< Device operational mode. */
    uint8_t statusRegister[4];              /*!< Device status registers. */
    uint8_t intMask0;                       /*!< Interrupts mask MASK0. */
    uint8_t intMask1;                       /*!< Interrupts mask MASK1. */
    uint8_t modeMask;                       /*!< Device general settings mask (lock, full-on, desaturation). */
    uint16_t deadtime;                      /*!< Deadtime value. */
} tpp_device_data_t;

/*!
 * @brief Driver configuration.
 *
 * This structure contains all information needed for proper functionality of the driver,
 * such as used peripherals configurations, control pins configuration and device configuration.
 */
typedef struct
{
    /* EN1, EN2 pin settings. */
    aml_instance_t en1PinInstance;          /*!< EN1 pin port instance. */
    uint8_t en1PinIndex;                    /*!< EN1 pin index. */
    aml_instance_t en2PinInstance;          /*!< EN2 pin port instance. */
    uint8_t en2PinIndex;                    /*!< EN2 pin index. */
    /* RST pin settings. */
    aml_instance_t rstPinInstance;          /*!< RST pin port instance. */
    uint8_t rstPinIndex;                    /*!< RST pin index. */
    /* SPI settings. */
    aml_instance_t spiInstance;             /*!< SPI instance. */
    spi_tpp_config_t spiTppConfig;          /*!< Device SPI configuration. */
    aml_instance_t csPinInstance;           /*!< CS pin port instance (SW controlled PCS pin). */
    uint8_t csPinIndex;                     /*!< CS pin index (SW controlled PCS pin). */
    /* Device settings. */
    tpp_device_data_t deviceConfig;         /*!< Device configuration and data. */
} tpp_drv_config_t;
/*! @} */

/*******************************************************************************
 * API
 ******************************************************************************/

/*!
 * @addtogroup function_group
 * @{
 */

/*!
 * @brief This function configures GPIO for usage with this driver.
 *
 * This function initializes GPIO (EN1, EN2, RST pins).
 *
 * @param drvConfig Pointer to driver instance configuration.
 *
 * @return status_t Error code.
 */
status_t TPP_ConfigureGpio(tpp_drv_config_t* const drvConfig);

/*!
 * @brief This function configures SPI for usage with this driver.
 *
 * This function initializes SPI. There are two parameters.
 * Tpp_drv_config_t must be used always with appropriate driver settings
 * but spi_sdk_master_config_t could be used for custom user SDK settings
 * (use NULL pointer for default settings).
 *
 * @param drvConfig Pointer to driver instance configuration.
 * @param spiSdkMasterConfig SDK specific configuration. Use NULL pointer for default settings.
 *
 * @return status_t Error code.
 */
status_t TPP_ConfigureSpi(tpp_drv_config_t* const drvConfig, spi_sdk_master_config_t* const spiSdkMasterConfig);

/*!
 * @brief This function initializes the device.
 *
 * Configures device mode and interrupts. Prepares low side and high side output stages.
 * Note that before each call of TPP_Init() method TPP_Deinit() method must be called except
 * first initialization.
 *
 * @param initConfig Pointer to initial driver configuration.
 * @param mode Operation mode after initialization. Only tppModeStandby and tppModeEnable are allowed.
 *
 * @return tpp_return_t Error code.
 */
status_t TPP_Init(tpp_drv_config_t* const initConfig, tpp_device_mode_t mode);

/*!
 * @brief This function deinitializes the device.
 *
 * Note that device must be in ACTIVE or SLEEP operational mode before calling this method.
 *
 * @param drvConfig Pointer to driver instance configuration.
 *
 * @return tpp_return_t Error code.
 */
status_t TPP_Deinit(tpp_drv_config_t* const drvConfig);

/*!
 * @brief This function sets the operational mode of the device.
 *
 * Sets device operational mode. Internal method logic is responsible for consistency
 * between transitions, but it is recommended to use only valid and logical transitions.
 *
 * SLEEP/INITIALIZATION -> ACTIVE: Enables SPI communication, loads configuration stored
 * in tpp_device_data_t structure.
 * STANDBY -> ACTIVE: Initializes and turns on output stages.
 * FAULT_PROTECTION -> ACTIVE: Clears all interrupt flags, initializes and turns on output stages.
 * ACTIVE -> SLEEP: Disables SPI communication, erases device internal configuration, but
 * configuration is preserved in tpp_device_data_t structure.
 * ACTIVE -> STANDBY: Turns off output stages, preserves device internal configuration.
 * ACTIVE -> FAULT_PROTECTION: Can be used during interrupt processing, when output stages
 * are automatically turned off.
 *
 * @param drvConfig Pointer to driver instance configuration.
 * @param mode Operational mode to switch the device to.
 *
 * @return status_t Error code.
 */
status_t TPP_SetOperationalMode(tpp_drv_config_t* const drvConfig, tpp_device_mode_t mode);

/*!
 * @brief This function sends a command to the device.
 *
 * This function sends command to device over SPI communication bus and receives
 * content of device status register 0 (or another status register in case of NULL command).
 * One of tpp_spi_command_t could be selected. The command is combined with its subcommand.
 *
 * @param drvConfig Pointer to driver instance configuration.
 * @param cmd Selected command.
 * @param subcmd Selected sub command.
 * @param rxData pointer to 1B rxBuffer, where received content of status register chosen
 *               by sub command of NULL command or content of status register 0 in case of
 *               other commands will be stored.
 *
 * @return status_t Error code.
 */
status_t TPP_SendCommand(tpp_drv_config_t* const drvConfig, tpp_spi_command_t cmd, uint8_t subcmd, uint8_t* rxData);

/*!
 * @brief This function reads selected status register of the device.
 *
 * This function reads data from device using SPI. One status register of tpp_status_register_t
 * could be selected. Data will be stored in buffer which is pointed by rxData.
 *
 * @param drvConfig Pointer to driver instance configuration.
 * @param statusRegister Selected register to be read.
 * @param rxData Pointer to buffer for read value.
 *
 * @return status_t Error code.
 */
status_t TPP_GetStatusRegister(tpp_drv_config_t* const drvConfig, tpp_status_register_t statusRegister, uint8_t* const rxData);

/*!
 * @brief This function sets device interrupts mask.
 *
 * If selected interrupt is disabled, it is still possible to check occurrence of that event
 * by reading device status register manually.
 * Note that it is not possible to change interrupt mask when lock mode is enabled.
 *
 * @param drvConfig Pointer to driver instance configuration.
 * @param mask0 Mask for interrupts in MASK0 command to enable/disable.
 * @param mask1 Mask for interrupts in MASK1 command to enable/disable.
 *
 * @return status_t Error code.
 */
status_t TPP_SetInterruptMasks(tpp_drv_config_t* const drvConfig, uint8_t mask0, uint8_t mask1);

/*!
 * @brief This function clears device interrupt flags.
 *
 * It is recommended to clear only flags, which were actually set in device status register 0.
 *
 * @param drvConfig Pointer to driver instance configuration.
 * @param mask0 Mask for interrupts in MASK0 command to clear their state.
 * @param mask1 Mask for interrupts in MASK1 command to clear their state.
 *
 * @return status_t Error code.
 */
status_t TPP_ClearInterrupts(tpp_drv_config_t* const drvConfig, uint8_t mask0, uint8_t mask1);

/*!
 * @brief This function sets the device mode register.
 *
 * Note that it is not possible to change device mode settings (lock, full-on, desaturation)
 * when lock mode is enabled.
 *
 * @param drvConfig Pointer to driver instance configuration.
 * @param modeMask Mask of mode which should be set.
 *
 * @return status_t Error code.
 */
status_t TPP_SetModeRegister(tpp_drv_config_t* const drvConfig, uint8_t modeMask);

/*!
 * @brief This function sets deadtime value.
 *
 * Admissible range is from 0 to 15000 ns.
 * If the value is set to 0, user is responsible for handling delay between low side
 * and high side output stages toggling to prevent short.
 * This method disables maskable interrupts for necessary time to prevent deadtime
 * calibration interference and is available only when full-on mode is disabled.
 * Note that it is not possible to change deadtime when lock mode is enabled. Minimal
 * delay is one TPP predriver internal time base clock cycle duration (typically
 * 58.82 ns for 17 Mhz) * 16 = 940ns.
 *
 * @param drvConfig Pointer to driver instance configuration.
 * @param deadtime DeadTime in nanoseconds. Admissible range for dead time is 0 to 15000 ns.
 *
 * @return status_t Error code.
 */
status_t TPP_SetDeadtime(tpp_drv_config_t* const drvConfig, uint16_t deadtime);

/*!
 * @brief This function is invoked during initialization of device.
 *
 * It is required to initialize outputs according to datasheet recommendations.
 */
extern void TPP_InitializeOutputs(void);
/*! @} */

#endif /* __TPP_H__ */
/*******************************************************************************
 * EOF
 ******************************************************************************/
