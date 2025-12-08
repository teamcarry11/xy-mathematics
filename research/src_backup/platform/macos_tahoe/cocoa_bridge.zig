const std = @import("std");
const c = @import("objc_runtime.zig").c;

/// Cocoa bridge helpers: typed wrappers for Objective-C runtime calls.
/// Why: objc_msgSend is variadic; Zig needs explicit function signatures.
/// 
/// Pointer design (GrainStyle single-level only):
/// - All function parameters and returns are single-level pointers.
/// - No double indirection in Objective-C message sends.

/// Get objc_msgSend function pointer.
/// Why: objc_msgSend is a variadic function; we need to cast it to specific signatures.
/// We use @extern to get the function pointer directly from the Objective-C runtime.
fn getObjcMsgSendPtr() *const anyopaque {
    const msgSend_extern = @extern(*const anyopaque, .{ .name = "objc_msgSend" });
    return msgSend_extern;
}

/// Declare C wrapper functions directly using @extern.
/// Why: Calling through function pointer causes pointer corruption. Direct @extern call
/// preserves pointer values correctly.
/// Signatures match objc_wrapper.c functions exactly.
extern fn objc_msgSend_wrapper(receiver: *const anyopaque, selector: c.SEL) ?*c.objc_object;
extern fn objc_msgSend_wrapper_string(receiver: *const anyopaque, selector: c.SEL, utf8_string: [*c]const u8) ?*c.objc_object;
extern fn objc_msgSend_wrapper_rect(receiver: *const anyopaque, selector: c.SEL, rect: *const anyopaque) ?*c.objc_object;
extern fn objc_msgSend_wrapper_4(receiver: *const anyopaque, selector: c.SEL, rect: *const anyopaque, arg2: usize, arg3: usize, arg4: bool) ?*c.objc_object;
extern fn objc_msgSend_wrapper_1_uint(receiver: *const anyopaque, selector: c.SEL, index: c_ulong) ?*c.objc_object;
extern fn objc_msgSend_void_1(receiver: *const anyopaque, selector: c.SEL, arg1: *const anyopaque) void;
extern fn objc_msgSend_void_0(receiver: *const anyopaque, selector: c.SEL) void;
extern fn objc_msgSend_void_1_bool(receiver: *const anyopaque, selector: c.SEL, arg1: bool) void;

/// Typed function pointer aliases for objc_msgSend wrapper.
/// Why: objc_msgSend is variadic; we use explicit function pointer types.
/// Note: The C wrapper function signature is: id objc_msgSend_wrapper(void* receiver, SEL selector)
/// We need to match this signature exactly, including the parameter types.
/// Note: void* and *const anyopaque should be compatible, but we need to ensure
/// the calling convention matches.
const ObjCMsgSend0 = *const fn (*const anyopaque, c.SEL) ?*c.objc_object;
const ObjCMsgSend1Rect = *const fn (*const anyopaque, c.SEL, NSRect) ?*c.objc_object;
const ObjCMsgSend4 = *const fn (*const anyopaque, c.SEL, NSRect, usize, usize, bool) ?*c.objc_object;
const ObjCMsgSendVoid1Obj = *const fn (*const anyopaque, c.SEL, *const anyopaque) void;
const ObjCMsgSendVoid0 = *const fn (*const anyopaque, c.SEL) void;
const ObjCMsgSendVoid1Bool = *const fn (*const anyopaque, c.SEL, bool) void;
const ObjCMsgSendString = *const fn (*const anyopaque, c.SEL, [*c]const u8) ?*c.objc_object;

/// NSRect struct: compatible with Cocoa NSRect layout.
pub const NSRect = extern struct {
    origin: extern struct {
        x: f64,
        y: f64,
    },
    size: extern struct {
        width: f64,
        height: f64,
    },
};

