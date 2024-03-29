/*
 * Copyright (c) 2004-2007 Crossbow Technology, Inc.
 * Copyright (c) 2002-2005 Intel Corporation
 * Copyright (c) 2000-2005 The Regents of the University of California
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: TempHumM.nc,v 1.1.4.1 2007/04/27 05:21:47 njain Exp $
 */
 
/*
 *
 * Authors:		Mohammad Rahmim, Joe Polastre
 *
 */

module TempHumM {
  provides {
    interface StdControl;
    interface ADC as TempSensor;
    interface ADC as HumSensor;
    interface ADCError as HumError;
    interface ADCError as TempError;
  }
  uses {
    interface Leds;
    interface Timer;
    interface StdControl as TimerControl;
  }

}
implementation {


  //states
  enum {READY=0, TEMP_MEASUREMENT=1, HUM_MEASUREMENT=2, POWER_OFF};

  norace char state;
  norace uint8_t timeout;
  norace uint8_t errornum;
  norace uint32_t timeval;
  int16_t data;

  norace bool humerror,temperror;

#if 0
  char calc_crc(char current, char in) {
    return crctable[current ^ in];
  }
#endif

  task void signalHumError() {
    signal HumError.error(errornum);
  }

  task void signalTempError() {
    signal TempError.error(errornum);
  }

  task void TimerRepeat()
  {
  	call Timer.start(TIMER_REPEAT, timeval);
  }
  
  static inline void  ack()
  {
    HUMIDITY_MAKE_DATA_OUTPUT();
    HUMIDITY_CLEAR_DATA();
    TOSH_wait_250ns();
    HUMIDITY_SET_CLOCK();
    TOSH_wait_250ns();
    HUMIDITY_CLEAR_CLOCK();
    HUMIDITY_MAKE_DATA_INPUT();
    HUMIDITY_SET_DATA();
  }

  static inline void initseq()
  { 
    HUMIDITY_MAKE_DATA_OUTPUT();
    HUMIDITY_SET_DATA();
    HUMIDITY_CLEAR_CLOCK();   
    TOSH_wait_250ns();         
    HUMIDITY_SET_CLOCK();
    TOSH_wait_250ns();
    HUMIDITY_CLEAR_DATA();
    TOSH_wait_250ns();
    HUMIDITY_CLEAR_CLOCK();
    TOSH_wait_250ns();
    HUMIDITY_SET_CLOCK();
    TOSH_wait_250ns(); 
    HUMIDITY_SET_DATA();
    TOSH_wait_250ns(); 
    HUMIDITY_CLEAR_CLOCK();
  }

  static inline void reset()
  {
    int i;
    HUMIDITY_MAKE_DATA_OUTPUT();
    HUMIDITY_SET_DATA();
    HUMIDITY_CLEAR_CLOCK();
    for (i=0;i<9;i++) {
      HUMIDITY_SET_CLOCK();
      TOSH_wait_250ns();
      HUMIDITY_CLEAR_CLOCK();
    }
  }

  static inline char processCommand(int cmd)
  {
    int i;
    int CMD = cmd;
    cmd &= 0x1f;
    HUMIDITY_INT_DISABLE();
    reset();           
    initseq();        //sending the init sequence
    for(i=0;i<8;i++){
      if(cmd & 0x80) HUMIDITY_SET_DATA();
      else HUMIDITY_CLEAR_DATA();
      cmd = cmd << 1 ;
      HUMIDITY_SET_CLOCK();
      TOSH_wait_250ns();              
      TOSH_wait_250ns();              
      HUMIDITY_CLEAR_CLOCK();        
    }
    HUMIDITY_MAKE_DATA_INPUT();
    HUMIDITY_SET_DATA();
    TOSH_wait_250ns();
    HUMIDITY_SET_CLOCK();
    TOSH_wait_250ns();
    if(HUMIDITY_GET_DATA()) 
    { 
      reset(); 
      errornum = 2;
      if ((CMD == TOSH_HUMIDITY_ADDR) && (humerror == TRUE))
        post signalHumError();
      else if ((CMD == TOSH_HUMIDTEMP_ADDR) && (temperror == TRUE))
        post signalTempError();
      return 0; 
    }
    TOSH_wait_250ns();
    HUMIDITY_CLEAR_CLOCK();
    if((CMD == TOSH_HUMIDITY_ADDR) || (CMD == TOSH_HUMIDTEMP_ADDR) ){
      if ((CMD == TOSH_HUMIDITY_ADDR) && (humerror == TRUE)) {
        timeout = 0;
        timeval=HUMIDITY_TIMEOUT_MS;
        post TimerRepeat();
      }
      else if ((CMD == TOSH_HUMIDTEMP_ADDR) && (temperror == TRUE)) {
        timeout = 0;
        timeval=HUMIDITY_TIMEOUT_MS;
        post TimerRepeat();
      }
      HUMIDITY_INT_ENABLE();
    }
    return 1;
  }

  command result_t StdControl.init() {
    humerror = FALSE;
    temperror = FALSE;
    state = POWER_OFF;
    return call TimerControl.init();
  }

  command result_t StdControl.start() {
    state=READY;
    HUMIDITY_CLEAR_CLOCK();
    HUMIDITY_MAKE_CLOCK_OUTPUT();
    HUMIDITY_SET_DATA();
    HUMIDITY_MAKE_DATA_INPUT();
    HUMIDITY_INT_DISABLE();
    reset();
    processCommand(TOSH_HUMIDITY_RESET);
    return SUCCESS;
  }

  command result_t StdControl.stop() {
    state = POWER_OFF;
    call Timer.stop();
    HUMIDITY_CLEAR_CLOCK();
    HUMIDITY_CLEAR_DATA();
    HUMIDITY_MAKE_CLOCK_INPUT();
    HUMIDITY_MAKE_DATA_INPUT();
    return SUCCESS;
  }

  default async event result_t TempSensor.dataReady(uint16_t tempData) 
  {
    return SUCCESS;
  }


  default async event result_t HumSensor.dataReady(uint16_t humData) 
  {
    return SUCCESS;
  }


  task void readSensor()
  {
    char i;
    char CRC=0;  
    data=0; 

    call Timer.stop();

    for(i=0;i<8;i++){
      HUMIDITY_SET_CLOCK();   
      TOSH_wait_250ns();
      data |= HUMIDITY_GET_DATA();
      data = data << 1;
      HUMIDITY_CLEAR_CLOCK();
    }
    ack();
    for(i=0;i<8;i++){
      HUMIDITY_SET_CLOCK();   
      TOSH_wait_250ns();
      data |= HUMIDITY_GET_DATA();
      //the last byte of data should not be shifted
      if(i!=7) data = data << 1;  
      HUMIDITY_CLEAR_CLOCK();
    }
    ack();
    for(i=0;i<8;i++){
      HUMIDITY_SET_CLOCK();   
      TOSH_wait_250ns();
      CRC |= HUMIDITY_GET_DATA();
      if(i!=7)CRC = CRC << 1;
      HUMIDITY_CLEAR_CLOCK();
    }
    // nack with high as it should be for the CRC ack
    HUMIDITY_MAKE_DATA_OUTPUT();
    HUMIDITY_SET_DATA();          
    TOSH_wait_250ns();
    HUMIDITY_SET_CLOCK();
    TOSH_wait_250ns();
    HUMIDITY_CLEAR_CLOCK();

    /**********
     * initial implementation of CRC calculation
     * commented out for now
    {
	int i;
	char crc = 0;
	char reverse_crc = 0;

	// check CRC
	crc = calc_crc(crc,TOSH_HUMIDTEMP_ADDR);
	crc = calc_crc(crc,data[0]);
	crc = calc_crc(crc,data[1]);

	// reverse the crc bits
	for (i=0; i<8; i++)
	  reverse_crc = reverse_crc + (((crc >> i) & 0x01) << (7-i));

	// is the crc correct?
	if ((reverse_crc == data[2]) || (crc == data[2])) {
	}
    }
    **/


    if(state==TEMP_MEASUREMENT){
      /* let the PC do the calculation *****
      temp=data;
      t= (((float)(temp) )*0.98-3840)/100;
      temp= (int16_t) t; 
      if(temp > 100 ) temp=100;
      if(temp < -40 ) temp=-40;
      signal TempSensor.dataReady(temp);
      ****/
      signal TempSensor.dataReady(data);
    }
    else if(state==HUM_MEASUREMENT) {
      /* let the PC do the calculation *****
      hum=data;
      h= 0.0405 * (float) (hum) - 4 - (float)(hum) * (float)(hum)*0.0000028;
      h= (t-25) * (0.01 + 0.00128 * hum) + h;
      hum= (int16_t) h;
      if(hum > 100 ) hum=100;
      if(hum < 0 ) hum=0;
      signal HumSensor.dataReady(hum);
      ****/
      signal HumSensor.dataReady(data);
    }
    state=READY;
  }

#ifndef PLATFORM_PC
  TOSH_SIGNAL(HUMIDITY_INTERRUPT)
  {
    HUMIDITY_INT_DISABLE();
    post readSensor();
    return;
  }
#endif

  // no such thing
  async command result_t TempSensor.getContinuousData() {
    return FAIL;
  }

  // no such thing
  async command result_t HumSensor.getContinuousData() {
    return FAIL;
  }

  async command result_t TempSensor.getData()
  {
    if(state!= READY ){
      reset();
    }
    state=TEMP_MEASUREMENT;
    processCommand(TOSH_HUMIDTEMP_ADDR);
    return SUCCESS;
  }

  async command result_t HumSensor.getData()
  {
    if(state!= READY ){
      reset();
    }
    state=HUM_MEASUREMENT;
    processCommand(TOSH_HUMIDITY_ADDR);
    return SUCCESS;
  }

  command result_t HumError.enable() {
    if (humerror == FALSE) {
      atomic humerror = TRUE;
      return SUCCESS;
    }
    return FAIL;
  }

  command result_t TempError.enable() {
    if (temperror == FALSE) {
      atomic temperror = TRUE;
      return SUCCESS;
    }
    return FAIL;
  }

  command result_t HumError.disable() {
    if (humerror == TRUE) {
      atomic humerror = FALSE;
      return SUCCESS;
    }
    return FAIL;
  }

  command result_t TempError.disable() {
    if (temperror == TRUE) {
      atomic temperror = FALSE;
      return SUCCESS;
    }
    return FAIL;
  }

  event result_t Timer.fired() {
    timeout++;
    if (timeout > HUMIDITY_TIMEOUT_TRIES) {
      if ((state == HUM_MEASUREMENT) && (humerror == TRUE)) {
        call Timer.stop();
        HUMIDITY_INT_DISABLE();
        state = READY;
        errornum = 1;
        post signalHumError();
      }
      else if ((state == TEMP_MEASUREMENT) && (temperror == TRUE)) {
        call Timer.stop();
        HUMIDITY_INT_DISABLE();
        state = READY;
        errornum = 1;
        post signalTempError();
      }
    }
    return SUCCESS;
  }

  default event result_t HumError.error(uint8_t token) { return SUCCESS; }

  default event result_t TempError.error(uint8_t token) { return SUCCESS; }

}
