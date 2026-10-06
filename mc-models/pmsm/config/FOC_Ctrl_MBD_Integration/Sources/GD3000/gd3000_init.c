/*******************************************************************************
*
* Copyright 2006-2015 Freescale Semiconductor, Inc.
* Copyright 2016-2017 NXP
*
****************************************************************************//*!
*
* @file     gd3000_init.c
*
* @date     March-28-2017
*
* @brief    MC34GD3000 Initialization
*
*******************************************************************************/
/*******************************************************************************
* Includes
*******************************************************************************/
#include "gd3000_init.h"

tpp_drv_config_t  tppDrvConfig;

/*******************************************************************************
*
* Function: 	void GD3000_Init(void)
*
* Description:  This function initialize MC34GD3000 MOSFET pre-driver.
* 				MC34GD3000 SW driver uses S32K144 LPSPI0 module as a communication
* 				interface to configure MC34GD3000 operation mode and to track MC34GD3000
* 				Status0/Status1 registers.
*
*******************************************************************************/
void GD3000_Init(void)
{
	/* GD3000 pin configuration - EN1:PTA2 EN2:PTA2 & RST:PTA3 */
    tppDrvConfig.en1PinIndex 	= 2U;
    tppDrvConfig.en1PinInstance = instanceA;
    tppDrvConfig.en2PinIndex 	= 2U;
    tppDrvConfig.en2PinInstance = instanceA;
    tppDrvConfig.rstPinIndex 	= 3U;
    tppDrvConfig.rstPinInstance = instanceA;

	/* GD3000 device configuration */
    tppDrvConfig.deviceConfig.deadtime = 	INIT_DEADTIME;
    tppDrvConfig.deviceConfig.intMask0 = 	INIT_INTERRUPTS0;
    tppDrvConfig.deviceConfig.intMask1 = 	INIT_INTERRUPTS1;
    tppDrvConfig.deviceConfig.modeMask = 	INIT_MODE;

    tppDrvConfig.deviceConfig.statusRegister[0U] = 0U;
    tppDrvConfig.deviceConfig.statusRegister[1U] = 0U;
    tppDrvConfig.deviceConfig.statusRegister[2U] = 0U;
    tppDrvConfig.deviceConfig.statusRegister[3U] = 0U;

    tppDrvConfig.csPinIndex = 5U;
    tppDrvConfig.csPinInstance = instanceB;
    tppDrvConfig.spiInstance = 0;
    tppDrvConfig.spiTppConfig.baudRateHz = 	  LPSPI_FREQ;
    tppDrvConfig.spiTppConfig.sourceClockHz = 48000000U;

	TPP_ConfigureGpio(&tppDrvConfig);
	TPP_ConfigureSpi(&tppDrvConfig, NULL);
	TPP_Init(&tppDrvConfig, tppModeEnable);
}
