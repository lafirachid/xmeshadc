/*
 * Copyright (c) 2002-2005 Intel Corporation
 * Copyright (c) 2000-2005 The Regents of the University of California
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: eepromM.nc,v 1.1.4.1 2007/04/26 00:28:13 njain Exp $
 */
 
/*
 *
 * Authors:		Rob Szewczyk, David Gay, Philip Levis
 * Date last modified:  6/25/02
 *
 */

/**
 * @author Rob Szewczyk
 * @author David Gay
 * @author Philip Levis
 */


module eepromM {
  provides {
    interface StdControl;
    interface EEPROMRead;
    /* The identity of the writer is indicated by the id they choose when
       connecting to the EEPROMWrite interface (the usual argument is
       unique("EEPROMWRite") to guarantee a unique value for each writer) */
    interface EEPROMWrite[uint8_t id];
  }
  uses {
    interface StdControl as PageControl;
    interface PageEEPROM;
  }
}
implementation
{
  enum { // states
    S_IDLE = 0,
    S_READ = 1,
    S_WIDLE = 2, /* startWrite called, no write in progress */
    S_WRITE = 3,
    S_ENDWRITE = 4
  };

  // 256-byte pages. Normally we have 16-byte lines, so 16 lines per page
  enum {
    LOG2_LINES_PER_PAGE = 8 - TOS_EEPROM_LOG2_LINE_SIZE
  };

  uint8_t state;
  uint8_t *data; /* The data being read or written */
  result_t writeResult; /* FAIL if any write in a sequence fails */
  uint8_t currentWriter;

  command result_t StdControl.init() {
    state = S_IDLE;
    return call PageControl.init();
  }
  
  command result_t StdControl.start() {
    return call PageControl.start();
  }

  command result_t StdControl.stop() {
    return call PageControl.stop();
  }

  command result_t EEPROMRead.read(uint16_t line, uint8_t *buffer) {
    if (state != S_IDLE)
      return FAIL;
    state = S_READ;
    
    data = buffer;
    return call PageEEPROM.read(line >> LOG2_LINES_PER_PAGE,
				(line & ((1 << LOG2_LINES_PER_PAGE) - 1))
				<< TOS_EEPROM_LOG2_LINE_SIZE,
				buffer, TOS_EEPROM_LINE_SIZE);
  }

  event result_t PageEEPROM.readDone(result_t result) {
    state = S_IDLE;
    return signal EEPROMRead.readDone(data, result);
  }

  command result_t EEPROMWrite.startWrite[uint8_t id]() {
    if (state != S_IDLE)
      return FAIL;
    state = S_WIDLE;
    writeResult = SUCCESS;
    currentWriter = id;

    return SUCCESS;
  }

  command result_t EEPROMWrite.write[uint8_t id](uint16_t line, uint8_t *buffer) {
    if (state != S_WIDLE || id != currentWriter)
      return FAIL;

    if (call PageEEPROM.write(line >> LOG2_LINES_PER_PAGE,
			      (line & ((1 << LOG2_LINES_PER_PAGE) - 1))
			      << TOS_EEPROM_LOG2_LINE_SIZE,
			      buffer, TOS_EEPROM_LINE_SIZE) == FAIL)
      return FAIL;

    state = S_WRITE;
    data = buffer;

    return SUCCESS;
  }

  event result_t PageEEPROM.writeDone(result_t result) {
    writeResult = rcombine(writeResult, result);
    state = S_WIDLE;
    return signal EEPROMWrite.writeDone[currentWriter](data);
  }

  command result_t EEPROMWrite.endWrite[uint8_t id]() {
    if (state != S_WIDLE || id != currentWriter)
      return FAIL;

    state = S_ENDWRITE;
    call PageEEPROM.syncAll();

    return SUCCESS;
  }

  event result_t PageEEPROM.syncDone(result_t result) {
    state = S_IDLE;
    return signal EEPROMWrite.endWriteDone[currentWriter](result);
  }

  event result_t PageEEPROM.flushDone(result_t result) {
    state = S_IDLE;
    return signal EEPROMWrite.endWriteDone[currentWriter](result);
  }

  default event result_t EEPROMWrite.writeDone[uint8_t id](uint8_t *buffer) {
    return FAIL;
  }

  default event result_t EEPROMWrite.endWriteDone[uint8_t id](result_t result) {
    return FAIL;
  }

  event result_t PageEEPROM.eraseDone(result_t result) {
    return SUCCESS;
  }
#if 0
  event result_t PageEEPROM.flushDone(result_t result) {
    return SUCCESS;
  }
#endif
  event result_t PageEEPROM.computeCrcDone(result_t result, uint16_t crc) {
    return SUCCESS;
  }
}
