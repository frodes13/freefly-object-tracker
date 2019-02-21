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

    Filename: "QX_Parsing_Functions.h"
-----------------------------------------------------------------*/

#ifndef QX_PARSING_FUNCTIONS_H
#define QX_PARSING_FUNCTIONS_H

//****************************************************************************
// Headers
//****************************************************************************
#include <stdlib.h>
#include <stdint.h>		// for Standard Data Types

//****************************************************************************
// Defines
//****************************************************************************


//****************************************************************************
// Types
//****************************************************************************
typedef enum {
	QB_Parser_Dir_Read,
	QB_Parser_Dir_WriteDel,
	QB_Parser_Dir_WriteAbs,
} QB_Parser_Dir_e;

//****************************************************************************
// Global Variables
//****************************************************************************
extern QB_Parser_Dir_e rw;

//****************************************************************************
// Public Function Prototypes
//****************************************************************************
void QX_Parser_SetMsgPtr(uint8_t *p);
void QX_Parser_AdvMsgPtr(void);
volatile uint8_t *QX_Parser_GetMsgPtr(void);
void QX_Parser_SetDir_Read(void);
void QX_Parser_SetDir_WriteRel(void);
void QX_Parser_SetDir_WriteAbs(void);
QB_Parser_Dir_e QX_Parser_GetDir(void);


//****************************************************************************
// Private Function Prototypes
//****************************************************************************
void AddFloatAsSignedLong(float *v, uint32_t n, float scaleto);
void AddFloatAsSignedShort(float *v, uint32_t n, float scaleto);
void AddFloatAsSignedChar(float *v, uint32_t n, float scaleto);
void AddFloatAsUnsignedChar(float *v, uint32_t n, float scaleto);
void AddFloatAsUnsignedShort(float *v, uint32_t n, float scaleto);
void GetFloatAsSignedLong(float *v, uint32_t n, float max, float min, float scalefrom);
void GetFloatAsSignedShort(float *v, uint32_t n, float max, float min, float scalefrom);
void GetFloatAsSignedChar(float *v, uint32_t n, float max, float min, float scalefrom);
void GetFloatAsUnsignedChar(float *v, uint32_t n, float max, float min, float scalefrom);
void GetFloatAsUnsignedShort(float *v, uint32_t n, float max, float min, float scalefrom);
void AddSignedLongAsSignedLong(int32_t *v, uint32_t n);
void AddSignedLongAsSignedShort(int32_t *v, uint32_t n);
void AddSignedLongAsSignedChar(int32_t *v, uint32_t n);
void AddSignedLongAsUnsignedChar(int32_t *v, uint32_t n);
void GetSignedLongAsSignedLong(int32_t *v, uint32_t n, int32_t max, int32_t min);
void GetSignedLongAsSignedShort(int32_t *v, uint32_t n, int32_t max, int32_t min);
void GetSignedLongAsSignedChar(int32_t *v, uint32_t n, int32_t max, int32_t min);
void GetSignedLongAsUnsignedChar(int32_t *v, uint32_t n, int32_t max, int32_t min);
void AddSignedShortAsSignedShort(int16_t *v, uint32_t n);
void AddSignedShortAsSignedChar(int16_t *v, uint32_t n);
void AddSignedShortAsUnsignedChar(int16_t *v, uint32_t n);
void GetSignedShortAsSignedShort(int16_t *v, uint32_t n, float max, float min);
void GetSignedShortAsSignedChar(int16_t *v, uint32_t n, float max, float min);
void GetSignedShortAsUnsignedChar(int16_t *v, uint32_t n, int16_t max, int16_t min);
void AddSignedCharAsSignedChar(int8_t *v, uint32_t n);
void GetSignedCharAsSignedChar(int8_t *v, uint32_t n, int8_t max, int8_t min);
void AddUnsignedCharAsUnsignedChar(uint8_t *v, uint32_t n);
void GetUnsignedCharAsUnsignedChar(uint8_t *v, uint32_t n, uint8_t max, uint8_t min);
void AddUnsignedShortAsUnsignedShort(uint16_t *v, uint32_t n);
void GetUnsignedShortAsUnsignedShort(uint16_t *v, uint32_t n, uint16_t max, uint16_t min); 
void AddBitsAsByte(uint8_t *v, uint8_t start_bit, uint8_t n_bits);
void GetBitsAsByte(uint8_t *v, uint8_t start_bit, uint8_t n_bits);
void GetFloatAsFloat(float *v, uint32_t n, float max, float min);
void AddFloatAsFloat(float *v, uint32_t n);
void AddUnsignedLongAsUnsignedLong(uint32_t *v, uint32_t n);
void GetUnsignedLongAsUnsignedLong(uint32_t *v, uint32_t n, uint32_t max, uint32_t min);

//****************************************************************************
// Public Function Like Macros for 
//****************************************************************************

