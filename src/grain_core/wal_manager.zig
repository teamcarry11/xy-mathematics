//! Grain Core WAL Manager: Write-ahead log for database transactions.
//!
//! Why: Provide ACID guarantees for database transactions (Silo Agent).
//! Architecture: WAL file format, rotation, checkpoint, recovery.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const file_storage = @import("file_storage.zig");

// Bounded: Max WAL file size (100MB).
pub const MAX_WAL_FILE_SIZE: u64 = 100 * 1024 * 1024;

// Bounded: Max WAL entries.
pub const MAX_WAL_ENTRIES: u32 = 10000;

// Bounded: Max WAL entry size.
pub const MAX_WAL_ENTRY_SIZE: u32 = 64 * 1024;

// Bounded: WAL checkpoint interval (entries).
pub const WAL_CHECKPOINT_INTERVAL: u32 = 1000;

// WAL entry type.
pub const WalEntryType = enum(u8) {
    insert,
    update,
    delete,
    checkpoint,
};

// WAL entry.
pub const WalEntry = struct {
    entry_id: u64,
    entry_type: WalEntryType,
    table_id: u32,
    record_id: u64,
    data: [MAX_WAL_ENTRY_SIZE]u8,
    data_len: u32,
    timestamp: u64,
    checksum: [file_storage.CHECKSUM_SIZE]u8,

    pub fn init() WalEntry {
        var entry = WalEntry{
            .entry_id = 0,
            .entry_type = WalEntryType.insert,
            .table_id = 0,
            .record_id = 0,
            .data = undefined,
            .data_len = 0,
            .timestamp = 0,
            .checksum = undefined,
        };
        var i: u32 = 0;
        while (i < MAX_WAL_ENTRY_SIZE) : (i += 1) {
            entry.data[i] = 0;
        }
        i = 0;
        while (i < file_storage.CHECKSUM_SIZE) : (i += 1) {
            entry.checksum[i] = 0;
        }
        return entry;
    }

    pub fn calculate_checksum(self: *WalEntry) void {
        var combined: [MAX_WAL_ENTRY_SIZE + 16]u8 = undefined;
        var combined_len: u32 = 0;
        var i: u32 = 0;
        while (i < self.data_len and i < MAX_WAL_ENTRY_SIZE) : (i += 1) {
            combined[combined_len] = self.data[i];
            combined_len += 1;
        }
        const table_id_bytes = std.mem.toBytes(self.table_id);
        i = 0;
        while (i < 4) : (i += 1) {
            combined[combined_len] = table_id_bytes[i];
            combined_len += 1;
        }
        const record_id_bytes = std.mem.toBytes(self.record_id);
        i = 0;
        while (i < 8) : (i += 1) {
            combined[combined_len] = record_id_bytes[i];
            combined_len += 1;
        }
        const entry_type_byte: u8 = @intFromEnum(self.entry_type);
        combined[combined_len] = entry_type_byte;
        combined_len += 1;
        var hash: [file_storage.CHECKSUM_SIZE]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(combined[0..combined_len], &hash, .{});
        i = 0;
        while (i < file_storage.CHECKSUM_SIZE) : (i += 1) {
            self.checksum[i] = hash[i];
        }
    }

    pub fn verify_checksum(self: *const WalEntry) bool {
        var computed: [file_storage.CHECKSUM_SIZE]u8 = undefined;
        var combined: [MAX_WAL_ENTRY_SIZE + 16]u8 = undefined;
        var combined_len: u32 = 0;
        var i: u32 = 0;
        while (i < self.data_len and i < MAX_WAL_ENTRY_SIZE) : (i += 1) {
            combined[combined_len] = self.data[i];
            combined_len += 1;
        }
        const table_id_bytes = std.mem.toBytes(self.table_id);
        i = 0;
        while (i < 4) : (i += 1) {
            combined[combined_len] = table_id_bytes[i];
            combined_len += 1;
        }
        const record_id_bytes = std.mem.toBytes(self.record_id);
        i = 0;
        while (i < 8) : (i += 1) {
            combined[combined_len] = record_id_bytes[i];
            combined_len += 1;
        }
        const entry_type_byte: u8 = @intFromEnum(self.entry_type);
        combined[combined_len] = entry_type_byte;
        combined_len += 1;
        std.crypto.hash.sha2.Sha256.hash(combined[0..combined_len], &computed, .{});
        i = 0;
        while (i < file_storage.CHECKSUM_SIZE) : (i += 1) {
            if (computed[i] != self.checksum[i]) {
                return false;
            }
        }
        return true;
    }
};

