
/*-----------------------------------------------------------------
 MIT License
 
 Copyright (c) 2018 Freefly Systems
 
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
 
 Filename: "QX_Protocol_App.c"
 
 QX_Protocol_App contains application specific tools for interfacing a
 particular app with QX_Lib.  See QX.java for usage examples.
 
 -----------------------------------------------------------------*/

//****************************************************************************
// Headers
//****************************************************************************

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "QX_Protocol_App.h"
#include "QX_Protocol.h"
#include "QX_Parsing_Functions.h"
#include <float.h>
#include <MacTypes.h>
#include "FF_API_IOS-Bridging-Header.h"


QX_TxMsgOptions_t options;

static float rxVals[ARE_LEN];
static float txVals[ARE_LEN];
static float *vals;


/*
 * Initialize the QX_Lib
 */
void QX_Init() {
    QX_InitCli(&QX_Clients[0], QX_DEV_ID_BROADCAST, QX_ID_DEVICE, QX_ParsePacket_Cli_CB);
    QX_InitTxOptions(&options);
}


// -------------------------------------- C -> Swift -----------------------------------------

/**
 * Forward a TxMsg from QX lib to bluetooth
 */
void QX_SendMsg2CommsPort_CB(QX_Msg_t *TxMsg_p) {
    for (int i = 0; i <= TxMsg_p->MsgBuf_MsgLen; i++)
        bridgeCSsendByte(TxMsg_p->MsgBuf[i]);
}


/**
 * Convenience method, send attribute received event to App with data
 */
void AttributeRxEvent(QX_Msg_t *Msg_p, float paramValues[]) {
    char *ParamNames = GetParamList(Msg_p->Header.Attrib);
    bridgeCSattributeRxEvent( ParamNames, paramValues);
}



// -------------------------------------- Swift -> C -----------------------------------------

/**
 * Make a relative change to a parameter on the device
 * @param attr Attribute containing this parameter
 * @param key Text string used to identify this parameter
 * @param value Relative value to adjust the parameter
 */
void QX_ChangeValue(long attr, char *key, float value) {
    int index = GetParamIndex(key, attr);
    if (index == -1) return;
    for (int i = 0; i <= ARE_LEN; i++) txVals[i] = 0;
    txVals[index] = value;
    
    QX_SendPacket_Cli_WriteREL(&QX_Clients[0], (uint32_t) attr, PORT, options);
}

/**
 * Make an absolute change to a parameter on the device.
 * WARNING: ALL PARAMS IN ATTRIBUTE WILL BE RESET
 * @param attr Attribute containing this parameter
 * @param key Text string used to identify this parameter
 * @param value New parameter value
 */
void QX_ChangeValueAbsolute(long attr, char *key, float value) {
    int index = GetParamIndex(key, attr);
    if (index == -1) return;
    for (int i = 0; i <= ARE_LEN; i++) txVals[i] = 0;
    txVals[index] = value;
    
    QX_SendPacket_Cli_WriteABS(&QX_Clients[0], (uint32_t) attr, PORT, options);
}

/**
 * Update all parameters in an Attribute
 * @param attr Attribute to update
 * @param values Array of parameter values to update
 */
void QX_ChangeAttributeAbsoluteUnsafe(long attr, float values[]) {
    for (int i = 0; i <= ARE_LEN; i++) txVals[i] = values[i];
    QX_SendPacket_Cli_WriteABS(&QX_Clients[0], (uint32_t) attr, PORT, options);
}


/**
 * Request current parameter values from device
 * @param attr Attribute containing the desired parameters
 */
void QX_RequestAttr(long attr) {
    QX_SendPacket_Cli_Read(&QX_Clients[0], (uint32_t) attr, PORT, options);
}

/**
 * Forward data from the bluetooth LE radio to the QX Library
 */
void QX_RxData(UInt8 data) {
    QX_StreamRxCharSM(PORT, (unsigned char) data);
}


//-------------------------------- INTERNAL QX SUPPORT -------------------------------------

void QX_FwdMsg_CB(QX_Msg_t __unused *TxMsg_p) {}

uint32_t QX_GetTicks_ms(void) { return 0; }

bool QX_QB_Check4Opt(long QB_Att) {
    return ((QB_Att >= 64) && (QB_Att != 78) && (QB_Att != 79) && (QB_Att != 81) && (QB_Att != 120) &&
            (QB_Att != 121) && (QB_Att != 122) && (QB_Att != 126));
}

