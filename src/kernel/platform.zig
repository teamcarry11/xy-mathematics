//! Unified Platform Interface
//! Why: Abstract platform runtime services for RISC-V and AArch64 kernels.
//! Grain Style: Minimal, type-safe, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

/// Platform architecture.
/// Why: Identify target architecture for platform abstraction.
pub const PlatformArch = enum(u32) {
    /// RISC-V64 architecture.
    riscv64 = 0,
    /// AArch64 architecture.
    aarch64 = 1,
};

/// Platform function IDs (unified for RISC-V SBI and AArch64 platform calls).
/// Why: Standard platform function identifiers across architectures.
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

/// Platform interface function pointer type.
/// Why: Type-safe function pointer for platform calls.
pub const PlatformCallFn = *const fn (
    function_id: PlatformFunction,
    arg0: u64,
    arg1: u64,
    arg2: u64,
    arg3: u64,
) PlatformResult;

/// Time source function pointer type.
/// Why: Type-safe function pointer for time source.
pub const TimeSourceFn = *const fn () u64;

/// Platform interface implementation.
/// Why: Unified platform abstraction for RISC-V and AArch64.
pub const Platform = struct {
    /// Platform architecture.
    arch: PlatformArch,
    /// Platform call function pointer.
    platform_call_fn: ?PlatformCallFn,
    /// Time source function pointer.
    time_source_fn: ?TimeSourceFn,
    /// Whether platform is initialized.
    initialized: bool,
    
    /// Initialize platform interface.
    /// Why: Set up platform abstraction with architecture-specific implementation.
    /// Contract: arch must be valid, platform_call_fn and time_source_fn must be set.
    pub fn init(
        arch: PlatformArch,
        platform_call_fn: ?PlatformCallFn,
        time_source_fn: ?TimeSourceFn,
    ) Platform {
        // Assert: Architecture must be valid.
        Debug.kassert(
            arch == .riscv64 or arch == .aarch64,
            "Invalid platform architecture",
            .{},
        );
        
        return Platform{
            .arch = arch,
            .platform_call_fn = platform_call_fn,
            .time_source_fn = time_source_fn,
            .initialized = true,
        };
    }
    
    /// Call platform function.
    /// Why: Invoke platform runtime services.
    /// Contract: function_id must be valid, args must be valid.
    pub fn call(
        self: *const Platform,
        function_id: PlatformFunction,
        arg0: u64,
        arg1: u64,
        arg2: u64,
        arg3: u64,
    ) PlatformResult {
        // Assert: Platform must be initialized.
        Debug.kassert(self.initialized, "Platform not initialized", .{});
        
        // Assert: Platform call function must be set.
        Debug.kassert(
            self.platform_call_fn != null,
            "Platform call function not set",
            .{},
        );
        
        // Call platform function.
        const call_fn = self.platform_call_fn.?;
        return call_fn(function_id, arg0, arg1, arg2, arg3);
    }
    
    /// Get current time in nanoseconds.
    /// Why: Provide time source for kernel.
    /// Contract: Returns monotonic time.
    pub fn get_time_ns(self: *const Platform) u64 {
        // Assert: Platform must be initialized.
        Debug.kassert(self.initialized, "Platform not initialized", .{});
        
        // Assert: Time source function must be set.
        Debug.kassert(
            self.time_source_fn != null,
            "Time source function not set",
            .{},
        );
        
        // Get time from time source.
        const time_fn = self.time_source_fn.?;
        return time_fn();
    }
    
    /// Write character to console.
    /// Why: Output character to platform console.
    /// Contract: character must be valid ASCII.
    pub fn console_putchar(self: *const Platform, character: u8) void {
        _ = self.call(.console_putchar, @as(u64, @intCast(character)), 0, 0, 0);
    }
    
    /// Read character from console.
    /// Why: Read character from platform console.
    /// Returns: Character code, or -1 if no character available.
    pub fn console_getchar(self: *const Platform) i32 {
        const result = self.call(.console_getchar, 0, 0, 0, 0);
        if (result.is_success()) {
            return @as(i32, @intCast(result.value));
        }
        return -1;
    }
    
    /// Set timer for next interrupt.
    /// Why: Schedule timer interrupt at specified time.
    /// Contract: time must be valid (nanoseconds since boot).
    pub fn set_timer(self: *const Platform, time: u64) void {
        _ = self.call(.set_timer, time, 0, 0, 0);
    }
    
    /// Shutdown system.
    /// Why: Shutdown or reboot the system.
    /// Contract: shutdown_type must be valid (0 = shutdown, 1 = reboot).
    pub fn shutdown(self: *const Platform, shutdown_type: u32) void {
        _ = self.call(.shutdown, @as(u64, @intCast(shutdown_type)), 0, 0, 0);
    }
};

/// Global platform instance.
/// Why: Single platform instance for kernel use.
var global_platform: ?Platform = null;

/// Set global platform instance.
/// Why: Initialize platform abstraction for kernel use.
/// Contract: platform must be initialized.
pub fn set_platform(platform: Platform) void {
    // Assert: Platform must be initialized.
    Debug.kassert(platform.initialized, "Platform not initialized", .{});
    
    global_platform = platform;
}

/// Get global platform instance.
/// Why: Access platform abstraction from kernel code.
/// Contract: Platform must be set before use.
pub fn get_platform() *const Platform {
    // Assert: Global platform must be set.
    Debug.kassert(global_platform != null, "Global platform not set", .{});
    
    return &global_platform.?;
}
