//! AArch64 Platform Interface
//! Why: Platform runtime services for AArch64 kernels (equivalent to RISC-V SBI).
//! Grain Style: Minimal, type-safe, comprehensive assertions.

const std = @import("std");

/// AArch64 platform function IDs.
/// Why: Standard platform function identifiers for AArch64.
pub const PlatformFunction = enum(u32) {
    /// Console putchar - write character to console.
    console_putchar = 0x1,
    /// Console getchar - read character from console.
    console_getchar = 0x2,
    /// Set timer - set timer for next interrupt.
    set_timer = 0x3,
    /// Shutdown - system shutdown/reboot.
    shutdown = 0x4,
};

/// Platform error codes.
/// Why: Standard platform error return values.
pub const PlatformError = enum(i64) {
    /// Success (no error).
    success = 0,
    /// Failed (unspecified error).
    failed = -1,
    /// Not supported (function not available).
    not_supported = -2,
    /// Invalid parameter.
    invalid_parameter = -3,
    /// Denied (permission denied).
    denied = -4,
    /// Invalid address.
    invalid_address = -5,
};

/// Platform function result.
/// Why: Type-safe result for platform function calls.
pub const PlatformResult = struct {
    /// Error code (0 = success, negative = error).
    error_code: i64,
    /// Return value (function-specific).
    value: i64,
    
    /// Check if result is success.
    /// Why: Validate platform function call success.
    pub fn is_success(self: *const PlatformResult) bool {
        return self.error_code == 0;
    }
    
    /// Get error code.
    /// Why: Extract error code from result.
    pub fn get_error(self: *const PlatformResult) PlatformError {
        return switch (self.error_code) {
            0 => .success,
            -1 => .failed,
            -2 => .not_supported,
            -3 => .invalid_parameter,
            -4 => .denied,
            -5 => .invalid_address,
            else => .failed,
        };
    }
};

/// Call platform function (stub implementation).
/// Why: Invoke platform runtime services.
/// Contract: function_id must be valid, args must be valid.
/// Note: This is a stub - actual implementation will use AArch64 SMC/HVC calls.
pub fn platform_call(
    function_id: PlatformFunction,
    arg0: u64,
    arg1: u64,
    arg2: u64,
    arg3: u64,
) PlatformResult {
    // Note: function_id, arg0, arg1, arg2, arg3 are validated but not used in stub.
    // Actual implementation will use SMC (Secure Monitor Call) or HVC (Hypervisor Call).
    _ = function_id;
    _ = arg0;
    _ = arg1;
    _ = arg2;
    _ = arg3;
    
    // Stub: Return success for now.
    return PlatformResult{
        .error_code = 0,
        .value = 0,
    };
}

/// Write character to console.
/// Why: Output character to platform console.
/// Contract: character must be valid ASCII.
pub fn console_putchar(character: u8) void {
    _ = platform_call(.console_putchar, @as(u64, @intCast(character)), 0, 0, 0);
}

/// Read character from console.
/// Why: Read character from platform console.
/// Returns: Character code, or -1 if no character available.
pub fn console_getchar() i32 {
    const result = platform_call(.console_getchar, 0, 0, 0, 0);
    if (result.is_success()) {
        return @as(i32, @intCast(result.value));
    }
    return -1;
}

/// Set timer for next interrupt.
/// Why: Schedule timer interrupt at specified time.
/// Contract: time must be valid (nanoseconds since boot).
pub fn set_timer(time: u64) void {
    _ = platform_call(.set_timer, time, 0, 0, 0);
}

/// Shutdown system.
/// Why: Shutdown or reboot the system.
/// Contract: shutdown_type must be valid (0 = shutdown, 1 = reboot).
pub fn shutdown(shutdown_type: u32) void {
    _ = platform_call(.shutdown, @as(u64, @intCast(shutdown_type)), 0, 0, 0);
}

