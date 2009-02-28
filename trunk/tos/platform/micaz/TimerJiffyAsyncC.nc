/*
 * Copyright (c) 2004-2007 Crossbow Technology, Inc.
 * Copyright (c) 2002-2005 Intel Corporation
 * Copyright (c) 2000-2005 The Regents of the University of California
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: TimerJiffyAsyncC.nc,v 1.2.4.1 2007/04/26 21:51:10 njain Exp $
 */
 
/* 
 * Author: Xin Yang (xyang@xbow.com)
 * Date:   11/05/05
 */
 
/**
 * TimerJiffyAsyncC.nc - configuration wiring from Jiffy Timer to Hardware Timer.
 *
 *
 * <pre>
 *	$Id: TimerJiffyAsyncC.nc,v 1.2.4.1 2007/04/26 21:51:10 njain Exp $
 * </pre>
 * 
 * @author Cory Sharp
 * @author Xin Yang
 * @date November 5 2005
 */ 
 
configuration TimerJiffyAsyncC
{
  provides interface StdControl;
  provides interface TimerJiffyAsync;
}
implementation
{
  components TimerJiffyAsyncM, HPLTimer2C as CPUClockTimer, HPLPowerManagementM;

  StdControl = TimerJiffyAsyncM;
  TimerJiffyAsync = TimerJiffyAsyncM;
  TimerJiffyAsyncM.Timer -> CPUClockTimer;
  TimerJiffyAsyncM.PowerManagement -> HPLPowerManagementM;

}

