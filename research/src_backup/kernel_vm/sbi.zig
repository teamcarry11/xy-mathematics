// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Grain Basin kernel - RISC-V SBI wrapper
// Inspired by CascadeOS/zig-sbi (MIT licensed) - see credits in docs

/// RISC-V SBI (Supervisor Binary Interface) wrapper.
/// Grain Style: Minimal, type-safe, comprehensive assertions.
/// Why: Platform runtime services (timer, console, reset) for RISC-V kernels.
/// Credits: Inspired by CascadeOS/zig-sbi (MIT licensed).

const std = @import("std");

/// SBI Extension ID (EID) for legacy functions.
/// Why: Legacy SBI functions use EID as function ID directly.
pub const EID = enum(u32) {
    /// Set timer (legacy).
    LEGACY_SET_TIMER = 0x0,
    /// Console putchar (legacy) - write character to console.
    LEGACY_CONSOLE_PUTCHAR = 0x1,
    /// Console getchar (legacy) - read character from console.
    LEGACY_CONSOLE_GETCHAR = 0x2,
    /// Clear IPI (legacy).
    LEGACY_CLEAR_IPI = 0x3,
    /// Send IPI (legacy).
    LEGACY_SEND_IPI = 0x4,
    /// Remote fence I (legacy).
    LEGACY_REMOTE_FENCE_I = 0x5,
    /// Remote SFENCE VMA (legacy).
    LEGACY_REMOTE_SFENCE_VMA = 0x6,
    /// Remote SFENCE VMA with ASID (legacy).
    LEGACY_REMOTE_SFENCE_VMA_ASID = 0x7,
    /// Shutdown (legacy) - system shutdown/reboot.
    LEGACY_SHUTDOWN = 0x8,
};

/// SBI error codes.
/// Why: Standard SBI error return values.
pub const SBIError = enum(i64) {
    /// Success (no error).
    Success = 0,
    /// Failed (unspecified error).
    Failed = -1,
    /// Not supported (function not available).
    NotSupported = -2,
    /// Invalid parameter.
    InvalidParameter = -3,
    /// Denied (permission denied).
    Denied = -4,
    /// Invalid address.
    InvalidAddress = -5,
};

/// SBI console putchar result.
/// Why: Type-safe result for console output.
pub const ConsolePutcharResult = enum(u64) {
    /// Success (character written).
    Success = 0,
    _,
};

/// SBI console getchar result.
/// Why: Type-safe result for console input.
pub const ConsoleGetcharResult = enum(i64) {
    /// No character available (non-blocking).
    NoChar = -1,
    _,
};

/// Check if SBI function ID is legacy (< 10).
/// Why: Legacy SBI functions use EID directly as function ID.
pub fn is_legacy_sbi(eid: u32) bool {
    // Assert: EID must be valid (< 10 for legacy).
    std.debug.assert(eid < 10);
    return eid < 10;
}

/// Get SBI error code from return value.
/// Why: Convert SBI return value to error code.
pub fn get_sbi_error(result: i64) SBIError {
    // Assert: result must be valid error code.
    std.debug.assert(result <= 0);
    
    // Convert to error enum.
    return switch (result) {
        @intFromEnum(SBIError.Success) => .Success,
        @intFromEnum(SBIError.Failed) => .Failed,
        @intFromEnum(SBIError.NotSupported) => .NotSupported,
        @intFromEnum(SBIError.InvalidParameter) => .InvalidParameter,
        @intFromEnum(SBIError.Denied) => .Denied,
        @intFromEnum(SBIError.InvalidAddress) => .InvalidAddress,
        else => .Failed, // Unknown error -> Failed.
    };
}

/// SBI console putchar (write character to console).
/// Why: Standard RISC-V console output function.
/// Calling convention: character in a0 (x10), returns 0 on success.
pub fn console_putchar(character: u8) ConsolePutcharResult {
    // Assert: character must be valid (always true for u8).
    _ = character;
    
    // Note: Actual SBI call would use inline assembly here.
    // In VM, this is handled by VM's handle_sbi_call.
    // This function is for type safety and documentation.
    
    // Return success (VM will handle actual output).
    return .Success;
}

/// SBI console getchar (read character from console).
/// Why: Standard RISC-V console input function.
/// Calling convention: returns character in a0 (x10), or -1 if no character.
pub fn console_getchar() ConsoleGetcharResult {
    // Note: Actual SBI call would use inline assembly here.
    // In VM, this is handled by VM's handle_sbi_call.
    // This function is for type safety and documentation.
    
    // Return no character (non-blocking).
    return .NoChar;
}

/// SBI shutdown (system shutdown/reboot).
/// Why: Standard RISC-V shutdown function.
/// Calling convention: no arguments, doesn't return.
pub fn shutdown() noreturn {
    // Note: Actual SBI call would use inline assembly here.
    // In VM, this is handled by VM's handle_sbi_call.
    // This function is for type safety and documentation.
    
    // Shutdown never returns.
    while (true) {
        std.Thread.yield();
    }
}

/// SBI set timer (set timer interrupt).
/// Why: Standard RISC-V timer function.
/// Calling convention: time_value in a0 (x10), no return value.
pub fn set_timer(time_value: u64) void {
    // Assert: time_value must be valid (always true for u64).
    _ = time_value;
    
    // Note: Actual SBI call would use inline assembly here.
    // In VM, this is handled by VM's handle_sbi_call.
    // This function is for type safety and documentation.
}

