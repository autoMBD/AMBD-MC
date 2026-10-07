AML
================================================================================
Analog middleware layer is designed to improve compatibility between KSDK2.0
and S32 SDK mainly by using the same function prototypes. This layer
automatically distinguishes which type of peripheral is used (for example FTM
or TPM as a timer and SPI, DSPI or LPSPI as type of SPI). This layer supports
main functionality of pheripherals only. There can be implemented support
for additional custom peripherals and for custom MCUs using same prototypes.

Versions
================================================================================
Version 1.3
S32_SDK API was changed (1.0.0). Changes were implemented to aml.
SDK32 migrate to global status_t. AML status_t must be replace by aml_status_t.
It was done using: 
	#define status_t aml_status_t
	typedef int32_t status_t;
Type used for all status and error return values. This code is 
taken from SDK 2.0. File common_aml.h define value for aml_status_t.
This status is returned from AML but SDK32 driver returns status_t 
from status.h file. AML need to be compatible with older existing drivers. 
Be careful if use status from AML or SDK32 driver directly. 
AML SPI: Bit count per frame was inserted into (both master and slave) AML SPI 
configuration structures. For S32K, interrupts were set as transfer type. 
TMR_AML_Init: Fixed issue with FTM initialization if there 
is no channel for allocation.
TMR_AML_ResetTimer: Fixed issue with FTM, which did not leave this function.

Version 1.2
Added fixed TMR_AML_Init: Fixed issue with initialization timer if there 
is no channel for allocation with some devices 
(KL25 call assert if there was 0 channels). Problem is solved.

Version 1.1
Added new implemented feature:
Wait

Version 1.0 (initial).
Implemented pheripherals:
Timer - TPM, FTM
SPI - SPI, DSPI
ADC
GPIO
I2C