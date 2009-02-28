/*
 * Copyright (c) 2002-2005 Intel Corporation
 * Copyright (c) 2000-2005 The Regents of the University of California
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: MicaHighSpeedRadioM.nc,v 1.1.4.1 2007/04/26 00:29:10 njain Exp $
 */


includes TimeSyncMsg;
includes TosTime;
includes crc;

module MicaHighSpeedRadioM
{
  provides {
    interface StdControl as Control;
    interface BareSendMsg as Send;
    interface ReceiveMsg as Receive;
    interface RadioCoordinator as RadioSendCoordinator;
    interface RadioCoordinator as RadioReceiveCoordinator;
    interface TinySecRadio;
  }
  uses {
    interface RadioEncoding as Code;
    interface Random;
    interface SpiByteFifo;
    interface ChannelMon;
    interface RadioTiming;
    interface Time;
    interface PowerManagement;
    interface TinySec;
    interface Leds;
  }
}
implementation
{
  enum { //states
    IDLE_STATE,
    SEND_WAITING,
    HEADER_RX_STATE,
    RX_STATE_TINYSEC,
    RX_STATE,
    TRANSMITTING,
    TRANSMITTING_TINYSEC,
    WAITING_FOR_ACK,
    SENDING_STRENGTH_PULSE,
    TRANSMITTING_START,
    RX_DONE_STATE,
    ACK_SEND_STATE,
    STOPPED_STATE
  };

  enum {
    ACK_CNT = 4,
    ENCODE_PACKET_LENGTH_DEFAULT  = MSG_DATA_SIZE*3
  };


  //static char start[3] = {0xab, 0x34, 0xd5}; //10 Kbps
  //static char start[6] = {0xcc, 0xcf, 0x0f, 0x30, 0xf3, 0x33}; //20 Kbps
  // The C attribute is used here because we are not currently supporting
  // intialisers on module variables (because tossim makes it tricky)
  char TOSH_MHSR_start[12] __attribute((C)) = 
    {0xf0, 0xf0, 0xf0, 0xff, 0x00, 0xff, 0x0f, 0x00, 0xff, 0x0f, 0x0f, 0x0f}; //40 Kbps

  char state;
  char send_state;
  char tx_count;
  uint16_t calc_crc;
  uint8_t ack_count;
  char rec_count;
  TOS_Msg_TinySecCompat buffer;
  TOS_Msg_TinySecCompat* rec_ptr;
  TOS_Msg_TinySecCompat* send_ptr;
  unsigned char rx_count;
  char msg_length;
  char buf_head;
  char buf_end;
  char encoded_buffer[4];
  char enc_count;
  char decode_byte;
  char code_count;
  char timeSyncFlag;

  bool tx_done;
  bool tinysec_rx_done;

  /**** TinySec ****/
  void swapLengthAndGroup(TOS_Msg* buf) {
    uint8_t tmp = buf->group;

    ((TOS_Msg_TinySecCompat*) buf)->length = buf->length;
    ((TOS_Msg_TinySecCompat*) buf)->group = tmp;

  }
  /**** TinySec ****/
  
  task void packetReceived(){
    TOS_MsgPtr tmp;

    atomic {
      /**** TinySec ****/
      tmp = (TOS_MsgPtr) rec_ptr;
      swapLengthAndGroup(tmp);
      /**** TinySec ****/
      state = IDLE_STATE;
    }
    tmp = signal Receive.receive(tmp);
    if(tmp != 0) {
      atomic {
	rec_ptr = (TOS_Msg_TinySecCompat*) tmp;
      }
    }
    call ChannelMon.startSymbolSearch();
  }

  task void packetSent(){
    TOS_MsgPtr ptr;
    atomic {
      send_state = IDLE_STATE;
      state = IDLE_STATE;
      /**** TinySec ****/
      swapLengthAndGroup((TOS_Msg*) send_ptr);
      /**** TinySec ****/
      ptr = (TOS_MsgPtr) send_ptr;
    }
    call ChannelMon.startSymbolSearch();
    signal Send.sendDone(ptr, SUCCESS);
  }


  command result_t Send.send(TOS_MsgPtr msg) {
    uint8_t oldSendState;
    atomic {
      oldSendState = send_state;
      if (send_state == IDLE_STATE) {
	send_state = SEND_WAITING;
	/**** TinySec ****/
	swapLengthAndGroup(msg);
	send_ptr = (TOS_Msg_TinySecCompat*) msg;
	tx_done = FALSE;
        /**** TinySec ****/
	tx_count = 1;
      }
    }

    if(oldSendState == IDLE_STATE){
      return call ChannelMon.macDelay();
    }else{
      return FAIL;
    }
  }

    /* Initialization of this component */
  command result_t Control.init() {
    atomic {
      rec_ptr = &buffer;
      send_state = IDLE_STATE;
      state = IDLE_STATE;
      tx_done = FALSE;
      tinysec_rx_done = FALSE;
    }
    return rcombine(call ChannelMon.init(), call Random.init());
    // TODO:  TOSH_RF_COMM_ADC_INIT();
  } 

  /* Command to control the power of the network stack */
  command result_t Control.start() {
    uint8_t oldState;
    result_t rval = SUCCESS;
    atomic {
      oldState = state;
      if (state == STOPPED_STATE) {
        state = IDLE_STATE;
        send_state = IDLE_STATE;
        call PowerManagement.adjustPower();
        rval = call ChannelMon.startSymbolSearch();	    
      }
    }
    
    return rval;
  }

  /* Command to control the power of the network stack */
  command result_t Control.stop() {
    TOS_MsgPtr ptr = NULL;
    result_t ret = rcombine(call ChannelMon.stopMonitorChannel(),
			    call SpiByteFifo.idle());
    if (ret == SUCCESS) {
      bool sigDone = FALSE;
      atomic {
	call PowerManagement.adjustPower();
	state = STOPPED_STATE;
	if ((send_state != IDLE_STATE) && (send_state != STOPPED_STATE)) {
	  send_state = STOPPED_STATE;
	  sigDone = TRUE;
	  ptr = (TOS_MsgPtr)send_ptr;
	}
	send_state = STOPPED_STATE;
      }
      if (sigDone) {
	signal Send.sendDone(ptr, FAIL);
      }
      return SUCCESS;
    }
    return ret;
  }
  
  async event result_t TinySec.sendDone(result_t result) {
    atomic {
      tx_done = TRUE;
    }
    return SUCCESS;
  }

  async event result_t TinySec.receiveInitDone(result_t result,
					       uint16_t length,
					       bool ts_enabled) {
    atomic {
      msg_length = length;
      tinysec_rx_done = FALSE;
      if(result == SUCCESS) {
	if(ts_enabled) {
	  state = RX_STATE_TINYSEC;
	} else {
	  state = RX_STATE;
	  // set tinysec_rx_done to TRUE to force post of packetReceived
	  // in ACK_SEND_STATE below.
	  tinysec_rx_done = TRUE;
	}
      } else {
	rec_ptr->length = 0;
	state = IDLE_STATE;
      }
    }
    return SUCCESS;
  }

  async event result_t TinySec.receiveDone(result_t result) {
    atomic {
      if(state == RX_DONE_STATE) {
	tinysec_rx_done = TRUE;
	post packetReceived();
      } else {
	tinysec_rx_done = TRUE;
      }
    }
    return SUCCESS;
  }

  // Handles the latest decoded byte propagated by the Byte Level component
  async event result_t ChannelMon.startSymDetect() {
    uint16_t tmp;
    //TOSH_SET_GREEN_LED_PIN();
    atomic {
      ack_count = 0;
      rec_count = 0;
      state = HEADER_RX_STATE;
    }
    tmp = call RadioTiming.getTiming();
//TOSH_CLR_GREEN_LED_PIN();
    call SpiByteFifo.startReadBytes(tmp);
    atomic {
      msg_length = MSG_DATA_SIZE - 2;
      calc_crc = 0;
      rec_ptr->time = tmp;
      rec_ptr->strength = 0;
    }
    signal RadioReceiveCoordinator.startSymbol(8, 0, (TOS_MsgPtr) rec_ptr);
    /**** TinySec ****/
    call TinySec.receiveInit(rec_ptr);
    /**** TinySec ****/
    return SUCCESS;
  }

  /* See below (at call point) why this was moved into a separate
     function. Basically, register spill/inlining/timing issues. -pal */
  void timeSyncFunctionHack() {
    struct TimeSyncMsg * ptr;
    tos_time_t tt;
    // this is a time sync msg
    ptr = (struct TimeSyncMsg *)send_ptr->data;
    tt = call Time.get();
    //TOSH_CLR_GREEN_LED_PIN();
    ptr->timeH = tt.high32;
    ptr->timeL = tt.low32;
    ptr->phase = call Time.getUs();
  }

  async event result_t ChannelMon.idleDetect() {
    uint8_t firstSSByte;
    uint8_t firstMsgByte;
    uint16_t timeVal;
    uint16_t tmpCrc;
    uint8_t oldSendState;

    atomic {
      oldSendState = send_state;
      if (send_state == SEND_WAITING) {
	send_state = IDLE_STATE;
	state = TRANSMITTING_START;
      }
    }
    
    if (oldSendState == SEND_WAITING){
      atomic {
        firstMsgByte = ((char*)send_ptr)[0];
        firstSSByte = TOSH_MHSR_start[0];

        buf_end = buf_head = 0;
        enc_count = 0;
        call Code.encode(firstMsgByte);
	rx_count = 0;
        /**** TinySec ****/
        if(send_ptr->length & TINYSEC_ENABLED_BIT) {
	  msg_length = call TinySec.sendInit(send_ptr);
	} else {
	  msg_length = (unsigned char)(send_ptr->length) +
	    MSG_DATA_SIZE - DATA_LENGTH - 2;
	}
        /**** TinySec ****/
	
	/* In the original MicaHighSpeedRadioM, the TimeSync operations
	   were in the handler itself. This causes problems with
	   atomic sections: the large structure allocated by the function
	   causes a lot of registers to spill, making the above
	   initialization code a lot slower. When the time sync code
	   was in this function, the radio stack stopped working.

	   So, I've put it in a separate function, which gets its own
	   stack space, etc. However, nesC loves inlining things,
	   which returns us to the original problem. To prevent inlining,
	   the function has to have two call points: in this case,
	   one of them is never executed (the else if (0) statement).
	   Yay embedded programming. -pal
	*/
	if (send_ptr->type == AM_TIMESYNCMSG) {
	  timeSyncFunctionHack();
	}
	else if (0) {
	  timeSyncFunctionHack();
	}
      }
      // end of timesync change 
      
      call SpiByteFifo.send(firstSSByte);
      timeVal = call RadioTiming.currentTime();
      tmpCrc = crcByte(0x00, firstMsgByte);
      atomic {
        send_ptr->time = timeVal;
        calc_crc = tmpCrc;
      }
    }
    signal RadioSendCoordinator.startSymbol(8, 0, (TOS_MsgPtr) send_ptr);
    /**** TinySec ****/
    if(send_ptr->length & TINYSEC_ENABLED_BIT) {
      call TinySec.send();
    }
    /**** TinySec ****/
    return 1;
  } 

  async event result_t Code.decodeDone(char data, char error){
    result_t rval = SUCCESS;
    atomic {
      if(state == IDLE_STATE){
	rval = FAIL;
      }
      else if (state == HEADER_RX_STATE) {
	((char*)rec_ptr)[(int)rec_count] = data;
	rec_count++;
	calc_crc = crcByte(calc_crc, data);
	signal RadioReceiveCoordinator.byte((TOS_MsgPtr) rec_ptr,
					    (uint8_t)rec_count);
	signal TinySecRadio.byteReceived(data);
      }
      else if(state == RX_STATE){
	((char*)rec_ptr)[(int)rec_count] = data;
	rec_count++;
	if(rec_count >= MSG_DATA_SIZE){
	  // TODO:  TOSH_RF_COMM_ADC_GET_DATA(0);
	  if(calc_crc == rec_ptr->crc){
	    rec_ptr->crc = 1;
	    if(rec_ptr->addr == TOS_LOCAL_ADDRESS ||
	       rec_ptr->addr == TOS_BCAST_ADDR){
	      call SpiByteFifo.send(0x55);
	    }
	  }else{
	    rec_ptr->crc = 0;
	  }
	  state = ACK_SEND_STATE;
	  rval = 0;
	  signal RadioReceiveCoordinator.byte((TOS_MsgPtr) rec_ptr,
					      (uint8_t)rec_count);
	}
	else if(rec_count <= MSG_DATA_SIZE-2){
	  calc_crc = crcByte(calc_crc, data);
	  if(rec_count == msg_length){
	    rec_count = MSG_DATA_SIZE-2;
	  }
	}
      } else if(state == RX_STATE_TINYSEC) {
	uint8_t rec_count_save = ++rec_count;
	signal RadioReceiveCoordinator.byte((TOS_MsgPtr) rec_ptr,
					    (uint8_t)rec_count);
	signal TinySecRadio.byteReceived(data);
	if(rec_count_save == msg_length + TINYSEC_MAC_LENGTH) {
	  if(rec_ptr->crc == 1 &&
	     (rec_ptr->addr == TOS_LOCAL_ADDRESS ||
	      rec_ptr->addr == TOS_BCAST_ADDR)){
	    call SpiByteFifo.send(0x55);
	  }
	  state = ACK_SEND_STATE;
	}
      }
    }
    return rval;
  }

  async event result_t Code.encodeDone(char data1){
    atomic {
      encoded_buffer[(int)buf_end] = data1;
      buf_end ++;
      buf_end &= 0x3;
      enc_count += 1;
    }
    return SUCCESS;
  }

  async event result_t SpiByteFifo.dataReady(uint8_t data) {
    signal RadioSendCoordinator.blockTimer();
    signal RadioReceiveCoordinator.blockTimer();
    atomic {
      if(state == TRANSMITTING_START){
	call SpiByteFifo.send(TOSH_MHSR_start[(int)tx_count]);
	tx_count ++;
	if(tx_count == sizeof(TOSH_MHSR_start)){
	  if(send_ptr->length & TINYSEC_ENABLED_BIT) {
	    // just a dummy call. first byte already encoded
	    signal TinySecRadio.getTransmitByte();
	    state = TRANSMITTING_TINYSEC;
	  }
	  else {
	    state = TRANSMITTING;
	  }
	  tx_count = 1;
	}
      }else if(state == TRANSMITTING){
	call SpiByteFifo.send(encoded_buffer[(int)buf_head]);
	buf_head ++;
	buf_head &= 0x3;
	enc_count --;
	//now check if that was the last byte.
	
	if(enc_count >= 2){
	  ;
	}else if(tx_count < MSG_DATA_SIZE){ 
	  char next_data = ((char*)send_ptr)[(int)tx_count];
	  call Code.encode(next_data);
	  tx_count ++;
	  if(tx_count <= msg_length){
	    calc_crc = crcByte(calc_crc, next_data);
	  }
	  if(tx_count == msg_length){
	    //the last 2 bytes must be the CRC and are
	    //transmitted regardless of the length.
	    tx_count = MSG_DATA_SIZE - 2;
	    send_ptr->crc = calc_crc;
	  }
	  signal RadioSendCoordinator.byte((TOS_MsgPtr) send_ptr,
					   (uint8_t)tx_count);
	}else if(buf_head != buf_end){
	  call Code.encode_flush();
	}else{
	  state = SENDING_STRENGTH_PULSE;
	  tx_count = 0;
	  tx_done = TRUE;
	}
      }else if(state == TRANSMITTING_TINYSEC) {
	call SpiByteFifo.send(encoded_buffer[(int)buf_head]);
	buf_head ++;
	buf_head &= 0x3;
	enc_count --;
	//now check if that was the last byte.

	if(enc_count >= 2){
	  ;
	}else if(tx_count < TINYSEC_MSG_DATA_SIZE){ 
	  uint8_t next_data = signal TinySecRadio.getTransmitByte();
	  call Code.encode(next_data);
	  tx_count ++;
	  if(tx_done){
	    tx_count = TINYSEC_MSG_DATA_SIZE;
	  }
	  signal RadioSendCoordinator.byte((TOS_MsgPtr) send_ptr,
					   (uint8_t)tx_count);
	}else if(buf_head != buf_end){
	  call Code.encode_flush();
	}else{
	  state = SENDING_STRENGTH_PULSE;
	  tx_count = 0;
	}
      }else if(state == SENDING_STRENGTH_PULSE){
	tx_count ++;
	if(tx_count == 3){
	  state = WAITING_FOR_ACK;
	  call SpiByteFifo.phaseShift();
	  tx_count = 1;
	  call SpiByteFifo.send(0x00);
	  
	}else{
	  call SpiByteFifo.send(0xff);
	  
	}
      }else if(state == WAITING_FOR_ACK){
	data &= 0x7f;
	call SpiByteFifo.send(0x00);
	if(tx_count == 1) 
	  call SpiByteFifo.rxMode();
	tx_count ++;  
	if(tx_count == ACK_CNT + 2) {
	  send_ptr->ack = (data == 0x55);
	  state = IDLE_STATE;
	  /* changes for timesync
	     if (timeSyncFlag) {
	     // clock phase reset
	     call Time.set(tt.high32, tt.low32);
	     timeSyncFlag =0;
	     } // end of change
	  */
	  //TOSH_CLR_GREEN_LED_PIN();
	  call SpiByteFifo.idle();
	  post packetSent();
	}
      }else if(state == RX_STATE ||
	       state == RX_STATE_TINYSEC ||
	       state == HEADER_RX_STATE){
	call Code.decode(data);
      }else if(state == ACK_SEND_STATE){
	ack_count ++;
	if(ack_count > ACK_CNT + 1){
	  state = RX_DONE_STATE;
	  call SpiByteFifo.idle();
	  // this is was set to TRUE for CRC packets
	  if(tinysec_rx_done) {
	    post packetReceived();
	  }
	}else{
	  call SpiByteFifo.txMode();
	}
      }
    }
    return 1; 
  }

#if 0
  char SIG_STRENGTH_READING(short data){
    atomic {
      rec_ptr->strength = data;
    }
    return 1;
  }
#endif


  // Default events for radio send/receive coordinators do nothing.
  // Be very careful using these, you'll break the stack.
  default async event void RadioSendCoordinator.startSymbol(uint8_t bitsPerBlock, uint8_t offset, TOS_MsgPtr msgBuff) { }
  default async event void RadioSendCoordinator.byte(TOS_MsgPtr msg, uint8_t byteCount) {}
  default async event void RadioSendCoordinator.blockTimer() { }
  default async event void RadioReceiveCoordinator.startSymbol(uint8_t bitsPerBlock, uint8_t offset, TOS_MsgPtr msgBuff) { }
  default async event void RadioReceiveCoordinator.byte(TOS_MsgPtr msg, uint8_t byteCount) {}
  default async event void RadioReceiveCoordinator.blockTimer() { }
}

