const std = @import("std");
const testing = std.testing;
const backup_manager = @import("grain_core").backup_manager;

test "backup manager init" {
    const manager = backup_manager.BackupManager.init();
    std.debug.assert(manager.backups_len == 0);
    std.debug.assert(manager.next_backup_id == 1);
    std.debug.assert(manager.last_full_backup == 0);
}

test "backup metadata init" {
    const meta = backup_manager.BackupMetadata.init();
    std.debug.assert(meta.backup_id == 0);
    std.debug.assert(meta.filename_len == 0);
    std.debug.assert(meta.file_size == 0);
    std.debug.assert(meta.state == backup_manager.BackupState.pending);
}

test "backup metadata set filename" {
    var meta = backup_manager.BackupMetadata.init();
    const filename = "test_backup.db";
    const set = meta.set_filename(filename);
    std.debug.assert(set);
    std.debug.assert(meta.filename_len == filename.len);
}

test "backup manager create backup" {
    var manager = backup_manager.BackupManager.init();
    const filename = "test_backup.db";
    const backup = manager.create_backup(
        backup_manager.BackupType.full,
        filename,
        1000,
    );
    std.debug.assert(backup != null);
    std.debug.assert(manager.backups_len == 1);
    std.debug.assert(backup.?.backup_id == 1);
    std.debug.assert(backup.?.backup_type == backup_manager.BackupType.full);
}

test "backup manager find backup" {
    var manager = backup_manager.BackupManager.init();
    const filename = "test_backup.db";
    _ = manager.create_backup(
        backup_manager.BackupType.full,
        filename,
        1000,
    );
    const found = manager.find_backup(1);
    std.debug.assert(found != null);
    std.debug.assert(found.?.backup_id == 1);
}

test "backup manager update backup state" {
    var manager = backup_manager.BackupManager.init();
    const filename = "test_backup.db";
    _ = manager.create_backup(
        backup_manager.BackupType.full,
        filename,
        1000,
    );
    var checksum: [32]u8 = undefined;
    var i: u32 = 0;
    while (i < 32) : (i += 1) {
        checksum[i] = @intCast(i);
    }
    const updated = manager.update_backup_state(
        1,
        backup_manager.BackupState.completed,
        1024,
        &checksum,
    );
    std.debug.assert(updated);
    const backup = manager.find_backup(1);
    std.debug.assert(backup != null);
    std.debug.assert(backup.?.state == backup_manager.BackupState.completed);
    std.debug.assert(backup.?.file_size == 1024);
}

test "backup manager delete backup" {
    var manager = backup_manager.BackupManager.init();
    const filename = "test_backup.db";
    _ = manager.create_backup(
        backup_manager.BackupType.full,
        filename,
        1000,
    );
    const deleted = manager.delete_backup(1);
    std.debug.assert(deleted);
    std.debug.assert(manager.backups_len == 0);
    const found = manager.find_backup(1);
    std.debug.assert(found == null);
}

test "backup manager get latest full backup" {
    var manager = backup_manager.BackupManager.init();
    _ = manager.create_backup(
        backup_manager.BackupType.full,
        "backup1.db",
        1000,
    );
    _ = manager.create_backup(
        backup_manager.BackupType.full,
        "backup2.db",
        2000,
    );
    var checksum: [32]u8 = undefined;
    var i: u32 = 0;
    while (i < 32) : (i += 1) {
        checksum[i] = @intCast(i);
    }
    _ = manager.update_backup_state(1, backup_manager.BackupState.completed, 1024, &checksum);
    _ = manager.update_backup_state(2, backup_manager.BackupState.completed, 2048, &checksum);
    const latest = manager.get_latest_full_backup();
    std.debug.assert(latest != null);
    std.debug.assert(latest.?.backup_id == 2);
}

test "backup manager should schedule backup" {
    var manager = backup_manager.BackupManager.init();
    const should_backup = manager.should_schedule_backup(
        backup_manager.BackupType.full,
        1000,
        3600,
        1800,
    );
    std.debug.assert(should_backup);
}

