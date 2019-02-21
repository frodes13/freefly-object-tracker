/*-----------------------------------------------------------------
	MIT License

	Copyright (c) 2017 Freefly Systems

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

	Filename: "QX_Protocol.c"

	Description: This file provides the non-project specific portions of the Freefly QX Protocol

	Reuse and Porting:
	This code is design for simple reuse in other projects
	by separation of the protocol code/data from the application code/data.
	Steps:
	1.	Include QX_Protocol.c/.h and QX_Parsing_Util.c/.h files in your new project. 
		These should not be modified for the application.
	2.	Write the QX_Protocol_App.c/.h files. Other projects can be used as a template.
		This contains the client/server parser callback functions, support functions, 
		and QX_SendMsg2CommsPort_CB() which should send the messages to the desired port.
		The message support arrays (QX_Cli_MsgSupport and QX_Srv_MsgSupport)
		should also be initialized with the supported messages and their length check enforcement status.
	3. Define the number of servers and clients in your system by defining QX_NUM_SRV and QX_NUM_CLI in QX_Protocol_App.h
	4. Assign parser callback functions for each client and server using QX_InitSrv() and QX_InitCli().
	5. Call the QX_Init() function at application startup.
	6. In a periodic loop (main, or control/comms task) call QX_StreamRxCharSM() for each port to receive messages and transmit standard responses.
	7. Send any unsolicited messages such periodic current value messages (charting) and client read/write.

	There are 3 Main Message Types that can be sent via QX:
	CURRENT VALUE - Sent by server in response to read, write or periodically (charting). Recieved by clients.
	READ - Sent by client to request that a current value message be sent by server as a reply.
	WRITE (Absolute or Relative) - Sent by client to write data. Triggers a current value response by the server after the data has been written.
		
-----------------------------------------------------------------*/

//****************************************************************************
// Headers
//****************************************************************************
#include "QX_Protocol.h"			// Protocol Header
#include "QX_App_Config.h"			// Configure application specific values in this file
#include "QX_Protocol_App.h"		// This contains the application specific interface functions
#include "QX_Parsing_Functions.h"	// Contains utility functions for parsing data in/out of raw buffers
#include <stdlib.h>
#include <stdint.h>		// for Standard Data Types
#include <string.h>		// for array and string manipulation
#ifdef QX_DEBUG
#include <stdio.h>
#include "QX_Debug.h"
#endif
//****************************************************************************
// Private Defines
//****************************************************************************

//****************************************************************************
// Private Types
//****************************************************************************

//****************************************************************************
// Public Global Vars
//****************************************************************************

// The following arrays define the servers and clients present on this device. 
// The qty of each (QX_NUM_xxx) is defined by the application in QX_App_Config.h
QX_Server_t QX_Servers[QX_NUM_SRV];
QX_Client_t QX_Clients[QX_NUM_CLI];

// Array of communication ports
// QX_NUM_OF_PORTS is application specific and defined in QX_App_Config.h
QX_CommsPort_t QX_CommsPorts[QX_NUM_OF_PORTS];		

// Freefly Extension FunctionsPointers
void (*QX_BuildHeader_Legacy)(QX_Msg_t *Msg_p) = NULL;
void (*QX_ParseHeader_Legacy)(QX_Msg_t *Msg_p) = NULL;

//****************************************************************************
// Weakly Defined Functions
//****************************************************************************

// QX_Packet_Len_Lookup returns the maximum allowed packet length, re-define this function
// to allow certain packets to have an extended length (up to QX_MAX_PAYLOAD_LEN)

