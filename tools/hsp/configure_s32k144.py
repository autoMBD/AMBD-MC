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
# File:        configure_s32k144.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-08
# Version:     0.1.0
# Description: Configure S32K144 clocks, FTM/PDB acquisition, and kit I/O.
# =================================================================================

"""Configure the MCSPTE1AK344 electrical interfaces using RTD 7 data models."""
from copy import deepcopy
"""Author the MCSPTE1AK144 external EB configuration from its saved source."""
from copy import deepcopy
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / 'mc-models/hsp/config/S32K144/config'
D = 'http://www.tresos.de/_projects/DataModel2/06/data.xsd'
NS = {'d': D}

def get(root, name, kind='var'):
    node = root.find('.//d:' + kind + '[@name="' + name + '"]', NS)
    if node is None:
        raise ValueError('Missing configuration entry: ' + name)
    return node

def setv(root, name, value):
    get(root, name).set('value', str(value).lower() if isinstance(value, bool) else str(value))

def read(module):
    return ET.parse(CONFIG / (module + '.xdm'))

def save(module, tree):
    ET.indent(tree, space='  ')
    tree.write(CONFIG / (module + '.xdm'), encoding='utf-8', xml_declaration=True)

def clocks():
    tree = read('Mcu'); root = tree.getroot()
    setv(root, 'McuNoPll', False)
    setv(root, 'McuSOSCExternalReferenceSelect', False)
    pll = get(root, 'McuSystemPll', 'ctr')
    for key, value in {'McuSystemPllUnderMcuControl': True, 'McuSPLLEnable': True,
                       'McuSPLLMultiplier': 40, 'McuSPLLFrequency': 160000000,
                       'McuSPLLDiv1': 2, 'McuSPLLDiv1Frequency': 80000000,
                       'McuSPLLDiv2': 4, 'McuSPLLDiv2Frequency': 40000000}.items():
        setv(pll, key, value)
    run = get(root, 'McuRunClockConfig', 'ctr')
    for key, value in {'McuSystemClockSwitch': 'SPLL_CLK', 'McuCoreClockDivider': 2,
                       'McuBusClockDivider': 2, 'McuSlowClockDivider': 4,
                       'McuPreDivSystemClockFrequency': 160000000,
                       'McuCoreClockFrequency': 80000000, 'McuSystemClockFrequency': 80000000,
                       'McuBusClockFrequency': 40000000, 'McuFlashClockFrequency': 20000000,
                       'McuScgClkOutFrequency': 20000000}.items():
        setv(run, key, value)
    for item in root.findall('.//d:lst[@name="McuPeripheralClockConfig"]/d:ctr', NS):
        name = get(item, 'McuPerName').get('value')
        if name in ('FTM3', 'ADC1', 'ADC0', 'PDB1', 'PDB0'):
            setv(item, 'McuPeripheralClockEnable', True)
        if name == 'FTM3':
            setv(item, 'McuPeripheralClockSelect', 'SPLL')
            setv(item, 'McuPeripheralClockFrequency', 80000000)
        if name == 'ADC1':
            setv(item, 'McuPeripheralClockSelect', 'FIRC')
            setv(item, 'McuPeripheralClockFrequency', 24000000)
    point = get(root, 'Hsp_FtmClock', 'ctr')
    for node in point.iter():
        if node.get('name') == 'McuClockReferencePointFrequency': node.set('value', '80000000')
        if node.get('name') == 'McuClockFrequencySelect': node.set('value', 'FTM3_CLK')
    for name in ('Hsp_CoreClock','Hsp_CanClock'):
        setv(get(root,name,'ctr'),'McuClockReferencePointFrequency',80000000)
    save('Mcu', tree)

