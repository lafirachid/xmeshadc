/*
 * Copyright (c) 2004-2007 Crossbow Technology, Inc.
 * Copyright (c) 2002-2005 Intel Corporation
 * Copyright (c) 2000-2005 The Regents of the University of California
 * Copyright (c) 2004 by Sensicast, Inc.
 * All rights reserved.
 * See your enterprise license, which controls the extent of your license grant.
 *
 * $Id: SOdebug.h,v 1.1.2.2 2007/04/26 00:07:32 njain Exp $
 */

//
// @Author: Michael Newman
//
#ifndef SOdebugEdit
#define SOdebugEdit 1
//
// Modification History:
//  25Jan04 MJNewman 1: Created.

#include <stdarg.h>


//turn off debug output by default
#ifndef SO_DEBUG
#define SO_DEBUG 0
#endif

// Assume we are not a dot by default
#ifndef SO_DEBUG_DOT
#define SODEBUG_DOT 0
#endif

// Most of this module is off unless enabled
#if (SO_DEBUG)


//#include <stdio.h>

// This varaiable is shared by many possible users of SOdebug.
// The rest of the code is duplicated!.
bool debugStarted;
static const char hex[16] = "0123456789ABCDEF";

#if (!SO_DEBUG_DOT)
// uint8_t
static void init_debug(){           
    atomic {
	       outp(0,UBRR0H); 

#if 1
	// 115K with 0% error clock is 7.3728Mhz
	       outp(7, UBRR0L);                              //set baud rate
	       outp((1<<U2X0),UCSR0A);                         // Set UART double speed
#endif
#if 0
	// 56K with 0% error clock is 7.3728Mhz
	       outp(15, UBRR0L);                              //set baud rate
	       outp((1<<U2X0),UCSR0A);                         // Set UART double speed
#endif

	       outp(((1 << UCSZ01) | (1 << UCSZ00)) , UCSR0C);  // Set frame format: 8 data-bits, 1 stop-bit
	       inp(UDR0); 
	       outp((1 << TXEN0) ,UCSR0B);   // Enable uart reciever and transmitter
    }
}
#else
//init comm port (19K baud) for mica2dot for debug
static void init_debug(){
    atomic {
     	outp(0,UBRR0H);            // Set baudrate to 19.2 KBps
	     outp(12, UBRR0L);
	     outp(0,UCSR0A);            // Disable U2X0 and MPCM
	     outp(((1 << UCSZ01) | (1 << UCSZ00)) , UCSR0C);
	     inp(UDR0); 
	     outp((1 << TXEN0) ,UCSR0B);
    }
}
#endif

// output a char to the uart
void UARTPutChar(char c) {
    if (c == '\n') {
	   loop_until_bit_is_set(UCSR0A, UDRE0);
	   //outb(UDR0,'\r');
	   outb(UDR0,0xd);
	   loop_until_bit_is_set(UCSR0A, UDRE0);
	   outb(UDR0,0xa);
	   //loop_until_bit_is_set(UCSR0A, UDRE0);
       loop_until_bit_is_set(UCSR0A, TXC0);
       
       TOSH_uwait(100);
       return; 
    };
    loop_until_bit_is_set(UCSR0A, UDRE0);
    outb(UDR0,c);
    loop_until_bit_is_set(UCSR0A, TXC0);
    return;
}

