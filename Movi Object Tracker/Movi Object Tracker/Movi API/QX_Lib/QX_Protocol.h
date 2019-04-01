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
		
    Filename: "QX_Protocol.h"
		
	NOTE: THIS HEADER SHOULD ONLY BE INCLUDED IN QX_Protocol_App.c/.h, and not in other application files.
	
-----------------------------------------------------------------*/

#ifndef QX_PROTOCOL_H
#define QX_PROTOCOL_H

//****************************************************************************
// Headers
//****************************************************************************
#include <stdlib.h>				// for Standard Data Types
#include <stdint.h>				// for Standard Data Types
#include "QX_App_Config.h"		// This contains the application specific types and defines for configuration

//****************************************************************************
// Definitions
//****************************************************************************
#define QX_MAX_MSG_LEN				(QX_MAX_OUTER_FRAME_LEN + QX_MAX_PAYLOAD_LEN)
#define QX_MAX_OUTER_FRAME_LEN		5	// Q+X+LEN1+LEN2+CHKSUM = 5
#define QX_MAX_PAYLOAD_LEN			2048 //This should never exceed 1,048,568 without reworking the timeout system
#define QX_MAX_PAYLOAD_LEN_DEFAULT  64
#define QX_PORT_TIMEOUT_MSEC		500

//****************************************************************************
// Data Types
//****************************************************************************

typedef enum {
	QX_RX_STATE_START_WAIT = 0,
	QX_RX_STATE_GET_PROTOCOL_VER,
	QX_RX_STATE_GET_QX_LEN0,
	QX_RX_STATE_GET_QX_LEN1,
	QX_RX_STATE_GET_QB_LEN0,
	QX_RX_STATE_GET_QB_LEN1,
	QX_RX_STATE_GET_DATA,
	QX_RX_STATE_GET_CHKSUM
} QX_Rx_State_e;

// DEVICE IDs - 7 bits (Used in Source/Destination IDs)
typedef enum {
	QX_DEV_ID_BROADCAST = 0,
	QX_DEV_ID_WEDGE_LENS_CONTROLLER,		// This placement is due to legacy reasons
	QX_DEV_ID_GIMBAL,
	QX_DEV_ID_GIMBAL_INT_FIZ,
	QX_DEV_ID_INTERNAL_GUI,
	QX_DEV_ID_MOBILE_CONFIG_GUI,
	QX_DEV_ID_ENGINEERING_CONFIG_GUI,
	QX_DEV_ID_MOVI_CONTROLLER,
	QX_DEV_ID_LENS_CONTROLLER,
	QX_DEV_ID_POD_CONTROLLER_1,
	QX_DEV_ID_POD_CONTROLLER_2,
	QX_DEV_ID_POD_CONTROLLER_3,
	QX_DEV_ID_POD_CONTROLLER_4,
	QX_DEV_ID_EXT_FIZ_CAM1,
	QX_DEV_ID_EXT_FIZ_CAM2,
	QX_DEV_ID_EXT_FIZ_3D,
	QX_DEV_ID_FLIGHT_CONTROLLER_CORE1,
	QX_DEV_ID_FLIGHT_CONTROLLER_CORE2,
	QX_DEV_ID_GPS_COMPASS_UNIT,
	QX_DEV_ID_FLOGGER,
	QX_DEV_ID_MOVI_API_CONTROLLER,
	QX_DEV_ID_PILOT_FOCUS_CONTROLLER,
	QX_DEV_ID_PILOT_IRIS_ZOOM_CONTROLLER,
	QX_DEV_ID_UNIVERSAL_MOTOR_DRIVE_GENERIC_HARDWARE_NO_SPECIAL_FEATURES,
	QX_DEV_ID_MOTOR_DRIVE_TESTER,
	QX_DEV_ID_UNIVERSAL_MOTOR_DRIVE_MINI_F7_FULL_IO,
} QX_DevId_e;

