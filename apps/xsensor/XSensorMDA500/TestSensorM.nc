/*
 * Copyright (c) 2004-2007 Crossbow Technology, Inc.
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: TestSensorM.nc,v 1.3.4.1 2007/04/26 20:28:12 njain Exp $
 */

/** 
 * XSensor single-hop application for MDA500 sensorboard.
 *
 *    -Measures mica2dot battery voltage using the on-board voltage reference. 
 *     As the battery voltage changes the Atmega ADC's full scale decreases. By
 *     measuring a known voltage reference the battery voltage can be computed.
 *
 *
 *    - Measure the mica2dot thermistor resistance.
 *      The thermistor and voltage reference share the same adc channel (ADC1).
 *      They have indiviual on/off controls:
 *      thermistor:  PW6 = lo => on; PW6 = hi => off
 *      voltage ref: PW7 = lo => on; PW7 = hi => off
 *      They cannot both be turned on together.
 *      Give ~msec of settling time after applying power before making a measurement.
 *
 *    -Tests the MDA500 general prototyping card (see Crossbow MTS Series User Manaul)
 *     Read and control all MDA500 signals:
 *     - reads ADC2,ADC3,...ADC7 inputs
 *     - toggles the following MDA500 I/O lines at a 1Hz rate:
 *       THERM_PWR (GPS_EN on mica2dot pcb), PWM1B,INT1,INT0,PW0,PW1
 *-----------------------------------------------------------------------------
 * Output results through mica2dot uart and radio. 
 * Use Console.exe program to view data from either port:
 *  uart: mount mica2dot on mib510 with or without MDA500
 *        connect serial cable to PC
 *        run xlisten.exe at 19200 baud
 *  radio: run mica2dot with or withouth MDA500, 
 *         run mica2 with TOSBASE
 *         run xlisten.exe at 56K baud
 *-----------------------------------------------------------------------------
 * Data packet structure  :
 *  msg->data[0] : sensor id, MDA500 = 0x1
 *  msg->data[1] : packet id
 *  msg->data[2] : node id
 *  msg->data[3] : reserved
 *  msg->data[4,5] : battery adc data
 *  msg->data[6,7] : thermistor adc data
 *  msg->data[8,9] : adc2 data
 *  msg->data[10,11] : adc3 data
 *  msg->data[12,13] : adc4 data
 *	msg->data[14,15] : adc5 data
 *	msg->data[16,17] : adc6 data
 *  msg->data[18,19] : adc7 data
 * 
 *------------------------------------------------------------------------------
 * Mica2Dot:
 * The thermistor and voltage reference share the same adc channel (ADC1).
 * They have indiviual on/off controls:
 *  thermistor:  PW6 = lo => on; PW6 = hi => off
 *  voltage ref: PW7 = lo => on; PW7 = hi => off
 *  They cannot both be turned on together.
 *  Give ~msec of settling time after applying power before making a measurement.
 *
 *
 * @author Martin Turon, Alan Broad, Hu Siquan, Pi Peng
 */


module TestSensorM {
  provides {
    interface StdControl;
  }
  uses {
  //  interface Clock;
	interface ADC as ADCBATT;
	interface ADC as ADC2;
    interface ADC as ADC3;
    interface ADC as ADC4;
    interface ADC as ADC5;
    interface ADC as ADC6;
    interface ADC as ADC7;
    

  	interface ADCControl;
    interface Timer;
	interface Leds;

//communication
	interface StdControl as CommControl;
	interface SendMsg as Send;
	interface ReceiveMsg as Receive;
  }
}

