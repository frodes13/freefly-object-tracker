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
 
 
 Filename: "QX_App_Config.h"
 -----------------------------------------------------------------*/

#ifndef QX_APP_CONFIG_H
#define QX_APP_CONFIG_H

//****************************************************************************
// Defines
//****************************************************************************
//#define QX_DEBUG // enables printf in QX code

//****************************************************************************
// Headers
//****************************************************************************
#include <stdlib.h>        // for Standard Data Types
#include <stdint.h>        // for Standard Data Types
#include <stdbool.h>  // for Standard Data Types

//****************************************************************************
// Definitions
//****************************************************************************
// Quantity of clients and servers
#define QX_NUM_SRV            1
#define QX_NUM_CLI            1


//****************************************************************************
// Data Types
//****************************************************************************

// Communication Ports - port dependent
typedef enum {
    PORT,
    QX_NUM_OF_PORTS        // Ensure this remains as the last value because it sets the number of ports!
} QX_Comms_Port_e;

//****************************************************************************
// Public Global Vars
//****************************************************************************


//****************************************************************************
// Public Function Prototypes
//****************************************************************************



#endif

