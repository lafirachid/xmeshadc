/*
 * Copyright (c) 2002-2005 Intel Corporation
 * Copyright (c) 2000-2005 The Regents of the University of California
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: dbg_modes.h,v 1.1.4.1 2007/04/27 06:07:45 njain Exp $
 */

/*
 *
 * Authors:		Philip Levis (derived from work by Mike Castelle)
 * Date last modified:  6/25/02
 *
 */

/* 
 *   FILE: dbg_modes.h 
 * AUTHOR: Phil Levis (pal)
 *  DESCR: Definition of dbg modes and the bindings to DBG env settings. 
 */

/**
 * @author Philip Levis (derived from work by Mike Castelle)
 * @author Phil Levis (pal)
 */



#ifndef DBG_MODES_H
#define DBG_MODES_H

typedef long long TOS_dbg_mode;

#define DBG_MODE(x)	(1ULL << (x))

enum {
  DBG_ALL =		(~0ULL),	/* umm, "verbose"		*/

/*====== Core mote modes =============*/
  DBG_BOOT =		DBG_MODE(0),	/* the boot sequence		*/
  DBG_CLOCK =		DBG_MODE(1),	/* clock        		*/
  DBG_TASK =		DBG_MODE(2),	/* task stuff			*/
  DBG_SCHED =		DBG_MODE(3),	/* switch, scheduling		*/
  DBG_SENSOR =		DBG_MODE(4),	/* sensor readings              */
  DBG_LED =	 	DBG_MODE(5),	/* LEDs         		*/
  DBG_CRYPTO =	        DBG_MODE(6),	/* Cryptography/security        */

/*====== Networking modes ============*/
  DBG_ROUTE =		DBG_MODE(7),	/* network routing       	*/
  DBG_AM =		DBG_MODE(8),	/* Active Messages		*/
  DBG_CRC =		DBG_MODE(9),	/* packet CRC stuff		*/
  DBG_PACKET =		DBG_MODE(10),	/* Packet level stuff 		*/
  DBG_ENCODE =		DBG_MODE(11),   /* Radio encoding/decoding      */
  DBG_RADIO =		DBG_MODE(12),	/* radio bits                   */

/*====== Misc. hardware & system =====*/
  DBG_LOG =	   	DBG_MODE(13),	/* Logger component 		*/
  DBG_ADC =		DBG_MODE(14),	/* Analog Digital Converter	*/
  DBG_I2C =		DBG_MODE(15),	/* I2C bus			*/
  DBG_UART =		DBG_MODE(16),	/* UART				*/
  DBG_PROG =		DBG_MODE(17),	/* Remote programming		*/
  DBG_SOUNDER =		DBG_MODE(18),   /* SOUNDER component            */
  DBG_TIME =	        DBG_MODE(19),   /* Time and Timer components    */
  DBG_POWER =	        DBG_MODE(20),   /* Power profiling      */


/*====== Simulator modes =============*/
  DBG_SIM =	        DBG_MODE(21),   /* Simulator                    */
  DBG_QUEUE =	        DBG_MODE(22),   /* Simulator event queue        */
  DBG_SIMRADIO =	DBG_MODE(23),   /* Simulator radio model        */
  DBG_HARD =	        DBG_MODE(24),   /* Hardware emulation           */
  DBG_MEM =	        DBG_MODE(25),   /* malloc/free                  */
//DBG_RESERVED =	DBG_MODE(26),   /* reserved for future use      */

/*====== For application use =========*/
  DBG_USR1 =		DBG_MODE(27),	/* User component 1		*/
  DBG_USR2 =		DBG_MODE(28),	/* User component 2		*/
  DBG_USR3 =		DBG_MODE(29),	/* User component 3		*/
  DBG_TEMP =		DBG_MODE(30),	/* Temorpary testing use	*/

  DBG_ERROR =		DBG_MODE(31),	/* Error condition		*/
  DBG_NONE =		0,		/* Nothing                      */

  DBG_DEFAULT =	     DBG_ALL	  	/* default modes, 0 for none	*/
};

#define DBG_NAMETAB \
	{"all", DBG_ALL}, \
	{"boot", DBG_BOOT|DBG_ERROR}, \
	{"clock", DBG_CLOCK|DBG_ERROR}, \
        {"task", DBG_TASK|DBG_ERROR}, \
	{"sched", DBG_SCHED|DBG_ERROR}, \
	{"sensor", DBG_SENSOR|DBG_ERROR}, \
	{"led", DBG_LED|DBG_ERROR}, \
	{"crypto", DBG_CRYPTO|DBG_ERROR}, \
\
        {"route", DBG_ROUTE|DBG_ERROR}, \
        {"am", DBG_AM|DBG_ERROR}, \
        {"crc", DBG_CRC|DBG_ERROR}, \
        {"packet", DBG_PACKET|DBG_ERROR}, \
        {"encode", DBG_ENCODE|DBG_ERROR}, \
        {"radio", DBG_RADIO|DBG_ERROR}, \
\
	{"logger", DBG_LOG|DBG_ERROR}, \
        {"adc", DBG_ADC|DBG_ERROR}, \
        {"i2c", DBG_I2C|DBG_ERROR}, \
        {"uart", DBG_UART|DBG_ERROR}, \
        {"prog", DBG_PROG|DBG_ERROR}, \
        {"sounder", DBG_SOUNDER|DBG_ERROR}, \
        {"time", DBG_TIME|DBG_ERROR}, \
        {"power", DBG_POWER|DBG_ERROR}, \
\
        {"sim", DBG_SIM|DBG_ERROR}, \
        {"queue", DBG_QUEUE|DBG_ERROR}, \
        {"simradio", DBG_SIMRADIO|DBG_ERROR}, \
        {"hardware", DBG_HARD|DBG_ERROR}, \
        {"simmem", DBG_MEM|DBG_ERROR}, \
\
        {"usr1", DBG_USR1|DBG_ERROR}, \
        {"usr2", DBG_USR2|DBG_ERROR}, \
        {"usr3", DBG_USR3|DBG_ERROR}, \
        {"temp", DBG_TEMP|DBG_ERROR}, \
	{"error", DBG_ERROR}, \
\
        {"none", DBG_NONE}, \
        { NULL, DBG_ERROR } 

#define DBG_ENV		"DBG"

#endif 
