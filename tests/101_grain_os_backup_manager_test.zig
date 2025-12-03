//! Tests for Grain OS backup management system.
//!
//! Why: Verify backup management functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const BackupManager = grain_os.backup_manager.BackupManager;
const BackupType = grain_os.backup_manager.BackupType;
const BackupState = grain_os.backup_manager.BackupState;

test "backup manager initialization" {
    const manager = BackupManager.init();
    std.debug.assert(manager.backups_len == 0);
    std.debug.assert(manager.next_backup_id == 1);
    std.debug.assert(manager.current_backup_id == 0);
}

test "create backup" {
    var manager = BackupManager.init();
    const backup_id_opt = manager.create_backup(
        "test_backup",
        "Test backup description",
        "/backups/test_backup",
        BackupType.full,
        1000,
    );
    std.debug.assert(backup_id_opt != null);
    if (backup_id_opt) |backup_id| {
        std.debug.assert(backup_id == 1);
        std.debug.assert(manager.get_backup_count() == 1);
    }
}

test "start backup" {
    var manager = BackupManager.init();
    if (manager.create_backup("test_backup", "Test", "/backups/test", BackupType.full, 1000)) |backup_id| {
        const result = manager.start_backup(backup_id);
        std.debug.assert(result);
        if (manager.find_backup(backup_id)) |backup| {
            std.debug.assert(backup.state == BackupState.in_progress);
            std.debug.assert(manager.get_current_backup_id() == backup_id);
        }
    }
}

test "complete backup" {
    var manager = BackupManager.init();
    if (manager.create_backup("test_backup", "Test", "/backups/test", BackupType.full, 1000)) |backup_id| {
        _ = manager.start_backup(backup_id);
        const result = manager.complete_backup(backup_id, 1024);
        std.debug.assert(result);
        if (manager.find_backup(backup_id)) |backup| {
            std.debug.assert(backup.state == BackupState.completed);
            std.debug.assert(backup.size_bytes == 1024);
        }
    }
}

test "fail backup" {
    var manager = BackupManager.init();
    if (manager.create_backup("test_backup", "Test", "/backups/test", BackupType.full, 1000)) |backup_id| {
        _ = manager.start_backup(backup_id);
        const result = manager.fail_backup(backup_id);
        std.debug.assert(result);
        if (manager.find_backup(backup_id)) |backup| {
            std.debug.assert(backup.state == BackupState.failed);
        }
    }
}

test "cancel backup" {
    var manager = BackupManager.init();
    if (manager.create_backup("test_backup", "Test", "/backups/test", BackupType.full, 1000)) |backup_id| {
        const result = manager.cancel_backup(backup_id);
        std.debug.assert(result);
        if (manager.find_backup(backup_id)) |backup| {
            std.debug.assert(backup.state == BackupState.cancelled);
        }
    }
}

test "restore backup" {
    var manager = BackupManager.init();
    if (manager.create_backup("test_backup", "Test", "/backups/test", BackupType.full, 1000)) |backup_id| {
        _ = manager.start_backup(backup_id);
        _ = manager.complete_backup(backup_id, 1024);
        const result = manager.restore_backup(backup_id);
        std.debug.assert(result);
    }
}

test "remove backup" {
    var manager = BackupManager.init();
    if (manager.create_backup("test_backup", "Test", "/backups/test", BackupType.full, 1000)) |backup_id| {
        const result = manager.remove_backup(backup_id);
        std.debug.assert(result);
        std.debug.assert(manager.get_backup_count() == 0);
    }
}

test "get completed backup count" {
    var manager = BackupManager.init();
    if (manager.create_backup("backup1", "Test 1", "/backups/1", BackupType.full, 1000)) |backup_id_1| {
        if (manager.create_backup("backup2", "Test 2", "/backups/2", BackupType.full, 2000)) |backup_id_2| {
            _ = manager.start_backup(backup_id_1);
            _ = manager.complete_backup(backup_id_1, 1024);
            _ = manager.start_backup(backup_id_2);
            _ = manager.complete_backup(backup_id_2, 2048);
            const count = manager.get_completed_backup_count();
            std.debug.assert(count == 2);
        }
    }
}

test "compositor create backup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const backup_id_opt = comp.create_backup(
        "test_backup",
        "Test backup description",
        "/backups/test_backup",
        BackupType.full,
        1000,
    );
    std.debug.assert(backup_id_opt != null);
}

test "compositor start backup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.create_backup("test_backup", "Test", "/backups/test", BackupType.full, 1000)) |backup_id| {
        const result = comp.start_backup(backup_id);
        std.debug.assert(result);
    }
}

test "compositor complete backup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.create_backup("test_backup", "Test", "/backups/test", BackupType.full, 1000)) |backup_id| {
        _ = comp.start_backup(backup_id);
        const result = comp.complete_backup(backup_id, 1024);
        std.debug.assert(result);
    }
}

test "compositor restore backup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.create_backup("test_backup", "Test", "/backups/test", BackupType.full, 1000)) |backup_id| {
        _ = comp.start_backup(backup_id);
        _ = comp.complete_backup(backup_id, 1024);
        const result = comp.restore_backup(backup_id);
        std.debug.assert(result);
    }
}

test "backup types" {
    std.debug.assert(@intFromEnum(BackupType.full) == 0);
    std.debug.assert(@intFromEnum(BackupType.incremental) == 1);
    std.debug.assert(@intFromEnum(BackupType.settings_only) == 2);
    std.debug.assert(@intFromEnum(BackupType.data_only) == 3);
    std.debug.assert(@intFromEnum(BackupType.custom) == 4);
}

test "backup states" {
    std.debug.assert(@intFromEnum(BackupState.pending) == 0);
    std.debug.assert(@intFromEnum(BackupState.in_progress) == 1);
    std.debug.assert(@intFromEnum(BackupState.completed) == 2);
    std.debug.assert(@intFromEnum(BackupState.failed) == 3);
    std.debug.assert(@intFromEnum(BackupState.cancelled) == 4);
}

test "backup manager constants" {
    std.debug.assert(grain_os.backup_manager.MAX_BACKUPS == 32);
    std.debug.assert(grain_os.backup_manager.MAX_BACKUP_NAME_LEN == 128);
    std.debug.assert(grain_os.backup_manager.MAX_BACKUP_PATH_LEN == 512);
    std.debug.assert(grain_os.backup_manager.MAX_BACKUP_DESC_LEN == 256);
}