// WAL manager: manages write-ahead log.
pub const WalManager = struct {
    entries: [MAX_WAL_ENTRIES]WalEntry,
    entries_len: u32,
    next_entry_id: u64,
    file_size: u64,
    checkpoint_count: u32,
    last_checkpoint: u64,

    pub fn init() WalManager {
        var manager = WalManager{
            .entries = undefined,
            .entries_len = 0,
            .next_entry_id = 1,
            .file_size = 0,
            .checkpoint_count = 0,
            .last_checkpoint = 0,
        };
        var i: u32 = 0;
        while (i < MAX_WAL_ENTRIES) : (i += 1) {
            manager.entries[i] = WalEntry.init();
        }
        return manager;
    }

    // Add WAL entry.
    pub fn add_entry(
        self: *WalManager,
        entry_type: WalEntryType,
        table_id: u32,
        record_id: u64,
        data: []const u8,
        timestamp: u64,
    ) ?*WalEntry {
        std.debug.assert(table_id > 0);
        std.debug.assert(record_id > 0);
        std.debug.assert(data.len > 0);
        std.debug.assert(data.len <= MAX_WAL_ENTRY_SIZE);
        std.debug.assert(timestamp > 0);
        if (self.entries_len >= MAX_WAL_ENTRIES) {
            return null;
        }
        const entry_id = self.next_entry_id;
        self.next_entry_id += 1;
        self.entries[self.entries_len] = WalEntry.init();
        const entry = &self.entries[self.entries_len];
        entry.entry_id = entry_id;
        entry.entry_type = entry_type;
        entry.table_id = table_id;
        entry.record_id = record_id;
        const data_len = @min(data.len, MAX_WAL_ENTRY_SIZE);
        var i: u32 = 0;
        while (i < MAX_WAL_ENTRY_SIZE) : (i += 1) {
            entry.data[i] = 0;
        }
        i = 0;
        while (i < data_len) : (i += 1) {
            entry.data[i] = data[i];
        }
        entry.data_len = data_len;
        entry.timestamp = timestamp;
        entry.calculate_checksum();
        const entry_size: u64 = @as(u64, @intCast(64 + data_len));
        self.file_size += entry_size;
        self.entries_len += 1;
        return entry;
    }

    // Check if checkpoint needed.
    pub fn needs_checkpoint(self: *const WalManager) bool {
        if (self.entries_len >= WAL_CHECKPOINT_INTERVAL) {
            return true;
        }
        if (self.file_size >= MAX_WAL_FILE_SIZE) {
            return true;
        }
        return false;
    }

    // Perform checkpoint.
    pub fn checkpoint(self: *WalManager, current_time: u64) bool {
        std.debug.assert(current_time > 0);
        if (self.entries_len == 0) {
            return false;
        }
        self.checkpoint_count += 1;
        self.last_checkpoint = current_time;
        var checkpoint_entry = WalEntry.init();
        checkpoint_entry.entry_id = self.next_entry_id;
        self.next_entry_id += 1;
        checkpoint_entry.entry_type = WalEntryType.checkpoint;
        checkpoint_entry.timestamp = current_time;
        checkpoint_entry.calculate_checksum();
        self.file_size = 0;
        self.entries_len = 0;
        return true;
    }

    // Get entries for recovery.
    pub fn get_recovery_entries(
        self: *const WalManager,
        entries_out: []WalEntry,
    ) u32 {
        std.debug.assert(entries_out.len >= MAX_WAL_ENTRIES);
        const count = @min(self.entries_len, entries_out.len);
        var i: u32 = 0;
        while (i < count) : (i += 1) {
            entries_out[i] = self.entries[i];
        }
        return count;
    }

    // Clear all entries.
    pub fn clear_all(self: *WalManager) void {
        self.entries_len = 0;
        self.file_size = 0;
        self.checkpoint_count = 0;
        self.last_checkpoint = 0;
    }
};

