# =================================================================================
# The MIT License
# MIT许可证
#
# <https://opensource.org/license/mit>
#
# SPDX short identifier / SPDX 短标识符：MIT
#
# Copyright (c) 2026 autoMBD
# 版权所有 (c) 2026 autoMBD
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the “Software”),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
# 特此向获得本软件及相关文档（合称“本软件”）副本的任何人免费授予不受限制地利用本软
# 件的许可，包括而不限于：使用、复制、修改、合并、发布、分发、分许可和/或销售本软
# 件副本，并允许本软件的接收者也获得前述许可，但须遵守以下条件：
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
# 以上版权声明及本许可声明应包含在本软件的所有副本或主要部分中。
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALLTHE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# 本软件系“按原样”提供，不包含任何形式的明示或默示保证，包括但不限于适销性、特定
# 目的适用性及不侵权的保证。在任何情况下，无论是在合同、侵权或其他案件中，作者或版
# 权持有人均不对因本软件、或因本软件的使用或其他利用而引起的、引发的或与之相关的任
# 何权利主张、损害赔偿或其他责任承担责任。
# =================================================================================
# Project:     autoMBD Motor Control <https://github.com/autoMBD/AMBD-MC>
# File:        test_s32k144_config.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-08
# Version:     0.1.0
# Description: Compile and test the kit electrical contracts with deterministic SPI peers.
# =================================================================================

from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
CONFIG=ROOT/'mc-models/hsp/config/S32K144/config'
NS={'d':'http://www.tresos.de/_projects/DataModel2/06/data.xsd'}

def values(module,name):
    return [e.get('value') for e in ET.parse(CONFIG/(module+'.xdm')).findall('.//d:var[@name="'+name+'"]',NS)]

class K144ConfigurationTest(unittest.TestCase):
    def test_pwm_uses_kit_ftm3_and_8khz(self):
        self.assertEqual(values('Pwm','PwmHwInstance'),['Ftm_3'])
        self.assertEqual(values('Pwm','PwmFtmPeriod'),['10000'])
        self.assertEqual(values('Pwm','PwmFtmDeadTime'),['48'])
        self.assertEqual(values('Pwm','PwmFtmCounterMode'),['Center_Aligned_mode'])
    def test_synchronous_pairs(self):
        self.assertEqual(values('Pwm','PwmFtmChId'),['CH_0','CH_2','CH_4','CH_6'])
        self.assertEqual(values('Pwm','PwmFtmPairChEnable'),['true','true','true','false'])
        self.assertEqual(values('Pwm','PwmFtmMaxLoadPoint'),['true'])
        self.assertEqual(values('Pwm','PwmFtmCounterSync'),['Sync_disabled'])
        self.assertEqual(values('Pwm','PwmSetDutyCycle_NoUpdate'),['false'])
        self.assertEqual(values('Pwm','PwmSetPeriodAndDuty_NoUpdate'),['false'])
    def test_crystal_is_not_bypassed(self):
        self.assertEqual(values('Mcu','McuSOSCExternalReferenceSelect'),['false'])
        self.assertIn('XTAL',values('Port','PortPinMode'))
        self.assertIn('EXTAL',values('Port','PortPinMode'))
    def test_core_clock(self):
        root=ET.parse(CONFIG/'Mcu.xdm')
        run=root.find('.//d:ctr[@name="McuRunClockConfig"]',NS)
        self.assertEqual(run.find('d:var[@name="McuCoreClockFrequency"]',NS).get('value'),'80000000')
        self.assertEqual(values('Mcu','McuNoPll'),['false'])
    def test_kit_pin_routes(self):
        root=ET.parse(CONFIG/'Port.xdm')
        expected={'Ambd_PhaseAHigh':('40','FTM3_CH0'),'Ambd_PhaseALow':('41','FTM3_CH1'),
                  'Ambd_PhaseBHigh':('42','FTM3_CH2'),'Ambd_PhaseBLow':('43','FTM3_CH3'),
                  'Ambd_PhaseCHigh':('74','FTM3_CH4'),'Ambd_PhaseCLow':('75','FTM3_CH5'),
                  'Hsp_GateEnable':('2','GPIO'),'Hsp_GateReset':('3','GPIO')}
        for name,(pin,mode) in expected.items():
            with self.subTest(name=name):
                n=root.find('.//d:ctr[@name="'+name+'"]',NS)
                self.assertIsNotNone(n)
                self.assertEqual(n.find('d:var[@name="PortPinPcr"]',NS).get('value'),pin)
                self.assertEqual(n.find('d:var[@name="PortPinMode"]',NS).get('value'),mode)
    def test_two_adc_units_and_physical_irq_owner(self):
        self.assertEqual(values('Adc','AdcHwUnitId'),['ADC0','ADC1'])
        self.assertIn('Ambd_KitAdcIrq',values('Platform','IsrHandler'))
        self.assertNotIn('Hsp_ModelEvent',values('Adc','AdcNotification'))
    def test_original_k344_configuration_remains_separate(self):
        path=ROOT/'mc-models/hsp/config/S32K344/config/Adc.xdm'
        self.assertIn('Bctu',path.read_text(encoding='utf-8'))

if __name__=='__main__':unittest.main()
