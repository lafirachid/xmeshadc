/*
 * Copyright (c) 2004-2007 Crossbow Technology, Inc.
 * Copyright (c) 2000-2005 The Regents of the University of California
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: Power.nc,v 1.1.4.1 2007/04/27 05:15:17 njain Exp $
 */

/*
 * Authors:   Mohammad Rahimi mhr@cens.ucla.edu
 * History:   created 11/14/2003
 *
 * to turn ON/OFF 2.5V,3.3V,5.0V interface
 *
 */


interface Power {
  command void on();
  command void off();
}
