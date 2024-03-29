/*
 * Copyright (c) 2004-2007 Crossbow Technology, Inc.
 * Copyright (c) 2002-2005 Intel Corporation
 * Copyright (c) 2000-2005 The Regents of the University of California
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: HPLCC2420M.nc,v 1.1.4.1 2007/04/26 00:30:57 njain Exp $
 */
 
/*
 *
 * Authors: Alan Broad, Crossbow
 * Date last modified:  $Revision: 1.1.4.1 $
 *
 */

/**
 * Low level hardware access to the CC2420
 * @author Alan Broad
 */

/***************************************************************************** 
$Log: HPLCC2420M.nc,v $
Revision 1.1.4.1  2007/04/26 00:30:57  njain
CVS: Please enter a Bugzilla bug number on the next line.
BugID: 1100

CVS: Please enter the commit log message below.
License header modified in each file for MoteWorks_2_0_F release

Revision 1.1  2006/01/03 07:46:19  mturon
Initial install of MoteWorks tree

Revision 1.2  2005/03/02 22:45:00  jprabhu
Added Log CVS-Tag

*****************************************************************************/
module HPLCC2420M {
  provides {
    interface StdControl;
    interface HPLCC2420;
    interface HPLCC2420RAM;
  }
}
implementation
{
 norace bool bSpiAvail;                    //true if Spi bus available
 norace uint8_t* rambuf;
  norace uint8_t ramlen;
  norace uint16_t ramaddr;

/*********************************************************
 * function: init
 *  set Atmega pin directions for cc2420
 *  enable SPI master bus
 ********************************************************/
    command result_t StdControl.init() {
    
    bSpiAvail = TRUE;
    TOSH_MAKE_MISO_INPUT();
    TOSH_MAKE_MOSI_OUTPUT();
    TOSH_MAKE_SPI_SCK_OUTPUT();
    TOSH_MAKE_CC_RSTN_OUTPUT();    
    TOSH_MAKE_CC_VREN_OUTPUT();
    TOSH_MAKE_CC_CS_OUTPUT(); 
    TOSH_MAKE_CC_FIFOP1_INPUT();    
    TOSH_MAKE_CC_CCA_INPUT();
    TOSH_MAKE_CC_SFD_INPUT();
    TOSH_MAKE_CC_FIFO_INPUT(); 
	atomic {
      TOSH_MAKE_SPI_SCK_OUTPUT();
      TOSH_MAKE_MISO_INPUT();	   // miso
      TOSH_MAKE_MOSI_OUTPUT();	   // mosi
	  sbi (SPSR, SPI2X);           // Double speed spi clock
	  sbi(SPCR, MSTR);             // Set master mode
      cbi(SPCR, CPOL);		       // Set proper polarity...
      cbi(SPCR, CPHA);		       // ...and phase
	  cbi(SPCR, SPR1);             // set clock, fosc/2 (~3.6 Mhz)
      cbi(SPCR, SPR0);
//    sbi(SPCR, SPIE);	           // enable spi port interrupt
      sbi(SPCR, SPE);              // enable spie port
 } 
    return SUCCESS;
  }
  
  command result_t StdControl.start() { return SUCCESS; }
  command result_t StdControl.stop() { 
	call HPLCC2420.cmd(CC2420_SRFOFF);
	call HPLCC2420.cmd(CC2420_SXOSCOFF);
     	return SUCCESS; 
}
  
  /*********************************************************
  * function: enableFIFOP
  *  enable CC2420 fifop interrupt
  CC2420 is configured for FIFOP interrupt on RXFIFO > Thresh
  where thresh is programmed in CC2420Const.h CP_IOCFGO reg. 
  Threshold is 127 asof 15apr04 (AlmostFull)
  FIFOP is asserted when complete msg OR RXFIFO>Threshold
  FIFOP is active LOW
  ********************************************************/
  async command result_t HPLCC2420.enableFIFOP(){
      cbi(EICRB,ISC60);              //trigger on low level
      cbi(EICRB,ISC61);				 //low level - for CC2420RadioAck
//      sbi(EICRB,ISC61);				 //falling edge
      CC2420_FIFOP_INT_ENABLE();
      return SUCCESS;
  }
   /*********************************************************
   * function: disbleFIFOP
   *  disable CC2420 fifop interrupt
   ********************************************************/
  async command result_t HPLCC2420.disableFIFOP(){
    CC2420_FIFOP_INT_DISABLE();
	return SUCCESS;
  }
   /*********************************************************
   * function: cmd
   *  send a command strobe
   ********************************************************/
   async command uint8_t HPLCC2420.cmd(uint8_t addr){
     uint8_t status;

	atomic {
      TOSH_CLR_CC_CS_PIN();                   //enable chip select
	  outp(addr,SPDR);
	  while (!(inp(SPSR) & 0x80)){};          //wait for spi xfr to complete
	  status = inp(SPDR);
    }
	TOSH_SET_CC_CS_PIN();                       //disable chip select
    return status;
   }

   /**************************************************************************
   * function: write                                       
   *   - accepts a 6 bit address and 16 bit data, 
   *   - write addr byte to SPI while reading status
   *   - if cmd strobe then just write addr, read status and exit
   *   - else write 16 bit data
   *   - SPI bus runs at ~ 3.6Mhz clock (2.2 usec/byte xfr) 
   *      
   *  NEED TO CHK IS SPI BUS IN USE?????????????????????????????
   *  THIS ROUTINE IS POLLING SPI CHANGE ????????????????????????
   * 
   ********************************************************/
  async command result_t HPLCC2420.write(uint8_t addr, uint16_t data) {
     uint8_t status;
 
 //   while (!bSpiAvail){};                      //wait for spi bus 

	atomic {
	  bSpiAvail = FALSE;
      TOSH_CLR_CC_CS_PIN();                   //enable chip select
	  outp(addr,SPDR);
	  while (!(inp(SPSR) & 0x80)){};          //wait for spi xfr to complete
	  status = inp(SPDR);
      if (addr > CC2420_SAES ){ 
	    outp(data >> 8,SPDR);
	    while (!(inp(SPSR) & 0x80)){};          //wait for spi xfr to complete
	    outp(data & 0xff,SPDR);
	    while (!(inp(SPSR) & 0x80)){};          //wait for spi xfr to complete
      }
	  bSpiAvail = TRUE;
    }
	TOSH_SET_CC_CS_PIN();                       //disable chip select
    return status;
  }
  
  /****************************************************************************
   * function: read                                        
   *   description: accepts a 6 bit address, 
   *   write addr byte to SPI while reading status 
   *   read status, followed by 2 data bytes
   * Input:  6 bit address                                 
   * Output: 16 bit data                                   
   ****************************************************************************/
  async command uint16_t HPLCC2420.read(uint8_t addr) {
  
    uint16_t data = 0;
    uint8_t status;

//    while (bSpiAvail){};                 //wait for spi bus
   atomic{
      bSpiAvail = FALSE;
      TOSH_CLR_CC_CS_PIN();                   //enable chip select
      outp(addr | 0x40,SPDR);
      while (!(inp(SPSR) & 0x80)){};          //wait for spi xfr to complete
      status = inp(SPDR); 
      outp(0,SPDR);
      while (!(inp(SPSR) & 0x80)){};          //wait for spi xfr to complete
      data = inp(SPDR);
      outp(0,SPDR);
      while (!(inp(SPSR) & 0x80)){};          //wait for spi xfr to complete
      data = (data << 8) | inp(SPDR);
      TOSH_SET_CC_CS_PIN();                       //disable chip select
	  bSpiAvail = TRUE;
    }
    return data;
  }

  TOSH_SIGNAL(TOSH_CC_FIFOP_INT) {
      // signal the interrupt
      signal HPLCC2420.FIFOPIntr();
  }
  task void signalRAMRd() {
    signal HPLCC2420RAM.readDone(ramaddr, ramlen, rambuf);
  }
  /**
   * Read data from CC2420 RAM
   *
   * @return SUCCESS if the request was accepted
   */

  async command result_t HPLCC2420RAM.read(uint16_t addr, uint8_t length, uint8_t* buffer) {
    // not yet implemented
    return FAIL;
  }

  task void signalRAMWr() {
    signal HPLCC2420RAM.writeDone(ramaddr, ramlen, rambuf);
  }
  /**
   * Write databuffer to CC2420 RAM.
   * @param addr RAM Address (9 bits)
   * @param length Nof bytes to write
   * @param buffer Pointer to data buffer
   * @return SUCCESS if the request was accepted
   */

  async command result_t HPLCC2420RAM.write(uint16_t addr, uint8_t length, uint8_t* buffer) {
    uint8_t i = 0;
    uint8_t status;

	if( !bSpiAvail )
		return FALSE;

	atomic {
		bSpiAvail = FALSE;
		ramaddr = addr;
		ramlen = length;
		rambuf = buffer;
		TOSH_CLR_CC_CS_PIN();                   //enable chip select
		outp( ((ramaddr & 0x7F) | 0x80),SPDR);	  //ls address	and set RAM/Reg flagbit
		while (!(inp(SPSR) & 0x80)){};          //wait for spi xfr to complete
		status = inp(SPDR);
		outp( ((ramaddr >> 1) & 0xC0),SPDR);	  //ms address
		while (!(inp(SPSR) & 0x80)){};          //wait for spi xfr to complete
		status = inp(SPDR);

		for (i = 0; i < ramlen; i++) {				  //buffer write
       	outp( rambuf[i] ,SPDR);
//        call USARTControl.tx(rambuf[i]);
	  	while (!(inp(SPSR) & 0x80)){};          //wait for spi xfr to complete
      }
	}//atomic
	bSpiAvail = TRUE;
	return post signalRAMWr();
  }	//RAM.write

}//HPLCC2420M.nc
  
