/*
 * Copyright (c) 2004-2007 Crossbow Technology, Inc.
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: XMEP410M.nc,v 1.4.4.3 2007/04/26 20:11:53 njain Exp $
 */

/** 
 * XSensor multi-hop application for MEP410 sensorboard.
 *
 *    -Tests the Mep410 Mica2 Sensor Board
 *    -Read Accel, Light, Pressure, Temperature and Humidity(Internal and External) sensor readings
 *-----------------------------------------------------------------------------
 * Output results through mica2 uart and radio. 
 * Use Xlisten.exe program to view data from either port:
 *  uart: mount mica2 on mib510 with Mep401
 *        connect serial cable to PC
 *        run xlisten.exe at 56K baud
 *  radio: run mica2 with Mep410, 
 *         run mica2 with TOSBASE
 *         run xlisten.exe at 56K baud
 *-----------------------------------------------------------------------------
 * The following changes were made to improve reliability under low battery voltages:
 *   - Reboot on errors when sampling
 *   - Enable the route update watchdog timer
 *   - Disable OTAPLITE component that writes/reads eeprom (OTAP cannot be used)
 *-----------------------------------------------------------------------------
 * Data packet structure  :
 *
 * PACKET #1 (of 2)
 * ----------------
 *  msg->data[0] : sensor id, Mep401 = 0x87
 *  msg->data[1] : packet id = 10
 *  msg->data[2] : node id
 *  msg->data[3] : reserved
 *  msg->data[4,5] : accel_x adc data
 *  msg->data[6,7] : accel_y adc data
 *  msg->data[8,9] : photo1 data 
 *  msg->data[10,11] : photo2 data  
 *  msg->data[12,13] : photo3 data 
 *  msg->data[12,13] : photo4 data 
 *  msg->data[14,15] : humidity data
 *  msg->data[16,17] : thermistor data
 *  
 * PACKET #2 (of 2)
 * ----------------
 *  msg->data[0] : sensor id, Mep401 = 0x87
 *  msg->data[1] : packet id = 11
 *  msg->data[2] : node id
 *  msg->data[3] : reserved 
 *  msg->data[4,5] : cal_word1 
 *  msg->data[6,7] : cal_word2
 *  msg->data[8,9] : cal_word3
 *  msg->data[10,11] : cal_word4
 *  msg->data[12,13] : intersematemp
 *  msg->data[14,15] : pressure
 *
 * @author @author Martin Turon, Pi Peng, Mao Shifeng
 */


#include "appFeatures.h"
includes XCommand;
includes sensorboard;

module XMEP410M {
  provides {
    interface StdControl;
  }
  uses {
  
	interface Leds;
	interface MhopSend as Send;
	interface RouteControl;
	interface XCommand;
	interface XEEControl;
    //interface ADCControl;
    interface Timer;

    
// Battery    
    interface ADC as ADCBATT;
    interface StdControl as BattControl;

    interface SplitControl as AccelControl;
    interface ADC as AccelX;
    interface ADC as AccelY;
    
    interface SplitControl as PhotoControl;
    interface ADC as Photo1;
    interface ADC as Photo2;
    interface ADC as Photo3;
    interface ADC as Photo4;
    
    interface SplitControl as HumControl;
    interface ADC as Humidity;
    interface ADC as Temperature;
    interface ADCError as HumidityError;
    interface ADCError as TemperatureError;

    interface SplitControl as IntHumControl;
    interface ADC as IntHumidity;
    interface ADC as IntTemperature;
    interface ADCError as IntHumidityError;
    interface ADCError as IntTemperatureError;
    
    interface SplitControl as IntersemaControl;
    interface ADC as Pressure;
    interface ADC as IntersemaTemperature;
    interface ADCError as PressureError;
    interface ADCError as IntersemaTemperatureError;
    interface Calibration;
    
#if FEATURE_UART_SEND
	interface SendMsg as SendUART;
	command result_t PowerMgrEnable();
	command result_t PowerMgrDisable();
#endif
  command void health_packet(bool enable, uint16_t intv);
  command HealthMsg* HealthMsgGet();
  }
}

