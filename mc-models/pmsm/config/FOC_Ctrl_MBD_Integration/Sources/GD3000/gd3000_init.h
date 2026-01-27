/*******************************************************************************
*
* Copyright 2006-2015 Freescale Semiconductor, Inc.
* Copyright 2016-2017 NXP
*
****************************************************************************//*!
*
* @file     gd3000_init.h
*
* @date     March-28-2017
*
* @brief    MC34GD3000 Initialization
*
*******************************************************************************/
#ifndef GD3000_GD3000_INIT_H_
#define GD3000_GD3000_INIT_H_
/*******************************************************************************
* Includes
*******************************************************************************/
#include "aml/common_aml.h"
#include "aml/gpio_aml.h"
#include "tpp/tpp.h"

/*******************************************************************************
* Constants and macros
*******************************************************************************/
/* Frequency of SPI communication with device in Hz. */
#define LPSPI_FREQ         2000000
/* Device interrupt masks set by MASK0 and MASK1 commands. */
#define INIT_INTERRUPTS0 (TPP_MASK0_OT_INT_ENABLED | TPP_MASK0_DES_INT_ENABLED | \
                          TPP_MASK0_UV_INT_ENABLED | TPP_MASK0_OC_INT_ENABLED)
#define INIT_INTERRUPTS1 (TPP_MASK1_PHS_INT_ENABLED | TPP_MASK1_FRM_INT_ENABLED | \
                          TPP_MASK1_WRT_INT_ENABLED | TPP_MASK1_RST_INT_ENABLED)
/* Device configuration set by Mode command. */
#define INIT_MODE        (TPP_MODE_DESF_DISABLED | TPP_MODE_FULL_ENABLED | TPP_MODE_LOCK_ENABLED)
/* Dead time of device in nanoseconds. */
#define INIT_DEADTIME    500

extern tpp_drv_config_t tppDrvConfig;

/*******************************************************************************
* Global function prototypes
*******************************************************************************/
void GD3000_Init(void);


#endif /* GD3000_GD3000_INIT_H_ */
