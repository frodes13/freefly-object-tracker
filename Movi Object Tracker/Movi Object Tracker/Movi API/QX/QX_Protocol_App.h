
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
 
 Filename: "QX_Protocol_App.h"
 -----------------------------------------------------------------*/

#ifndef QX_PROTOCOL_APP_H
#define QX_PROTOCOL_APP_H

//****************************************************************************
// Defines
//****************************************************************************



//****************************************************************************
// Headers
//****************************************************************************

// Standard headers
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

// QX Library headers
#include "QX_Protocol.h"
#include "QX_App_Config.h"

//****************************************************************************
// Definitions
//****************************************************************************

#define UID_BASE              0x1FF0F420U

//****************************************************************************
// Data Types
//****************************************************************************

//****************************************************************************
// Public Global Vars
//****************************************************************************

//****************************************************************************
// Public Function Prototypes QX_Lib
//****************************************************************************
extern uint8_t *QX_ParsePacket_Cli_CB(QX_Msg_t *Msg_p);

extern bool QX_QB_Check4Opt(long QB_Att);

extern char *GetParamList(long attr);

extern int GetParamIndex(const char *key, long attr);

//****************************************************************************
// Public Function Prototypes QX_Ext
//****************************************************************************







#endif

