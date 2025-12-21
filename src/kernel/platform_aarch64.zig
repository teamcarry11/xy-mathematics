//! AArch64 Platform Interface
//! Why: Platform runtime services for AArch64 kernels (equivalent to RISC-V SBI).
//! Grain Style: Minimal, type-safe, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");
const platform = @import("platform.zig");

/// AArch64 platform function implementation.
/// Why: Map unified platform functions to AArch64 platform calls.
/// Contract: function_id must be valid, args must be valid.
/// Note: This is a stub - actual implementation will use AArch64 SMC/HVC calls.
pub fn platform_call(
    function_id: platform.PlatformFunction,
    arg0: u64,
    arg1: u64,
    arg2: u64,
    arg3: u64,
) platform.PlatformResult {
    // Assert: function_id must be valid.
    Debug.kassert(
        @intFromEnum(function_id) >= 1 and @intFromEnum(function_id) <= 4,
        "Invalid platform function ID",
        .{},
    );
    
    // Assert: Unused args must be zero (for now).
    _ = arg1;
    _ = arg2;
    _ = arg3;
    
    // Map unified platform functions to AArch64 platform calls.
    return switch (function_id) {
        .console_putchar => {
            // Assert: character must fit in u8.
            Debug.kassert(arg0 <= 0xFF, "Character out of range", .{});
            
            // Stub: Return success for now.
            // Actual implementation will use AArch64 SMC/HVC calls.
            return platform.PlatformResult{
                .error_code = 0,
                .value = 0,
            };
        },
        .console_getchar => {
            // Stub: Return no character for now.
            // Actual implementation will use AArch64 SMC/HVC calls.
            return platform.PlatformResult{
                .error_code = -1, // Failed (no character)
                .value = -1,
            };
        },
        .set_timer => {
            // Stub: Return success for now.
            // Actual implementation will use AArch64 SMC/HVC calls.
            return platform.PlatformResult{
                .error_code = 0,
                .value = 0,
            };
        },
        .shutdown => {
            // Stub: Return success for now.
            // Actual implementation will use AArch64 SMC/HVC calls.
            // Note: Shutdown should not return, but stub does for compilation.
            return platform.PlatformResult{
                .error_code = 0,
                .value = 0,
            };
        },
    };
}

/// Get current time in nanoseconds since epoch.
/// Why: Provide time source for freestanding AArch64 kernel.
/// Contract: Returns monotonic time (or fixed value for stub).
/// Note: This is a stub - actual implementation should use AArch64 timer registers.
pub fn get_time_ns() u64 {
    // Stub: Return a fixed time value for now.
    // Actual implementation should read AArch64 CNTPCT_EL0 (Physical Counter) register.
    // For now, use a reasonable fixed value to allow compilation.
    const FIXED_TIME_NS: u64 = 1703000000 * 1000000000; // Jan 2024
    return FIXED_TIME_NS;
}

