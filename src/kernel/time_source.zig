//! Platform-Agnostic Time Source
//! Why: Provide a consistent time source for the kernel, abstracting platform details.
//! Grain Style: Explicit types (u64 not usize), minimal dependencies, comprehensive assertions.

const std = @import("std");
const builtin = @import("builtin");
const Debug = @import("debug.zig");

/// Time source implementation function pointer.
/// Why: Allow platform-specific time source to be injected.
var get_time_ns_impl: *const fn () u64 = default_get_time_ns;

/// Default time source implementation (uses platform-specific code).
/// Why: Provide a default implementation that works for non-freestanding targets.
/// Note: For freestanding targets, this should be overridden by platform code.
fn default_get_time_ns() u64 {
    // For non-freestanding targets, use std.time.timestamp().
    // For freestanding targets, this will be overridden by platform code.
    if (builtin.os.tag == .freestanding) {
        // Freestanding: Use a simple counter-based time source.
        // Note: This is a stub - actual implementation should use platform timer.
        // For now, return a fixed value to allow compilation.
        const FIXED_TIME_NS: u64 = 1703000000 * 1000000000; // Jan 2024
        return FIXED_TIME_NS;
    } else {
        // Non-freestanding: Use std.time.timestamp().
        const now_sec = std.time.timestamp();
        const now_ns = @as(u64, @intCast(now_sec)) * 1000000000;
        
        // Assert: Time must be reasonable (not before year 2000).
        const YEAR_2000_NS: u64 = 946684800 * 1000000000; // Jan 1, 2000
        Debug.kassert(now_ns >= YEAR_2000_NS, "Time before year 2000", .{});
        
        return now_ns;
    }
}

/// Time source interface.
/// Why: Abstract time source for different platforms (VM, real hardware).
pub const TimeSource = struct {
    /// Get current time in nanoseconds since epoch.
    /// Why: Provide a consistent time value for kernel operations.
    /// Contract: Returns monotonic time, or 0 if not available.
    pub fn get_time_ns() u64 {
        return get_time_ns_impl();
    }
    
    /// Set time source implementation.
    /// Why: Allow platform-specific time source to be injected.
    /// Contract: Must be called once at kernel boot.
    pub fn set_implementation(impl: *const fn () u64) void {
        get_time_ns_impl = impl;
    }
};