// QX ID type (Used in Source/Destination IDs)
typedef enum {
	QX_ID_DEVICE = 0,		// Device type only ID (using QX_DevId_e enum)
	QX_ID_UID,					// Device type + 21 bits of MCU UID
} QX_ID_e;

// QX Message Types (As seen on wire, not for parsing)
typedef enum {
	QX_MSG_TYPE_CURVAL = 0,				// Current Value of the Attribute
	QX_MSG_TYPE_READ,					// Read Request (Cur Val is Response)
	QX_MSG_TYPE_WRITE_ABS,				// Writes the Absolute Values to the Application Variables
	QX_MSG_TYPE_WRITE_REL				// Writes the Relative Values to the Application Variables
} QX_Msg_Type_e;

// QX Parsing Types (used to determine which direction to parse data between message and application data)
typedef enum {
	QX_PARSE_TYPE_CURVAL_SEND = 0,		// Packs data from application variables to a send buffer
	QX_PARSE_TYPE_CURVAL_RECV,			// Un-Packs data from Rx buffer into application variables
	QX_PARSE_TYPE_WRITE_ABS_SEND,		// Writes the Absolute Value of application variables to message buffers
	QX_PARSE_TYPE_WRITE_ABS_RECV,		// Writes the Absolute Value of message buffers to the Application Variables
	QX_PARSE_TYPE_WRITE_REL_SEND,		// Writes the Relative Value of application variables to message buffers
	QX_PARSE_TYPE_WRITE_REL_RECV,		// Writes the Relative Value of message buffers to the Application Variables
} QX_Parse_Type_e;

// QX Status Enum
typedef enum {
	QX_STAT_OK = 0,
	QX_STAT_ERROR,
	QX_STAT_ERROR_MSG_TYPE_NOT_SUPPORTED,
	QX_STAT_ERROR_EXTENSION_FAILED,
	QX_STAT_ERROR_INVALID_EXTENSION,
	QX_STAT_ERROR_MSG_LENGTH_INVALID,
	QX_STAT_ERROR_KEY_REQUIRED,
	QX_STAT_ERROR_RXMSG_CRC32_FAIL,
	QX_STAT_ERROR_ATT_NOT_HANDLED
} QX_Stat_e;

// Contains options for TX messages that will be passed to the send functions
typedef struct
{
	uint8_t FF_Ext;					// Freefly protocol extension
	uint8_t use_CRC32;				// set to 1 to use crc32 for higher data integrity
	
	// Addressing
	uint8_t Remove_Addr_Fields;		// Removes the Source_Addr and Target_Addr fields (for speed optimized transmission when the addresses not needed)
	uint8_t Remove_Req_Fields;		// Remove the TransFreq_Addr and RespReq_Addr fields.
	uint32_t Target_Addr;				// Target Address
	QX_DevId_e TransReq_Addr;		// Transmit Request Address
	QX_DevId_e RespReq_Addr;		// Response Request Address
	bool Legacy;
} QX_TxMsgOptions_t;

// Message Frame Header Data
// All of this data is actually contained in the header as seen on the wire
typedef struct
{	
	uint16_t MsgLength;				// Message Length Field
	uint32_t Attrib;				// 32 bit Attribute Number
	QX_Msg_Type_e Type;				// Message Type (enum)

	// Misc Option Byte Flags
	uint8_t AddOptionByte1;			// Adds Option byte 1
	uint8_t AddCRC32;				// pads the message frame to be 32 bit aligned not including the outer 8 bit checksum

	// Freefly protocol extension
	uint8_t FF_Ext;
	uint8_t FF_Ext_R0;
	uint8_t FF_Ext_R1;

	// Addressing
	uint8_t Remove_Addr_Fields;		// Removes the Source_Addr and Target_Addr fields (for speed optimized transmission when the addresses not needed)
	uint8_t Remove_Req_Fields;		// Remove the TransFreq_Addr and RespReq_Addr fields.

	uint32_t Source_Addr;				// Source Address
	uint32_t Target_Addr;				// Target Address
	QX_DevId_e TransReq_Addr;		// Transmit Request Address
	QX_DevId_e RespReq_Addr;		// Response Request Address
	
} QX_MsgHeader_t;

