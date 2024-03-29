/*
 * Copyright (c) 2000-2005 The Regents of the University of California
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: I2CPacketM.nc,v 1.1.4.1 2007/04/26 22:25:33 njain Exp $
 */
 
/**
 * @author Joe Polastre
 * Revision:  $Revision: 1.1.4.1 $
 *
 * Provides the ability to write or read a series of bytes to/from the
 * I2C bus.  
 **/
module I2CPacketM
{
  provides {
    interface MSP430I2CPacket as I2CPacket;
    interface StdControl;
  }
  uses {
    interface MSP430I2CPacket as LPacket;
    interface StdControl as LControl;
    interface BusArbitration;
  }
}

implementation
{
  command result_t StdControl.init() {
    call LControl.init();
    return SUCCESS;
  }

  command result_t StdControl.start() {
    return SUCCESS;
  }

  command result_t StdControl.stop() {
    return SUCCESS;
  }

  command result_t I2CPacket.readPacket(uint16_t _addr, uint8_t _length, uint8_t* _data) {
    // bus arbitration occurs here
    if (call BusArbitration.getBus() == SUCCESS) {
      if (call LControl.start())
	return call LPacket.readPacket(_addr, _length, _data);
    }
    return FAIL;
  }

  event void LPacket.readPacketDone(uint16_t _addr, uint8_t _length, uint8_t* _data, result_t _result) {
    call LControl.stop();
    call BusArbitration.releaseBus();
    signal I2CPacket.readPacketDone(_addr, _length, _data, _result);
  }

  command result_t I2CPacket.writePacket(uint16_t _addr, uint8_t _length, uint8_t* _data) {
    // bus arbitration occurs here
    if (call BusArbitration.getBus() == SUCCESS) {
      if (call LControl.start())
	return call LPacket.writePacket(_addr, _length, _data);
    }
    return FAIL;
  }

  event void LPacket.writePacketDone(uint16_t _addr, uint8_t _length, uint8_t* _data, result_t _result) {
    call LControl.stop();
    call BusArbitration.releaseBus();
    signal I2CPacket.writePacketDone(_addr, _length, _data, _result);
  }

  event result_t BusArbitration.busFree() { return SUCCESS; }
}
