//! Grain Database Storage Persistence: Integration between StorageEngine and PersistenceManager.
//!
//! Why: Bridge in-memory storage engine with file-based persistence for durability.
//! Architecture: WAL logging, index updates, backup coordination.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-07-020414-pst: Grain Silo Agent

const std = @import("std");
const storage_engine = @import("storage_engine.zig");
const persistence = @import("persistence.zig");
const grain_core = @import("grain_core");
const wal_manager = grain_core.wal_manager;

// Storage persistence integration.
pub const StoragePersistence = struct {
    persistence_manager: *persistence.PersistenceManager,
    storage_engine: *storage_engine.StorageEngine,
    table_id: u32,

    // Initialize storage persistence.
    pub fn init(
        persistence_manager: *persistence.PersistenceManager,
        storage_engine: *storage_engine.StorageEngine,
        table_id: u32,
    ) StoragePersistence {
        std.debug.assert(persistence_manager != null);
        std.debug.assert(storage_engine != null);
        std.debug.assert(table_id > 0);
        return StoragePersistence{
            .persistence_manager = persistence_manager,
            .storage_engine = storage_engine,
            .table_id = table_id,
        };
    }

    // Create record with WAL logging.
    pub fn create_record_with_wal(
        self: *StoragePersistence,
        key: []const u8,
        value: []const u8,
    ) !u64 {
        std.debug.assert(key.len > 0);
        std.debug.assert(key.len <= storage_engine.MAX_KEY_LEN);
        std.debug.assert(value.len <= storage_engine.MAX_VALUE_LEN);
        const record_id = try self.storage_engine.create_record(key, value);
        const record_data = try std.fmt.allocPrint(
            self.storage_engine.allocator,
            "{s}:{s}",
            .{ key, value },
        );
        defer self.storage_engine.allocator.free(record_data);
        _ = self.persistence_manager.append_wal_entry(
            wal_manager.WalEntryType.insert,
            self.table_id,
            record_id,
            record_data,
        );
        std.debug.assert(record_id > 0);
        return record_id;
    }

    // Update record with WAL logging.
    pub fn update_record_with_wal(
        self: *StoragePersistence,
        key: []const u8,
        new_value: []const u8,
    ) !void {
        std.debug.assert(key.len > 0);
        std.debug.assert(key.len <= storage_engine.MAX_KEY_LEN);
        std.debug.assert(new_value.len <= storage_engine.MAX_VALUE_LEN);
        const record = self.storage_engine.read_record_by_key(key);
        if (record == null) {
            return error.RecordNotFound;
        }
        const record_id = record.?.record_id;
        try self.storage_engine.update_record(key, new_value);
        const record_data = try std.fmt.allocPrint(
            self.storage_engine.allocator,
            "{s}:{s}",
            .{ key, new_value },
        );
        defer self.storage_engine.allocator.free(record_data);
        _ = self.persistence_manager.append_wal_entry(
            wal_manager.WalEntryType.update,
            self.table_id,
            record_id,
            record_data,
        );
    }

    // Delete record with WAL logging.
    pub fn delete_record_with_wal(
        self: *StoragePersistence,
        key: []const u8,
    ) !void {
        std.debug.assert(key.len > 0);
        std.debug.assert(key.len <= storage_engine.MAX_KEY_LEN);
        const record = self.storage_engine.read_record_by_key(key);
        if (record == null) {
            return error.RecordNotFound;
        }
        const record_id = record.?.record_id;
        try self.storage_engine.delete_record(key);
        const record_data = try std.fmt.allocPrint(
            self.storage_engine.allocator,
            "{s}:",
            .{key},
        );
        defer self.storage_engine.allocator.free(record_data);
        _ = self.persistence_manager.append_wal_entry(
            wal_manager.WalEntryType.delete,
            self.table_id,
            record_id,
            record_data,
        );
    }

    // Perform WAL checkpoint if needed.
    pub fn checkpoint_if_needed(
        self: *StoragePersistence,
    ) bool {
        if (!self.persistence_manager.needs_wal_checkpoint()) {
            return false;
        }
        return self.persistence_manager.perform_wal_checkpoint();
    }
};

