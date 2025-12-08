//! Kernel Log Buffer
//! Why: Store kernel log entries for userspace access via syscall.
//! Grain Style: Static allocation, bounded buffer, explicit types.

const std = @import("std");
const Debug = @import("debug.zig");
const Timer = @import("timer.zig").Timer;

/// Maximum number of log entries in buffer.
/// Why: Bounded allocation, prevent unbounded growth.
const MAX_LOG_ENTRIES: u32 = 256;

/// Maximum message length per log entry.
/// Why: Bounded message size, prevent buffer overflow.
const MAX_MESSAGE_LEN: u32 = 256;

/// Maximum source name length.
/// Why: Bounded source identifier size.
const MAX_SOURCE_LEN: u32 = 32;

/// Log level enumeration (matches debug.zig LogLevel).
/// Why: Explicit log levels for filtering.
pub const KernelLogLevel = enum(u8) {
    debug = 0,
    info = 1,
    warn = 2,
    error_lvl = 3,
};

/// Kernel log entry structure.
/// Why: Store log entry with timestamp, level, source, and message.
/// Grain Style: Explicit types, bounded size, deterministic layout.
pub const KernelLogEntry = struct {
    /// Timestamp (nanoseconds since boot).
    timestamp: u64,
    /// Log level (0=debug, 1=info, 2=warn, 3=error).
    level: u8,
    /// Source identifier (null-terminated).
    source: [MAX_SOURCE_LEN]u8,
    /// Message (null-terminated).
    message: [MAX_MESSAGE_LEN]u8,
    
    /// Initialize empty log entry.
    /// Why: Explicit initialization, prevent uninitialized fields.
    pub fn init() KernelLogEntry {
        return KernelLogEntry{
            .timestamp = 0,
            .level = 0,
            .source = [_]u8{0} ** MAX_SOURCE_LEN,
            .message = [_]u8{0} ** MAX_MESSAGE_LEN,
        };
    }
};

/// Kernel log buffer.
/// Why: Store kernel log entries for userspace access.
/// Grain Style: Static allocation, circular buffer, bounded size.
pub const KernelLogBuffer = struct {
    /// Log entries (circular buffer).
    entries: [MAX_LOG_ENTRIES]KernelLogEntry,
    /// Write index (next entry to write).
    write_index: u32,
    /// Entry count (number of valid entries, up to MAX_LOG_ENTRIES).
    entry_count: u32,
    /// Timer reference for timestamps.
    timer: *const Timer,
    
    /// Initialize log buffer.
    /// Why: Explicit initialization, clear state.
    pub fn init(timer: *const Timer) KernelLogBuffer {
        return KernelLogBuffer{
            .entries = [_]KernelLogEntry{KernelLogEntry.init()} ** MAX_LOG_ENTRIES,
            .write_index = 0,
            .entry_count = 0,
            .timer = timer,
        };
    }
    
    /// Add log entry to buffer.
    /// Why: Store log entry for userspace access.
    /// Contract: source and message must be null-terminated, within size limits.
    pub fn add_entry(
        self: *KernelLogBuffer,
        level: KernelLogLevel,
        source: []const u8,
        message: []const u8,
    ) void {
        // Assert: source length must be within bounds.
        Debug.kassert(source.len < MAX_SOURCE_LEN, "Source too long", .{});
        
        // Assert: message length must be within bounds.
        Debug.kassert(message.len < MAX_MESSAGE_LEN, "Message too long", .{});
        
        // Get current timestamp.
        const timestamp = self.timer.get_uptime_ns();
        
        // Get entry at write index.
        const idx = self.write_index;
        var entry = &self.entries[idx];
        
        // Initialize entry.
        entry.timestamp = timestamp;
        entry.level = @intFromEnum(level);
        
        // Copy source (null-terminated).
        var i: u32 = 0;
        while (i < source.len and i < MAX_SOURCE_LEN - 1) : (i += 1) {
            entry.source[i] = source[i];
        }
        entry.source[i] = 0;
        
        // Copy message (null-terminated).
        i = 0;
        while (i < message.len and i < MAX_MESSAGE_LEN - 1) : (i += 1) {
            entry.message[i] = message[i];
        }
        entry.message[i] = 0;
        
        // Update write index (circular buffer).
        self.write_index = (self.write_index + 1) % MAX_LOG_ENTRIES;
        
        // Update entry count (bounded by MAX_LOG_ENTRIES).
        if (self.entry_count < MAX_LOG_ENTRIES) {
            self.entry_count += 1;
        }
    }
    
    /// Get number of log entries.
    /// Why: Return entry count for userspace.
    pub fn get_entry_count(self: *const KernelLogBuffer) u32 {
        return self.entry_count;
    }
    
    /// Get log entry by index (0-based, oldest first).
    /// Why: Allow userspace to read entries sequentially.
    /// Returns: null if index is out of range, otherwise pointer to entry.
    pub fn get_entry(self: *const KernelLogBuffer, index: u32) ?*const KernelLogEntry {
        if (index >= self.entry_count) {
            return null;
        }
        
        // Calculate actual index in circular buffer.
        // Oldest entry is at (write_index - entry_count) % MAX_LOG_ENTRIES.
        const start_idx = if (self.entry_count == MAX_LOG_ENTRIES) 
            self.write_index 
        else 
            0;
        const actual_idx = (start_idx + index) % MAX_LOG_ENTRIES;
        
        return &self.entries[actual_idx];
    }
};

