//! Tests for Grain Database Backup Restore Functionality
//! 2025-12-07-083520-pst: Grain Silo Agent

const std = @import("std");
const testing = std.testing;
const grain_core = @import("grain_core");
const backup_manager = grain_core.backup_manager;
const grain_database = @import("grain_database");
const PersistenceManager = grain_database.PersistenceManager;

test "validate_backup_for_restore valid" {
    var manager = PersistenceManager.init("test_backup.db");
    std.debug.assert(manager.create_database_file());
    const backup = manager.create_backup(backup_manager.BackupType.full, "backup1.db");
    std.debug.assert(backup != null);
    const current_time = @as(u64, @intCast(std.time.timestamp()));
    var checksum: [32]u8 = undefined;
    var i: u32 = 0;
    while (i < 32) : (i += 1) {
        checksum[i] = @as(u8, @intCast(i));
    }
    const updated = manager.backup_manager.update_backup_state(
        backup.?.backup_id,
        backup_manager.BackupState.completed,
        1000,
        &checksum,
    );
    std.debug.assert(updated);
    const valid = manager.validate_backup_for_restore(backup.?.backup_id);
    std.debug.assert(valid);
}

test "validate_backup_for_restore invalid_state" {
    var manager = PersistenceManager.init("test_backup2.db");
    std.debug.assert(manager.create_database_file());
    const backup = manager.create_backup(backup_manager.BackupType.full, "backup2.db");
    std.debug.assert(backup != null);
    const valid = manager.validate_backup_for_restore(backup.?.backup_id);
    std.debug.assert(!valid);
}

test "validate_backup_for_restore not_found" {
    var manager = PersistenceManager.init("test_backup3.db");
    std.debug.assert(manager.create_database_file());
    const valid = manager.validate_backup_for_restore(999);
    std.debug.assert(!valid);
}

test "get_backup_metadata" {
    var manager = PersistenceManager.init("test_backup4.db");
    std.debug.assert(manager.create_database_file());
    const backup = manager.create_backup(backup_manager.BackupType.incremental, "backup4.db");
    std.debug.assert(backup != null);
    const metadata = manager.get_backup_metadata(backup.?.backup_id);
    std.debug.assert(metadata != null);
    std.debug.assert(metadata.?.backup_id == backup.?.backup_id);
    std.debug.assert(metadata.?.backup_type == backup_manager.BackupType.incremental);
}

test "list_backups" {
    var manager = PersistenceManager.init("test_backup5.db");
    std.debug.assert(manager.create_database_file());
    const backup1 = manager.create_backup(backup_manager.BackupType.full, "backup5a.db");
    std.debug.assert(backup1 != null);
    const backup2 = manager.create_backup(backup_manager.BackupType.incremental, "backup5b.db");
    std.debug.assert(backup2 != null);
    var backups: [100]backup_manager.BackupMetadata = undefined;
    const count = manager.list_backups(&backups);
    std.debug.assert(count >= 2);
    var found1: bool = false;
    var found2: bool = false;
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        if (backups[i].backup_id == backup1.?.backup_id) {
            found1 = true;
        }
        if (backups[i].backup_id == backup2.?.backup_id) {
            found2 = true;
        }
    }
    std.debug.assert(found1);
    std.debug.assert(found2);
}

test "restore_from_backup validation" {
    var manager = PersistenceManager.init("test_backup6.db");
    std.debug.assert(manager.create_database_file());
    const backup = manager.create_backup(backup_manager.BackupType.full, "backup6.db");
    std.debug.assert(backup != null);
    const current_time = @as(u64, @intCast(std.time.timestamp()));
    var checksum: [32]u8 = undefined;
    var i: u32 = 0;
    while (i < 32) : (i += 1) {
        checksum[i] = @as(u8, @intCast(i + 10));
    }
    const updated = manager.backup_manager.update_backup_state(
        backup.?.backup_id,
        backup_manager.BackupState.completed,
        2000,
        &checksum,
    );
    std.debug.assert(updated);
    const restored = manager.restore_from_backup(backup.?.backup_id);
    std.debug.assert(restored);
}

test "restore_from_backup invalid_backup" {
    var manager = PersistenceManager.init("test_backup7.db");
    std.debug.assert(manager.create_database_file());
    const restored = manager.restore_from_backup(999);
    std.debug.assert(!restored);
}

test "restore_from_backup pending_state" {
    var manager = PersistenceManager.init("test_backup8.db");
    std.debug.assert(manager.create_database_file());
    const backup = manager.create_backup(backup_manager.BackupType.full, "backup8.db");
    std.debug.assert(backup != null);
    const restored = manager.restore_from_backup(backup.?.backup_id);
    std.debug.assert(!restored);
}

