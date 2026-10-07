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
# File:        configure_board.py
# Author:      autoMBD <tkung.lqk@foxmail.com>
# Date:        2026-10-07
# Version:     0.1.0
# Description: Configure MCSPTE1AK344 acquisition, complementary LCU gating, and GD3000 SPI.
# =================================================================================

"""Configure the MCSPTE1AK344 electrical interfaces using RTD 7 data models."""
from copy import deepcopy
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
CONFIG=ROOT/'mc-models/hsp/config/S32K344/config'
D='http://www.tresos.de/_projects/DataModel2/06/data.xsd'
A='http://www.tresos.de/_projects/DataModel2/18/attribute.xsd'
NS={'d':D}
ET.register_namespace('', 'http://www.tresos.de/_projects/DataModel2/18/root.xsd')
ET.register_namespace('d',D);ET.register_namespace('a',A)

def node(parent,kind,name,typ=None):
    attributes={'name':name}
    if typ:attributes['type']=typ
    return ET.SubElement(parent,'{'+D+'}'+kind,attributes)

def var(parent,name,value,typ='BOOLEAN'):
    item=node(parent,'var',name,typ)
    item.set('value',str(value).lower() if isinstance(value,bool) else str(value))
    return item

def get(parent,name,kind='var'):
    result=parent.find('.//d:'+kind+'[@name="'+name+'"]',NS)
    if result is None:raise ValueError(name)
    return result

def set_value(parent,name,value):
    item=get(parent,name)
    item.set('value',str(value).lower() if isinstance(value,bool) else str(value))
    # Saved generated-default markers must not override explicit project values.
    for child in list(item):item.remove(child)

def read(module):return ET.parse(CONFIG/(module+'.xdm'))
def save(module,tree):
    ET.indent(tree,space='  ')
    tree.write(CONFIG/(module+'.xdm'),encoding='utf-8',xml_declaration=True)