/// Typed objc_msgSend wrapper: 0 arguments.
/// Why: Accepts both objc_class and objc_object (they're compatible in Objective-C runtime).
pub fn objc_msgSend0(receiver: *const anyopaque, sel: c.SEL) ?*c.objc_object {
    // Assert: receiver and selector must be valid.
    // Note: receiver can be a class pointer or object pointer, but must not be NULL.
    const receiverPtrValue = @intFromPtr(receiver);
    if (receiverPtrValue == 0) {
        std.debug.panic("objc_msgSend0 called with NULL receiver pointer", .{});
    }
    std.debug.assert(receiverPtrValue != 0);
    // Assert: receiver pointer should be aligned (Objective-C objects/classes are aligned).
    if (receiverPtrValue % 8 != 0) {
        std.debug.panic("objc_msgSend0 receiver pointer is not properly aligned: 0x{x}. Expected 8-byte alignment.", .{receiverPtrValue});
    }
    // Assert: receiver pointer should be reasonable (not suspiciously small).
    if (receiverPtrValue < 0x1000) {
        std.debug.panic("objc_msgSend0 receiver pointer is suspiciously small: 0x{x}. This suggests an invalid pointer.", .{receiverPtrValue});
    }
    
    const selPtrValue = @intFromPtr(sel);
    if (sel == null) {
        std.debug.panic("objc_msgSend0 called with NULL selector", .{});
    }
    std.debug.assert(sel != null);
    // Assert: selector pointer should be reasonable (selectors are typically in a specific range).
    if (selPtrValue < 0x1000) {
        std.debug.panic("objc_msgSend0 selector pointer is suspiciously small: 0x{x}. This suggests an invalid selector.", .{selPtrValue});
    }
    
    // Debug: Print receiver pointer value before calling wrapper.
    // This helps us verify the pointer is correct before passing to C wrapper.
    std.debug.print("[cocoa_bridge] objc_msgSend0 receiver: 0x{x}, selector: 0x{x}\n", .{ receiverPtrValue, selPtrValue });
    
    // Call C wrapper function directly using @extern declaration.
    // Why: Calling through function pointer causes pointer corruption. Direct @extern call
    // preserves pointer values correctly and matches the C function signature exactly.
    return objc_msgSend_wrapper(receiver, sel);
}

/// Typed objc_msgSend wrapper: 1 argument (NSRect).
/// Why: Accepts both objc_class and objc_object (they're compatible in Objective-C runtime).
pub fn objc_msgSend1(receiver: *const anyopaque, sel: c.SEL, arg1: NSRect) ?*c.objc_object {
    // Pass NSRect by reference to match C wrapper signature (void* rect).
    return objc_msgSend_wrapper_rect(receiver, sel, @ptrCast(&arg1));
}

/// Typed objc_msgSend wrapper: 1 argument (NSUInteger).
/// Why: For methods like objectAtIndex: that take unsigned long index.
pub fn objc_msgSend1Uint(receiver: *const anyopaque, sel: c.SEL, index: c_ulong) ?*c.objc_object {
    return objc_msgSend_wrapper_1_uint(receiver, sel, index);
}

/// Typed objc_msgSend wrapper: 4 arguments (initWithContentRect).
/// Why: Accepts both objc_class and objc_object (they're compatible in Objective-C runtime).
pub fn objc_msgSend4(
    receiver: *const anyopaque,
    sel: c.SEL,
    arg1: NSRect,
    arg2: usize,
    arg3: usize,
    arg4: bool,
) ?*c.objc_object {
    // Pass NSRect by reference to match C wrapper signature (void* rect).
    return objc_msgSend_wrapper_4(receiver, sel, @ptrCast(&arg1), arg2, arg3, arg4);
}

/// Typed objc_msgSend wrapper: void return, 1 argument (object pointer).
pub fn objc_msgSendVoid1(receiver: *const anyopaque, sel: c.SEL, arg1: *const anyopaque) void {
    objc_msgSend_void_1(receiver, sel, arg1);
}

/// Typed objc_msgSend wrapper: void return, 0 arguments.
pub fn objc_msgSendVoid0(receiver: *const anyopaque, sel: c.SEL) void {
    objc_msgSend_void_0(receiver, sel);
}

/// Typed objc_msgSend wrapper: void return, bool argument.
pub fn objc_msgSendVoidBool(receiver: *const anyopaque, sel: c.SEL, arg1: bool) void {
    objc_msgSend_void_1_bool(receiver, sel, arg1);
}

/// Typed objc_msgSend wrapper: NSString from UTF8 string.
/// Note: This uses a C wrapper function that accepts a C string argument.
pub fn objc_msgSendNSString(class: *const anyopaque, sel: c.SEL, utf8: [*c]const u8) ?*c.objc_object {
    return objc_msgSend_wrapper_string(class, sel, utf8);
}

/// Typed objc_msgSend wrapper: returns NSRect by value.
/// Why: Methods like bounds return NSRect struct by value (in registers on arm64).
extern fn objc_msgSend_returns_NSRect(receiver: *const anyopaque, selector: c.SEL) NSRect;

/// Get NSRect return value from objc_msgSend.
pub fn objc_msgSendNSRect(receiver: *const anyopaque, sel: c.SEL) NSRect {
    // Assert: receiver and selector must be valid.
    const receiverPtrValue = @intFromPtr(receiver);
    std.debug.assert(receiverPtrValue != 0);
    std.debug.assert(sel != null);
    
    return objc_msgSend_returns_NSRect(receiver, sel);
}