// QX Message Structure
// This contains all of the data that makes up a QX Message
// The "QX_" functions operate on instances of this data type.
typedef struct {
	
	// Message Meta Data
	QX_Parse_Type_e Parse_Type;		// Message Parsing Type (used in parser callback to determine the pack/unpack data direction)
	uint8_t DisableStdResponse;		// If 1, the Auto Response to Write and Read Mesasages will be disabled. This allows the Message Parser to Control the option of a Response Message.
	uint8_t RunningChecksum;		// Running Checksum Value for calculating checksum while recieving characters
	uint8_t CRC32_Checksum;			// Checksum for CRC32 of entire message not including final 8 bit checksum
	uint8_t AttNotHandled;			// Indicates if the specified attribute is not handled by this device
	uint8_t Legacy_Header;			// Indicates that this is a legacy header type
	QX_Comms_Port_e CommPort;		// Communication Port from which the message was recieved and/or will be transmitted
	
	// Message Header Data
	QX_MsgHeader_t Header;
	
	// Message Data Buffer (Contains Actual Message Data to be sent on the wire)
#ifdef USE_APPROVED_EXTENDED_LENGTH_PACKETS
	uint8_t MsgBuf[QX_MAX_PAYLOAD_LEN + QX_MAX_OUTER_FRAME_LEN];
#else
	uint8_t MsgBuf[QX_MAX_PAYLOAD_LEN_DEFAULT + QX_MAX_OUTER_FRAME_LEN];
#endif //USE_APPROVED_EXTENDED_LENGTH_PACKETS
	uint16_t MsgBuf_MsgLen;			// Length of the Message (# of Bytes on Wire)
	
	// Message Pointers and Lengths
	uint8_t *MsgBufStart_p;
	uint8_t *MsgBufAtt_p;
	uint8_t *BufPayloadStart_p;		// Points to the begining of the message data payload field, and not moved within the buffer!
	uint8_t *MsgBuf_p;				// General pointer for parser usage
	
} QX_Msg_t;

// QX Comms Port type - Contains info specific to each instance of a communications port
typedef struct {
	QX_Rx_State_e RxState;		// State of Stream RX State Machine
	uint16_t RxCntr;			// Count Chars RX'd from Stream
	QX_Msg_t RxMsg;				// One Deadicated Message Instance for Each Port to Recieve Messages To
	uint32_t Timeout_Cntr;		// Counts up using systick counter. cleared by successful msg rx
	uint8_t Connected;			// Connection Flag. Times out if no successful rx
	uint8_t len_approved; //Flag to determine whether the packet's length has been approved yet
	uint32_t ChkSumFail_cnt;
	uint32_t non_Q_cnt;			// increment when a non Q char is RX'd when waiting for a Q - Very helpful for debugging comms
	uint32_t rx_msg_start_time;  //Time at which this packet started being received
	uint32_t last_rx_msg_time;	// history variable of last recieved succussful message
} QX_CommsPort_t;

// QX Server object type - data storage for a server instance
// WARNING! QX_Server_t and QX_Client_t are cast intelligibly. Ensure consistent interface!
typedef struct {
	uint32_t Address;
	uint8_t *(*Parser_CB)(QX_Msg_t *QX_Msg);
	bool isServer;
} QX_Server_t;

// QX Client object type - data storage for a client instance
// WARNING! QX_Server_t and QX_Client_t are cast intelligibly. Ensure consistent interface!
typedef struct {
	uint32_t Address;
	uint8_t *(*Parser_CB)(QX_Msg_t *QX_Msg);
	bool isServer;
} QX_Client_t;


//****************************************************************************
// Public Vars
//****************************************************************************

// The Application should define these app specific vars in the QX_Protocol_App.c File
extern QX_CommsPort_t QX_CommsPorts[QX_NUM_OF_PORTS];

