/*
 * Copyright (c) 2004-2007 Crossbow Technology, Inc.
 * All rights reserved.
 * See license.txt file included with the distribution.
 *
 * $Id: RouteSelect.nc,v 1.3.2.1 2007/04/25 23:29:27 njain Exp $
 */

includes AM;
interface RouteSelect {

  /**
   * Whether there is currently a valid route.
   *
   * @return Whether there is a valid route.
   */
  command bool isActive();

  /**
   * Select a route and fill in all of the necessary routing
   * information to a packet.
   *
   * @param msg: Message to select route for and fill in routing information.
   * @param direction: upstream or downstream 
   * @param flags: bit flags that indicates: resent, forced monitor, search dscdant table, update dscdant table 
   *
   * @return Whether a route was selected succesfully. On FAIL the
   * packet should not be sent.
   *
   */
  
  command result_t selectRoute(TOS_MsgPtr msg, uint8_t direction, uint8_t flags);


  command result_t chooseNewParent();


  /**
   * Given a TOS_MstPtr, initialize its routing fields to a known
   * state, specifying that the message is originating from this node.
   * This known state can then be used by selectRoute() to fill in
   * the necessary data.
   *
   * @param msg Message to select route for and fill in init data.
   *
   * @return Should always return SUCCESS.
   *
   */

  command result_t initializeFields(TOS_MsgPtr msg, uint8_t direction, uint8_t appId);

  
  /**
   * Given a TinyOS message buffer, provide a pointer to the data
   * buffer within it that an application can use as well as its
   * length. Unlike the getBuffer of the Send interface, this can
   * be called freely and does not modify the buffer.
   *
   * @param msg The message to get the data region of.
   *
   * @param length Pointer to a field to store the length of the data region.
   *
   * @return A pointer to the data region.
   */
  
  command uint8_t* getBuffer(TOS_MsgPtr msg, uint16_t* len);
  command result_t  RouteHold();
  command uint16_t getNextSeqno();
}
