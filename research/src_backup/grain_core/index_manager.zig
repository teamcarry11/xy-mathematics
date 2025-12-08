//! Grain Core Index Manager: Index file management for database queries.
//!
//! Why: Provide efficient database queries via indexes (Silo Agent).
//! Architecture: B-tree and hash index formats, creation, update, recovery.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const file_storage = @import("file_storage.zig");

// Bounded: Max index entries.
pub const MAX_INDEX_ENTRIES: u32 = 100000;

// Bounded: Max index key size.
pub const MAX_INDEX_KEY_SIZE: u32 = 256;

// Bounded: Max index value size.
pub const MAX_INDEX_VALUE_SIZE: u32 = 1024;

// Bounded: Max indexes per table.
pub const MAX_INDEXES_PER_TABLE: u32 = 8;

// Bounded: Max total indexes.
pub const MAX_TOTAL_INDEXES: u32 = 64;

// Index type.
pub const IndexType = enum(u8) {
    btree,
    hash,
};

// Index entry.
pub const IndexEntry = struct {
    key: [MAX_INDEX_KEY_SIZE]u8,
    key_len: u32,
    value: [MAX_INDEX_VALUE_SIZE]u8,
    value_len: u32,
    record_id: u64,
    timestamp: u64,

    pub fn init() IndexEntry {
        var entry = IndexEntry{
            .key = undefined,
            .key_len = 0,
            .value = undefined,
            .value_len = 0,
            .record_id = 0,
            .timestamp = 0,
        };
        var i: u32 = 0;
        while (i < MAX_INDEX_KEY_SIZE) : (i += 1) {
            entry.key[i] = 0;
        }
        i = 0;
        while (i < MAX_INDEX_VALUE_SIZE) : (i += 1) {
            entry.value[i] = 0;
        }
        return entry;
    }
};

// Index structure.
pub const Index = struct {
    index_id: u32,
    table_id: u32,
    index_type: IndexType,
    name: [64]u8,
    name_len: u32,
    entries: [MAX_INDEX_ENTRIES]IndexEntry,
    entries_len: u32,
    created_at: u64,
    updated_at: u64,
    active: bool,

    pub fn init(index_id: u32, table_id: u32, index_type: IndexType) Index {
        std.debug.assert(index_id > 0);
        std.debug.assert(table_id > 0);
        var index = Index{
            .index_id = index_id,
            .table_id = table_id,
            .index_type = index_type,
            .name = undefined,
            .name_len = 0,
            .entries = undefined,
            .entries_len = 0,
            .created_at = 0,
            .updated_at = 0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < 64) : (i += 1) {
            index.name[i] = 0;
        }
        i = 0;
        while (i < MAX_INDEX_ENTRIES) : (i += 1) {
            index.entries[i] = IndexEntry.init();
        }
        return index;
    }

    pub fn set_name(self: *Index, name: []const u8) bool {
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= 64);
        const name_len = @min(name.len, 64);
        var i: u32 = 0;
        while (i < 64) : (i += 1) {
            self.name[i] = 0;
        }
        i = 0;
        while (i < name_len) : (i += 1) {
            self.name[i] = name[i];
        }
        self.name_len = name_len;
        return true;
    }

    pub fn add_entry(
        self: *Index,
        key: []const u8,
        value: []const u8,
        record_id: u64,
        timestamp: u64,
    ) bool {
        std.debug.assert(key.len > 0);
        std.debug.assert(key.len <= MAX_INDEX_KEY_SIZE);
        std.debug.assert(value.len <= MAX_INDEX_VALUE_SIZE);
        std.debug.assert(record_id > 0);
        std.debug.assert(timestamp > 0);
        if (self.entries_len >= MAX_INDEX_ENTRIES) {
            return false;
        }
        const entry = &self.entries[self.entries_len];
        const key_len = @min(key.len, MAX_INDEX_KEY_SIZE);
        var i: u32 = 0;
        while (i < MAX_INDEX_KEY_SIZE) : (i += 1) {
            entry.key[i] = 0;
        }
        i = 0;
        while (i < key_len) : (i += 1) {
            entry.key[i] = key[i];
        }
        entry.key_len = key_len;
        const value_len = @min(value.len, MAX_INDEX_VALUE_SIZE);
        i = 0;
        while (i < MAX_INDEX_VALUE_SIZE) : (i += 1) {
            entry.value[i] = 0;
        }
        i = 0;
        while (i < value_len) : (i += 1) {
            entry.value[i] = value[i];
        }
        entry.value_len = value_len;
        entry.record_id = record_id;
        entry.timestamp = timestamp;
        self.entries_len += 1;
        self.updated_at = timestamp;
        return true;
    }

    pub fn find_entry(
        self: *const Index,
        key: []const u8,
    ) ?*const IndexEntry {
        std.debug.assert(key.len > 0);
        std.debug.assert(key.len <= MAX_INDEX_KEY_SIZE);
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            if (self.entries[i].key_len != key.len) {
                continue;
            }
            var match: bool = true;
            var j: u32 = 0;
            while (j < key.len) : (j += 1) {
                if (self.entries[i].key[j] != key[j]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                return &self.entries[i];
            }
        }
        return null;
    }
};

// Index manager: manages all indexes.
pub const IndexManager = struct {
    indexes: [MAX_INDEXES_PER_TABLE * 32]Index,
    indexes_len: u32,
    next_index_id: u32,

    pub fn init() IndexManager {
        var manager = IndexManager{
            .indexes = undefined,
            .indexes_len = 0,
            .next_index_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_INDEXES_PER_TABLE * 32) : (i += 1) {
            manager.indexes[i] = Index.init(0, 0, IndexType.btree);
        }
        return manager;
    }

    pub fn create_index(
        self: *IndexManager,
        table_id: u32,
        index_type: IndexType,
        name: []const u8,
        timestamp: u64,
    ) ?*Index {
        std.debug.assert(table_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(timestamp > 0);
        if (self.indexes_len >= MAX_TOTAL_INDEXES) {
            return null;
        }
        const index_id = self.next_index_id;
        self.next_index_id += 1;
        self.indexes[self.indexes_len] = Index.init(index_id, table_id, index_type);
        const index = &self.indexes[self.indexes_len];
        _ = index.set_name(name);
        index.created_at = timestamp;
        index.updated_at = timestamp;
        index.active = true;
        self.indexes_len += 1;
        return index;
    }

    pub fn find_index(
        self: *IndexManager,
        table_id: u32,
        name: []const u8,
    ) ?*Index {
        std.debug.assert(table_id > 0);
        std.debug.assert(name.len > 0);
        var i: u32 = 0;
        while (i < self.indexes_len) : (i += 1) {
            if (self.indexes[i].table_id != table_id) {
                continue;
            }
            if (self.indexes[i].name_len != name.len) {
                continue;
            }
            var match: bool = true;
            var j: u32 = 0;
            while (j < name.len) : (j += 1) {
                if (self.indexes[i].name[j] != name[j]) {
                    match = false;
                    break;
                }
            }
            if (match and self.indexes[i].active) {
                return &self.indexes[i];
            }
        }
        return null;
    }

    pub fn delete_index(
        self: *IndexManager,
        table_id: u32,
        name: []const u8,
    ) bool {
        std.debug.assert(table_id > 0);
        std.debug.assert(name.len > 0);
        if (self.find_index(table_id, name)) |index| {
            index.active = false;
            index.entries_len = 0;
            return true;
        }
        return false;
    }
};