#define PARSE_FL_AS_SL(value, len, max, min, scale)\
    if(rw == QB_Parser_Dir_Read) { AddFloatAsSignedLong(value, len, scale); } else { GetFloatAsSignedLong(value, len, max, min, 1.0f / scale); }

#define PARSE_FL_AS_SS(value, len, max, min, scale)\
    if(rw == QB_Parser_Dir_Read) { AddFloatAsSignedShort(value, len, scale); } else { GetFloatAsSignedShort(value, len, max, min, 1.0f / scale); }

#define PARSE_FL_AS_SC(value, len, max, min, scale)\
    if(rw == QB_Parser_Dir_Read) { AddFloatAsSignedChar(value, len, scale); } else { GetFloatAsSignedChar(value, len, max, min, 1.0f / scale); }

#define PARSE_FL_AS_UC(value, len, max, min, scale)\
    if(rw == QB_Parser_Dir_Read) { AddFloatAsUnsignedChar(value, len, scale); } else { GetFloatAsUnsignedChar(value, len, max, min, 1.0f / scale); }

#define PARSE_FL_AS_US(value, len, max, min, scale)\
    if(rw == QB_Parser_Dir_Read) { AddFloatAsUnsignedShort(value, len, scale); } else { GetFloatAsUnsignedShort(value, len, max, min, 1.0f / scale); }
	
#define PARSE_SL_AS_SL(value, len, max, min)\
    if(rw == QB_Parser_Dir_Read) { AddSignedLongAsSignedLong((int32_t *)value, len); } else { GetSignedLongAsSignedLong((int32_t *)value, len, max, min); }

#define PARSE_SL_AS_SS(value, len, max, min)\
    if(rw == QB_Parser_Dir_Read) { AddSignedLongAsSignedShort((int32_t *)value, len); } else { GetSignedLongAsSignedShort((int32_t *)value, len, max, min); }

#define PARSE_SL_AS_SC(value, len, max, min)\
    if(rw == QB_Parser_Dir_Read) { AddSignedLongAsSignedChar((int32_t *)value, len); } else { GetSignedLongAsSignedChar((int32_t *)value, len, max, min); }

#define PARSE_SL_AS_UC(value, len, max, min)\
    if(rw == QB_Parser_Dir_Read) { AddSignedLongAsUnsignedChar((int32_t *)value, len); } else { GetSignedLongAsUnsignedChar((int32_t *)value, len, max, min); }

#define PARSE_SS_AS_SS(value, len, max, min)\
    if(rw == QB_Parser_Dir_Read) { AddSignedShortAsSignedShort((int16_t *)value, len); } else { GetSignedShortAsSignedShort((int16_t *)value, len, max, min); }

#define PARSE_SS_AS_SC(value, len, max, min)\
    if(rw == QB_Parser_Dir_Read) { AddSignedShortAsSignedChar((int16_t *)value, len); } else { GetSignedShortAsSignedChar((int16_t *)value, len, max, min); }

#define PARSE_SS_AS_UC(value, len, max, min)\
    if(rw == QB_Parser_Dir_Read) { AddSignedShortAsUnsignedChar((int16_t *)value, len); } else { GetSignedShortAsUnsignedChar((int16_t *)value, len, max, min); }

#define PARSE_SC_AS_SC(value, len, max, min)\
    if(rw == QB_Parser_Dir_Read) { AddSignedCharAsSignedChar(value, len); } else { GetSignedCharAsSignedChar(value, len, max, min); }

#define PARSE_UC_AS_UC(value, len, max, min)\
    if(rw == QB_Parser_Dir_Read) { AddUnsignedCharAsUnsignedChar(value, len); } else { GetUnsignedCharAsUnsignedChar(value, len, max, min); }

#define PARSE_US_AS_US(value, len, max, min)\
    if(rw == QB_Parser_Dir_Read) { AddUnsignedShortAsUnsignedShort((uint16_t *)value, len); } else { GetUnsignedShortAsUnsignedShort((uint16_t *)value, len, max, min); }
		
#define PARSE_UL_AS_UL(value, len, max, min)\
    if(rw == QB_Parser_Dir_Read) { AddUnsignedLongAsUnsignedLong((uint32_t *)value, len); } else { GetUnsignedLongAsUnsignedLong((uint32_t *)value, len, max, min); }

#define PARSE_BITS_AS_UC(value, start_bit, n_bits)\
    if(rw == QB_Parser_Dir_Read) { AddBitsAsByte((uint8_t *)value, start_bit, n_bits); } else { GetBitsAsByte((uint8_t *)value, start_bit, n_bits); }
		
#define PARSE_FL_AS_FL(value, len, max, min)\
		if(rw == QB_Parser_Dir_Read) { AddFloatAsFloat(value, len); } else { GetFloatAsFloat(value, len, max, min); }
	
#endif
		