int GetParamIndex(const char *key, long attr) {
    int index = 0, keyIndex = 0;
    bool reset = false, match = true;
    char *list = GetParamList(attr);
    for (int i = 0; i <= strlen(list); i++) {
        if (list[i] == ',' || i == strlen(list)) reset = true;
        if (reset) {
            if (match) return index + 1;
            index++;
            keyIndex = 0;
            match = true;
            reset = false;
        } else {
            if (match) if (list[i] != key[keyIndex++]) match = false;
        }
    }
    return -1;
}


uint8_t *QX_ParsePacket_Cli_CB(QX_Msg_t *Msg_p) {
    
    // Set Parser direction based on message type
    switch (Msg_p->Parse_Type) {
        case QX_PARSE_TYPE_WRITE_REL_SEND:
        case QX_PARSE_TYPE_WRITE_ABS_SEND:
            QX_Parser_SetDir_Read();
            vals = txVals;
            break;
        case QX_PARSE_TYPE_CURVAL_RECV:
            QX_Parser_SetDir_WriteAbs();
            vals = rxVals;
            break;
        default:
            break;
    }
    
    // Parse Message
    QX_Parser_SetMsgPtr(Msg_p->BufPayloadStart_p); // set parser to start of message
    if (Msg_p->Parse_Type == QX_PARSE_TYPE_CURVAL_RECV) for (int i = 0; i <= ARE_LEN; i++) rxVals[i] = 0; // clear
    int i = 0; // index for parsing params
    vals[i++] = Msg_p->Header.Attrib; // attrib val in data 0
    
    switch (Msg_p->Header.Attrib) {
            
#define P34 "Timelapse Keyframe,Timelapse Progress,Timelapse state,Timelapse Pan Offset,Timelapse Tilt,Timelapse Roll,Timelapse Pan,Pan Revolutions"
        case 34:
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, -FLT_MAX, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, -FLT_MAX, 100);// progress
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, -FLT_MAX, 1);//state
            QX_Parser_AdvMsgPtr();
            QX_Parser_AdvMsgPtr();
            QX_Parser_AdvMsgPtr();
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, -FLT_MAX, 10);//offset
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, -FLT_MAX, 10);//tilt
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, -FLT_MAX, 10);//roll
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, -FLT_MAX, 10);//pan
            PARSE_FL_AS_SL(&vals[i++], 1, FLT_MAX, -FLT_MAX, 1);
            break;
            
#define P51 "gcu_fw major,gcu_fw minor,gcu_fw patch,tsu_fw major,tsu_fw minor,tsu_fw patch,esc0_fw major,esc0_fw minor,esc0_fw patch,esc1_fw major,esc1_fw minor,esc1_fw patch,esc2_fw major,esc2_fw minor,esc2_fw patch"
        case 51:
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, 0, 1);
            break;
            
#define P81 "FLASH"
        case 81:
            QX_Parser_AdvMsgPtr();
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            break;
            
#define P109 "Shaky-cam Pan,Shaky-cam Tilt,Setdown Sleep,Roll Joint Gain Schedule,Roll Actuator Notch,Tilt Actuator Notch,Motion Booting,Autotune Start,Autotune Percentage,Autotune Progress,Jolt Rejection"
        case 109:
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_SC(&vals[i++], 1, FLT_MAX, 0, 1); // REL US
            PARSE_FL_AS_SC(&vals[i++], 1, FLT_MAX, 0, 1); // REL US
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            break;
            
#define P121 "A,B,C,D"
        case 121: // Internal use only.  Take values from QX.sn, QX.comms, QX.hw
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            break;
            
#define P277 "Control Bind Flags,Control Bind Address,Control gimbal Flags,Control RX,Control RY,Control RZ,Control Q R,Control Lens Flags,Control Focus,Control Iris,Control Zoom,Control Auxiliary Flags"
        case 277:
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, 0, 1);
            
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, 0, 1);
            break;
            
#define P306 "Roll Mode,Roll Smoothing,Roll Window,Roll Majestic Span"
        case 306:
            PARSE_FL_AS_SC(&vals[i++], 1, FLT_MAX, 0, 1); //REL UC
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            break;
            
#define P309 "Fromo Button Trigger,Fromo Button Record,Fromo Button Up,Fromo Button Down,Fromo Button Left,Fromo Button Right,Fromo Button Center"
        case 309:
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, 0, 1);
            break;
            