def pwm():
    tree=read('Pwm'); root=tree.getroot()
    for key,value in {'PwmHwInstance':'Ftm_3','PwmFtmCounterMode':'Center_Aligned_mode',
                      'PwmFtmPeriod':10000,'PwmFtmDeadTime':48,
                      'PwmSetDutyCycle_NoUpdate':False,'PwmSetPeriodAndDuty_NoUpdate':False,
                      'PwmNotificationSupported':False,'PwmFtmMaxLoadPoint':True,'PwmFtmCounterSync':'Sync_disabled',
                      'PwmFtmOutputMask':'Sync_on_FTM_Sync_Trigger'}.items():setv(root,key,value)
    physical=get(root,'PwmFtmCh','lst'); prototype=deepcopy(list(physical)[0]); physical[:]=[]
    logical=get(root,'PwmChannel','lst'); logical_prototype=deepcopy(list(logical)[0]); logical[:]=[]
    for i in range(4):
        ch=deepcopy(prototype); ch.set('name','PwmFtmCh_'+str(i));physical.append(ch)
        for key,value in {'PwmFtmChId':'CH_'+str(i*2),'PwmFtmChDutyCycle':16384,
                          'PwmFtmChPolarity':'Channel_active_LOW' if i<3 else 'Channel_active_HIGH',
                          'PwmFtmChInitOutput':'HIGH' if i<3 else 'LOW',
                          'PwmFtmPairChEnable':i<3,'PwmFtmPairedChDeadtimeEnable':i<3,
                          'PwmFtmPairedChComplementary':i<3,'PwmFtmPairedChComplementaryMode':'Duplicate_Output',
                          'PwmFtmChExternTriggerEnable':i==3}.items():setv(ch,key,value)
        item=deepcopy(logical_prototype);item.set('name',('Hsp_Phase'+chr(65+i)) if i<3 else 'Hsp_AdcTrigger');logical.append(item)
        setv(item,'PwmChannelId',i);setv(item,'PwmPeriodDefault',10000)
        setv(item,'PwmDutycycleDefault',16384)
        setv(item,'PwmPolarity','PWM_LOW' if i<3 else 'PWM_HIGH')
        setv(item,'PwmIdleState','PWM_HIGH' if i<3 else 'PWM_LOW')
        get(item,'PwmHwChannel','ref').set('value','ASPath:/Pwm/Pwm/PwmChannelConfigSet/PwmFtm_0/PwmFtmCh_'+str(i))
    resources=get(root,'PwmHwResourceConfig','lst'); seed=deepcopy(list(resources)[0]);resources[:]=[]
    for i in range(4):
        item=deepcopy(seed);item.set('name','PwmHwResourceConfig_'+str(i));resources.append(item)
        setv(item,'PwmHwResourceId','FTM_3_CH_'+str(i*2));setv(item,'PwmIsrEnable',False)
    save('Pwm',tree)

def adc():
    tree=read('Adc');root=tree.getroot();units=get(root,'AdcHwUnit','lst')
    seed=deepcopy(list(units)[0]);units[:]=[]
    for i in range(2):
        unit=deepcopy(seed);unit.set('name','AdcHwUnit_'+str(i));units.append(unit)
        setv(unit,'AdcHwUnitId','ADC'+str(i));setv(unit,'AdcLogicalUnitId',i)
        groups=get(unit,'AdcGroup','lst');groups[:]=list(groups)[:1]
        groups[0].set('name','Ambd_AdcGroup'+str(i))
        setv(unit,'AdcGroupId',i);setv(unit,'AdcNotification','NULL_PTR')
        for channel in list(get(unit,'AdcChannel','lst')):
            channel.set('name',channel.get('name').replace('Adc0_','Adc'+str(i)+'_'))
        for node in unit.iter():
            if node.tag.endswith('ref') and node.get('value'):
                node.set('value',node.get('value').replace('AdcHwUnit_0','AdcHwUnit_'+str(i)).replace('Adc0_','Adc'+str(i)+'_'))
    hardware=get(root,'AdcHwConfiguration','lst');seed=deepcopy(list(hardware)[0]);hardware[:]=[]
    for i in range(2):
        item=deepcopy(seed);item.set('name','AdcHwConfiguration_'+str(i));hardware.append(item)
        setv(item,'AdcHwConfiguredId','ADC'+str(i));setv(item,'AdcNormalInterruptEnable',True)
    # Native ADC/PDB channel ownership starts only in Ambd_KitStart.
    save('Adc',tree)

