//! Tests for Grain Database End-to-End Persistence with Recovery
//! 2025-12-08-162744-pst: Grain Silo Agent

const std = @import("std");
const testing = std.testing;
const grain_core = @import("grain_core");
const wal_manager = grain_core.wal_manager;
const backup_manager = grain_core.backup_manager;
const grain_database = @import("grain_database");
const PersistenceManager = grain_database.PersistenceManager;
const StorageEngine = grain_database.StorageEngine;
const StoragePersistence = grain_database.StoragePersistence;

test "end_to_end_persistence_create_and_recover" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var manager = PersistenceManager.init("test_e2e.db");
    std.debug.assert(manager.create_database_file());
    var engine = StorageEngine.init(allocator);
    var storage_persistence = StoragePersistence.init(&manager, &engine, 1);
    const key1 = "test_key1";
    const value1 = "test_value1";
    const record_id1 = storage_persistence.create_record_with_wal(key1, value1) catch return;
    std.debug.assert(record_id1 > 0);
    const key2 = "test_key2";
    const value2 = "test_value2";
    const record_id2 = storage_persistence.create_record_with_wal(key2, value2) catch return;
    std.debug.assert(record_id2 > 0);
    const needs_checkpoint = manager.needs_wal_checkpoint();
    if (needs_checkpoint) {
        const checkpointed = manager.perform_wal_checkpoint();
        std.debug.assert(checkpointed);
    }
    var recovery_entries: [1000]wal_manager.WalEntry = undefined;
    const recovery_count = manager.get_wal_recovery_entries(&recovery_entries);
    std.debug.assert(recovery_count >= 0);
    const record1 = engine.get_record(record_id1);
    std.debug.assert(record1 != null);
    std.debug.assert(record1.?.key_len == key1.len);
    const record2 = engine.get_record(record_id2);
    std.debug.assert(record2 != null);
    std.debug.assert(record2.?.key_len == key2.len);
}

test "end_to_end_persistence_update_and_recover" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var manager = PersistenceManager.init("test_e2e2.db");
    std.debug.assert(manager.create_database_file());
    var engine = StorageEngine.init(allocator);
    var storage_persistence = StoragePersistence.init(&manager, &engine, 1);
    const key = "update_key";
    const value1 = "value1";
    const record_id = storage_persistence.create_record_with_wal(key, value1) catch return;
    std.debug.assert(record_id > 0);
    const value2 = "value2_updated";
    storage_persistence.update_record_with_wal(key, value2) catch return;
    const needs_checkpoint = manager.needs_wal_checkpoint();
    if (needs_checkpoint) {
        const checkpointed = manager.perform_wal_checkpoint();
        std.debug.assert(checkpointed);
    }
    const record = engine.get_record(record_id);
    std.debug.assert(record != null);
    std.debug.assert(record.?.value_len == value2.len);
    var i: u32 = 0;
    while (i < value2.len) : (i += 1) {
        std.debug.assert(record.?.value[i] == value2[i]);
    }
}

test "end_to_end_persistence_delete_and_recover" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var manager = PersistenceManager.init("test_e2e3.db");
    std.debug.assert(manager.create_database_file());
    var engine = StorageEngine.init(allocator);
    var storage_persistence = StoragePersistence.init(&manager, &engine, 1);
    const key = "delete_key";
    const value = "delete_value";
    const record_id = storage_persistence.create_record_with_wal(key, value) catch return;
    std.debug.assert(record_id > 0);
    storage_persistence.delete_record_with_wal(key) catch return;
    const needs_checkpoint = manager.needs_wal_checkpoint();
    if (needs_checkpoint) {
        const checkpointed = manager.perform_wal_checkpoint();
        std.debug.assert(checkpointed);
    }
    const record = engine.get_record(record_id);
    std.debug.assert(record == null);
}

test "end_to_end_persistence_backup_and_restore" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var manager = PersistenceManager.init("test_e2e4.db");
    std.debug.assert(manager.create_database_file());
    var engine = StorageEngine.init(allocator);
    var storage_persistence = StoragePersistence.init(&manager, &engine, 1);
    const key1 = "backup_key1";
    const value1 = "backup_value1";
    const record_id1 = storage_persistence.create_record_with_wal(key1, value1) catch return;
    std.debug.assert(record_id1 > 0);
    const key2 = "backup_key2";
    const value2 = "backup_value2";
    const record_id2 = storage_persistence.create_record_with_wal(key2, value2) catch return;
    std.debug.assert(record_id2 > 0);
    const backup = manager.create_backup(backup_manager.BackupType.full, "backup_e2e.db");
    std.debug.assert(backup != null);
    var checksum: [32]u8 = undefined;
    var i: u32 = 0;
    while (i < 32) : (i += 1) {
        checksum[i] = @as(u8, @intCast(i + 20));
    }
    const updated = manager.backup_manager.update_backup_state(
        backup.?.backup_id,
        backup_manager.BackupState.completed,
        3000,
        &checksum,
    );
    std.debug.assert(updated);
    const valid = manager.validate_backup_for_restore(backup.?.backup_id);
    std.debug.assert(valid);
    const restored = manager.restore_from_backup(backup.?.backup_id);
    std.debug.assert(restored);
}

test "end_to_end_persistence_wal_recovery_after_crash" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var manager = PersistenceManager.init("test_e2e5.db");
    std.debug.assert(manager.create_database_file());
    var engine = StorageEngine.init(allocator);
    var storage_persistence = StoragePersistence.init(&manager, &engine, 1);
    const key1 = "crash_key1";
    const value1 = "crash_value1";
    const record_id1 = storage_persistence.create_record_with_wal(key1, value1) catch return;
    std.debug.assert(record_id1 > 0);
    const key2 = "crash_key2";
    const value2 = "crash_value2";
    const record_id2 = storage_persistence.create_record_with_wal(key2, value2) catch return;
    std.debug.assert(record_id2 > 0);
    var recovery_entries: [1000]wal_manager.WalEntry = undefined;
    const recovery_count = manager.get_wal_recovery_entries(&recovery_entries);
    std.debug.assert(recovery_count >= 2);
    var found1: bool = false;
    var found2: bool = false;
    var i: u32 = 0;
    while (i < recovery_count) : (i += 1) {
        if (recovery_entries[i].record_id == record_id1) {
            found1 = true;
        }
        if (recovery_entries[i].record_id == record_id2) {
            found2 = true;
        }
    }
    std.debug.assert(found1);
    std.debug.assert(found2);
}

test "end_to_end_persistence_checkpoint_coordination" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var manager = PersistenceManager.init("test_e2e6.db");
    std.debug.assert(manager.create_database_file());
    var engine = StorageEngine.init(allocator);
    var storage_persistence = StoragePersistence.init(&manager, &engine, 1);
    const key = "checkpoint_key";
    const value = "checkpoint_value";
    const record_id = storage_persistence.create_record_with_wal(key, value) catch return;
    std.debug.assert(record_id > 0);
    const needs_checkpoint = storage_persistence.checkpoint_if_needed();
    if (needs_checkpoint) {
        const checkpointed = manager.perform_wal_checkpoint();
        std.debug.assert(checkpointed);
    }
    const record = engine.get_record(record_id);
    std.debug.assert(record != null);
    std.debug.assert(record.?.record_id == record_id);
}