def configure_lcu():
    tree=read('Mcl');root=tree.getroot()
    for field in ['MclEnableLcu','MclEnableLcuSyncFunc','MclEnableTrgMux']:
        set_value(root,field,True)
    lcus=get(root,'lcuConfiguration','lst');lcus[:]=[]
    cfg=node(lcus,'ctr','Ambd_KitLcu','IDENTIFIABLE')
    instances=node(cfg,'lst','lcuInstanceCfg','MAP')
    inst=node(instances,'ctr','Ambd_PowerBridge','IDENTIFIABLE')
    var(inst,'lcuLogicInstance_LogicName','AMBD_POWER_BRIDGE','STRING')
    var(inst,'lcuLogicInstance_HwInstID','LCU_IP_HW_INST_0','ENUMERATION')
    var(inst,'lcuLogicInstance_OperationMode','POLLING','ENUMERATION')
    var(inst,'lcuLogicCell_UsingForceSignal',False)
    var(inst,'lcuLogicCell_UsingSyncSignal',False)
    inputs=node(cfg,'lst','mclLcuInputConfiguration','MAP')
    for index in range(3):
        inp=node(inputs,'ctr','Ambd_PwmInput'+str(index),'IDENTIFIABLE')
        for field,value in [('LogicName','AMBD_LCU_INPUT_'+str(index)),('HwInstID','LCU_IP_HW_INST_0'),('HwLcID','LCU_IP_HW_LC_'+str(index//2)),('HwInputID','LCU_IP_HW_INPUT_'+str(index%2)),('MuxSelect','LCU_IP_MUX_SEL_LU_IN_'+str(index)),('SwOverrideMode','LCU_IP_SW_SYNC_IMMEDIATE'),('SwOverrideValue','LCU_IP_SW_OVERRIDE_LOGIC_LOW')]:
            var(inp,'lcuLogicInput_'+field,value,'STRING' if field=='LogicName' else 'ENUMERATION')
        inp.remove(get(inp,'lcuLogicInput_SwOverrideMode'))
        var(inp,'lcuLogicInput_UsingSwOverride',False)
    outputs=node(cfg,'lst','mclLcuOutputConfiguration','MAP')
    for index,lut in enumerate([0x5555,0xAAAA,0x3333,0xCCCC,0x5555,0xAAAA]):
        out=node(outputs,'ctr','Ambd_PhaseOutput'+str(index),'IDENTIFIABLE')
        for field,value in [('LogicName','AMBD_LCU_OUTPUT_'+str(index)),('HwInstID','LCU_IP_HW_INST_0'),('HwLcID','LCU_IP_HW_LC_'+str(index//4)),('HwOutputID','LCU_IP_HW_OUTPUT_'+str(index%4))]:
            var(out,'lcuLogicOutput_'+field,value,'STRING' if field=='LogicName' else 'ENUMERATION')
        for field,value in [('LutControl',lut),('LutRiseFilter',96),('LutFallFilter',0)]:var(out,'lcuLogicOutput_'+field,value,'INTEGER')
        var(out,'lcuLogicOutput_InterruptCallback','NULL_PTR','FUNCTION-NAME')
        for field in ['DebugMode','LutDmaEnable','LutIntEnable','UsingForceSignal']:var(out,'lcuLogicOutput_'+field,False)
        var(out,'lcuLogicOutput_InvertOutput',bool(index%2))
        force=node(out,'ctr','lcuLogicOutput_ForceSignalConfiguration','IDENTIFIABLE')
        var(force,'lcuLogicOutput_ForceClearMode','LCU_IP_CLEAR_FORCE_SIGNAL_IMMEDIATE','ENUMERATION')
        var(force,'lcuLogicOutput_ForceSyncSelect','LCU_IP_SYNC_SEL_INPUT0','ENUMERATION')
        var(force,'lcuLogicOutput_ForceDmaEnable',False);var(force,'lcuLogicOutput_ForceIntEnable',False)
        node(force,'lst','lcuLogicOutput_ForceSignalSelect','MAP')
    instances=get(root,'trgmuxInstaceList','lst');instances[:]=[]
    inst=node(instances,'ctr','Ambd_TriggerMux','IDENTIFIABLE')
    var(inst,'trgmuxHardwareInstance','TRGMUX_IP_HW_INST_0','ENUMERATION')
    groups=get(root,'trgmuxLogicGroup','lst');groups[:]=[]
    group=node(groups,'ctr','Ambd_PwmRouting','IDENTIFIABLE')
    var(group,'trgmuxLogicGroupHardwareInstance','TRGMUX_IP_HW_INST_0','ENUMERATION')
    var(group,'trgmuxLogicGroup_Name','TRGMUX_IP_LCU0_0','ENUMERATION');var(group,'trgmuxLogicGroup_Lock',False)
    routes=node(group,'lst','trgmuxLogicTrigger','MAP')
    for index in range(3):
        route=node(routes,'ctr','Ambd_RoutePhase'+str(index),'IDENTIFIABLE')
        var(route,'trgmuxLogicTrigger_Name','AMBD_PWM_TO_LCU_'+str(index),'STRING')
        var(route,'trgmuxLogicTrigger_Output','TRGMUX_IP_OUTPUT_LCU0_0_INP_I'+str(index),'ENUMERATION')
        var(route,'trgmuxLogicTrigger_Input','TRGMUX_IP_INPUT_EMIOS0_IPP_CH'+str(index+1),'ENUMERATION')
        node(route,'ref','trgmuxLogicTrigger_EcucPartitionRef','REFERENCE').append(ET.Element('{'+A+'}a',{'name':'ENABLE','value':'false'}))
    master=get(root,'EmiosCommon_0','ctr')
    set_value(master,'EmiosMclMasterBusModeType','MCB_UP_COUNTER')
    set_value(master,'EmiosMclDefaultPeriod',10000)
    save('Mcl',tree)

def configure_acquisition():
    tree=read('Adc');root=tree.getroot();units=get(root,'AdcHwUnit','lst')
    prototype=deepcopy(list(units)[0]);units[:]=[]
    for index,channels in enumerate([[0,1,2],[1,2,3]]):
        unit=deepcopy(prototype);unit.set('name','AdcHwUnit_'+str(index));units.append(unit)
        set_value(unit,'AdcHwUnitId','ADC'+str(index));set_value(unit,'AdcLogicalUnitId',index)
        chlist=get(unit,'AdcChannel','lst');channel=deepcopy(list(chlist)[0]);chlist[:]=[]
        for logical,physical in enumerate(channels):
            ch=deepcopy(channel);ch.set('name','Ambd_Adc'+str(index)+'Ch'+str(logical));chlist.append(ch)
            set_value(ch,'AdcLogicalChannelId',logical);set_value(ch,'AdcChannelId',physical)
            set_value(ch,'AdcChannelName','P'+str(physical)+'_ChanNum'+str(physical))
        set_value(unit,'AdcGroupId',index)
        group=list(get(unit,'AdcGroup','lst'))[0]
        group.set('name','Ambd_AdcGroup'+str(index))
        for entry in unit.iter():
            if entry.tag.endswith('ref') and 'value' in entry.attrib:
                value=entry.get('value').replace('AdcHwUnit_0','AdcHwUnit_'+str(index))
                value=value.replace('Hsp_Bandgap','Ambd_Adc'+str(index)+'Ch0').replace('Hsp_Vref','Ambd_Adc'+str(index)+'Ch1')
                value=value.replace('Ambd_Adc0Ch','Ambd_Adc'+str(index)+'Ch')
                entry.set('value',value)
    hw=get(root,'AdcHwConfiguration','lst');prototype=deepcopy(list(hw)[0]);hw[:]=[]
    for index in range(2):
        item=deepcopy(prototype);item.set('name','AdcHwConfiguration_'+str(index));hw.append(item)
        set_value(item,'AdcHwConfiguredId','ADC'+str(index))
    set_value(root,'BctuAdcTargetMask',3)
    samples=list(get(root,'BctuListItems','lst'))
    for sample,physical in zip(samples,[2,1,1,1]):set_value(sample,'BctuAdcChannelList','P'+str(physical)+'_ChanNum'+str(physical))
    set_value(root,'BctuFifoDmaRawData',False)
    save('Adc',tree)

def configure_pins():
    tree=read('Port');root=tree.getroot();pins=get(root,'PortPin','lst')
    prototype=deepcopy(list(pins)[0])
    for index,name in enumerate(['Hsp_PhaseALow','Hsp_PhaseAHigh','Hsp_PhaseBLow','Hsp_PhaseBHigh','Hsp_PhaseCLow','Hsp_PhaseCHigh']):
        pin=get(root,name,'ctr');set_value(pin,'PortPinMode','LCU0_LCU0_OUT'+str(index)+'_OUT')
        set_value(pin,'PortPinLevelValue','PORT_PIN_LEVEL_HIGH' if index%2 else 'PORT_PIN_LEVEL_LOW')
    added=[('Ambd_Idc',97,'ADC0_ADC0_P0_IN'),('Ambd_Vdc',96,'ADC0_ADC0_P1_IN'),('Ambd_Ib',8,'ADC0_ADC0_P2_IN'),('Ambd_IaVa',13,'ADC1_ADC1_P1_IN'),('Ambd_Vb',129,'ADC1_ADC1_P3_IN'),('Ambd_Vc',128,'ADC1_ADC1_P2_IN'),('Ambd_HallA',19,'GPIO'),('Ambd_HallB',20,'GPIO'),('Ambd_HallC',21,'GPIO')]
    for name,_,_ in added:
        old=pins.find('d:ctr[@name="'+name+'"]',NS)
        if old is not None:pins.remove(old)
    for name,pcr,mode in added:
        pin=deepcopy(prototype);pin.set('name',name);pins.append(pin)
        set_value(pin,'PortPinId',len(pins));set_value(pin,'PortPinPcr',pcr)
        set_value(pin,'PortPinMode',mode);set_value(pin,'PortPinDirection','PORT_PIN_IN')
        set_value(pin,'PortPinLevelValue','PORT_PIN_LEVEL_LOW')
    set_value(root,'PortNumberOfPortPins',len(pins))
    save('Port',tree)
    tree=read('Dio');root=tree.getroot();ports=get(root,'DioPort','lst')
    for portname,portid,entries in [('Ambd_CsPort',3,[('Ambd_GdCs',1)]),('Ambd_FaultPort',4,[('Ambd_GdInt',7)]),('Hsp_LedPort',1,[('Ambd_HallA',3),('Ambd_HallB',4),('Ambd_HallC',5)])]:
        port=ports.find('d:ctr[@name="'+portname+'"]',NS)
        if port is None:
            port=node(ports,'ctr',portname,'IDENTIFIABLE');var(port,'DioPortId',portid,'INTEGER')
            node(port,'lst','DioChannel','MAP');node(port,'lst','DioChannelGroup','MAP');node(port,'lst','DioPortEcucPartitionRef')
        channels=get(port,'DioChannel','lst')
        for name,identifier in entries:
            old=channels.find('d:ctr[@name="'+name+'"]',NS)
            if old is not None:channels.remove(old)
            ch=node(channels,'ctr',name,'IDENTIFIABLE');var(ch,'DioChannelId',identifier,'INTEGER')
            var(ch,'PDACSlot','VIRTUAL_WRAPPER_PDAC0','ENUMERATION');node(ch,'lst','DioChannelEcucPartitionRef')
    save('Dio',tree)

def configure_support():
    tree=read('Mcu')
    for peripheral in tree.findall('.//d:lst[@name="McuPeripheral"]/d:ctr',NS):
        if get(peripheral,'McuPeripheralName').get('value') in ['TRGMUX','LCU_0','ADC_0','ADC_1']:
            set_value(peripheral,'McuPeripheralClockEnable',True)
    save('Mcu',tree)
    tree=read('Pwm');root=tree.getroot()
    for mode in root.findall('.//d:var[@name="EmiosChMode"]',NS):mode.set('value','EMIOS_PWM_IP_MODE_OPWMB')
    save('Pwm',tree)
    tree=read('Spi');root=tree.getroot()
    for key,value in [('SpiIbNBuffers',1),('SpiDataShiftEdge','TRAILING'),('SpiEnableCs',False),('SpiTransmitTimeout',10000)]:set_value(root,key,value)
    save('Spi',tree)
    tree=read('Icu');channel=get(tree.getroot(),'IcuChannel_0','ctr')
    set_value(channel,'IcuDefaultStartEdge','ICU_RISING_EDGE')
    set_value(channel,'IcuSignalNotification','Ambd_KitFaultIrq')
    save('Icu',tree)
    tree=read('Gpt');set_value(tree.getroot(),'GptNotification','Ambd_KitTick');save('Gpt',tree)

def main():
    configure_lcu();configure_acquisition();configure_pins();configure_support()

if __name__=='__main__':main()
