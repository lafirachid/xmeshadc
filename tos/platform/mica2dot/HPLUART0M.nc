/*
 * Copyright (c) 2002-2005 Intel Corporation
 * Copyright (c) 2000-2005 The Regents of the University of California
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: HPLUART0M.nc,v 1.1.4.3 2007/04/26 00:20:59 njain Exp $
 */
 
/*
 *
 * Authors:		Jason Hill, David Gay, Philip Levis
 * Date last modified:  $Revision: 1.1.4.3 $
 *
 */

// The hardware presentation layer. See hpl.h for the C side.
// Note: there's a separate C side (hpl.h) to get access to the avr macros

// The model is that HPL is stateless. If the desired interface is as stateless
// it can be implemented here (Clock, FlashBitSPI). Otherwise you should
// create a separate component


/**
 * @author Jason Hill
 * @author David Gay
 * @author Philip Levis
 */
module HPLUART0M {
  provides interface HPLUART as UART;

}
implementation
{
  async command result_t UART.init() {

    // Set baudrate to 19.2 KBps
    outp(0,UBRR0H);
    outp(12, UBRR0L);
    inp(UDR0); 

    // Disable U2X and MPCM
    outp(0,UCSR0A);

    // Set frame format: 8 data-bits, 1 stop-bit
    outp(((1 << UCSZ1) | (1 << UCSZ0)) , UCSR0C);

    // Enable reciever and transmitter and their interrupts
    outp(((1 << RXCIE) | (1 << TXCIE) | (1 << RXEN) | (1 << TXEN)) ,UCSR0B);


    return SUCCESS;
  }

  async command result_t UART.stop() {
    outp(0x00, UCSR0A);
    outp(0x00, UCSR0B);
    outp(0x00, UCSR0C);
    return SUCCESS;
  }

  default async event result_t UART.get(uint8_t data) { return SUCCESS; }
  TOSH_SIGNAL(SIG_UART0_RECV) {
    if (inp(UCSR0A) & (1 << RXC))
      signal UART.get(inp(UDR0));
  }

  default async event result_t UART.putDone() { return SUCCESS; }

#ifdef ENABLE_UART_DEBUG
#warning "UART Interrups Redirected"
#else
  TOSH_INTERRUPT(SIG_UART0_TRANS) {
    signal UART.putDone();
  }
#endif

  async command result_t UART.put(uint8_t data) {
    outp(data, UDR0); 
    sbi(UCSR0A, TXC);

    return SUCCESS;
  }
}
