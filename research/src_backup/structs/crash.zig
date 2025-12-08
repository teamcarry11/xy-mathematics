const std = @import("std");

/// Crash handler structs: panic handling and error logging.
/// All crash-related struct definitions in one place.

/// Crash handler: captures panics, stack traces, and formats logs.
pub const CrashHandler = struct {
    allocator: std.mem.Allocator,
    log_buffer: std.ArrayListUnmanaged(u8),
};