def pins():
    tree=read('Port');root=tree.getroot();items=get(root,'PortPin','lst')
    prototype=deepcopy(list(items)[0])
    routes=[('Ambd_Xtal',38,'XTAL','IN',False),('Ambd_Extal',39,'EXTAL','IN',False),
            ('Ambd_PhaseAHigh',40,'FTM3_CH0','OUT',True),('Ambd_PhaseALow',41,'FTM3_CH1','OUT',False),
            ('Ambd_PhaseBHigh',42,'FTM3_CH2','OUT',True),('Ambd_PhaseBLow',43,'FTM3_CH3','OUT',False),
            ('Ambd_PhaseCHigh',74,'FTM3_CH4','OUT',True),('Ambd_PhaseCLow',75,'FTM3_CH5','OUT',False),
            ('Hsp_GateEnable',2,'GPIO','OUT',False),('Hsp_GateReset',3,'GPIO','OUT',False),
            ('Ambd_GdCs',37,'GPIO','OUT',True),('Ambd_GdInt',138,'GPIO','IN',False),
            ('Ambd_SpiSck',34,'LPSPI0_SCK','OUT',False),('Ambd_SpiSin',35,'LPSPI0_SIN','IN',False),
            ('Ambd_SpiSout',36,'LPSPI0_SOUT','OUT',False),
            ('Ambd_HallA',107,'GPIO','IN',False),('Ambd_HallB',106,'GPIO','IN',False),('Ambd_HallC',1,'GPIO','IN',False),
            ('Ambd_IaVa',32,'ADC0_SE4','IN',False),('Ambd_IbVb',33,'ADC1_SE15','IN',False),
            ('Ambd_Vc',6,'ADC0_SE2','IN',False),('Ambd_Vdc',44,'ADC1_SE7','IN',False),('Ambd_Idc',100,'ADC1_SE6','IN',False)]
    names={r[0] for r in routes}
    for node in list(items):
        if node.get('name') in names:items.remove(node)
    for name,pcr,mode,direction,high in routes:
        pin=deepcopy(prototype);pin.set('name',name);items.append(pin)
        for key,value in {'PortPinId':len(items),'PortPinPcr':pcr,'PortPinMode':mode,
                          'PortPinDirection':'PORT_PIN_'+direction,
                          'PortPinLevelValue':'PORT_PIN_LEVEL_HIGH' if high else 'PORT_PIN_LEVEL_LOW'}.items():setv(pin,key,value)
    setv(root,'PortNumberOfPortPins',len(items));save('Port',tree)
    tree=read('Dio');root=tree.getroot();ports=get(root,'DioPort','lst');prototype=deepcopy(list(ports)[0]);ports[:]=[]
    routes.append(('BoardLedRed',111,'GPIO','OUT',True))
    for portid in [0,1,2,3,4]:
        name='Ambd_Port'+str(portid)
        for node in list(ports):
            if node.get('name')==name:ports.remove(node)
        entries=[r for r in routes if r[2]=='GPIO' and r[1]//32==portid]
        if not entries:continue
        port=deepcopy(prototype);port.set('name',name);ports.append(port);setv(port,'DioPortId',portid)
        channels=get(port,'DioChannel','lst');chproto=deepcopy(list(channels)[0]);channels[:]=[]
        for name,pcr,*_ in entries:
            ch=deepcopy(chproto);ch.set('name',name);setv(ch,'DioChannelId',pcr%32);channels.append(ch)
    save('Dio',tree)

def triggers():
    tree=read('Mcl');root=tree.getroot();groups=get(root,'trgmuxLogicGroup','lst')
    prototype=deepcopy(list(groups)[0]);groups[:]=[]
    for i in range(2):
        group=deepcopy(prototype);group.set('name','Ambd_AdcRoute'+str(i));groups.append(group)
        setv(group,'trgmuxLogicGroup_Name','TRGMUX_IP_PDB'+str(i))
        route=get(group,'trgmuxLogicTrigger_0','ctr')
        setv(route,'trgmuxLogicTrigger_Name','AMBD_ADC'+str(i)+'_TRIGGER')
        setv(route,'trgmuxLogicTrigger_Output','TRGMUX_IP_OUTPUT_PDB'+str(i)+'_TRIGGER_IN0')
        setv(route,'trgmuxLogicTrigger_Input','TRGMUX_IP_INPUT_LOGIC0_VSS')
    save('Mcl',tree)

def support():
    tree=read('Platform');root=tree.getroot()
    existing=get(root,'Hsp_ADC0_IRQn','ctr')
    setv(existing,'IsrEnabled',False)
    interrupts=next(n for n in root.iter() if existing in list(n));proto=deepcopy(existing)
    for name,irq,handler,priority in [('Ambd_ADC1','ADC1_IRQn','Ambd_KitAdcIrq',6),('Ambd_GdFault','PORTE_IRQn','Ambd_KitFaultIrq',5)]:
        for node in list(interrupts):
            if node.get('name')==name:interrupts.remove(node)
        row=deepcopy(proto);row.set('name',name);interrupts.append(row)
        for key,value in {'IsrName':irq,'IsrHandler':handler,'IsrEnabled':True,'IsrPriority':priority}.items():setv(row,key,value)
    save('Platform',tree)
    tree=read('Spi');root=tree.getroot()
    for key,value in {'SpiIbNBuffers':1,'SpiTransferStart':'MSB','SpiEnableCs':False,'SpiTransmitTimeout':10000}.items():setv(root,key,value)
    save('Spi',tree)
    tree=read('Gpt');setv(tree.getroot(),'GptNotification','Ambd_KitTick');save('Gpt',tree)

def main():
    prefs=ET.parse(CONFIG.parent/'.prefs/pref_general.xdm')
    for module in ('Can_43_FLEXCAN','CanIf'):
        entry=get(prefs.getroot(),module,'ctr')
        setv(entry,'Enabled',False);setv(entry,'Generate',False)
    ET.indent(prefs,space='  ')
    prefs.write(CONFIG.parent/'.prefs/pref_general.xdm',encoding='utf-8',xml_declaration=True)
    clocks();pwm();adc();pins();support();triggers()

if __name__=='__main__':main()
