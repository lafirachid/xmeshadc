/*
 * Copyright (c) 2002-2005 Intel Corporation
 * Copyright (c) 2000-2005 The Regents of the University of California
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: CryptoPrimitives.h,v 1.1.4.1 2007/04/26 00:23:34 njain Exp $
 */

/* Authors: Naveen Sastry
 * Date:    10/24/02
 */

// Look at the movw instruction to shave a few more cycles.
// [probably only for the atmel 128's]

/*
 * Performs a leftward rotation on 32 bits of data, 1 bit
 * at a time.
 * (2 + (n * 9)) cycles
 */

/**
 * @author Naveen Sastry
 */

#define rol32(a, n) ({		                        \
    	unsigned long num = (unsigned long)(a);         \
    	unsigned char nsh = (unsigned char)(n);         \
	__asm__ __volatile__ (                          \
		"dec %0" "\n\t"			        \
		"brmi L_%=" "\n\t"		        \
	"L1_%=:" "\n\t"                                 \
		"clc" "\n\t"			        \
		"sbrc %D1, 7" "\n\t"		        \
		"sec" "\n\t"			        \
		"rol %A1" "\n\t"		        \
		"rol %B1" "\n\t"		        \
		"rol %C1" "\n\t"		        \
		"rol %D1" "\n\t"		        \
		"dec %0" "\n\t"			        \
		"brpl L1_%=" "\n\t"		        \
	"L_%=:" "\n\t"                                  \
		: "=r" (nsh), "=r" (num)                \
		: "0" (nsh), "1" (num)			\
	);						\
        a = num;                                        \
})

                                                        
/*
 * Performs a rightward rotation on 32 bits of data, 1 bit
 * at a time.
 * (2 + (n * 9)) cycles 
 */
#define ror32(a, n) ({					\
    	unsigned long num = (unsigned long)(a); 	\
    	unsigned char nsh = (unsigned char)(n); 	\
	__asm__ (				        \
		"dec %0" "\n\t"				\
		"brmi L_%=" "\n\t"			\
	"L1_%=:" "\n\t"                                 \
		"clc" "\n\t"				\
		"sbrc %A1, 0" "\n\t"			\
		"sec" "\n\t"				\
		"ror %D1" "\n\t"			\
		"ror %C1" "\n\t"			\
		"ror %B1" "\n\t"			\
		"ror %A1" "\n\t"			\
		"dec %0" "\n\t"				\
		"brpl L1_%=" "\n\t"			\
	"L_%=:" "\n\t"                                  \
		: "=r" (nsh), "=r" (num)                \
		: "0" (nsh), "1" (num)			\
	);						\
        a = num;                                        \
})

/*
 * Copies a 4 byte char buf to a long and moves the ptr
 * 10 cycles
 */
#define c2l(c,l) ({                                    \
  __asm__ (    "mov r30, %A1" "\n\t"                   \
               "mov r31, %B1" "\n\t"                   \
               "ld %A0, Z+" "\n\t"                     \
               "ld %B0, Z+" "\n\t"                     \
               "ld %C0, Z+" "\n\t"                     \
               "ld %D0, Z " "\n\t"                     \
               : "=r" (l)                              \
               : "r" (c)                               \
               : "r30", "r31");                        \
});

/*
 * Copies a long to a 4 byte char buf to a long and
 * doesn't advances the char ptr
 * 10 cycles
 */
#define l2c(l,c) ({                                    \
  __asm__ volatile (    "mov r30, %A0" "\n\t"          \
               "mov r31, %B0" "\n\t"                   \
               "st Z+, %A1" "\n\t"                     \
               "st Z+, %B1" "\n\t"                     \
               "st Z+, %C1" "\n\t"                     \
               "st Z,  %D1" "\n\t"                     \
               :                                       \
               : "r" (c), "r" (l)                      \
               : "r30", "r31");                        \
});

/*
 * Performs a 1 byte block roll to the left equiv to
 * rol32(a, 8)
 * 5 cycles
 */