// !!WARNING!! If you utilize this feature, it is highly recommended to also utilize
// the timeout system so that long packets can't lock up the parser for an extended time period
// in the case of a significant number of lost packets in the middle of a long message
#ifdef USE_APPROVED_EXTENDED_LENGTH_PACKETS
	__weak uint32_t QX_Packet_Len_Lookup(uint32_t packet_id) {
#else
	uint32_t QX_Packet_Len_Lookup(uint32_t packet_id) {
#endif //USE_APPROVED_EXTENDED_LENGTH_PACKETS
	/* For example
	switch (packet_id) {
		case LONG_PACKET_ID_1: return 512; //Allow up to 512 bytes for this ID
		case LONG_PACKET_ID_2: return 2048; //Allow up to full 2048 bytes for this ID
		default: return QX_MAX_PAYLOAD_LEN_DEFAULT; //all other packets 64 bytes
	}
	*/
	
	return QX_MAX_PAYLOAD_LEN_DEFAULT;
}
	

#ifdef USE_QX_PACKET_TIMEOUT
//Return the latency of the channel for any given port 
//This includes channel delays (including things like windows thread delays if communicating over USB)
//Generally, set this number higher than you might think you need to avoid unnecessarily dropped packets.
//In most cases, it's best to set this to hundreds of milliseconds.
__weak uint32_t QX_GetPortLatencyMilliseconds(QX_Comms_Port_e port) {
	return 0;
}

//Return the baudrate of the channel
//Inverse baudrate: (milliseconds per bit) * 4096
//This should account for expected (and tolerated) dropped packets in long messages
__weak uint32_t QX_GetPortBaudrateMillisecondsPerBitTimes4096(QX_Comms_Port_e port) {
	return 0;
}
	
#endif //USE_QX_PACKET_TIMEOUT

//****************************************************************************
// Private Global Vars
//****************************************************************************


//****************************************************************************
// Private Function Prototypes - DO NOT EXPOSE THESE TO APPLICATION
//****************************************************************************

// Initialize QX Message Structure with Defaults
QX_Stat_e QX_InitMsg(QX_Msg_t *Msg_p);

// Recieve QX Message, Process and Respond if Neccessary
QX_Stat_e QX_RxMsg(QX_Msg_t *RxMsg_p);

// Create message header and prepare it for payload parsing
QX_Stat_e QX_TxMsg_Setup(QX_Msg_t *TxMsg_p);

// After message data has been parsed, finish building the message
QX_Stat_e QX_TxMsg_Finish(QX_Msg_t *TxMsg_p);

// Recieve Functions
void QX_Srv_Rx_Read(QX_Msg_t *RxMsg_p);
void QX_Srv_Rx_Write(QX_Msg_t *RxMsg_p);
void QX_Cli_Rx_CurVal(QX_Msg_t *RxMsg_p);

// Verify the length of an incoming message, return 1 if length is valid
uint8_t QX_VerifyLen(QX_Comms_Port_e port);

// Build QX Message Header in the buffer using data from the structure
void QX_BuildHeader(QX_Msg_t *Msg_p);

// Parse QX Message buffer to populate the header structure
void QX_ParseHeader(QX_Msg_t *Msg_p);

// Add a bit 7 extendable value to a buffer (up to 4 bytes, 28 bits)
void QX_AddExtdValToBuf(uint8_t **p, uint32_t Val);

// Get a bit 7 extendable value from a buffer (up to 4 bytes, 28 bits)
uint32_t QX_GetExtdValFromBuf(uint8_t **p);

// Calculate 8 bit checksum
uint8_t QX_Calc8bChecksum(uint8_t *buf_p, uint32_t len);

// Calculate 32 bit checksum
uint8_t QX_Calc32bChecksum(uint8_t *buf_p, uint32_t len);

//****************************************************************************
// Private Function Definitions
//****************************************************************************

//----------------------------------------------------------------------------
// Initialize all data in a Message Structure
QX_Stat_e QX_InitMsg(QX_Msg_t *Msg_p)
{
	// Set all to zero. Zero for most variables is default. Set any values that need to
	memset(Msg_p, 0, sizeof(QX_Msg_t));
	
	// Pointer Init
	Msg_p->BufPayloadStart_p = NULL;
	Msg_p->MsgBufAtt_p = NULL;
	Msg_p->MsgBuf_p = NULL;
	
	return QX_STAT_OK;
}


//----------------------------------------------------------------------------
// Recieve QX Packet, Process and Respond if Neccessary
//
QX_Stat_e QX_RxMsg(QX_Msg_t *RxMsg_p)
{
	RxMsg_p->MsgBuf_p = &RxMsg_p->MsgBuf[0];
	RxMsg_p->MsgBufStart_p = &RxMsg_p->MsgBuf[0];
	RxMsg_p->AttNotHandled = 0;		// Assume it will be handled to start - let the parser set this flag if needed
	
	#ifdef QX_DEBUG
	printf("\n\rRaw Msg Packet Recieved:\n\r");
	//QX_debug_print_Hex(&RxMsg_p->MsgBuf[0], RxMsg_p->Header.MsgLength);
	#endif

	// Parse Protocol Header
	if (RxMsg_p->Legacy_Header){
		if (*QX_ParseHeader_Legacy != NULL){
			QX_ParseHeader_Legacy(RxMsg_p);
		} else {
			return QX_STAT_ERROR;
		}
	} else {									
		QX_ParseHeader(RxMsg_p);
	}
	
	RxMsg_p->BufPayloadStart_p = RxMsg_p->MsgBuf_p;	// the pointer is at the payload after parsing the header
	
	// Check the CRC32 if enabled
	if (RxMsg_p->Header.AddCRC32){
		uint32_t crc32_result = QX_accumulate_crc32(0xFFFFFFFF, RxMsg_p->MsgBuf, RxMsg_p->MsgBuf_MsgLen - 5);	// length is -5 for 4 CRC bytes and outer checksum
		uint32_t crc32_msg = 0;
		memcpy(&crc32_msg, &RxMsg_p->MsgBuf[RxMsg_p->MsgBuf_MsgLen - 5], sizeof(crc32_msg));
		if (crc32_result != crc32_msg)
			return QX_STAT_ERROR_RXMSG_CRC32_FAIL;
	}

	// Print out the recieved packet info for Debug
	#ifdef QX_DEBUG
	QX_debug_print_MsgDetails(RxMsg_p);
	#endif
	
	if(RxMsg_p->Header.Type == QX_MSG_TYPE_CURVAL) {
		while(0);
	}
		
	// Unicast or broadcast message
	if ((RxMsg_p->Header.Target_Addr == QX_Servers[0].Address) || (RxMsg_p->Header.Target_Addr == QX_DEV_ID_BROADCAST))
	{
		// Handle Each type of message
		switch (RxMsg_p->Header.Type){
			
			case QX_MSG_TYPE_READ:
				QX_Srv_Rx_Read(RxMsg_p);
				break;
			
			case QX_MSG_TYPE_WRITE_ABS:
			case QX_MSG_TYPE_WRITE_REL:
				QX_Srv_Rx_Write(RxMsg_p);
				break;
			
			case QX_MSG_TYPE_CURVAL:
				QX_Cli_Rx_CurVal(RxMsg_p);
				break;
			
			default:
				return QX_STAT_ERROR_MSG_TYPE_NOT_SUPPORTED;
		}
	}

	// Allow application specific message forwarding if target address does not match (send a copy of the message out one or more other comm ports)
	// All server and client nodes have same address so check against one only
	if ((RxMsg_p->Header.Target_Addr != QX_Servers[0].Address))	
	{
		QX_FwdMsg_CB(RxMsg_p);
	}
	
	return QX_STAT_OK;
}


//----------------------------------------------------------------------------
// Server - Recv Read
// (No data payload) then APP->MSG
void QX_Srv_Rx_Read(QX_Msg_t *RxMsg_p)
{
	// Check Address - For each server node, if unicast & address match or broadcast, handle it
	for (int srv_i = 0; srv_i < QX_NUM_SRV; srv_i++){
		if ((RxMsg_p->Header.Target_Addr == QX_Servers[srv_i].Address) || (RxMsg_p->Header.Target_Addr == QX_DEV_ID_BROADCAST)){
			QX_TxMsgOptions_t options;
			QX_InitTxOptions(&options); 
			options.Legacy = RxMsg_p->Legacy_Header;
			options.use_CRC32 = RxMsg_p->Header.AddCRC32;
			options.FF_Ext = RxMsg_p->Header.FF_Ext;
			options.Remove_Addr_Fields = RxMsg_p->Header.Remove_Addr_Fields;
			options.Remove_Req_Fields = 1;		// No need for request fields in a response.
			options.Target_Addr = RxMsg_p->Header.Source_Addr;		// Reverse target
			QX_SendPacket_Srv_CurVal(&QX_Servers[srv_i], RxMsg_p->Header.Attrib, RxMsg_p->CommPort, options);
			while(0);
		}
	}
}

//----------------------------------------------------------------------------
// Server - Recv Write
// MSG->APP then APP->MSG
void QX_Srv_Rx_Write(QX_Msg_t *RxMsg_p)
{
	// Set parsing type
	if (RxMsg_p->Header.Type == QX_MSG_TYPE_WRITE_REL){
		RxMsg_p->Parse_Type = QX_PARSE_TYPE_WRITE_REL_RECV;
	} else if (RxMsg_p->Header.Type == QX_MSG_TYPE_WRITE_ABS){
		RxMsg_p->Parse_Type = QX_PARSE_TYPE_WRITE_ABS_RECV;
	}
	
	// Check Address - For each server node, if unicast & address match or broadcast, handle it
	for (int srv_i = 0; srv_i < QX_NUM_SRV; srv_i++){
		if ((RxMsg_p->Header.Target_Addr == QX_Servers[srv_i].Address) || (RxMsg_p->Header.Target_Addr == QX_DEV_ID_BROADCAST)){
			QX_Servers[srv_i].Parser_CB(RxMsg_p);	// Application callback
		
			// Re-purpose the message to send it
			if (RxMsg_p->DisableStdResponse == 0){
				QX_TxMsgOptions_t options;
				QX_InitTxOptions(&options);
				options.use_CRC32 = RxMsg_p->Header.AddCRC32;
				options.FF_Ext = RxMsg_p->Header.FF_Ext;
				options.Remove_Addr_Fields = RxMsg_p->Header.Remove_Addr_Fields;
				options.Remove_Req_Fields = 1;		// No need for request fields in a response.
				options.Target_Addr = RxMsg_p->Header.Source_Addr;		// Reverse target
				options.Legacy = RxMsg_p->Legacy_Header;
				QX_SendPacket_Srv_CurVal(&QX_Servers[srv_i], RxMsg_p->Header.Attrib, RxMsg_p->CommPort, options);
			}
		}
	}
}


//----------------------------------------------------------------------------
// Client - Recv Current Value
// MSG->APP
void QX_Cli_Rx_CurVal(QX_Msg_t *RxMsg_p)
{
	// Set parsing type
	RxMsg_p->Parse_Type = QX_PARSE_TYPE_CURVAL_RECV;
	
	// Check Address - For each client instance, if unicast & address match or broadcast, handle it
	for (int cli_i = 0; cli_i < QX_NUM_CLI; cli_i++){
		if ((RxMsg_p->Header.Target_Addr == QX_Clients[cli_i].Address) || (RxMsg_p->Header.Target_Addr == QX_DEV_ID_BROADCAST)){
			QX_Clients[cli_i].Parser_CB(RxMsg_p);	// Application callback
		}
	}
}


//----------------------------------------------------------------------------
// Transmit QX Packet according to Message Structure
QX_Stat_e QX_TxMsg_Setup(QX_Msg_t *TxMsg_p)
{
	// Set the Buffer pointer to the start of the Attribute field accounting for the maximum number of header fields 
	// (unknown length prior to parsing) ('Q' + 'X' + LEN0 + LEN1)
	TxMsg_p->MsgBufAtt_p = &TxMsg_p->MsgBuf[4];
	TxMsg_p->MsgBuf_p = TxMsg_p->MsgBufAtt_p;
	
	// Build the Frame Header
	if ((TxMsg_p->Header.Attrib <= 128) && TxMsg_p->Legacy_Header){		// Attribute must be in the legacy range to tx as legacy!
		if (*QX_BuildHeader_Legacy != NULL){
			QX_BuildHeader_Legacy(TxMsg_p);
		} else {
			return QX_STAT_ERROR;
		}
	} else {									
		QX_BuildHeader(TxMsg_p);
	}
	
	return QX_STAT_OK;
}


//----------------------------------------------------------------------------
// After message data has been parsed, finish building the message
QX_Stat_e QX_TxMsg_Finish(QX_Msg_t *TxMsg_p)
{	
	uint8_t QX_use2ByteLen = 0;
	
	// If this attribute isn't handled, (no data) return
	if(TxMsg_p->AttNotHandled == 1) return QX_STAT_ERROR_ATT_NOT_HANDLED;
	
	// Find the Message Length (Attribute to End of Payload)
	TxMsg_p->Header.MsgLength = TxMsg_p->MsgBuf_p - TxMsg_p->MsgBufAtt_p;
	
	// force two_byte length field if the message body is the legacy type or is already larger than 100 so that we can fit in padding + CRC if needed
	if (TxMsg_p->Legacy_Header || (TxMsg_p->Header.MsgLength > 100)){
		TxMsg_p->MsgBufStart_p = &TxMsg_p->MsgBuf[0];
		QX_use2ByteLen = 1;
	} else {
		TxMsg_p->MsgBufStart_p = &TxMsg_p->MsgBuf[1];
	}
	
	// Save the size of the overall message buffer after determining start location, before any CRC is added, before outer checksum is added
	TxMsg_p->MsgBuf_MsgLen = TxMsg_p->MsgBuf_p - TxMsg_p->MsgBufStart_p;
	
	// If CRC32 is used, find sizing with padding
	if (TxMsg_p->Header.AddCRC32){
		
		// Add padding to get to 4 byte alignment
		uint32_t bytes_to_add = 4 - ((TxMsg_p->MsgBuf_MsgLen) % 4);		// CRC will bec checked over all bytes except the 8 bit outer checksum
		memset(TxMsg_p->MsgBuf_p, 0, bytes_to_add);		// write zeros to the padding
		TxMsg_p->MsgBuf_p += bytes_to_add;				// Move to where the CRC should be inserted
		TxMsg_p->MsgBuf_MsgLen += bytes_to_add;			// msg length not including CRC + outer checksum
		TxMsg_p->Header.MsgLength = (TxMsg_p->MsgBuf_p - TxMsg_p->MsgBufAtt_p) + 4;	// length between attribute and outer checksum
	}
	
	// Add In the Final Message Size (Expandable if above 100 bytes) and Start Bytes
	if (TxMsg_p->Legacy_Header){
			TxMsg_p->MsgBuf[0] = 'Q';
			TxMsg_p->MsgBuf[1] = 'B';
			TxMsg_p->MsgBuf[2] = (TxMsg_p->Header.MsgLength >> 8) & 0xFF;
			TxMsg_p->MsgBuf[3] = TxMsg_p->Header.MsgLength & 0xFF;
	} else {	// QX
		if (QX_use2ByteLen) {
			TxMsg_p->MsgBuf[0] = 'Q';
			TxMsg_p->MsgBuf[1] = 'X';
			TxMsg_p->MsgBuf[2] = (TxMsg_p->Header.MsgLength & 0x7F) | 0x80;
			TxMsg_p->MsgBuf[3] = ((TxMsg_p->Header.MsgLength >> 7) & 0x7F);
		} else {
			TxMsg_p->MsgBuf[1] = 'Q';
			TxMsg_p->MsgBuf[2] = 'X';
			TxMsg_p->MsgBuf[3] = TxMsg_p->Header.MsgLength & 0x7F;
		}
	}
	
	// Add in the CRC32 if needed
	if (TxMsg_p->Header.AddCRC32){
		uint32_t crc = QX_accumulate_crc32(0xFFFFFFFF, TxMsg_p->MsgBufStart_p, TxMsg_p->MsgBuf_MsgLen);
		memcpy(TxMsg_p->MsgBuf_p, &crc, sizeof(crc));
		TxMsg_p->MsgBuf_p += 4;		// Add space for CRC32 checksum
		TxMsg_p->MsgBuf_MsgLen = TxMsg_p->MsgBuf_p - TxMsg_p->MsgBufStart_p;	// Update the overall msg length
	}
	
	// Calculate overall outer checksum
	uint8_t chksum = QX_Calc8bChecksum(TxMsg_p->MsgBufAtt_p, TxMsg_p->Header.MsgLength);
	
	*TxMsg_p->MsgBuf_p++ = 0xFF - chksum;	// Add the Overall Checksum
	TxMsg_p->MsgBuf_MsgLen++;	// Final message length on the wire
	
	#ifdef QX_DEBUG
	printf("\n\rRaw Msg Packet Send:\n\r");
	//QX_debug_print_Hex(TxMsg_p->MsgBufStart_p, TxMsg_p->MsgBuf_MsgLen);
	QX_debug_print_MsgDetails(TxMsg_p);
	#endif
	
	// Send the Message to the Appropriate Comms Port
	QX_SendMsg2CommsPort_CB(TxMsg_p);
	
	return QX_STAT_OK;
}


//----------------------------------------------------------------------------
// Build a QX Message Header
void QX_BuildHeader(QX_Msg_t *Msg_p)
{
	// Start at the Attribute Field
	Msg_p->MsgBuf_p = Msg_p->MsgBufAtt_p;

	// Add the Extendible Attribute Number
	QX_AddExtdValToBuf(&Msg_p->MsgBuf_p, Msg_p->Header.Attrib);

	Msg_p->Header.AddOptionByte1 = 0;
	
	// Check if option byte 1 is needed.
	if (Msg_p->Header.AddCRC32){
		Msg_p->Header.AddOptionByte1 = 1;
	}
	
	// Add Base Option Byte
	volatile uint8_t OptionByte = 0;
	OptionByte |= (Msg_p->Header.Type & 0xF);
	OptionByte |= (Msg_p->Header.FF_Ext & 0x01) << 4;
	OptionByte |= (Msg_p->Header.Remove_Req_Fields & 0x01) << 5;
	OptionByte |= (Msg_p->Header.Remove_Addr_Fields & 0x01) << 6;
	OptionByte |= (Msg_p->Header.AddOptionByte1 & 0x01) << 7;
	*Msg_p->MsgBuf_p++ = OptionByte;
	
	// Add option byte 1 if needed
	if(Msg_p->Header.AddOptionByte1){
		OptionByte = 0;
		OptionByte |= (Msg_p->Header.AddCRC32 & 0x01) << 0;
		*Msg_p->MsgBuf_p++ = OptionByte;
	}
	
	// Add the addresses.
	if (Msg_p->Header.Remove_Addr_Fields == 0){
		QX_AddExtdValToBuf(&Msg_p->MsgBuf_p, Msg_p->Header.Source_Addr);
		QX_AddExtdValToBuf(&Msg_p->MsgBuf_p, Msg_p->Header.Target_Addr);
	} else {
		Msg_p->Header.Source_Addr = QX_DEV_ID_BROADCAST;
		Msg_p->Header.Target_Addr = QX_DEV_ID_BROADCAST;
	}

	// Add the transmit/response request fields.
	if (Msg_p->Header.Remove_Req_Fields == 0){
		QX_AddExtdValToBuf(&Msg_p->MsgBuf_p, Msg_p->Header.TransReq_Addr);
		QX_AddExtdValToBuf(&Msg_p->MsgBuf_p, Msg_p->Header.RespReq_Addr);
	} else {
		Msg_p->Header.TransReq_Addr = QX_DEV_ID_BROADCAST;
		Msg_p->Header.RespReq_Addr = QX_DEV_ID_BROADCAST;
	}
	
	Msg_p->BufPayloadStart_p = Msg_p->MsgBuf_p;	// Set the Payload Begin Pointer
}

//----------------------------------------------------------------------------
// Parse a QX Type Message
// Note, this Function leaves the Pointer at the Start of the payload
void QX_ParseHeader(QX_Msg_t *Msg_p)
{
	volatile uint8_t OptionByte;
	volatile uint32_t temp32;
	Msg_p->MsgBuf_p = Msg_p->MsgBufAtt_p;		// Set the message pointer to the attribute position.


	// Get the Extendible Attribute Number
	Msg_p->Header.Attrib = QX_GetExtdValFromBuf(&Msg_p->MsgBuf_p);

	// Get Base Option Byte Bits
	OptionByte = *Msg_p->MsgBuf_p++;
	Msg_p->Header.Type = (QX_Msg_Type_e)(OptionByte & 0xF);
	Msg_p->Header.FF_Ext = (OptionByte >> 4) & 0x1;
	Msg_p->Header.Remove_Req_Fields = (OptionByte >> 5) & 0x1;
	Msg_p->Header.Remove_Addr_Fields = (OptionByte >> 6) & 0x1;
	Msg_p->Header.AddOptionByte1 = (OptionByte >> 7) & 0x1;
	
	// Option byte 1
	if(Msg_p->Header.AddOptionByte1){
		OptionByte = *Msg_p->MsgBuf_p++;
		Msg_p->Header.AddCRC32 = (OptionByte >> 0) & 0x1;
	}

	// If Availible, Get the Addresses
	if (Msg_p->Header.Remove_Addr_Fields == 0){
		Msg_p->Header.Source_Addr = QX_GetExtdValFromBuf(&Msg_p->MsgBuf_p);
		Msg_p->Header.Target_Addr = QX_GetExtdValFromBuf(&Msg_p->MsgBuf_p);
	}
	
	// If Availible, Get the Request Fields
	if (Msg_p->Header.Remove_Req_Fields == 0){
		Msg_p->Header.TransReq_Addr = (QX_DevId_e)(QX_GetExtdValFromBuf(&Msg_p->MsgBuf_p));
		Msg_p->Header.RespReq_Addr = (QX_DevId_e)(QX_GetExtdValFromBuf(&Msg_p->MsgBuf_p));
	}
	
	// Add Freefly extension bytes if needed
	if (Msg_p->Header.FF_Ext){
		Msg_p->MsgBuf_p += 2;
	}
}


//----------------------------------------------------------------------------
// Calculate 8 Bit Checksum
uint8_t QX_Calc8bChecksum(uint8_t *buf_p, uint32_t len)
{
	int j;
	uint8_t checksum = 0;
	for(j = 0; j < len; j++)
	{
		checksum += *buf_p++;
	}
	return checksum;
}

//----------------------------------------------------------------------------
// Add a 7th bit extendable (4 byte max) value to a buffer
void QX_AddExtdValToBuf(uint8_t **p, uint32_t Val)
{	
	int n;
	for (n = 0; n < 4; n++){
		uint8_t this_chunk = (Val >> (7*n)) & 0x7F;
		uint8_t next_chunk = (Val >> (7*(n+1))) & 0x7F;
		if (next_chunk > 0){
			**p = this_chunk | 0x80;
			(*p)++;
		} else {
			**p = this_chunk;
			(*p)++;
			break;
		}
	}
}

//----------------------------------------------------------------------------
// Get a 7th bit extendable (4 byte max) value from a buffer
uint32_t QX_GetExtdValFromBuf(uint8_t **p)
{
	uint32_t Val = 0;
	int n;
	for (n = 0; n < 4; n++){
		Val = (((uint32_t)(**p & 0x7F)) << (7*n)) | Val;
		if (**p & 0x80){
			(*p)++;
		} else {
			(*p)++;
			break;
		}
	}
	return Val;
}


//----------------------------------------------------------------------------
// Disable the default response to a message
void QX_Disable_Default_Response(QX_Msg_t *Msg_p)
{
	Msg_p->DisableStdResponse = 1;
}


//----------------------------------------------------------------------------
// compute a chunk of the CRC
uint32_t QX_compute_crc32(uint8_t data)
{
    uint8_t i;
    uint32_t crc;
    
    crc = (uint32_t)data << 24;
    for(i = 0; i < 8; i++)
    {
        if((crc & 0x80000000) != 0)
            crc = (crc << 1) ^ 0x04C11DB7;
        else
            crc = (crc << 1);
    }
    
    return crc;
}


//----------------------------------------------------------------------------
// Calculate CRC32 - overrideable
uint32_t QX_accumulate_crc32(uint32_t initial, const uint8_t * data, uint32_t size)
{
    uint32_t i;
    uint32_t final;
    
    final = initial;
    for(i = 0; i < size; i++)
        final = QX_compute_crc32((uint8_t)(final >> 24) ^ data[i]) ^ (final << 8);
    
    return final;
}


//****************************************************************************
// Public Function Definitions
//****************************************************************************

//----------------------------------------------------------------------------
// Initialize the server with the address, parser callback, etc
void QX_InitSrv(QX_Server_t *QX_Server, QX_DevId_e Address, QX_ID_e IDtype, uint8_t *(*Parser_CB)(QX_Msg_t *))
{
	uint32_t myAddress = Address;
	
	QX_Server->Parser_CB = Parser_CB;	// Register Callback for parsing
	QX_Server->Address = Address;
	QX_Server->isServer = true;
 	
 	// ID type
 	if (IDtype == QX_ID_DEVICE) {
 		QX_Server->Address = myAddress;
 	} else if (IDtype == QX_ID_UID) {
 		// Take CRC32 of 96-bit MCU UID >> Use only upper three bytes (21 bits) and combine with QX Device ID in the lower byte >> Turn on 8th extendible bits (and make sure last one is 0)
 		QX_Server->Address = (( myAddress | (QX_accumulate_crc32(0xFFFFFFFF, (uint8_t *) UID_BASE, 12)<<8) ) | 0x00808080) & 0x7FFFFFFF;		
 	}
}

//----------------------------------------------------------------------------
// Initialize the client with the address, parser callback, etc
void QX_InitCli(QX_Client_t *QX_Client, QX_DevId_e Address, QX_ID_e IDtype, uint8_t *(*Parser_CB)(QX_Msg_t *))
{
	uint32_t myAddress = Address;
	
	QX_Client->Parser_CB = Parser_CB;	// Register Callback for parsing
	QX_Client->Address = Address;
	QX_Client->isServer = false;
	
 	// ID type
 	if (IDtype == QX_ID_DEVICE) {
 		QX_Client->Address = myAddress;
 	} else if (IDtype == QX_ID_UID) {
 		// Take CRC32 of 96-bit MCU UID >> Use only upper three bytes (21 bits) and combine with QX Device ID in the lower byte >> Turn on 8th extendible bits (and make sure last one is 0)
 		QX_Client->Address = (( myAddress | (QX_accumulate_crc32(0xFFFFFFFF, (uint8_t *) UID_BASE, 12)<<8) ) | 0x00808080) & 0x7FFFFFFF;		
 	}
}

//----------------------------------------------------------------------------
// Verify the length of an incoming message
// To be called by the QX parser immediately after the attribute ID field downloaded
// Returns 1 if the length is acceptable and it's ok to proceed
// Returns 0 if the packet should be rejected due to an excessive length
uint8_t QX_VerifyLen(QX_Comms_Port_e port) {
	//Extract the attribute ID from the incoming message
	uint8_t * att_ptr = QX_CommsPorts[port].RxMsg.MsgBufAtt_p;
	uint32_t attribute = QX_GetExtdValFromBuf(&att_ptr);
	
	//Verify the message length is within expected range
	if (QX_Packet_Len_Lookup(attribute) >= QX_CommsPorts[port].RxMsg.Header.MsgLength) {
		return 1; //The message is an acceptable length
	} else {
		return 0; //The message has an invalid (probably corrupt) length, reject it
	}
}

//----------------------------------------------------------------------------
//Initialize the QX state machine
//Used from within QX_StreamRxCharSM whenever a 'Q' is received at the appropriate time to initialize the state machine and start receiving a packet
void  QX_InitializeSMPacketStartOnQ(QX_Comms_Port_e port) {
	QX_CommsPorts[port].RxCntr = 1;
	QX_CommsPorts[port].RxMsg.MsgBuf[0] = 'Q';
	QX_CommsPorts[port].RxMsg.MsgBuf_p = &QX_CommsPorts[port].RxMsg.MsgBuf[1];
	QX_CommsPorts[port].rx_msg_start_time = QX_GetTicks_ms(); //Store the current time for safety timeout
	QX_CommsPorts[port].len_approved = 0; //Reset the length-approved flag for the next packet
}


// QX Stream RX Char State Machine
// Accepts 1 charater from a serial data stream and recieves full messages
// Returns 1 if a message was parsed in this call
uint8_t QX_StreamRxCharSM(QX_Comms_Port_e port, unsigned char rxbyte)
{
	uint8_t chksum;
	
	#ifdef USE_QX_PACKET_TIMEOUT
	if ((QX_CommsPorts[port].len_approved) && ((((QX_CommsPorts[port].RxMsg.Header.MsgLength + 7) * QX_GetPortBaudrateMillisecondsPerBitTimes4096(port)) >> 12) + 2 + QX_GetPortLatencyMilliseconds(port) < ((QX_GetTicks_ms() - QX_CommsPorts[port].rx_msg_start_time)))) {
		//The message has timed out, need to reset the receiving state machine
		QX_CommsPorts[port].RxState = QX_RX_STATE_START_WAIT;
	}
	#endif //USE_QX_PACKET_TIMEOUT
	
	switch(QX_CommsPorts[port].RxState)
	{
		case QX_RX_STATE_START_WAIT:
				if(rxbyte == 'Q')
				{
					QX_InitializeSMPacketStartOnQ(port);
					QX_CommsPorts[port].RxState = QX_RX_STATE_GET_PROTOCOL_VER;
				} else {
					QX_CommsPorts[port].non_Q_cnt++;
				}
				break;
				
		case QX_RX_STATE_GET_PROTOCOL_VER:
				*QX_CommsPorts[port].RxMsg.MsgBuf_p++ = rxbyte;
				QX_CommsPorts[port].RxCntr++;
				if(rxbyte == 'X'){
					QX_CommsPorts[port].RxMsg.Legacy_Header = 0;
					QX_CommsPorts[port].RxState = QX_RX_STATE_GET_QX_LEN0;
				}
				else if (rxbyte == 'B'){
					QX_CommsPorts[port].RxMsg.Legacy_Header = 1;
					QX_CommsPorts[port].RxState = QX_RX_STATE_GET_QB_LEN0;
				} else if (rxbyte == 'Q'){
					//Received a Q so we want to accept that as the start of a new packet and remain in this state after resetting the receiver
					//Otherwise, receiving 'QQX...' will result in the packet being dropped due to the parser being in the wrong state during the second Q.
					QX_InitializeSMPacketStartOnQ(port);
				} else {
					QX_CommsPorts[port].RxState = QX_RX_STATE_START_WAIT;
				}
				break;
				
		case QX_RX_STATE_GET_QX_LEN0:	// Length LSB
			*QX_CommsPorts[port].RxMsg.MsgBuf_p++ = rxbyte;
				QX_CommsPorts[port].RxCntr++;
		
			if ((rxbyte & 0x80) || (QX_CommsPorts[port].RxMsg.Legacy_Header)){		// Check for Bit 7 extension
				QX_CommsPorts[port].RxMsg.Header.MsgLength = (uint16_t)(rxbyte & ~0x80);
				QX_CommsPorts[port].RxState = QX_RX_STATE_GET_QX_LEN1;
			} else {
				QX_CommsPorts[port].RxMsg.Header.MsgLength = (uint16_t)(rxbyte);
				QX_CommsPorts[port].RxMsg.MsgBufAtt_p = QX_CommsPorts[port].RxMsg.MsgBuf_p;
				QX_CommsPorts[port].RxMsg.RunningChecksum = 0;
				QX_CommsPorts[port].RxState = QX_RX_STATE_GET_DATA;
				
				if(QX_MAX_PAYLOAD_LEN < QX_CommsPorts[port].RxMsg.Header.MsgLength) 
				{
					QX_CommsPorts[port].RxState = QX_RX_STATE_START_WAIT;
				}
			}
			
			break;
			
		case QX_RX_STATE_GET_QX_LEN1:	// Length MSB
			*QX_CommsPorts[port].RxMsg.MsgBuf_p++ = rxbyte;
			QX_CommsPorts[port].RxCntr++;
			QX_CommsPorts[port].RxMsg.MsgBufAtt_p = QX_CommsPorts[port].RxMsg.MsgBuf_p;
			
			if (rxbyte & 0x80){
				QX_CommsPorts[port].RxState = QX_RX_STATE_START_WAIT;	// Should not reach here, 21 bit length not supported yet
			} else {
				QX_CommsPorts[port].RxMsg.Header.MsgLength |= (((uint16_t)(rxbyte & ~0x80)) << 7);
				QX_CommsPorts[port].RxMsg.RunningChecksum = 0;
				QX_CommsPorts[port].RxState = QX_RX_STATE_GET_DATA;
			}
			
			if(QX_MAX_PAYLOAD_LEN < QX_CommsPorts[port].RxMsg.Header.MsgLength)
			{
				QX_CommsPorts[port].RxState = QX_RX_STATE_START_WAIT;
			}
			
			break;
				
		case QX_RX_STATE_GET_QB_LEN0:
				*QX_CommsPorts[port].RxMsg.MsgBuf_p++ = rxbyte;
				QX_CommsPorts[port].RxCntr++;
				QX_CommsPorts[port].RxMsg.Header.MsgLength = (uint16_t)rxbyte << 8;
				QX_CommsPorts[port].RxState = QX_RX_STATE_GET_QB_LEN1;
				break;
				
		case QX_RX_STATE_GET_QB_LEN1:
				*QX_CommsPorts[port].RxMsg.MsgBuf_p++ = rxbyte;	// Leave the message buf pointer at the attribute byte
				QX_CommsPorts[port].RxCntr++;
				QX_CommsPorts[port].RxMsg.MsgBufAtt_p = QX_CommsPorts[port].RxMsg.MsgBuf_p;
				QX_CommsPorts[port].RxMsg.Header.MsgLength |= (uint16_t)rxbyte;
				QX_CommsPorts[port].RxMsg.RunningChecksum = 0;
				QX_CommsPorts[port].RxState = QX_RX_STATE_GET_DATA;
				if(QX_MAX_PAYLOAD_LEN < QX_CommsPorts[port].RxMsg.Header.MsgLength)
				{
						QX_CommsPorts[port].RxState = QX_RX_STATE_START_WAIT;
				}
				break;
				
		case QX_RX_STATE_GET_DATA:
				*QX_CommsPorts[port].RxMsg.MsgBuf_p++ = rxbyte;
				if ((!QX_CommsPorts[port].len_approved) && (!(rxbyte & 0x80))) { //Length hasn't yet been verified, and the full attribute has been downloaded
					//Time to verify the length of this packet and reject the incoming message if it's too long
					if (QX_VerifyLen(port)) {
						QX_CommsPorts[port].len_approved = 1;
					} else {
						QX_CommsPorts[port].RxState = QX_RX_STATE_START_WAIT; //Start over, the packet has been rejected by excessive length
					}
				}
				QX_CommsPorts[port].RxCntr++;
				QX_CommsPorts[port].RxMsg.RunningChecksum += rxbyte;
				if(QX_CommsPorts[port].RxMsg.Header.MsgLength <= QX_CommsPorts[port].RxCntr - (QX_CommsPorts[port].RxMsg.MsgBufAtt_p - &QX_CommsPorts[port].RxMsg.MsgBuf[0]))
				{
						QX_CommsPorts[port].RxState = QX_RX_STATE_GET_CHKSUM;
				}
				break;
				
		case QX_RX_STATE_GET_CHKSUM:
				*QX_CommsPorts[port].RxMsg.MsgBuf_p++ = rxbyte;
				QX_CommsPorts[port].RxCntr++;
				chksum = rxbyte;
				QX_CommsPorts[port].RxState = QX_RX_STATE_START_WAIT;
				QX_CommsPorts[port].RxMsg.CommPort = port;
				if((chksum + QX_CommsPorts[port].RxMsg.RunningChecksum) == 0xFF)		// Is checksum ok?
				{
					QX_CommsPorts[port].Timeout_Cntr = 0;
					QX_CommsPorts[port].last_rx_msg_time = QX_GetTicks_ms();
					QX_CommsPorts[port].Connected = 1;
					QX_CommsPorts[port].RxMsg.MsgBuf_MsgLen = QX_CommsPorts[port].RxCntr;
					QX_RxMsg(&QX_CommsPorts[port].RxMsg);	// Receive the Message
					return 1;
				} else {
					QX_CommsPorts[port].ChkSumFail_cnt++;
				}
				break;
	}
	return 0;
}

//----------------------------------------------------------------------------
// Call periodically to update lost connection status
void QX_Connection_Status_Update(QX_Comms_Port_e port)
{
	// Update Timeout Timer
	QX_CommsPorts[port].Timeout_Cntr = (QX_GetTicks_ms() - QX_CommsPorts[port].last_rx_msg_time);
	
	// Turn off connected flag if needed (turned on by successful packet RX)
	if (QX_CommsPorts[port].Timeout_Cntr > QX_PORT_TIMEOUT_MSEC){
		QX_CommsPorts[port].Connected = 0;
	}
}


//----------------------------------------------------------------------------
// Initialize the TX Options structure for a standard message
void QX_InitTxOptions(QX_TxMsgOptions_t *options)
{
	// Keep address fields by default
	options->Remove_Addr_Fields = 0;
	options->Remove_Req_Fields = 0;
	
	// standard addresses
	options->RespReq_Addr = QX_DEV_ID_BROADCAST;
	options->Target_Addr = QX_DEV_ID_BROADCAST;
	options->TransReq_Addr = QX_DEV_ID_BROADCAST;
	
	// standard flags
	options->FF_Ext = 0;
	options->use_CRC32 = 0;
	
	options->Legacy = 0;
}


//----------------------------------------------------------------------------
// Full Featured Send QX Packet - For use by the Application (Not in auto response to Read/Write)
// This version supports all features
// This function builds an appropriate message structure and calls calls QX_TxMsg().
QX_Stat_e QX_SendPacket_Srv_CurVal(QX_Server_t *Srv_p, uint32_t Attrib, QX_Comms_Port_e CommPort, QX_TxMsgOptions_t options)
{
	QX_Msg_t TxMsg;
	QX_InitMsg(&TxMsg);
	
	TxMsg.CommPort = CommPort;
	TxMsg.Header.Attrib = Attrib;
	TxMsg.Header.Type = QX_MSG_TYPE_CURVAL;
	TxMsg.Header.Target_Addr = options.Target_Addr;
	TxMsg.Header.TransReq_Addr = options.TransReq_Addr;
	TxMsg.Header.RespReq_Addr = options.RespReq_Addr;
	TxMsg.Header.Source_Addr = Srv_p->Address;
	TxMsg.Header.FF_Ext = options.FF_Ext;
	TxMsg.Header.AddCRC32 = options.use_CRC32;
	TxMsg.Legacy_Header = options.Legacy;
	
	QX_TxMsg_Setup(&TxMsg);
	TxMsg.Parse_Type = QX_PARSE_TYPE_CURVAL_SEND;
	TxMsg.MsgBuf_p = Srv_p->Parser_CB(&TxMsg);
	return QX_TxMsg_Finish(&TxMsg);
}

//----------------------------------------------------------------------------
// Full Featured Send QX Packet - For use by the Application (Not in auto response to Read/Write)
// This version supports all features
// This function builds an appropriate message structure and calls calls QX_TxMsg().
QX_Stat_e QX_SendPacket_Cli_Read(QX_Client_t *Cli_p, uint32_t Attrib, QX_Comms_Port_e CommPort, QX_TxMsgOptions_t options)
{
	QX_Msg_t TxMsg;
	QX_InitMsg(&TxMsg);
	
	TxMsg.CommPort = CommPort;
	TxMsg.Header.Attrib = Attrib;
	TxMsg.Header.Type = QX_MSG_TYPE_READ;
	TxMsg.Header.Target_Addr = options.Target_Addr;
	TxMsg.Header.TransReq_Addr = QX_DEV_ID_BROADCAST;
	TxMsg.Header.RespReq_Addr = options.RespReq_Addr;
	TxMsg.Header.Source_Addr = Cli_p->Address;
	TxMsg.Header.FF_Ext = options.FF_Ext;
	TxMsg.Header.AddCRC32 = options.use_CRC32;
	TxMsg.Legacy_Header = options.Legacy;
	
	QX_TxMsg_Setup(&TxMsg);
	return QX_TxMsg_Finish(&TxMsg);	// Read Messages have no data. Finish the message right away!
}

//----------------------------------------------------------------------------
// Full Featured Send QX Packet - For use by the Application (Not in auto response to Read/Write)
// This version supports all features
// This function builds an appropriate message structure and calls calls QX_TxMsg().
QX_Stat_e QX_SendPacket_Cli_WriteABS(QX_Client_t *Cli_p, uint32_t Attrib, QX_Comms_Port_e CommPort, QX_TxMsgOptions_t options)
{
	QX_Msg_t TxMsg;
	QX_InitMsg(&TxMsg);
	
	TxMsg.CommPort = CommPort;
	TxMsg.Header.Attrib = Attrib;
	TxMsg.Header.Type = QX_MSG_TYPE_WRITE_ABS;
	TxMsg.Header.Target_Addr = options.Target_Addr;
	TxMsg.Header.TransReq_Addr = options.TransReq_Addr;
	TxMsg.Header.RespReq_Addr = options.RespReq_Addr;
	TxMsg.Header.Source_Addr = Cli_p->Address;
	TxMsg.Header.FF_Ext = options.FF_Ext;
	TxMsg.Header.AddCRC32 = options.use_CRC32;
  TxMsg.Header.Remove_Addr_Fields = options.Remove_Addr_Fields;
  TxMsg.Header.Remove_Req_Fields = options.Remove_Req_Fields;
	TxMsg.Legacy_Header = options.Legacy;
	
	QX_TxMsg_Setup(&TxMsg);
	TxMsg.Parse_Type = QX_PARSE_TYPE_WRITE_ABS_SEND;
	TxMsg.MsgBuf_p = Cli_p->Parser_CB(&TxMsg);
	return QX_TxMsg_Finish(&TxMsg);
}

//----------------------------------------------------------------------------
// Full Featured Send QX Packet - For use by the Application (Not in auto response to Read/Write)
// This version supports all features
// This function builds an appropriate message structure and calls calls QX_TxMsg().
QX_Stat_e QX_SendPacket_Cli_WriteREL(QX_Client_t *Cli_p, uint32_t Attrib, QX_Comms_Port_e CommPort, QX_TxMsgOptions_t options)
{
	QX_Msg_t TxMsg;
	QX_InitMsg(&TxMsg);
	
	TxMsg.CommPort = CommPort;
	TxMsg.Header.Attrib = Attrib;
	TxMsg.Header.Type = QX_MSG_TYPE_WRITE_REL;
	TxMsg.Header.Target_Addr = options.Target_Addr;
	TxMsg.Header.TransReq_Addr = options.TransReq_Addr;
	TxMsg.Header.RespReq_Addr = options.RespReq_Addr;
	TxMsg.Header.Source_Addr = Cli_p->Address;
	TxMsg.Header.FF_Ext = options.FF_Ext;
	TxMsg.Header.AddCRC32 = options.use_CRC32;
	TxMsg.Legacy_Header = options.Legacy;
	
	QX_TxMsg_Setup(&TxMsg);
	TxMsg.Parse_Type = QX_PARSE_TYPE_WRITE_REL_SEND;
	TxMsg.MsgBuf_p = Cli_p->Parser_CB(&TxMsg);
	return QX_TxMsg_Finish(&TxMsg);
}

//----------------------------------------------------------------------------
// Send QX Packet with TRID and RRID for control.
// This version supports all features
// This function builds an appropriate message structure and calls calls QX_TxMsg().
QX_Stat_e QX_SendPacket_Cli_Control(QX_Client_t *Cli_p, uint32_t Attrib, QX_Comms_Port_e CommPort, QX_TxMsgOptions_t options)
{	
	return QX_SendPacket_Cli_WriteABS(Cli_p, Attrib, CommPort, options);
}


