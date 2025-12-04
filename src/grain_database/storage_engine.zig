//! Grain Database Storage Engine: Key-value storage extending Grain Silo.
//!
//! Why: Extend Grain Silo with database-specific features (indexes, transactions).
//! Architecture: Key-value foundation with bounded allocations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-03-163155-pst: Grain Database Agent

const std = @import("std");
const grain_silo = @import("grain_silo");

// Bounded: Max key length (bytes).
pub const MAX_KEY_LEN: u32 = 1_024;

// Bounded: Max value length (bytes).
pub const MAX_VALUE_LEN: u64 = 1_073_741_824; // 1 GB

// Bounded: Max records in storage engine.
pub const MAX_RECORDS: u32 = 10_000_000;

// Record: Key-value pair with metadata.
pub const Record = struct {
    key: []const u8,
    key_len: u32,
    value: []const u8,
    value_len: u64,
    record_id: u64,
    created_at: u64,
    updated_at: u64,
    allocator: std.mem.Allocator,

    // Initialize record.
    pub fn init(
        allocator: std.mem.Allocator,
        key: []const u8,
        value: []const u8,
        record_id: u64,
    ) !Record {
        std.debug.assert(key.len <= MAX_KEY_LEN);
        std.debug.assert(value.len <= MAX_VALUE_LEN);
        std.debug.assert(record_id > 0);

        const key_copy = try allocator.dupe(u8, key);
        errdefer allocator.free(key_copy);

        const value_copy = try allocator.dupe(u8, value);
        errdefer allocator.free(value_copy);

        const now = std.time.timestamp();

        return Record{
            .key = key_copy,
            .key_len = @as(u32, @intCast(key_copy.len)),
            .value = value_copy,
            .value_len = @as(u64, @intCast(value_copy.len)),
            .record_id = record_id,
            .created_at = @as(u64, @intCast(now)),
            .updated_at = @as(u64, @intCast(now)),
            .allocator = allocator,
        };
    }

    // Deinitialize record and free memory.
    pub fn deinit(self: *Record) void {
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

// Storage engine: Key-value storage extending Grain Silo.
pub const StorageEngine = struct {
    records: []Record,
    records_len: u32,
    next_record_id: u64,
    silo: grain_silo.Storage.ObjectStorage,
    allocator: std.mem.Allocator,

    // Initialize storage engine.
    pub fn init(
        allocator: std.mem.Allocator,
        hot_cache_size: u64,
    ) !StorageEngine {
        _ = allocator;
        const silo = try grain_silo.Storage.ObjectStorage.init(
            allocator,
            hot_cache_size,
        );
        errdefer silo.deinit();

        const records = try allocator.alloc(Record, MAX_RECORDS);
        errdefer allocator.free(records);

        return StorageEngine{
            .records = records,
            .records_len = 0,
            .next_record_id = 1,
            .silo = silo,
            .allocator = allocator,
        };
    }

    // Deinitialize storage engine and free memory.
    pub fn deinit(self: *StorageEngine) void {
        _ = self.allocator;
        var i: u32 = 0;
        while (i < self.records_len) : (i += 1) {
            self.records[i].deinit();
        }
        self.allocator.free(self.records);
        self.silo.deinit();
        self.* = undefined;
    }

    // Create record (insert key-value pair).
    pub fn create_record(
        self: *StorageEngine,
        key: []const u8,
        value: []const u8,
    ) !u64 {
        std.debug.assert(key.len <= MAX_KEY_LEN);
        std.debug.assert(value.len <= MAX_VALUE_LEN);
        std.debug.assert(self.records_len < MAX_RECORDS);

        if (self.find_record_by_key(key)) |_| {
            return error.RecordExists;
        }

        const record_id = self.next_record_id;
        self.next_record_id += 1;

        var record = try Record.init(
            self.allocator,
            key,
            value,
            record_id,
        );
        errdefer record.deinit();

        self.records[self.records_len] = record;
        self.records_len += 1;

        std.debug.assert(self.records_len <= MAX_RECORDS);
        return record_id;
    }

    // Read record by key.
    pub fn read_record_by_key(
        self: *StorageEngine,
        key: []const u8,
    ) ?*Record {
        std.debug.assert(key.len <= MAX_KEY_LEN);
        return self.find_record_by_key(key);
    }

    // Read record by ID.
    pub fn read_record_by_id(
        self: *StorageEngine,
        record_id: u64,
    ) ?*Record {
        std.debug.assert(record_id > 0);
        return self.find_record_by_id(record_id);
    }

    // Update record value.
    pub fn update_record(
        self: *StorageEngine,
        key: []const u8,
        new_value: []const u8,
    ) !void {
        std.debug.assert(key.len <= MAX_KEY_LEN);
        std.debug.assert(new_value.len <= MAX_VALUE_LEN);

        if (self.find_record_by_key(key)) |record| {
            if (new_value.len > 0) {
                self.allocator.free(record.value);
                const value_copy = try self.allocator.dupe(u8, new_value);
                record.value = value_copy;
                record.value_len = @as(u64, @intCast(value_copy.len));
            }
            const now = std.time.timestamp();
            record.updated_at = @as(u64, @intCast(now));
        } else {
            return error.RecordNotFound;
        }
    }

    // Delete record by key.
    pub fn delete_record(
        self: *StorageEngine,
        key: []const u8,
    ) !void {
        std.debug.assert(key.len <= MAX_KEY_LEN);

        var i: u32 = 0;
        while (i < self.records_len) : (i += 1) {
            if (std.mem.eql(u8, self.records[i].key, key)) {
                self.records[i].deinit();
                var j: u32 = i;
                while (j < self.records_len - 1) : (j += 1) {
                    self.records[j] = self.records[j + 1];
                }
                self.records_len -= 1;
                return;
            }
        }
        return error.RecordNotFound;
    }

    // Find record by key (internal helper).
    fn find_record_by_key(
        self: *StorageEngine,
        key: []const u8,
    ) ?*Record {
        std.debug.assert(key.len <= MAX_KEY_LEN);
        var i: u32 = 0;
        while (i < self.records_len) : (i += 1) {
            if (std.mem.eql(u8, self.records[i].key, key)) {
                return &self.records[i];
            }
        }
        return null;
    }

    // Find record by ID (internal helper).
    fn find_record_by_id(
        self: *StorageEngine,
        record_id: u64,
    ) ?*Record {
        std.debug.assert(record_id > 0);
        var i: u32 = 0;
        while (i < self.records_len) : (i += 1) {
            if (self.records[i].record_id == record_id) {
                return &self.records[i];
            }
        }
        return null;
    }
};