implementation {
  enum {STATE0 = 0, STATE1,STATE2};
  #define MSG_LEN  29 

   TOS_Msg msg_buf;
   TOS_MsgPtr msg_ptr;
   bool sending_packet;
   bool bGetVoltRef;
   bool bIOon;
   bool bLedOn;
   bool bIsUart;
   uint8_t state;
   XDataMsg *pack;
/****************************************************************************
 * Task to xmit radio message
 *
 ****************************************************************************/
   task void send_radio_msg(){
    if(sending_packet) return; 
    atomic sending_packet=TRUE;  
    call Leds.yellowToggle(); 
    call Send.send(TOS_BCAST_ADDR,sizeof(XDataMsg),msg_ptr);
    return;
  }
/****************************************************************************
 * Task to uart as message
 *
 ****************************************************************************/
   task void send_uart_msg(){
    if(sending_packet) return;    
    atomic sending_packet=TRUE;
    call Leds.yellowToggle();
    call Send.send(TOS_UART_ADDR,sizeof(XDataMsg),msg_ptr);
    return;
  }

 /****************************************************************************
 * Initialize the component. Initialize ADCControl, Leds
 *
 ****************************************************************************/
  command result_t StdControl.init() {
    atomic{
	bGetVoltRef = TRUE;
	bIOon = FALSE;
	bLedOn = FALSE;
    //bIsUart=TRUE;
    sending_packet=FALSE;
    atomic{
    msg_ptr = &msg_buf;
    }
    state = STATE0;
    pack=(XDataMsg *)msg_ptr->data;
    };
// set atmega pin directions for mda500	
	MAKE_THERM_OUTPUT();             //enable thermistor power pin as output
    MAKE_BAT_MONITOR_OUTPUT();       //enable voltage ref power pin as output
    MAKE_INT0_OUTPUT();
	MAKE_INT1_OUTPUT();
	MAKE_PWO_OUTPUT();
	MAKE_PW1_OUTPUT();
	MAKE_PWM1B_OUTPUT();
	MAKE_GPS_ENA_OUTPUT();

	call ADCControl.init();
    call Leds.init();
	call CommControl.init();
    call Leds.init();
   	return SUCCESS;

  }
 /****************************************************************************
 * Start the component. Start the clock.
 *
 ****************************************************************************/
  command result_t StdControl.start(){
    call CommControl.start();
	call Timer.start(TIMER_REPEAT, 500);
    pack->xSensorHeader.board_id = SENSOR_BOARD_ID;
    pack->xSensorHeader.packet_id = 1;     // Only one packet for MDA500
    pack->xSensorHeader.node_id = TOS_LOCAL_ADDRESS;
    pack->xSensorHeader.rsvd = 0;

    return SUCCESS;	
  }
 /****************************************************************************
 * Stop the component.
 *
 ****************************************************************************/
  command result_t StdControl.stop() {
    call CommControl.stop();
    call Timer.stop();
    return SUCCESS;    
  }
/****************************************************************************
 * Measure voltage ref  
 *
 ****************************************************************************/
event result_t Timer.fired() {
   uint8_t l_state;
        
   if (bLedOn){
    // call Leds.redOff();
     bLedOn = FALSE;
   }
   else{
     call Leds.redOn();
	 bLedOn = TRUE;
   }
   bIsUart = TRUE;


   if (!bIOon){        //turn IO pins on/off
     SET_INT0();
	 SET_INT1();
	 SET_PW0();
	 SET_PW1();
	 SET_PWM1B();
	 SET_GPS_ENA();
	 bIOon = TRUE;
   }
   else{
     CLR_INT0();
	 CLR_INT1();
	 CLR_PW0();
	 CLR_PW1();
	 CLR_PWM1B();
	 CLR_GPS_ENA();
	 bIOon = FALSE;
  }
   	     
  atomic l_state = state;
  switch (l_state) { 
     case STATE0:
	     CLEAR_THERM_POWER();              //turn off thermistor power
         SET_BAT_MONITOR();                //turn on voltage ref power
		 atomic bGetVoltRef = TRUE;
		 TOSH_uwait(1000);                 //allow time to turn on
         call ADCBATT.getData();           //get sensor data;
		 atomic state = STATE1;
		 break;
     case STATE1:
	     CLEAR_BAT_MONITOR();              //turn off power to voltage ref     
         SET_THERM_POWER();                //turn on thermistor power
         atomic bGetVoltRef = FALSE;
	     TOSH_uwait(1000);
         call ADCBATT.getData();           //get sensor data;
	     break;
    
   }
 
   
   return SUCCESS;  
  }
/****************************************************************************
 * Battery Ref  or thermistor data ready 
 ****************************************************************************/
  async event result_t ADCBATT.dataReady(uint16_t data) {
  
    if (bGetVoltRef) {
      pack->xData.datap1.vref = data;
   	}
	else {
	  pack->xData.datap1.thermistor=data;
	  call ADC2.getData();                    //get sensor data;
   }
   return SUCCESS;
  }
 /****************************************************************************
 * ADC data ready 
 * Read and get next channel.
 ****************************************************************************/ 
  async event result_t ADC2.dataReady(uint16_t data) {
       pack->xData.datap1.adc2 = data;
	   call ADC3.getData();         //get sensor data;
       return SUCCESS;
   }
 /****************************************************************************
 * ADC data ready 
 * Read and get next channel.
 ****************************************************************************/ 
  async event result_t ADC3.dataReady(uint16_t data) {
       pack->xData.datap1.adc3 = data;
	   call ADC4.getData();         //get sensor data;
       return SUCCESS;
   }
 /****************************************************************************
 * ADC data ready 
 * Read and get next channel.
 ****************************************************************************/ 
  async event result_t ADC4.dataReady(uint16_t data) {
       pack->xData.datap1.adc4 = data;
	   call ADC5.getData();         //get sensor data;
       return SUCCESS;
   }
 /****************************************************************************
 * ADC data ready 
 * Read and get next channel.
 ****************************************************************************/ 
  async event result_t ADC5.dataReady(uint16_t data) {
       pack->xData.datap1.adc5 = data;
	   call ADC6.getData();         //get sensor data;
       return SUCCESS;
   }
 /****************************************************************************
 * ADC data ready 
 * Read and get next channel.
 ****************************************************************************/ 
  async event result_t ADC6.dataReady(uint16_t data) {
       pack->xData.datap1.adc6 = data;
	   call ADC7.getData();         //get sensor data;
       return SUCCESS;
   }
 /****************************************************************************
 * ADC data ready 
 * Read and get next channel.
 * Send data packet
 ****************************************************************************/ 
  async event result_t ADC7.dataReady(uint16_t data) {
       pack->xData.datap1.adc7 = data;
       post send_uart_msg();
       atomic state = STATE0;            
       return SUCCESS;
  }

/****************************************************************************
 * if Uart msg xmitted,Xmit same msg over radio
 * if Radio msg xmitted, issue a new round measuring
 ****************************************************************************/
  event result_t Send.sendDone(TOS_MsgPtr msg, result_t success) {
      //atomic msg_uart = msg;

      
	  sending_packet = FALSE;
      //if message have sent by UART, send the message once again by radio.
      if(bIsUart)
      { 
        bIsUart=!bIsUart;  
        post send_radio_msg();
      }
      else
      {
        atomic msg_ptr = msg;
        }
      return SUCCESS;
  }

/****************************************************************************
 * Uart msg rcvd. 
 * This app doesn't respond to any incoming uart msg
 * Just return
 ****************************************************************************/
  event TOS_MsgPtr Receive.receive(TOS_MsgPtr data) {
      return data;
  }

}

