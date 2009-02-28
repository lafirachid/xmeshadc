/*
 * Copyright (c) 2002-2005 Intel Corporation
 * Copyright (c) 2000-2005 The Regents of the University of California
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: IntToLeds.nc,v 1.1.4.1 2007/04/25 23:36:08 njain Exp $
 */
 
/*
 * Authors:		Jason Hill, David Gay, Philip Levis
 * Date last modified:  6/25/02
 *
 */

/**
 * @author Jason Hill
 * @author David Gay
 * @author Philip Levis
 */


configuration IntToLeds
{
  provides interface IntOutput;
  provides interface StdControl;
}
implementation
{
  components IntToLedsM, LedsC;

  IntOutput = IntToLedsM.IntOutput;
  StdControl = IntToLedsM.StdControl;
  IntToLedsM.Leds -> LedsC.Leds;
}