// Local QX Server Instances
extern QX_Server_t QX_Servers[QX_NUM_SRV];

// Local QX Client Instances
extern QX_Client_t QX_Clients[QX_NUM_CLI];

//****************************************************************************
// Public Function Prototypes
//****************************************************************************

// Initialization functions for server and client instances
void QX_InitSrv(QX_Server_t *QX_Server, QX_DevId_e Address, QX_ID_e IDtype, uint8_t *(*Parser_CB)(QX_Msg_t *));
void QX_InitCli(QX_Client_t *QX_Client, QX_DevId_e Address, QX_ID_e IDtype, uint8_t *(*Parser_CB)(QX_Msg_t *));

// Recieve Characters from a stream, and handle recieved messages
uint8_t QX_StreamRxCharSM(QX_Comms_Port_e port, unsigned char rxbyte);
void  QX_InitializeSMPacketStartOnQ(QX_Comms_Port_e port);

// Initialize the TX Options structure for a standard message
void QX_InitTxOptions(QX_TxMsgOptions_t *options);
	
// Full Featured Send QX Packet - For Asynchronous use by the Application (Not in imediate response to Read/Write)
QX_Stat_e QX_SendPacket_Srv_CurVal(QX_Server_t *Srv_p, uint32_t Attrib, QX_Comms_Port_e CommPort, QX_TxMsgOptions_t options);

// Full Featured Send QX Packet
QX_Stat_e QX_SendPacket_Cli_Read(QX_Client_t *Cli_p, uint32_t Attrib, QX_Comms_Port_e CommPort, QX_TxMsgOptions_t options);
QX_Stat_e QX_SendPacket_Cli_WriteABS(QX_Client_t *Cli_p, uint32_t Attrib, QX_Comms_Port_e CommPort, QX_TxMsgOptions_t options);
QX_Stat_e QX_SendPacket_Cli_WriteREL(QX_Client_t *Cli_p, uint32_t Attrib, QX_Comms_Port_e CommPort, QX_TxMsgOptions_t options);

// Send QX Packet with TRID and RRID for control.
QX_Stat_e QX_SendPacket_Control(QX_Client_t *Cli_p, uint32_t Attrib, QX_Comms_Port_e CommPort, QX_TxMsgOptions_t options);

// Disable the default response to a message (for example, blocks sending a current value response to a write message)
void QX_Disable_Default_Response(QX_Msg_t *Msg_p);

// Call periodically to update lost connection status
void QX_Connection_Status_Update(QX_Comms_Port_e port);

// Freefly Extension FunctionsPointers
extern void (*QX_BuildHeader_Legacy)(QX_Msg_t *Msg_p);
extern void (*QX_ParseHeader_Legacy)(QX_Msg_t *Msg_p);

//****************************************************************************
// Function Prototypes to be Implemented by Application Interface
//****************************************************************************

// Client and Server Callbacks. This is a reminder that callbacks must be created for each client and server to allow parsing. 
// These callbacks should be assigned using the QX_InitSrv() and QX_InitCli() functions. 

// Send Tx Message to Comms Port - Application Callback
// This is an application specific function that directs the message to the appropriate communications port buffer.
// UART: AddUART(x)Tx(), BLE: aci_gatt_update_char_value(), etc
extern void QX_SendMsg2CommsPort_CB(QX_Msg_t *TxMsg_p);

// Allows the application to forward the message to selected other ports if needed.
// Note, this function should not modify the message structure at all since it will continue to be parsed.
extern void QX_FwdMsg_CB(QX_Msg_t *TxMsg_p);

// Application specific timer callback to read a free-running millisecond timer
extern uint32_t QX_GetTicks_ms(void);

// Calculate CRC32 - A software version of this is implemented in the protocol, but this is exposed for overriding with a hardware version externally. 
extern uint32_t QX_accumulate_crc32(uint32_t initial, const uint8_t * data, uint32_t size);

// Retrieve a variable length value from a buffer
extern uint32_t QX_GetExtdValFromBuf(uint8_t **p);

#endif
