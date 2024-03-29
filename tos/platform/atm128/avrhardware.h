/*
 * Copyright (c) 2002-2005 Intel Corporation
 * Copyright (c) 2000-2005 The Regents of the University of California
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: avrhardware.h,v 1.1.4.2 2007/04/26 00:12:12 njain Exp $
 */

/*
 *
 * Authors:             Jason Hill, Philip Levis, Nelson Lee
 *
 *
 */

/**
 * @author Jason Hill
 * @author Philip Levis
 * @author Nelson Lee
 */


#ifndef TOSH_AVRHARDWARE_H
#define TOSH_AVRHARDWARE_H

// check for a new-look avr-libc
#if defined(DTOSTR_ALWAYS_SIGN) && !defined(TOSH_NEW_AVRLIBC)
#define TOSH_NEW_AVRLIBC
#endif

#ifdef TOSH_NEW_AVRLIBC
#include <avr/io.h>
//#include <avr/signal.h>
#include <avr/interrupt.h>
#include <avr/wdt.h>
#include <avr/pgmspace.h>
#include <avr/eeprom.h>

#ifndef sbi
/* avr-libc 1.2.3 doesn't include these anymore. */
#define sbi(port, bit) ((port) |= _BV(bit))
#define cbi(port, bit) ((port) &= ~_BV(bit))
#define inp(port) (port)
#define inb(port) (port)
#define outp(value, port) ((port) = (value))
#define outb(port, value) ((port) = (value))
#define inw(port) (*(volatile uint16_t *)&port)
#define PRG_RDB(addr) pgm_read_byte(addr)
#endif

#else
#include <io.h>
#include <sig-avr.h>
#include <interrupt.h>
#include <wdt.h>
#include <pgmspace.h>
#endif /* TOSH_NEW_AVRLIBC */

// check for version 3.3 of GNU gcc or later
#if ((__GNUC__ == 3) && (__GNUC_MINOR__ >= 3))
#define __outw(val, port) outw(port, val);
#endif

#ifndef __inw
#ifndef __SFR_OFFSET
#define __SFR_OFFSET 0
#endif /* !__SFR_OFFSET */
#define __inw(_port) inw(_port)

#define __inw_atomic(__sfrport) ({				\
	uint16_t __t;					\
	bool bStatus;					\
	bStatus = bit_is_set(SREG,7);			\
	cli();						\
	__t = inw(__sfrport);				\
	if (bStatus) sei();				\
	__t;						\
 })

#endif /* __inw */

#define TOSH_ASSIGN_PIN(name, port, bit) \
static inline void TOSH_SET_##name##_PIN() {sbi(PORT##port , bit);} \
static inline void TOSH_CLR_##name##_PIN() {cbi(PORT##port , bit);} \
static inline int TOSH_READ_##name##_PIN() \
  {return (inp(PIN##port) & (1 << bit)) != 0;} \
static inline void TOSH_MAKE_##name##_OUTPUT() {sbi(DDR##port , bit);} \
static inline void TOSH_MAKE_##name##_INPUT() {cbi(DDR##port , bit);} 

#define TOSH_ASSIGN_OUTPUT_ONLY_PIN(name, port, bit) \
static inline void TOSH_SET_##name##_PIN() {sbi(PORT##port , bit);} \
static inline void TOSH_CLR_##name##_PIN() {cbi(PORT##port , bit);} \
static inline void TOSH_MAKE_##name##_OUTPUT() {;} 

#define TOSH_ALIAS_OUTPUT_ONLY_PIN(alias, connector)\
static inline void TOSH_SET_##alias##_PIN() {TOSH_SET_##connector##_PIN();} \
static inline void TOSH_CLR_##alias##_PIN() {TOSH_CLR_##connector##_PIN();} \
static inline void TOSH_MAKE_##alias##_OUTPUT() {} \

#define TOSH_ALIAS_PIN(alias, connector) \
static inline void TOSH_SET_##alias##_PIN() {TOSH_SET_##connector##_PIN();} \
static inline void TOSH_CLR_##alias##_PIN() {TOSH_CLR_##connector##_PIN();} \
static inline char TOSH_READ_##alias##_PIN() {return TOSH_READ_##connector##_PIN();} \
static inline void TOSH_MAKE_##alias##_OUTPUT() {TOSH_MAKE_##connector##_OUTPUT();} \
static inline void TOSH_MAKE_##alias##_INPUT()  {TOSH_MAKE_##connector##_INPUT();} 

// We need slightly different defs than SIGNAL, INTERRUPT
#define TOSH_SIGNAL(signame)					\
void signame() __attribute__ ((signal, spontaneous, C))

#define TOSH_INTERRUPT(signame)				\
void signame() __attribute__ ((interrupt, spontaneous, C))

/* Watchdog Prescaler
 */
enum {
  TOSH_period16 = 0x00, // 47ms
  TOSH_period32 = 0x01, // 94ms
  TOSH_period64 = 0x02, // 0.19s
  TOSH_period128 = 0x03, // 0.38s
  TOSH_period256 = 0x04, // 0.75s
  TOSH_period512 = 0x05, // 1.5s
  TOSH_period1024 = 0x06, // 3.0s
  TOSH_period2048 = 0x07 // 6.0s
};

void TOSH_wait()
{
  asm volatile("nop");
  asm volatile("nop");
}

// atomic statement runtime support

typedef uint8_t __nesc_atomic_t;

__nesc_atomic_t __nesc_atomic_start(void);
void __nesc_atomic_end(__nesc_atomic_t oldSreg);

#ifndef NESC_BUILD_BINARY

inline __nesc_atomic_t __nesc_atomic_start(void) __attribute__((spontaneous))
{
  __nesc_atomic_t result = inp(SREG);
  cli();
  return result;
}

inline void __nesc_atomic_end(__nesc_atomic_t oldSreg) __attribute__((spontaneous))
{
  outp(oldSreg, SREG);
}

inline void __nesc_atomic_sleep()
{
  /* Atomically enable interrupts and sleep */
  sei();  // Make sure interrupts are on, so we can wake up!
  asm volatile ("sleep");
  TOSH_wait();
}

#endif

inline void __nesc_enable_interrupt() {
  sei();
}
#endif //TOSH_AVRHARDWARE_H
