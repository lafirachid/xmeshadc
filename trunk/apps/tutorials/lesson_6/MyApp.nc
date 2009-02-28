/*
 * Copyright (c) 2004-2007 Crossbow Technology, Inc.
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: MyApp.nc,v 1.1.2.2 2007/04/26 20:03:24 njain Exp $
 */
 
#include "appFeatures.h"
includes sensorboardApp;

/**
 * This configuration shows how to use the Timer, LED, ADC and XMesh components.
 * Sensor messages are sent multi-hop over the RF radio
 * This application also accepts commands from the base for changing the reporting
 * rate and to toggle the LED states
 *
 **/
configuration MyApp {
}
implementation {
  components Main, GenericCommPromiscuous as Comm, MULTIHOPROUTER, MyAppM, TimerC, LedsC, Photo, XCommandC;
  
  Main.StdControl -> TimerC.StdControl;
  Main.StdControl -> MyAppM.StdControl;
  Main.StdControl -> Comm.Control;
  Main.StdControl -> MULTIHOPROUTER.StdControl;
  
  MyAppM.Timer -> TimerC.Timer[unique("Timer")];
  MyAppM.Leds -> LedsC.Leds;
  MyAppM.PhotoControl -> Photo.PhotoStdControl;
  MyAppM.Light -> Photo.ExternalPhotoADC;
  
  MyAppM.RouteControl -> MULTIHOPROUTER;
  MyAppM.Send -> MULTIHOPROUTER.MhopSend[AM_XMULTIHOP_MSG];
  MyAppM.XCommand -> XCommandC;
  MULTIHOPROUTER.ReceiveMsg[AM_XMULTIHOP_MSG] ->Comm.ReceiveMsg[AM_XMULTIHOP_MSG];   
}

