/*
 * Copyright (c) 2004-2007 Crossbow Technology, Inc.
 * Copyright (c) 2000-2005 The Regents of the University of California
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: sensorboard.h,v 1.2.4.1 2007/04/27 05:12:26 njain Exp $
 */

/* 
 * 
 * @author   PiPeng (pipeng@xbow.com.cn)
 * @date     2006/01/06
 */

//analog channel parameters
enum {
    SAMPLER_DEFAULT =0x00,
    AVERAGE_FOUR = 0x01,
    AVERAGE_EIGHT = 0x02,
    AVERAGE_SIXTEEN = 0x04,
    EXCITATION_25 = 0x08,
    EXCITATION_33 = 0x10,
    EXCITATION_50 = 0x20,
    EXCITATION_ALWAYS_ON = 0x40,
    DELAY_BEFORE_MEASUREMENT = 0x80
};

//analog digital channels parameters
enum {
    //SAMPLER_DEFAULT =0x00,    //previously defined for digital channels
    RISING_EDGE = 0x01,
    FALLING_EDGE = 0x02,
    EVENT = 0x04,
    EEPROM_TOTALIZER = 0x08,
    //    EXCITATION_33 = 0x10, //previously defined for digital channels
    //    EXCITATION_50 = 0x20, //previously defined for digital channels
    RESET_ZERO_AFTER_READ = 0x30,
    DIG_OUTPUT = 0x40,
    DIG_LOGIC = 0x80
};

enum {
    InputChannel=0,
    OutputChannel=1
};

enum {
    RisingEdge=0,
    FallingEdge=1,
    Edge=2
};


enum {
    NO_EXCITATION=0,
    ADCREF=1,
    THREE_VOLT=2,
    FIVE_VOLT=3,
    ALL_EXCITATION=4,	
    NO_ADCREF=5,
    NO_THREE_VOLT=6,
    NO_FIVE_VOLT=7
};

enum {
    POWER_SAVING_MODE=0,
    NO_POWER_SAVING_MODE=1
};

enum {
    FAST_COVERSION_MODE=0,
    SLOW_COVERSION_MODE=1
};
/*
enum {
    NO_AVERAGE = 1,
    FOUR_AVERAGE = 4,
    EIGHT_AVERAGE = 8,
    SIXTEEN_AVERAGE = 16,
};
*/
enum { 
    ATTENTION_PACKET = 9 
};

enum {
    ANALOG=0,
    BATTERY=1,
    TEMPERATURE=2,
    HUMIDITY=3,
    DIGITAL=4,
    COUNTER=5
};

enum {
    PENDING,
    NOT_PENDING
};

enum {
    MUX_CHANNEL_SEVEN = 0xC0,
    MUX_CHANNEL_EIGHT = 0x30,
    MUX_CHANNEL_NINE = 0x0C, 
    MUX_CHANNEL_TEN = 0x03
};

enum{
    LOCK,
    UNLOCK
};

enum {
    SAMPLE_RECORD_FREE=-1,
    SAMPLE_ONCE=-2
};

enum {
    NORMALY_OPEN=6,
    NORMALY_CLOSED=7,
    SET_HIGH,
    SET_LOW,
    SET_TOGGLE,
    SET_CLOSE,
    SET_OPEN
};

//Please note that the number of clients that can be handles by Smapler is MAX_CHANNEL which is defined here
//u can set it up to maximum of 127 values.I currently set it to 10.Please notice that addition of each 1 
//possible client cost 64 byte.This will be reduce soon by optimizing the data structure but not that magically.
#define MAX_SAMPLERECORD 25
#define BATTERY_PORT 7
#define ADC_ERROR 0xffff         //to be changed in case of 16 bit adc