implementation {
	
  enum {STATE_START, STATE_VREF, STATE_HUMIDITY,STATE_THERM,STATE_INTHUMIDITY,STATE_INTTHERM,
  	STATE_ACCELX,STATE_ACCELY,STATE_PHOTO1,STATE_PHOTO2,STATE_PHOTO3,STATE_PHOTO4,
        STATE_CALIBRATION,STATE_PRESSURE,STATE_TEMP,ENDPACKET3,ENDPACKET4,};
        

  #define MSG_LEN  44 

   TOS_Msg msg_buf;
   TOS_MsgPtr msg_ptr;
   HealthMsg *h_msg;
 
   bool sending_packet;
   bool bIsUart;
   norace uint8_t state;
   
   char count;
   XDataMsg pack;
   uint16_t calibration[4];           //intersema calibration words
   bool       sleeping;	       // application command state
   norace uint8_t  nextpacket;
   uint16_t     packetcnt;
   norace bool sensinginsession;

  // wait when triggering the clock
  void wait() {
    asm volatile  ("nop" ::);
    asm volatile  ("nop" ::);
  }

  void waitn(uint16_t n)
  {
  	uint16_t i;

  	for(i=0;i<n;i++)
  	{
  		wait();
  	}
  }

  static void initialize() 
    {
      atomic 
      {
          packetcnt=0;
    	  sleeping = FALSE;
    	  sending_packet = FALSE;
#ifdef APP_RATE	  
		timer_rate = XSENSOR_SAMPLE_RATE;
#else		
#ifdef USE_LOW_POWER 	  
		timer_rate = XSENSOR_SAMPLE_RATE  + ((TOS_LOCAL_ADDRESS%255) << 7);
#else 
	  timer_rate = XSENSOR_SAMPLE_RATE + ((TOS_LOCAL_ADDRESS%255) << 2);
#endif
#endif
    	  sensinginsession=FALSE;
      }
    }

  static void start() 
  {
    call HumidityError.enable();
    call TemperatureError.enable();
    call BattControl.start(); 
    call IntHumidityError.enable();
    call IntTemperatureError.enable();
    call PressureError.enable();
    call IntersemaTemperatureError.enable();
  }
  task void stop()
  {
  	call StdControl.stop();
  }
  task void AccelStart()
  {
  call AccelControl.start();
  }
  task void AccelStop()
  {
  call AccelControl.stop();
  }
  
  task void PhotoStart()
  {
  call PhotoControl.start();
  }
  task void PhotoStop()
  {
  call PhotoControl.stop();
  }
  
  task void HumStop()
  {
  call HumControl.stop();
  }
  task void HumStart()
  {
  call HumControl.start();
  }
  
  task void IntHumStop()
  {
  call IntHumControl.stop();
  }
  
  task void IntersemaStart()
  {
  call IntersemaControl.start();
  }

/****************************************************************************
 * Task to reboot
 *
 ****************************************************************************/
   task void reboot(){
     wdt_enable(0);
     while (1) { 
       __asm__ __volatile__("nop" "\n\t" ::);
     }
   }
/****************************************************************************
 * Task to xmit radio message
 *
 ****************************************************************************/
   task void send_radio_msg(){
    uint16_t  len;
	XDataMsg *data;
    uint8_t i;
    call Leds.yellowOn();
    if(sending_packet) return; 
    atomic sending_packet=TRUE;  
    data = (XDataMsg*)call Send.getBuffer(msg_ptr, &len);
	for (i=0; i<= sizeof(XDataMsg)-1; i++)
		((uint8_t*) data)[i] = ((uint8_t*)&pack)[i];
    data->xMeshHeader.board_id = SENSOR_BOARD_ID;
    data->xMeshHeader.packet_id = nextpacket;     
    //data->xMeshHeader.node_id = TOS_LOCAL_ADDRESS;
    data->xMeshHeader.parent    = call RouteControl.getParent();
    data->xMeshHeader.packet_id = data->xMeshHeader.packet_id | 0x80;
    
    #if FEATURE_UART_SEND
    	if (TOS_LOCAL_ADDRESS != 0) {
    		call Leds.yellowOn();
    	    call PowerMgrDisable();
    	    TOSH_uwait(1000);
    	    if (call SendUART.send(TOS_UART_ADDR, sizeof(XDataMsg),msg_ptr) != SUCCESS) 
    	    {
        		atomic sending_packet = FALSE;
        		call Leds.greenToggle();
        		call PowerMgrEnable();
    	    }
    	} 
    	else 
    #endif
    	{
    	    // Send the RF packet!
    	    if (call Send.send(BASE_STATION_ADDRESS,MODE_UPSTREAM,msg_ptr, sizeof(XDataMsg)) != SUCCESS) {
        		atomic sending_packet = FALSE;
    		    call Leds.yellowOn();
        		call Leds.greenOff();
    	    }
    	}
    return;
  }

/****************************************************************************
 * Initialize this and all low level components used in this application.
 * 
 * @return returns <code>SUCCESS</code> or <code>FAIL</code>
 ****************************************************************************/

  command result_t StdControl.init() {
    atomic{
        msg_ptr = &msg_buf;
    };
    
    call BattControl.init();    
    atomic sending_packet = TRUE;
    call Leds.init();
    atomic sending_packet = FALSE;
    
    call AccelControl.init();
    call PhotoControl.init();
    call HumControl.init();
    call IntHumControl.init();
    call IntersemaControl.init();
		
    atomic state = STATE_START;
    
    call Leds.greenOff(); 
    call Leds.yellowOff(); 
    call Leds.redOff(); 
    nextpacket=1;
    initialize();
    return SUCCESS;
  }

/**
 * Start this component.
 * 
 * @return returns <code>SUCCESS</code>
 */
  command result_t StdControl.start(){
    call StdControl.stop();
    h_msg = call HealthMsgGet();
    h_msg->rsvd_app_type = SENSOR_BOARD_ID;
    call Timer.start(TIMER_REPEAT, timer_rate);
    call health_packet(TRUE,TOS_HEALTH_UPDATE);
    return SUCCESS;	
  }
/**
 * Stop this component.
 * 
 * @return returns <code>SUCCESS</code>
 */
  command result_t StdControl.stop() {
    call BattControl.stop(); 
    call AccelControl.stop();
    call PhotoControl.stop();
    call HumControl.stop();
    call IntHumControl.stop();
    call IntersemaControl.stop();
    return SUCCESS;    
  }

/*********************************************
event handlers
*********************************************/

/***********************************************/  
  event result_t AccelControl.initDone() {
    return SUCCESS;
  }
  
/***********************************************/  
  event result_t AccelControl.stopDone() {
    return SUCCESS;
  }
  
/***********************************************/  
  event result_t PhotoControl.initDone() {
    return SUCCESS;
  }
  
/***********************************************/  
  event result_t PhotoControl.stopDone() {
    return SUCCESS;
  }
  
/***********************************************/  
  event result_t HumControl.initDone() {
    return SUCCESS;
  }
  
/***********************************************/  
  event result_t HumControl.stopDone() {
    return SUCCESS;
  }
  
/***********************************************/  
  event result_t IntHumControl.initDone() {
    return SUCCESS;
  }
  
/***********************************************/  
  event result_t IntHumControl.stopDone() {
    return SUCCESS;
  }
  
/***********************************************/  
  event result_t IntersemaControl.initDone() {
    return SUCCESS;
  }
  
/***********************************************/  
  event result_t IntersemaControl.stopDone() {
    return SUCCESS;
  }

/***********************************************/  
  event result_t Timer.fired() {
  	uint8_t l_state;
  	int i;
    call Leds.redToggle();
	atomic {
        l_state = state;
    }
  	if ( sending_packet ){
        atomic{
            packetcnt++;
            if(packetcnt>=((30000/timer_rate)+3))
            {
                state = STATE_START;
                wdt_enable(1);
                call Leds.greenOff();
                packetcnt=0;
            }
        }
        return SUCCESS ;      //don't overrun buffers
    }
    // sample
//    call Leds.redOn();
    switch(l_state) {
    	case STATE_START:
    	    start();
    	    for(i=4;i<44;i++){
    	       ((uint8_t *)(&pack))[i]=0x0;
    	    }
            if (!sensinginsession){
	      	  call ADCBATT.getData();
              atomic sensinginsession = TRUE;
              atomic state = STATE_VREF;	        
            }
        	break;
      default:
            packetcnt++;
            if(packetcnt>=((30000/timer_rate)+3)){
                state = STATE_START;
                wdt_enable(1);
                call Leds.greenOff();
                packetcnt=0;
            }
            break;
    }
    return SUCCESS;
  }

/***********************************************/  

 /**********************************************
 * Battery Ref
 ***********************************************/
  async event result_t ADCBATT.dataReady(uint16_t data) {
  	  if (!sensinginsession) return FAIL;
      atomic {
      	    sensinginsession = FALSE;
            pack.xData.datax.vref = data ;
            state = STATE_ACCELX;
            post AccelStart();
        }
      
      return SUCCESS;
  }
  
  event result_t AccelControl.startDone() {
    atomic {
        state = STATE_ACCELX;   
        call AccelX.getData();
    }
    return SUCCESS;
  }

  async event result_t AccelX.dataReady(uint16_t data)
  {
    call Leds.redOn();
    atomic {
        pack.xData.datax.accel_x=data;
        state = STATE_ACCELY;   
        call AccelY.getData();
    }
    return SUCCESS;
  }
  
  async event result_t AccelY.dataReady(uint16_t data)
  {
    atomic {
        pack.xData.datax.accel_y=data;
        post AccelStop();
        post PhotoStart();
    }
    return SUCCESS;
  }
  
  /***********************************************/  
  event result_t PhotoControl.startDone() {
  	atomic {
        state = STATE_PHOTO1;   
        call Photo1.getData();
    }
    return SUCCESS;
  }
  
  /***********************************************/  
    async event result_t Photo1.dataReady(uint16_t data)
  {
    atomic {
        pack.xData.datax.photo[0]=data;
        state = STATE_PHOTO2;   
        call Photo2.getData();
    }
    return SUCCESS;
  }

  async event result_t Photo2.dataReady(uint16_t data)
  {
    atomic {
        state = STATE_PHOTO3;   
        pack.xData.datax.photo[1]=data;
        call Photo3.getData();
    }
    return SUCCESS;
  }

  async event result_t Photo3.dataReady(uint16_t data)
  {
    atomic {
        state = STATE_PHOTO4;   
        pack.xData.datax.photo[2]=data;
        call Photo4.getData();
    }
    return SUCCESS;
  }

  async event result_t Photo4.dataReady(uint16_t data)
  {
    atomic {
        pack.xData.datax.photo[3]=data;
        post PhotoStop();
        atomic state = ENDPACKET3;  
        post HumStart();   
    } 
    return SUCCESS;
  }
  
/***********************************************/  
  event result_t HumControl.startDone() {
    atomic {
        state = STATE_HUMIDITY;   
        call IntHumControl.start();  
    }  
    return SUCCESS;
  }

  event result_t IntHumControl.startDone() {
    atomic {
        state = STATE_HUMIDITY;   
        call Humidity.getData();
    }
    return SUCCESS;
  }

  async event result_t Humidity.dataReady(uint16_t data)
  {
    atomic {
        state = STATE_THERM;   
        pack.xData.datax.humid=data;
        call Temperature.getData();
    }
    return SUCCESS;
  }
  
   event result_t HumidityError.error(uint8_t token)
  {
    atomic {
        post reboot();
        pack.xData.datax.humid= 0xffff;
        state = STATE_THERM;   
        call Temperature.getData();
    }
    return SUCCESS;
  }
  
  async event result_t Temperature.dataReady(uint16_t data)
  {	
    atomic {
        pack.xData.datax.humtemp= data;
        state = STATE_INTHUMIDITY; 
        call IntHumidity.getData();
    }
    return SUCCESS;
  }
  
  event result_t TemperatureError.error(uint8_t token)
  {
    atomic {
        post reboot();
        pack.xData.datax.humtemp= 0xffff;
        state = STATE_INTHUMIDITY; 
        call IntHumidity.getData();
    }
    return SUCCESS;
  }
  
  async event result_t IntHumidity.dataReady(uint16_t data)
  {
    atomic {
        pack.xData.datax.inthum = data;
        state = STATE_INTTHERM;   
        call IntTemperature.getData();
    }
    return SUCCESS;
  }
  
   event result_t IntHumidityError.error(uint8_t token)
  {
    atomic {
        pack.xData.datax.inthum = 0xffff;
        state = STATE_INTTHERM;   
        call IntTemperature.getData();
    }
    return SUCCESS;
  }
  
  async event result_t IntTemperature.dataReady(uint16_t data)
  {	
    atomic {
        pack.xData.datax.inttemp = data;
        post HumStop();
        post IntHumStop();
        state = STATE_CALIBRATION;	
        post IntersemaStart();
    }  
    return SUCCESS;
  }
  
  
  event result_t IntTemperatureError.error(uint8_t token)
  {
    atomic {
        pack.xData.datax.inttemp = 0xffff;
        post HumStop();
        post IntHumStop();
        state = STATE_CALIBRATION;	
        call IntersemaControl.start();
    } 
    
    return SUCCESS;
  }
  
  
    event result_t IntersemaControl.startDone() {
    atomic {
        count = 0;
        atomic state = STATE_CALIBRATION;
        call Calibration.getData();
    }
    return SUCCESS;
  }
  
    event result_t Calibration.dataReady(char word, uint16_t value) {
    // make sure we get all the calibration bytes
    atomic {
        count++;
        calibration[word-1] = value;
    
        if (count >= 4) {
        	pack.xData.datax.presscalib[0] = calibration[0];
        	pack.xData.datax.presscalib[1] = calibration[1];
        	pack.xData.datax.presscalib[2] = calibration[2];
        	pack.xData.datax.presscalib[3] = calibration[3];
    
    	    atomic state = STATE_PRESSURE;
            call Pressure.getData();
        }
    }
    return SUCCESS;
  }

  event result_t PressureError.error(uint8_t token) {
	atomic {
        pack.xData.datax.press=0xffff;
        state = STATE_TEMP;
        call IntersemaTemperature.getData();
    }
    return SUCCESS;
  }
  
  async event result_t Pressure.dataReady(uint16_t data)
  {
	atomic {
        pack.xData.datax.press=data;
        state = STATE_TEMP;
        call IntersemaTemperature.getData();
    }
    return SUCCESS;
  }


  task void stopPressureControl()
  {
    //atomic sensor_state = SENSOR_PRESSURE_STOP;
    call IntersemaControl.stop();
    return;
  }
 
  event result_t IntersemaTemperatureError.error(uint8_t token)
  {
	//call IntersemaControl.stop();
	atomic {
        pack.xData.datax.prtemp=0xffff;
    	post stopPressureControl();
        nextpacket = 1;      // The No.10 packet for MEP401
       	post send_radio_msg();                                  //post uart xmit
       	post stop();
        waitn(50);
    	atomic state = STATE_START;
    }
    call Leds.greenOn();
    return SUCCESS;
  }
  
  

  async event result_t IntersemaTemperature.dataReady(uint16_t data)
  {
	//call IntersemaControl.stop();
	atomic {
        pack.xData.datax.prtemp=data;
    	post stopPressureControl();
        nextpacket = 1;      // The No.10 packet for MEP401
       	post send_radio_msg();           
       	post stop();
        waitn(50);
    	atomic state = STATE_START;
    }
    call Leds.greenOn();
    return SUCCESS;
  }
  

#if FEATURE_UART_SEND
 /**
  * Handle completion of sent UART packet.
  *
  * @author    Martin Turon
  * @version   2004/7/21      mturon       Initial revision
  */
  event result_t SendUART.sendDone(TOS_MsgPtr msg, result_t success) 
  {
      //      if (msg->addr == TOS_UART_ADDR) {
      atomic msg_ptr = msg;
      msg_ptr->addr = TOS_BCAST_ADDR;
      
      if (call Send.send(BASE_STATION_ADDRESS,MODE_UPSTREAM,msg_ptr, sizeof(XDataMsg)) != SUCCESS) {
	  atomic sending_packet = FALSE;
	  call Leds.yellowOff();
      }
      
      if (TOS_LOCAL_ADDRESS != 0) // never turn on power mgr for base
	  call PowerMgrEnable();
      
      //}
      return SUCCESS;
  }
#endif

 /**
  * Handle completion of sent RF packet.
  *
  * @author    Martin Turon
  * @version   2004/5/27      mturon       Initial revision
  */
  event result_t Send.sendDone(TOS_MsgPtr msg, result_t success) 
  {
      atomic {
	  msg_ptr = msg;
	  sending_packet = FALSE;
      }
      call Leds.yellowOff();
      packetcnt=0;
      
#if FEATURE_UART_SEND
      if (TOS_LOCAL_ADDRESS != 0) // never turn on power mgr for base
	  call PowerMgrEnable();
#endif
      
      return SUCCESS;
  }

 /** 
  * Handles all broadcast command messages sent over network. 
  *
  * NOTE: Bcast messages will not be received if seq_no is not properly
  *       set in first two bytes of data payload.  Also, payload is 
  *       the remaining data after the required seq_no.
  *
  * @version   2004/10/5   mturon     Initial version
  */
  event result_t XCommand.received(XCommandOp *opcode) {

      switch (opcode->cmd) {
	  case XCOMMAND_SET_RATE:
	      // Change the data collection rate.
	      timer_rate = opcode->param.newrate;
	      call Timer.stop();
	      call Timer.start(TIMER_REPEAT, timer_rate);
	      break;
	      
	  case XCOMMAND_SLEEP:
	      // Stop collecting data, and go to sleep.
	      sleeping = TRUE;
	      call Timer.stop();
	      call Leds.set(0);
              break;
	      
	  case XCOMMAND_WAKEUP:
	      // Wake up from sleep state.
	      if (sleeping) {
		  initialize();
		  call Timer.start(TIMER_REPEAT, timer_rate);
		  sleeping = FALSE;
	      }
	      break;
	      
	  case XCOMMAND_RESET:
	      // Reset the mote now.
	      break;

	  case XCOMMAND_ACTUATE: 
	      break;	      

	  default:
	      break;
      }    
      
      return SUCCESS;
  }

   event result_t XEEControl.restoreDone(result_t result)
   {
   		if(result) {
   				call Timer.stop();
	      		call Timer.start(TIMER_REPEAT, timer_rate);
   		}
 	 return SUCCESS;
   }  

    
}

