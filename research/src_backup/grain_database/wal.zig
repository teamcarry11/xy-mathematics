//! Grain Database WAL: Write-ahead log for durability.
//!
//! Why: Ensure durability by logging all writes before applying them.
//! Architecture: Bounded log entries, iterative algorithms.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-03-163155-pst: Grain Database Agent

const std = @import("std");

// Bounded: Max log entries in WAL.
pub const MAX_LOG_ENTRIES: u32 = 1_000_000;

// Bounded: Max log entry size (bytes).
pub const MAX_LOG_ENTRY_SIZE: u32 = 1_048_576; // 1 MB

// Log entry type.
pub const LogEntryType = enum {
    insert,
    update,
    delete,
    commit,
    abort,
};

// WAL log entry.
pub const LogEntry = struct {
    entry_type: LogEntryType,
    record_id: u64,
    key: []const u8,
    key_len: u32,
    value: []const u8,
    value_len: u64,
    timestamp: u64,
    transaction_id: u64,
    allocator: std.mem.Allocator,

    // Initialize log entry.
    pub fn init(
        allocator: std.mem.Allocator,
        entry_type: LogEntryType,
        record_id: u64,
        key: []const u8,
        value: []const u8,
        transaction_id: u64,
    ) !LogEntry {
        std.debug.assert(key.len <= MAX_LOG_ENTRY_SIZE);
        std.debug.assert(value.len <= MAX_LOG_ENTRY_SIZE);
        std.debug.assert(record_id > 0);

        const key_copy = try allocator.dupe(u8, key);
        errdefer allocator.free(key_copy);

        const value_copy = try allocator.dupe(u8, value);
        errdefer allocator.free(value_copy);

        const now = std.time.timestamp();

        return LogEntry{
            .entry_type = entry_type,
            .record_id = record_id,
            .key = key_copy,
            .key_len = @as(u32, @intCast(key_copy.len)),
            .value = value_copy,
            .value_len = @as(u64, @intCast(value_copy.len)),
            .timestamp = @as(u64, @intCast(now)),
            .transaction_id = transaction_id,
            .allocator = allocator,
        };
    }

    // Deinitialize log entry and free memory.
    pub fn deinit(self: *LogEntry) void {
        _ = self.allocator;
        if (self.key_len > 0) {
            self.allocator.free(self.key);
        }
        if (self.value_len > 0) {
            self.allocator.free(self.value);
        }
        self.* = undefined;
    }
};

// Write-ahead log: Logs all writes for durability.
pub const WAL = struct {
    entries: []LogEntry,
    entries_len: u32,
    next_entry_id: u64,
    allocator: std.mem.Allocator,

    // Initialize WAL.
    pub fn init(allocator: std.mem.Allocator) !WAL {
        _ = allocator;
        const entries = try allocator.alloc(LogEntry, MAX_LOG_ENTRIES);
        errdefer allocator.free(entries);

        return WAL{
            .entries = entries,
            .entries_len = 0,
            .next_entry_id = 1,
            .allocator = allocator,
        };
    }

    // Deinitialize WAL and free memory.
    pub fn deinit(self: *WAL) void {
        _ = self.allocator;
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            self.entries[i].deinit();
        }
        self.allocator.free(self.entries);
        self.* = undefined;
    }

    // Append log entry.
    pub fn append(
        self: *WAL,
        entry_type: LogEntryType,
        record_id: u64,
        key: []const u8,
        value: []const u8,
        transaction_id: u64,
    ) !u64 {
        std.debug.assert(self.entries_len < MAX_LOG_ENTRIES);
        std.debug.assert(key.len <= MAX_LOG_ENTRY_SIZE);
        std.debug.assert(value.len <= MAX_LOG_ENTRY_SIZE);

        if (self.entries_len >= MAX_LOG_ENTRIES) {
            return error.WALFull;
        }

        const entry_id = self.next_entry_id;
        self.next_entry_id += 1;

        var entry = try LogEntry.init(
            self.allocator,
            entry_type,
            record_id,
            key,
            value,
            transaction_id,
        );
        errdefer entry.deinit();

        self.entries[self.entries_len] = entry;
        self.entries_len += 1;

        std.debug.assert(self.entries_len <= MAX_LOG_ENTRIES);
        return entry_id;
    }

    // Get log entry by index.
    pub fn get_entry(
        self: *WAL,
        entry_idx: u32,
    ) ?*LogEntry {
        std.debug.assert(entry_idx < MAX_LOG_ENTRIES);
        if (entry_idx >= self.entries_len) {
            return null;
        }
        return &self.entries[entry_idx];
    }

    // Clear all log entries (after checkpoint).
    pub fn clear(self: *WAL) void {
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            self.entries[i].deinit();
        }
        self.entries_len = 0;
        self.next_entry_id = 1;
    }
};