#define brol1(a) ({                                    \
  uint8_t  brol1tmp;                                   \
  __asm__  (   "mov %1, %D0" "\n\t"                    \
               "mov %D0, %C0" "\n\t"                   \
               "mov %C0, %B0" "\n\t"                   \
               "mov %B0, %A0" "\n\t"                   \
               "mov %A0, %1" "\n\t"                    \
               : "=r"(a), "=r" (brol1tmp)              \
               : "0" (a)                               \
               );                                      \
});

/*
 * Performs a 2 byte block roll to the left equiv to
 * rol32(a, 16)
 * 6 cycles
 */
#define brol2(a) ({                                    \
  uint8_t  brol2tmp;                                   \
  __asm__  (   "mov %1, %A0"   "\n\t"                  \
               "mov %A0, %C0"  "\n\t"                  \
               "mov %C0, %1"   "\n\t"                  \
               "mov %1, %B0"   "\n\t"                  \
               "mov %B0, %D0"  "\n\t"                  \
               "mov %D0, %1"   "\n\t"                  \
               : "=r"(a), "=r" (brol2tmp)              \
               : "0" (a)                               \
               );                                      \
});

/*
 * Performs a 3 byte block roll to the left equiv to
 * rol32(a, 24)
 * 5 cycles
 */
#define brol3(a) ({                                    \
  uint8_t  brol3tmp;                                   \
  __asm__  (   "mov %1, %A0" "\n\t"                    \
               "mov %A0, %B0" "\n\t"                   \
               "mov %B0, %C0" "\n\t"                   \
               "mov %C0, %D0" "\n\t"                   \
               "mov %D0, %1" "\n\t"                    \
               : "=r"(a), "=r" (brol3tmp)              \
               : "0" (a)                               \
               );                                      \
});

#define bror1(a) (brol3(a))
#define bror2(a) (brol2(a))
#define bror3(a) (brol1(a))

/*
 * Fast rol to the left using the above primitives.
 * (switch): 16 cycles
 * (brol.) :  5 cycles
 * sub:    :  1 cycle
 * rol32:  :  2 + (9n), 0 <= n <= 4
 * ===============================
 * BEST    : 16 / 21  cycles (byte boundaries)
 * AVG     : 42       cycles
 * WORST   : 60       cycles
 */
#define fastrol32(a, n) ({                                                 \
  switch ((n)) {                                                           \
  case 0: break;                                                           \
  case 1: case 2: case 3: case 4: case 5: rol32 (a, (n)); break;           \
  case 6: case 7: brol1(a); ror32(a, 8-(n)); break;                        \
  case 8: case 9: case 10: case 11: case 12:  brol1(a); rol32(a, (n)-8 );  \
          break;                                                           \
  case 13: case 14: case 15: case 16: brol2(a); ror32(a, 16-(n)); break;   \
  case 17: case 18: case 19: case 20: brol2(a); rol32(a, (n) -16); break;  \
  case 21: case 22: case 23: case 24: brol3(a); ror32(a, 24-(n)); break;   \
  case 25: case 26: case 27: case 28: brol3(a); rol32(a, (n) -24); break;  \
  case 29: case 30: case 31: ror32(a, 32 - (n));                           \
  }                                                                        \
});

// can be improved to eliminate the subtraction
#define fastror32(a,n) fastrol32(a, (32-n)) 

// convert a 2 byte char array to an unsigned short:
// [assumes MOST significant byte is first]
#define c2sM(c, s)       (s = ((unsigned short)(*((c))))  <<8L ,             \
                          s|= ((unsigned short)(*((c+1)))))

// convert a unsigned short to a 2 byte char array
// [assumes MOST significant byte is first]
#define s2cM(s, c)      (*((c))   = (unsigned short)(((s) >> 8L)&0xff), \
                         *((c+1)) = (unsigned short)(((s)      ) &0xff))

#define CRYPTO_TABLE_TYPE prog_uchar
#define CRYPTO_TABLE_ACCESS(addr) PRG_RDB((addr))
