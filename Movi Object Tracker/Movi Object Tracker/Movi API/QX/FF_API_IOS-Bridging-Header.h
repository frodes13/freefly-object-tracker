//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#include <MacTypes.h>

// Size of parameter arrays passed between C and Swift
#define ARE_LEN 40

// Calls from swift to C
void QX_Init(void);
void QX_ChangeValue(long attr, char *key, float value);
void QX_ChangeValueAbsolute(long attr, char *key, float value);
void QX_ChangeAttributeAbsoluteUnsafe(long attr, float values[]);
void QX_RequestAttr(long attr);
void QX_RxData(UInt8 data);


// Calls from C to swift (specified with _cdecl in swift)
void bridgeCSsendByte(intptr_t);
void bridgeCSattributeRxEvent(char *, float paramValues[]);

