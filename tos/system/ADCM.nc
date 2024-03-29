/*
 * Copyright (c) 2002-2005 Intel Corporation
 * Copyright (c) 2000-2005 The Regents of the University of California
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: ADCM.nc,v 1.1.4.1 2007/04/27 05:59:04 njain Exp $
 */
 
/*
 *
 * Authors:		Jason Hill, David Gay, Philip Levis, Phil Buonadonna
 * Date last modified:  $Id: ADCM.nc,v 1.1.4.1 2007/04/27 05:59:04 njain Exp $
 *
 */

/*  OS component abstraction of the analog to digital converter
 *  It provides an asynchronous interface that schedules access to 
 *  separate virtual ADC ports in a round-robin fashion.
 */

/**
 * @author Jason Hill
 * @author David Gay
 * @author Philip Levis
 * @author Phil Buonadonna
 */


module ADCM 
{
  provides {
    interface ADC[uint8_t port];
    interface ADCControl;
  }
  uses interface HPLADC;
}

implementation
{

  enum {
    IDLE = 0,
    SINGLE_CONVERSION = 1,
    CONTINUOUS_CONVERSION = 2,
  };

  uint16_t ReqPort;
  uint16_t ReqVector;
  uint16_t ContReqMask;

  command result_t ADCControl.init() {
    atomic {
      ReqPort = 0;
      ReqVector = ContReqMask = 0;
    }
    dbg(DBG_BOOT, ("ADC initialized.\n"));

    return call HPLADC.init();
  }

  command result_t ADCControl.setSamplingRate(uint8_t rate) {
    return call HPLADC.setSamplingRate(rate);
  }

  command result_t ADCControl.bindPort(uint8_t port, uint8_t adcPort) {
    return call HPLADC.bindPort(port, adcPort);
  }

  default async event result_t ADC.dataReady[uint8_t port](uint16_t data) {
    return FAIL; // ensures ADC is disabled if no handler
  }

  async event result_t HPLADC.dataReady(uint16_t data) {
    uint16_t doneValue = data;
    uint8_t donePort;
    result_t Result;

    // BEGIN atomic
    atomic { 
      donePort = ReqPort;
      // Check to see if this port has requested continous conversion
      if (((1<<donePort) & ContReqMask) == 0) { 
	call HPLADC.sampleStop();
	ReqVector &= ~(1<<donePort); 
      }
      
      if (ReqVector) {
	do {
	  ReqPort++;
	  ReqPort = (ReqPort == TOSH_ADC_PORTMAPSIZE)? 0 : ReqPort;
	} while (((1<<ReqPort) & ReqVector) == 0);
	call HPLADC.samplePort(ReqPort);
      }
    }
    // END atomic

    dbg(DBG_ADC, "adc_tick: port %d with value %i \n", donePort, (int)data);
    Result = signal ADC.dataReady[donePort](doneValue);

    atomic {
      if ((Result == FAIL) && (ContReqMask & (1<<donePort))) {
	call HPLADC.sampleStop();
	ContReqMask &= ~(1<<donePort);
      }
    }

    return SUCCESS;
  }

  inline result_t startGet(uint8_t newState, uint8_t port) {
    uint16_t PortMask, oldReqVector;
    result_t Result = SUCCESS;

    if (port > TOSH_ADC_PORTMAPSIZE) {
      return FAIL;
    }

    PortMask = (1<<port);
    // BEGIN atomic
    atomic {
      if ((PortMask & ReqVector) != 0) {
	// Already a pending request
	Result = FAIL;
      }
      else {
	oldReqVector = ReqVector;
	ReqVector |= PortMask;
	if (newState == CONTINUOUS_CONVERSION) {
	  ContReqMask |= PortMask;
	}
	if (oldReqVector == 0) {
	  // ADC was idle.  Initiate a port sample
	  ReqPort = port;
	  Result = call HPLADC.samplePort(port);
	}
      }
    }
    // END atomic

    return Result;
  }

  async command result_t ADC.getData[uint8_t port]() {
    return startGet(SINGLE_CONVERSION, port);
  }

  async command result_t ADC.getContinuousData[uint8_t port]() {
    return startGet(CONTINUOUS_CONVERSION, port);
  }
}
