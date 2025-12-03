//! Grain OS System Logger: System event logging and log management.
//!
//! Why: Provide system logging for events, errors, and debugging.
//! Architecture: Log entry management, log levels, log filtering.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max log entries.
pub const MAX_LOG_ENTRIES: u32 = 1024;

// Bounded: Max log message length.
pub const MAX_LOG_MESSAGE_LEN: u32 = 512;

// Bounded: Max log source length.
pub const MAX_LOG_SOURCE_LEN: u32 = 64;

// Log level.
pub const LogLevel = enum(u8) {
    debug,
    info,
    warning,
    err,
    critical,
};

// Log entry: represents a log entry.
pub const LogEntry = struct {
    entry_id: u32,
    timestamp: u64, // Log timestamp.
    level: LogLevel,
    source: [MAX_LOG_SOURCE_LEN]u8,
    source_len: u32,
    message: [MAX_LOG_MESSAGE_LEN]u8,
    message_len: u32,
    active: bool,

    pub fn init() LogEntry {
        var entry = LogEntry{
            .entry_id = 0,
            .timestamp = 0,
            .level = LogLevel.info,
            .source = undefined,
            .source_len = 0,
            .message = undefined,
            .message_len = 0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_LOG_SOURCE_LEN) : (i += 1) {
            entry.source[i] = 0;
        }
        i = 0;
        while (i < MAX_LOG_MESSAGE_LEN) : (i += 1) {
            entry.message[i] = 0;
        }
        return entry;
    }
};

// System logger: manages system logs.
pub const SystemLogger = struct {
    entries: [MAX_LOG_ENTRIES]LogEntry,
    entries_len: u32,
    next_entry_id: u32,
    min_log_level: LogLevel, // Minimum log level to store.

    pub fn init() SystemLogger {
        var logger = SystemLogger{
            .entries = undefined,
            .entries_len = 0,
            .next_entry_id = 1,
            .min_log_level = LogLevel.debug,
        };
        var i: u32 = 0;
        while (i < MAX_LOG_ENTRIES) : (i += 1) {
            logger.entries[i] = LogEntry.init();
        }
        return logger;
    }

    // Add log entry.
    pub fn log(
        self: *SystemLogger,
        level: LogLevel,
        source: []const u8,
        message: []const u8,
        timestamp: u64,
    ) ?u32 {
        // Check if log level is above minimum.
        if (@intFromEnum(level) < @intFromEnum(self.min_log_level)) {
            return null;
        }
        if (source.len > MAX_LOG_SOURCE_LEN) {
            return null;
        }
        if (message.len > MAX_LOG_MESSAGE_LEN) {
            return null;
        }
        // Use circular buffer: overwrite oldest entry if full.
        const entry_index = if (self.entries_len < MAX_LOG_ENTRIES) self.entries_len else (self.next_entry_id - 1) % MAX_LOG_ENTRIES;
        const entry_id = self.next_entry_id;
        self.next_entry_id += 1;
        self.entries[entry_index] = LogEntry.init();
        self.entries[entry_index].entry_id = entry_id;
        self.entries[entry_index].timestamp = timestamp;
        self.entries[entry_index].level = level;
        self.entries[entry_index].active = true;
        var i: u32 = 0;
        while (i < MAX_LOG_SOURCE_LEN) : (i += 1) {
            self.entries[entry_index].source[i] = 0;
        }
        const source_len = @min(source.len, MAX_LOG_SOURCE_LEN);
        i = 0;
        while (i < source_len) : (i += 1) {
            self.entries[entry_index].source[i] = source[i];
        }
        self.entries[entry_index].source_len = @intCast(source_len);
        i = 0;
        while (i < MAX_LOG_MESSAGE_LEN) : (i += 1) {
            self.entries[entry_index].message[i] = 0;
        }
        const message_len = @min(message.len, MAX_LOG_MESSAGE_LEN);
        i = 0;
        while (i < message_len) : (i += 1) {
            self.entries[entry_index].message[i] = message[i];
        }
        self.entries[entry_index].message_len = @intCast(message_len);
        if (self.entries_len < MAX_LOG_ENTRIES) {
            self.entries_len += 1;
        }
        return entry_id;
    }

    // Find entry by ID.
    pub fn find_entry(
        self: *SystemLogger,
        entry_id: u32,
    ) ?*const LogEntry {
        std.debug.assert(entry_id > 0);
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            if (self.entries[i].entry_id == entry_id and self.entries[i].active) {
                return &self.entries[i];
            }
        }
        return null;
    }

    // Get entry by index.
    pub fn get_entry(
        self: *const SystemLogger,
        index: u32,
    ) ?*const LogEntry {
        if (index >= self.entries_len) {
            return null;
        }
        return &self.entries[index];
    }

    // Set minimum log level.
    pub fn set_min_log_level(self: *SystemLogger, level: LogLevel) void {
        self.min_log_level = level;
    }

    // Get minimum log level.
    pub fn get_min_log_level(self: *const SystemLogger) LogLevel {
        return self.min_log_level;
    }

    // Clear all logs.
    pub fn clear_all(self: *SystemLogger) void {
        self.entries_len = 0;
        self.next_entry_id = 1;
    }

    // Get log count.
    pub fn get_log_count(self: *const SystemLogger) u32 {
        return self.entries_len;
    }

    // Get log count by level.
    pub fn get_log_count_by_level(self: *const SystemLogger, level: LogLevel) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            if (self.entries[i].level == level) {
                count += 1;
            }
        }
        return count;
    }
};

