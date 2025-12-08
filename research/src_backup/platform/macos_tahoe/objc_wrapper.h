#ifndef OBJC_WRAPPER_H
#define OBJC_WRAPPER_H

#include <objc/runtime.h>

// C wrapper functions for objc_msgSend to ensure proper calling convention on arm64.
id objc_msgSend_wrapper(id receiver, SEL selector);
id objc_msgSend_wrapper_rect(id receiver, SEL selector, void* rect);
id objc_msgSend_wrapper_4(id receiver, SEL selector, void* rect, unsigned long arg2, unsigned long arg3, _Bool arg4);
void objc_msgSend_void_1(id receiver, SEL selector, id arg1);
void objc_msgSend_void_0(id receiver, SEL selector);

#endif // OBJC_WRAPPER_H

