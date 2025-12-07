//! Tests for Grain Database Persistence.
//!
//! Why: Verify database persistence integration with Grain Core file storage, WAL, index manager, and backup manager.
//! Architecture: Comprehensive test coverage for persistence module.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-135508-pst: Grain Silo Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const PersistenceManager = grain_database.PersistenceManager;
const grain_core = @import("grain_core");
const file_storage = grain_core.file_storage;
const wal_manager = grain_core.wal_manager;
const index_manager = grain_core.index_manager;
const backup_manager = grain_core.backup_manager;

test "persistence manager init" {
    var manager = PersistenceManager.init("test_database.db");
    try testing.expect(manager.database_filename_len > 0);
    try testing.expect(!manager.is_initialized);
}

test "create database file" {
    var manager = PersistenceManager.init("test_create.db");
    const created = manager.create_database_file();
    try testing.expect(created);
    try testing.expect(manager.is_initialized);
}

test "open database file" {
    var manager = PersistenceManager.init("test_open.db");
    _ = manager.create_database_file();
    const opened = manager.open_database_file(file_storage.FileMode.read_write);
    try testing.expect(opened);
    try testing.expect(manager.is_initialized);
}

test "append wal entry" {
    var manager = PersistenceManager.init("test_wal.db");
    _ = manager.create_database_file();
    const data = "test_data_123";
    const entry = manager.append_wal_entry(
        wal_manager.WalEntryType.insert,
        1,
        1,
        data,
    );
    try testing.expect(entry != null);
    try testing.expect(entry.?.entry_type == wal_manager.WalEntryType.insert);
    try testing.expect(entry.?.table_id == 1);
    try testing.expect(entry.?.record_id == 1);
    try testing.expect(entry.?.data_len > 0);
}

test "create index" {
    var manager = PersistenceManager.init("test_index.db");
    _ = manager.create_database_file();
    const index = manager.create_index(
        1,
        index_manager.IndexType.btree,
        "test_index",
    );
    try testing.expect(index != null);
    try testing.expect(index.?.table_id == 1);
    try testing.expect(index.?.index_type == index_manager.IndexType.btree);
    try testing.expect(index.?.active);
}

test "add index entry" {
    var manager = PersistenceManager.init("test_index_entry.db");
    _ = manager.create_database_file();
    const index = manager.create_index(
        1,
        index_manager.IndexType.hash,
        "test_hash_index",
    );
    try testing.expect(index != null);
    const added = manager.add_index_entry(
        1,
        "test_hash_index",
        "test_key",
        "test_value",
        1,
    );
    try testing.expect(added);
}

test "create backup" {
    var manager = PersistenceManager.init("test_backup.db");
    _ = manager.create_database_file();
    const backup = manager.create_backup(
        backup_manager.BackupType.full,
        "test_backup_full.db",
    );
    try testing.expect(backup != null);
    try testing.expect(backup.?.backup_type == backup_manager.BackupType.full);
    try testing.expect(backup.?.state == backup_manager.BackupState.pending);
}

test "get latest full backup" {
    var manager = PersistenceManager.init("test_latest_backup.db");
    _ = manager.create_database_file();
    _ = manager.create_backup(backup_manager.BackupType.full, "backup1.db");
    _ = manager.create_backup(backup_manager.BackupType.incremental, "backup2.db");
    _ = manager.create_backup(backup_manager.BackupType.full, "backup3.db");
    const latest = manager.get_latest_full_backup();
    try testing.expect(latest != null);
    try testing.expect(latest.?.backup_type == backup_manager.BackupType.full);
}

test "wal checkpoint needed" {
    var manager = PersistenceManager.init("test_checkpoint.db");
    _ = manager.create_database_file();
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        _ = manager.append_wal_entry(
            wal_manager.WalEntryType.insert,
            1,
            i + 1,
            "test_data",
        );
    }
    const needs_checkpoint = manager.needs_wal_checkpoint();
    try testing.expect(!needs_checkpoint);
}

test "perform wal checkpoint" {
    var manager = PersistenceManager.init("test_perform_checkpoint.db");
    _ = manager.create_database_file();
    _ = manager.append_wal_entry(
        wal_manager.WalEntryType.insert,
        1,
        1,
        "test_data",
    );
    const checkpointed = manager.perform_wal_checkpoint();
    try testing.expect(checkpointed);
}

test "get wal recovery entries" {
    var manager = PersistenceManager.init("test_recovery.db");
    _ = manager.create_database_file();
    _ = manager.append_wal_entry(
        wal_manager.WalEntryType.insert,
        1,
        1,
        "test_data_1",
    );
    _ = manager.append_wal_entry(
        wal_manager.WalEntryType.update,
        1,
        1,
        "test_data_2",
    );
    var entries: [wal_manager.MAX_WAL_ENTRIES]wal_manager.WalEntry = undefined;
    const count = manager.get_wal_recovery_entries(&entries);
    try testing.expect(count == 2);
    try testing.expect(entries[0].entry_type == wal_manager.WalEntryType.insert);
    try testing.expect(entries[1].entry_type == wal_manager.WalEntryType.update);
}

test "should schedule backup" {
    var manager = PersistenceManager.init("test_schedule_backup.db");
    _ = manager.create_database_file();
    const should_schedule = manager.should_schedule_backup(
        backup_manager.BackupType.full,
        86400,
        3600,
    );
    try testing.expect(should_schedule);
}

test "update backup state" {
    var manager = PersistenceManager.init("test_update_backup.db");
    _ = manager.create_database_file();
    const backup = manager.create_backup(backup_manager.BackupType.full, "backup.db");
    try testing.expect(backup != null);
    var checksum: [file_storage.CHECKSUM_SIZE]u8 = undefined;
    var i: u32 = 0;
    while (i < file_storage.CHECKSUM_SIZE) : (i += 1) {
        checksum[i] = @intCast(i);
    }
    const updated = manager.update_backup_state(
        backup.?.backup_id,
        backup_manager.BackupState.completed,
        1024,
        &checksum,
    );
    try testing.expect(updated);
}

test "find backup" {
    var manager = PersistenceManager.init("test_find_backup.db");
    _ = manager.create_database_file();
    const backup = manager.create_backup(backup_manager.BackupType.full, "backup.db");
    try testing.expect(backup != null);
    const found = manager.find_backup(backup.?.backup_id);
    try testing.expect(found != null);
    try testing.expect(found.?.backup_id == backup.?.backup_id);
}

