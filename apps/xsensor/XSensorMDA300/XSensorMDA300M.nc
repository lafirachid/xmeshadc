/*
 * Copyright (c) 2004-2007 Crossbow Technology, Inc.
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: XSensorMDA300M.nc,v 1.3.4.1 2007/04/26 20:25:53 njain Exp $
 */

/** 
 * XSensor single-hop application for MDA300 sensorboard.
 *
 *    - Tests the MDA300 general prototyping card 
 *       (see Crossbow MTS Series User Manual)
 *    -  Read and control all MDA300 signals:
 *      ADC0, ADC1, ADC2, ADC3,...ADC11 inputs, DIO 0-5, 
 *      counter, battery, humidity, temp
 *-----------------------------------------------------------------------------
 * Output results through mica2 uart and radio. 
 * Use xlisten.exe program to view data from either port:
 *  uart: mount mica2 on mib510 with MDA300 
 *              (must be connected or now data is read)
 *        connect serial cable to PC
 *        run xlisten.exe at 57600 baud
 *  radio: run mica2 with MDA300, 
 *         run another mica2 with TOSBASE
 *         run xlisten.exe at 56K baud
 * LED: the led will be green if the MDA300 is connected to the mica2 and 
 *      the program is running (and sending out packets).  Otherwise it is red.
 *-----------------------------------------------------------------------------
 *
 * @author Martin Turon, Alan Broad, Hu Siquan, Pi Peng
 */


/******************************************************************************
 * Data packet structure:
 * 
 * PACKET #1 (of 4)
 * ----------------
 *  msg->data[0] : sensor id, MDA300 = 0x81
 *  msg->data[1] : packet number = 1
 *  msg->data[2] : node id
 *  msg->data[3] : reserved
 *  msg->data[4,5] : analog adc data Ch.0
 *  msg->data[6,7] : analog adc data Ch.1
 *  msg->data[8,9] : analog adc data Ch.2
 *  msg->data[10,11] : analog adc data Ch.3
 *  msg->data[12,13] : analog adc data Ch.4
 *  msg->data[14,15] : analog adc data Ch.5
 *  msg->data[16,17] : analog adc data Ch.6
 * 
 * PACKET #2 (of 4)
 * ----------------
 *  msg->data[0] : sensor id, MDA300 = 0x81
 *  msg->data[1] : packet number = 2
 *  msg->data[2] : node id
 *  msg->data[3] : reserved
 *  msg->data[4,5] : analog adc data Ch.7
 *  msg->data[6,7] : analog adc data Ch.8
 *  msg->data[8,9] : analog adc data Ch.9
 *  msg->data[10,11] : analog adc data Ch.10
 *  msg->data[12,13] : analog adc data Ch.11
 *  msg->data[14,15] : analog adc data Ch.12
 *  msg->data[16,17] : analog adc data Ch.13
 *
 * 
 * PACKET #3 (of 4)
 * ----------------
 *  msg->data[0] : sensor id, MDA300 = 0x81
 *  msg->data[1] : packet number = 3
 *  msg->data[2] : node id
 *  msg->data[3] : reserved
 *  msg->data[4,5] : digital data Ch.0
 *  msg->data[6,7] : digital data Ch.1
 *  msg->data[8,9] : digital data Ch.2
 *  msg->data[10,11] : digital data Ch.3
 *  msg->data[12,13] : digital data Ch.4
 *  msg->data[14,15] : digital data Ch.5
 *
 * PACKET #4 (of 4)
 * ----------------
 *  msg->data[0] : sensor id, MDA300 = 0x81
 *  msg->data[1] : packet number = 4
 *  msg->data[2] : node id
 *  msg->data[3] : reserved
 *  msg->data[4,5] : batt
 *  msg->data[6,7] : hum
 *  msg->data[8,9] : temp
 *  msg->data[10,11] : counter
 *  msg->data[14] : msg4_status (debug)
 * 
 ***************************************************************************/

// include sensorboard.h definitions from tos/mda300 directory
#include "appFeatures.h"
includes sensorboard;