// Simplified printf
int printf(const uint8_t *format, ...)
{
    uint8_t format_flag;
    uint32_t u_val=0;
    uint32_t div_val;
    uint8_t base;
    uint8_t *ptr;
    bool longNumber = FALSE;
    va_list ap;

    va_start (ap, format);
    if (!debugStarted) {
	      init_debug();
	      debugStarted = 1;
    };
    if (format == NULL)	format = "NULL\n";
    for (;;)    /* Until full format string read */
    {
	      if (!longNumber) {		// Assume char after %l is d or xX
	        while ((format_flag = *format++) != '%')      /* Until '%' or '\0' */
	        {
		         if (!format_flag) {
		         return 0;		// not bothering with count of chars output
		       };
		       UARTPutChar(format_flag);
	      };
	   };
	   switch (format_flag = *format++) {
	    case 'c':
		      format_flag = va_arg(ap, int);
	       default:
		      UARTPutChar(format_flag);
		      continue;

	    case 'S':
	    case 's':
		      ptr = (uint8_t *)va_arg(ap,char *);
		while ((format_flag = *ptr++) != 0) {
		      UARTPutChar(format_flag);
		};
		      continue;

#if 0
	    case 't':
	    {
        #define SECONDS_IN_ONE_DAY 86400
		      base = 10;

		      if (currentSeconds/86400)
		{//print days
		      div_val = 10000;
		      u_val = currentSeconds/SECONDS_IN_ONE_DAY;
		      do
		      {
			       UARTPutChar(hex[u_val / div_val]);
			       u_val %= div_val;
			       div_val /= base;
		    }
		    while (div_val);
		    UARTPutChar(' ');
		    UARTPutChar('d');
		    UARTPutChar('a');
		    UARTPutChar('y');
		    UARTPutChar('s');
		    UARTPutChar(' ');
		}
		//
		//hours
		div_val = 10;
		u_val = (currentSeconds % 86400)/3600;
		do
		{
		    UARTPutChar(hex[u_val / div_val]);
		    u_val %= div_val;
		    div_val /= base;
		}
		while (div_val);
		UARTPutChar(':');
		//
		//minutes
		div_val = 10;
		u_val = (INT16)((currentSeconds % 86400)%3600)/60;
		do
		{
		    UARTPutChar(hex[u_val / div_val]);
		    u_val %= div_val;
		    div_val /= base;
		}
		while (div_val);
		UARTPutChar(':');
		//
		//seconds
		div_val = 10;
		u_val = (INT16)(currentSeconds%60);
		do
		{
		    UARTPutChar(hex[u_val / div_val]);
		    u_val %= div_val;
		    div_val /= base;
		}
		while (div_val);
	    }
	    continue;
#endif	// 't' time output

	    case 'l':
		longNumber = TRUE;
		continue;

	    case 'o':
		base = 8;
		if (!longNumber)
		    div_val = 0x8000;
		else
		    div_val = 0x40000000;
		goto CONVERSION_LOOP;

	    case 'u':
	    case 'i':
	    case 'd':
		base = 10;
		if (!longNumber)
		    div_val = 10000;
		else
		    div_val = 1000000000;
		goto CONVERSION_LOOP;

	    case 'x':
		base = 16;
		if (!longNumber)
		    div_val = 0x1000;
		else
		    div_val = 0x10000000;

CONVERSION_LOOP:
		{
		    if (!longNumber)
			u_val = va_arg(ap,int);
		    else
			u_val = va_arg(ap,long);
		    if ((format_flag == 'd') || (format_flag == 'i')) {
			bool isNegative;
			if (!longNumber)
			    isNegative = (((int)u_val) < 0);
			else
			    isNegative = (((long)u_val) < 0);
			if (isNegative) {
			    u_val = - u_val;
			    UARTPutChar('-');
			};
			while (div_val > 1 && div_val > u_val) {
			    div_val /= 10;
			};
		    }
		    //  truncate signed values to a 16 bits for hex output
		    if ((format_flag == 'x') && (!longNumber)) u_val &= 0xffff;
		    do {
			UARTPutChar(hex[u_val / div_val]);
			u_val %= div_val;
			div_val /= base;
		    }
		    while (div_val);
		    longNumber = FALSE;
		};
		break;
	};
    };
 
}

#endif // SO_DEBUG 


#define SO_NO_DEBUG 0
#if (SO_DEBUG)
#define SODbg(__x,__args...) { \
				 if(__x != SO_NO_DEBUG){  \
				      printf(__args);	\
				 };    \
			     }
#else
#define SODbg(__x,__args...)
#endif


#endif //SOdebugEdit