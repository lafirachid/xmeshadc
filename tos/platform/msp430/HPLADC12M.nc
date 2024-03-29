/*
 * Copyright (c) 2004-2007 Crossbow Technology, Inc.
 * Copyright (c) 2004, Technische Universitaet Berlin
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: HPLADC12M.nc,v 1.1.4.1 2007/04/26 22:05:01 njain Exp $
 */
 
/*
 * - Description ----------------------------------------------------------
 * ADC lowlevel functions.
 * - Revision -------------------------------------------------------------
 * $Revision: 1.1.4.1 $
 * $Date: 2007/04/26 22:05:01 $
 * @author: Jan Hauer
 * ========================================================================
 */

module HPLADC12M {
  provides interface HPLADC12;
}
implementation
{
 
  MSP430REG_NORACE(ADC12CTL0);
  MSP430REG_NORACE(ADC12CTL1);
  MSP430REG_NORACE(ADC12IFG);
  MSP430REG_NORACE(ADC12IE);
  MSP430REG_NORACE(ADC12IV);
  
  async command void HPLADC12.setControl0(adc12ctl0_t control0){
    ADC12CTL0 = *(uint16_t*)&control0; 
  }
  
  async command void HPLADC12.setControl1(adc12ctl1_t control1){
    ADC12CTL1 = *(uint16_t*)&control1; 
  }
  
  async command void HPLADC12.setControl0_IgnoreRef(adc12ctl0_t control0){
    adc12ctl0_t oldControl0 = (*(adc12ctl0_t*) &ADC12CTL0);
    control0.refon = oldControl0.refon;
    control0.r2_5v = oldControl0.r2_5v;
    ADC12CTL0 = (*(uint16_t*)&control0); 
  }
     
  async command adc12ctl0_t HPLADC12.getControl0(){ 
    return *(adc12ctl0_t*) &ADC12CTL0; 
  }
  
  async command adc12ctl1_t HPLADC12.getControl1(){
    return *(adc12ctl1_t*) &ADC12CTL1; 
  }
  
  async command void HPLADC12.setMemControl(uint8_t i, adc12memctl_t memControl){
    uint8_t *memCtlPtr = (uint8_t*) ADC12MCTL;
    if (i<16){
      memCtlPtr += i;
      *memCtlPtr = *(uint8_t*)&memControl; 
    }
  }
   
  async command adc12memctl_t HPLADC12.getMemControl(uint8_t i){
    adc12memctl_t x = {inch: 0, sref: 0, eos: 0 };    
    uint8_t *memCtlPtr = (uint8_t*) ADC12MCTL;
    if (i<16){
      memCtlPtr += i;
      x = *(adc12memctl_t*) memCtlPtr;
    }
    return x;
  }  
  
  async command uint16_t HPLADC12.getMem(uint8_t i){
    return *((uint16_t*) ADC12MEM + i);
  }

  async command void HPLADC12.setIEFlags(uint16_t mask){ ADC12IE = mask; } 
  async command uint16_t HPLADC12.getIEFlags(){ return (uint16_t) ADC12IE; } 
  
  async command void HPLADC12.resetIFGs(){ 
    // workaround, because ADC12IFG = 0x0000 has no effect !
    if (!ADC12IFG)
      return;
    else {
      uint8_t i;
      volatile uint16_t mud;
      for (i=0; i<16; i++)
        mud = call HPLADC12.getMem(i);
    }
  } 
  
  async command uint16_t HPLADC12.getIFGs(){ return (uint16_t) ADC12IFG; } 

  async command bool HPLADC12.isBusy(){ return ADC12CTL1 & ADC12BUSY; }
  
  async command void HPLADC12.enableConversion(){ ADC12CTL0 |= ENC;}
  async command void HPLADC12.disableConversion(){ ADC12CTL0 &= ~ENC; }
  async command void HPLADC12.startConversion(){ ADC12CTL0 |= ADC12SC + ENC; }
  async command void HPLADC12.stopConversion(){ 
    ADC12CTL1 &= ~(CONSEQ_1 | CONSEQ_3); 
    ADC12CTL0 &= ~ENC; 
  }
  
  async command void HPLADC12.setMSC(){ ADC12CTL0 |= MSC; }
  async command void HPLADC12.resetMSC(){ ADC12CTL0 &= ~MSC; }
  
  async command void HPLADC12.setConversionMode(uint8_t mode){
    uint16_t ctl1 = ADC12CTL1 & 0xFFF9;
    switch(mode){
      case SINGLE_CHANNEL: ADC12CTL0 &= ~MSC; break;
      case SEQUENCE_OF_CHANNELS: ctl1 |= 0x0002; ADC12CTL0 |= MSC; break;
      case REPEAT_SINGLE_CHANNEL: ctl1 |= 0x0004; ADC12CTL0 |= MSC; break;
      case REPEAT_SEQUENCE_OF_CHANNELS: ctl1 |= 0x0006; ADC12CTL0 |= MSC; break;
    }
    ADC12CTL1 = ctl1;
    return;
  }
    
  async command void HPLADC12.setRefOn(){ ADC12CTL0 |= REFON;}
  async command void HPLADC12.setRefOff(){ ADC12CTL0 &= ~REFON;}
  async command uint8_t HPLADC12.getRefon(){ return ADC12CTL0 & REFON;}
  async command void HPLADC12.setRef1_5V(){ ADC12CTL0 &= ~REF2_5V;}
  async command void HPLADC12.setRef2_5V(){ ADC12CTL0 |= REF2_5V;}
  async command uint8_t HPLADC12.getRef2_5V(){ return ADC12CTL0 & REF2_5V;}
  
  async command void HPLADC12.setSHT(uint8_t sht){
    uint16_t ctl0 = ADC12CTL0;
    uint16_t shttemp = sht & 0x0F;    
    ctl0 &= 0x00FF;
    ctl0 |= (shttemp << 8);
    ctl0 |= (shttemp << 12);
    ADC12CTL0 = ctl0; 
  }
  
  async command bool HPLADC12.isInterruptPending(){ 
    if (ADC12IFG)
      return TRUE;
    else
      return FALSE;
  }
  
  async command void HPLADC12.off(){ ADC12CTL0 &= ~ADC12ON; }
  async command void HPLADC12.on(){ ADC12CTL0 |= ADC12ON; }

  TOSH_SIGNAL(ADC_VECTOR) {
    uint16_t iv = ADC12IV;
    switch(iv)
    {
      case  2: signal HPLADC12.memOverflow(); return;
      case  4: signal HPLADC12.timeOverflow(); return;
    }
    iv >>= 1;
    if (iv && iv < 19)
      signal HPLADC12.converted(iv-3);
  }
}