module XSensorMDA300M
{
  
    provides interface StdControl;
  
    uses {
	interface Leds;

	//Sampler Communication
	interface StdControl as SamplerControl;
	interface Sample;

//communication
	interface StdControl as CommControl;
	interface SendMsg as Send;
	interface ReceiveMsg as Receive;
    
	//Timer
	interface Timer;
    
	//relays
	interface Relay as relay_normally_closed;
	interface Relay as relay_normally_open;   
    
	//support for plug and play
	command result_t PlugPlay();
    }
}


implementation
{ 	
#define ANALOG_SAMPLING_TIME    90
#define DIGITAL_SAMPLING_TIME  100
#define MISC_SAMPLING_TIME     110

#define ANALOG_SEND_FLAG  1
#define DIGITAL_SEND_FLAG 1
#define MISC_SEND_FLAG    1
#define ERR_SEND_FLAG     1

#define PACKET1_FULL	0x7F
#define PACKET2_FULL	0x7F
#define PACKET3_FULL	0x3F
#define PACKET4_FULL	0x0F

#define MSG_LEN  29   // excludes TOS header, but includes xbow header
    
    enum {
	PENDING = 0,
	NO_MSG = 1
    };        

    enum {
	MDA300_PACKET1 = 1,
	MDA300_PACKET2 = 2,
	MDA300_PACKET3 = 3,
	MDA300_PACKET4 = 4,
	MDA300_ERR_PACKET = 0xf8	
    };

/******************************************************
    enum {
	SENSOR_ID = 0,
	PACKET_ID, 
	NODE_ID,
	RESERVED,
	DATA_START
    } XPacketDataEnum;
******************************************************/	
    /* Messages Buffers */	
	XDataMsg *pack, *tmppack;

    TOS_Msg packet[5];
    TOS_Msg msg_send_buffer;    
    TOS_MsgPtr msg_ptr;
    


    uint8_t pkt_send_order[4];
    uint8_t next_packet, old_packet;
    uint8_t packet_ready;
    bool    sending_packet, bIsUart;
    uint8_t msg_status[5], pkt_full[5];
    char test;

    int8_t record[25];
 
/****************************************************************************
 * Initialize the component. Initialize Leds
 *
 ****************************************************************************/
    command result_t StdControl.init() {
        
	uint8_t i;

	call Leds.init();
        
	atomic {
	    msg_ptr = &msg_send_buffer;
	    pack=(XDataMsg *)msg_ptr->data;

	    pkt_send_order[0] = 1;
	    pkt_send_order[1] = 2;
	    pkt_send_order[2] = 3;
	    pkt_send_order[3] = 4;

	    packet_ready = 0;
	    next_packet = 0;
        old_packet=pkt_send_order[3];
	    sending_packet = FALSE;
	}
	for (i=1; i<=4; i++) 
	    msg_status[i] = 0;
	pkt_full[1] = PACKET1_FULL;
	pkt_full[2] = PACKET2_FULL;
	pkt_full[3] = PACKET3_FULL;
	pkt_full[4] = PACKET4_FULL;

    call SamplerControl.init();
    call CommControl.init();
    return SUCCESS;
            
	//return rcombine(call SamplerControl.init(), call CommControl.init());
    }


 
/****************************************************************************
 * Start the component. Start the clock. Setup timer and sampling
 *
 ****************************************************************************/
    command result_t StdControl.start() {

        
	call SamplerControl.start();
        
	call CommControl.start();

    pack->xSensorHeader.board_id = SENSOR_BOARD_ID;
	pack->xSensorHeader.node_id = TOS_LOCAL_ADDRESS;
	pack->xSensorHeader.rsvd = 0;
    
	if(call PlugPlay())
	{
            
	    call Timer.start(TIMER_REPEAT, 3000);
            
            
	    //channel parameteres are irrelevent
            
	    record[14] = call Sample.getSample(0,TEMPERATURE,MISC_SAMPLING_TIME,SAMPLER_DEFAULT);
            
	    record[15] = call Sample.getSample(0,HUMIDITY,MISC_SAMPLING_TIME,SAMPLER_DEFAULT);
            
	    record[16] = call Sample.getSample(0, BATTERY,MISC_SAMPLING_TIME,SAMPLER_DEFAULT);

            
	    //start sampling  channels. Channels 7-10 with averaging since they are more percise.channels 3-6 make active excitation    
	    record[0] = call Sample.getSample(0,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT | EXCITATION_33);

	    record[1] = call Sample.getSample(1,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT );
            
	    record[2] = call Sample.getSample(2,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT);
            
	    record[3] = call Sample.getSample(3,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT | EXCITATION_33 | DELAY_BEFORE_MEASUREMENT);
            
	    record[4] = call Sample.getSample(4,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT);
            
	    record[5] = call Sample.getSample(5,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT);
            
	    record[6] = call Sample.getSample(6,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT);
            
	    record[7] = call Sample.getSample(7,ANALOG,ANALOG_SAMPLING_TIME,AVERAGE_FOUR | EXCITATION_25);
            
	    record[8] = call Sample.getSample(8,ANALOG,ANALOG_SAMPLING_TIME,AVERAGE_FOUR | EXCITATION_25);
            
	    record[9] = call Sample.getSample(9,ANALOG,ANALOG_SAMPLING_TIME,AVERAGE_FOUR | EXCITATION_25);
            
	    record[10] = call Sample.getSample(10,ANALOG,ANALOG_SAMPLING_TIME,AVERAGE_FOUR | EXCITATION_25);
         
	    record[11] = call Sample.getSample(11,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT);
            
	    record[12] = call Sample.getSample(12,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT);
            
	    record[13] = call Sample.getSample(13,ANALOG,ANALOG_SAMPLING_TIME,SAMPLER_DEFAULT | EXCITATION_50 | EXCITATION_ALWAYS_ON);                                
                        
            
	    //digital chennels as accumulative counter                
            
	    record[17] = call Sample.getSample(0,DIGITAL,DIGITAL_SAMPLING_TIME,DIG_LOGIC | EVENT);
            
	    record[18] = call Sample.getSample(1,DIGITAL,DIGITAL_SAMPLING_TIME,DIG_LOGIC | EVENT);
            
	    record[19] = call Sample.getSample(2,DIGITAL,DIGITAL_SAMPLING_TIME,DIG_LOGIC | EVENT);
            
	    record[20] = call Sample.getSample(3,DIGITAL,DIGITAL_SAMPLING_TIME,DIG_LOGIC | EVENT);
            
	    record[21] = call Sample.getSample(4,DIGITAL,DIGITAL_SAMPLING_TIME,DIG_LOGIC | EVENT);
            
	    record[22] = call Sample.getSample(5,DIGITAL,DIGITAL_SAMPLING_TIME,DIG_LOGIC | EVENT);                                
            
	    //counter channels for frequency measurement, will reset to zero.
            
	    record[23] = call Sample.getSample(0, COUNTER,MISC_SAMPLING_TIME,RESET_ZERO_AFTER_READ | RISING_EDGE);
	    call Leds.greenOn();          
	}
        
	else {
	    call Leds.redOn();
	}
        
	return SUCCESS;
    
    }
    
/****************************************************************************
 * Stop the component.
 *
 ****************************************************************************/
 
    command result_t StdControl.stop() {
        
 	call SamplerControl.stop();
    call CommControl.stop();
    
 	return SUCCESS;
    
    }


/****************************************************************************
 * Task to uart as message
 *
 ****************************************************************************/
    task void send_uart_msg(){
	uint8_t i;
    if(sending_packet)
        return;
	atomic sending_packet = TRUE;
    call Leds.yellowToggle();
    tmppack=(XDataMsg *)packet[next_packet].data;  
	for (i = 4; i <= MSG_LEN-1; i++) 
	    ((uint8_t*)pack)[i] = ((uint8_t*)tmppack)[i];
    pack->xSensorHeader.packet_id = next_packet;
	call Send.send(TOS_UART_ADDR,sizeof(XDataMsg),msg_ptr);

    }

/****************************************************************************
 * Task to transmit radio message
 * NOTE that data payload was already copied from the corresponding UART packet
 ****************************************************************************/
    task void send_radio_msg() 
	{
//	    uint8_t i;
	    if(sending_packet)
          return;
        atomic sending_packet=TRUE;
        call Leds.yellowToggle();
        call Send.send(TOS_BCAST_ADDR,sizeof(XDataMsg),msg_ptr);

	}

/****************************************************************************
 * if Uart msg xmitted,Xmit same msg over radio
 * if Radio msg xmitted, issue a new round measuring
 ****************************************************************************/
  event result_t Send.sendDone(TOS_MsgPtr msg, result_t success) {
      //atomic msg_uart = msg;
	  sending_packet = FALSE;
      if(bIsUart)
      {
        bIsUart=!bIsUart;
        post send_radio_msg();
        packet_ready &= ~(1 << (next_packet - 1));
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


 
/**
 * Handle a single dataReady event for all MDA300 data types. 
 * 
 * @author    Leah Fera, Martin Turon
 *
 * @version   2004/3/17       leahfera    Intial revision
 * @n         2004/4/1        mturon      Improved state machine
 */
    event result_t 
	Sample.dataReady(uint8_t channel,uint8_t channelType,uint16_t data)
	{          
	    uint8_t i;

	    switch (channelType) {
		case ANALOG:              
		    switch (channel) {		  
			// MSG 1 : first part of analog channels (0-6)
			case 0:
                tmppack=(XDataMsg *)packet[1].data;
			    tmppack->xData.datap1.analogCh0 =data ;
			    atomic {msg_status[1] |=0x01;}
			    break;

			case 1:   
                tmppack=(XDataMsg *)packet[1].data;
			    tmppack->xData.datap1.analogCh1 =data ;
			    atomic {msg_status[1] |=0x02;}
			    break;
             
			case 2:
                tmppack=(XDataMsg *)packet[1].data;
			    tmppack->xData.datap1.analogCh2 =data ;
			    atomic {msg_status[1] |=0x04;}
			    break;
              
			case 3:
                tmppack=(XDataMsg *)packet[1].data;
			    tmppack->xData.datap1.analogCh3 =data ;
			    atomic {msg_status[1] |=0x08;}
			    break;
              
			case 4:
                tmppack=(XDataMsg *)packet[1].data;
			    tmppack->xData.datap1.analogCh4 =data ;
			    atomic {msg_status[1] |=0x10;}
			    break;
              
			case 5:
                tmppack=(XDataMsg *)packet[1].data;
			    tmppack->xData.datap1.analogCh5 =data ;
			    atomic {msg_status[1] |=0x20;}
			    break;
              
			case 6:
                tmppack=(XDataMsg *)packet[1].data;
			    tmppack->xData.datap1.analogCh6 =data ;
			    atomic {msg_status[1]|=0x40;}
			    break;

			    // MSG 2 : second part of analog channels (7-13)
            case 7:
                tmppack=(XDataMsg *)packet[2].data;
			    tmppack->xData.datap2.analogCh7 =data ;
			    atomic {msg_status[2]|=0x01;}
			    break;

            case 8:
                tmppack=(XDataMsg *)packet[2].data;
			    tmppack->xData.datap2.analogCh8 =data ;
			    atomic {msg_status[2]|=0x02;}
			    break;
              
			case 9:
                tmppack=(XDataMsg *)packet[2].data;
			    tmppack->xData.datap2.analogCh9 =data ;
			    atomic {msg_status[2]|=0x04;}
			    break;
              
			case 10:
                tmppack=(XDataMsg *)packet[2].data;
			    tmppack->xData.datap2.analogCh10 =data ;
			    atomic {msg_status[2]|=0x08;}
			    break;
             
			case 11:
                tmppack=(XDataMsg *)packet[2].data;
			    tmppack->xData.datap2.analogCh11 =data ;
			    atomic {msg_status[2]|=0x10;}
			    break;
              
			case 12:
                tmppack=(XDataMsg *)packet[2].data;
			    tmppack->xData.datap2.analogCh12 =data ;
			    atomic {msg_status[2]|=0x20;}
			    break;
              
			case 13:
                tmppack=(XDataMsg *)packet[2].data;
			    tmppack->xData.datap2.analogCh13 =data ;
			    atomic {msg_status[2]|=0x40;}
			    break;
              
			default:
			    break;
		    }  // case ANALOG (channel) 
		    break;
          
		case DIGITAL:
		    switch (channel) {             
			case 0:
                tmppack=(XDataMsg *)packet[3].data;

			    tmppack->xData.datap3.digitalCh0=data;
			    atomic {msg_status[3]|=0x01;}
			    break;
              
			case 1:
                tmppack=(XDataMsg *)packet[3].data;
			    tmppack->xData.datap3.digitalCh1=data;
			    atomic {msg_status[3]|=0x02;}
			    break;
            
			case 2:
                tmppack=(XDataMsg *)packet[3].data;
			    tmppack->xData.datap3.digitalCh2=data;
			    atomic {msg_status[3]|=0x04;}
			    break;
              
			case 3:
                tmppack=(XDataMsg *)packet[3].data;
			    tmppack->xData.datap3.digitalCh3=data;
			    atomic {msg_status[3]|=0x08;}
			    break;
              
			case 4:
                tmppack=(XDataMsg *)packet[3].data;
			    tmppack->xData.datap3.digitalCh4=data;
			    atomic {msg_status[3]|=0x10;}
			    break;
              
			case 5:
                tmppack=(XDataMsg *)packet[3].data;
			    tmppack->xData.datap3.digitalCh5=data;
			    atomic {msg_status[3]|=0x20;}
			    break;
              
			default:
			    break;
		    }  // case DIGITAL (channel)
		    break;

		case BATTERY:            
            tmppack=(XDataMsg *)packet[4].data;
		    tmppack->xData.datap4.batt=data ;            
		    atomic {msg_status[4]|=0x01;}
		    break;
          
		case HUMIDITY:            
            tmppack=(XDataMsg *)packet[4].data;
		    tmppack->xData.datap4.hum=data ;            
		    atomic {msg_status[4]|=0x02;}
		    break;
                    
		case TEMPERATURE:          
            tmppack=(XDataMsg *)packet[4].data;
		    tmppack->xData.datap4.temp=data ;            
		    atomic {msg_status[4]|=0x04;}
		    break;

		case COUNTER:
            tmppack=(XDataMsg *)packet[4].data;
		    tmppack->xData.datap4.counter=data ;            
		    atomic {msg_status[4]|=0x08;}
		    break;  

		default:
		    break;

	    }  // switch (channelType) 

	    atomic {            
		for (i=1; i<=4; i++) {
		    if (sending_packet)
                        // avoid posting uart_send-Task while one is in process
			break; 
            
		    next_packet = pkt_send_order[0];

		    pkt_send_order[0] = pkt_send_order[1];
		    pkt_send_order[1] = pkt_send_order[2];
		    pkt_send_order[2] = pkt_send_order[3];
		    pkt_send_order[3] = next_packet;
            if(((old_packet%4)+1)!=next_packet)
                break;
		    if (msg_status[next_packet] == pkt_full[next_packet]) {
			msg_status[next_packet] = 0;
			packet_ready |= 1 << (next_packet - 1);
		    post send_uart_msg();
            old_packet = next_packet;
			break;
		    } 
		}
	    }
          
	    return SUCCESS;      
	}
  
/****************************************************************************
 * Timer Fired - 
 *
 ****************************************************************************/
    event result_t Timer.fired() {
    bIsUart=TRUE;  
 	if (test != 0)  {
	    test=0;
	    call relay_normally_closed.toggle();
        call Leds.greenOn();
 	}
	else  {
	    test=1;
	    call relay_normally_open.toggle();
        call Leds.greenOn();
 	}

	return SUCCESS;
  
    }

}