#define P454 "Active Method top level"
        case 454:
            PARSE_FL_AS_SL(&vals[i++], 1, FLT_MAX, 0, 1);
            break;
            
#define P455 "Tuning Active Method Status"
        case 455:
            PARSE_FL_AS_SL(&vals[i++], 1, FLT_MAX, 0, 1);
            break;
            
#define P456 "Active Method majestic window"
        case 456:
            PARSE_FL_AS_SL(&vals[i++], 1, FLT_MAX, 0, 1);
            break;
            
#define P457 "Active Method snappy roll"
        case 457:
            PARSE_FL_AS_SL(&vals[i++], 1, FLT_MAX, 0, 1);
            break;
            
#define P458 "Active Method hyperlapse compress"
        case 458:
            PARSE_FL_AS_SL(&vals[i++], 1, FLT_MAX, 0, 1);
            break;
            
#define P459 "Active Method majestic smoothing"
        case 459:
            PARSE_FL_AS_SL(&vals[i++], 1, FLT_MAX, 0, 1);
            break;
            
#define P460 "Tilt Mode Active Method Status"
        case 460:
            PARSE_FL_AS_SL(&vals[i++], 1, FLT_MAX, 0, 1);
            break;
            
#define P1126 "KF Index,KF Pan Degs,KF Pan Revs,KF Tilt Degs,KF Roll Degs,KF Seconds,KF Pan Diff 1,KF Pan Weight 1,KF Pan Diff 2,KF Pan Weight 2,KF Tilt Diff 1,KF Tilt Weight,KF Tilt Diff,KF Tilt Weight,KF Roll Diff,KF Roll Weight,KF Roll Diff,KF Roll Weight,KFs MAX RO,KF Programming Cmd,KF Action Cmd"
        case 1126:
            PARSE_FL_AS_SC(&vals[i++], 1, FLT_MAX, -FLT_MAX, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, -FLT_MAX, 10);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, -FLT_MAX, 1);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, -FLT_MAX, 10);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, -FLT_MAX, 10);
            PARSE_FL_AS_SL(&vals[i++], 1, FLT_MAX, -FLT_MAX, 10);//Seconds
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, -FLT_MAX, 10);// PD1
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, -FLT_MAX, 100);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, -FLT_MAX, 10);//PD2
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, -FLT_MAX, 100);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, -FLT_MAX, 10);//TD1
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, -FLT_MAX, 100);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, -FLT_MAX, 10);//TD2
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, -FLT_MAX, 100);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, -FLT_MAX, 10);//RD1
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, -FLT_MAX, 100);
            PARSE_FL_AS_SS(&vals[i++], 1, FLT_MAX, -FLT_MAX, 10);//RD2
            PARSE_FL_AS_US(&vals[i++], 1, FLT_MAX, -FLT_MAX, 100);
            PARSE_FL_AS_SC(&vals[i++], 1, FLT_MAX, -FLT_MAX, 1);//MAX KF
            QX_Parser_AdvMsgPtr();
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, -FLT_MAX, 1);
            PARSE_FL_AS_UC(&vals[i++], 1, FLT_MAX, -FLT_MAX, 1);
            break;
            
        default:
            Msg_p->AttNotHandled = true;
            break;
    }
    
    // Forward to App if values received
    if (!(Msg_p->AttNotHandled) && (Msg_p->Parse_Type == QX_PARSE_TYPE_CURVAL_RECV)) AttributeRxEvent(Msg_p, rxVals);
    
    printf("msgType %i %.0f with params %f %f %f %f %f %f %f %f %f %f \n", Msg_p->Parse_Type, vals[0], vals[1], vals[2],
           vals[3], vals[4], vals[5], vals[6], vals[7], vals[8], vals[9], vals[10]);
    
    return (uint8_t *) QX_Parser_GetMsgPtr();
}

/**
 * Look up the csv string of parameter names for this attribute
 */
char *GetParamList(long attr) {
    switch (attr) {
        case 34:
            return P34;
        case 51:
            return P51;
        case 81:
            return P81;
        case 121:
            return P121;
        case 109:
            return P109;
        case 277:
            return P277;
        case 306:
            return P306;
        case 309:
            return P309;
        case 454:
            return P454;
        case 455:
            return P455;
        case 456:
            return P456;
        case 457:
            return P457;
        case 458:
            return P458;
        case 459:
            return P459;
        case 460:
            return P460;
        case 1126:
            return P1126;
        default:
            return NULL;
            
    }
}












