/*
 * Copyright (c) 2004-2007 Crossbow Technology, Inc.
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: MyApp.nc,v 1.1.2.2 2007/04/26 19:59:29 njain Exp $
 */

 
includes sensorboardApp;

/**
 * This module shows how to use the Timer, LED, ADC and Messaging components.
 * Sensor messages are sent to the serial port
 **/
configuration MyApp {
}
implementation {
  components Main, MyAppM, TimerC, LedsC, Photo, GenericComm as Comm;
  
  Main.StdControl -> TimerC.StdControl;
  Main.StdControl -> MyAppM.StdControl;
  Main.StdControl -> Comm.Control;
  
  MyAppM.Timer -> TimerC.Timer[unique("Timer")];
  MyAppM.Leds -> LedsC.Leds;
  MyAppM.PhotoControl -> Photo.PhotoStdControl;
  MyAppM.Light -> Photo.ExternalPhotoADC;
  
  MyAppM.SendMsg -> Comm.SendMsg[AM_XSXMSG];
}

