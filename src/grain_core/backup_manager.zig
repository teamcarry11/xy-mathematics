//! Grain Core Backup Manager: Database backup and restore capabilities.
//!
//! Why: Provide database backup/restore for data protection (Silo Agent).
//! Architecture: Full backup, incremental backup, restore, scheduling.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const file_storage = @import("file_storage.zig");

// Bounded: Max backup files.
pub const MAX_BACKUP_FILES: u32 = 100;

// Bounded: Max backup filename length.
pub const MAX_BACKUP_FILENAME_LEN: u32 = 256;

// Bounded: Max backup metadata size.
pub const MAX_BACKUP_METADATA_SIZE: u32 = 1024;

// Backup type.
pub const BackupType = enum(u8) {
    full,
    incremental,
};

// Backup state.
pub const BackupState = enum(u8) {
    pending,
    in_progress,
    completed,
    failed,
};

// Backup metadata.
pub const BackupMetadata = struct {
    backup_id: u32,
    backup_type: BackupType,
    filename: [MAX_BACKUP_FILENAME_LEN]u8,
    filename_len: u32,
    file_size: u64,
    created_at: u64,
    state: BackupState,
    checksum: [file_storage.CHECKSUM_SIZE]u8,
    metadata: [MAX_BACKUP_METADATA_SIZE]u8,
    metadata_len: u32,

    pub fn init() BackupMetadata {
        var meta = BackupMetadata{
            .backup_id = 0,
            .backup_type = BackupType.full,
            .filename = undefined,
            .filename_len = 0,
            .file_size = 0,
            .created_at = 0,
            .state = BackupState.pending,
            .checksum = undefined,
            .metadata = undefined,
            .metadata_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_BACKUP_FILENAME_LEN) : (i += 1) {
            meta.filename[i] = 0;
        }
        i = 0;
        while (i < file_storage.CHECKSUM_SIZE) : (i += 1) {
            meta.checksum[i] = 0;
        }
        i = 0;
        while (i < MAX_BACKUP_METADATA_SIZE) : (i += 1) {
            meta.metadata[i] = 0;
        }
        return meta;
    }

    pub fn set_filename(self: *BackupMetadata, filename: []const u8) bool {
        std.debug.assert(filename.len > 0);
        std.debug.assert(filename.len <= MAX_BACKUP_FILENAME_LEN);
        const filename_len = @min(filename.len, MAX_BACKUP_FILENAME_LEN);
        var i: u32 = 0;
        while (i < MAX_BACKUP_FILENAME_LEN) : (i += 1) {
            self.filename[i] = 0;
        }
        i = 0;
        while (i < filename_len) : (i += 1) {
            self.filename[i] = filename[i];
        }
        self.filename_len = filename_len;
        return true;
    }
};

// Backup manager: manages database backups.
pub const BackupManager = struct {
    backups: [MAX_BACKUP_FILES]BackupMetadata,
    backups_len: u32,
    next_backup_id: u32,
    last_full_backup: u64,
    last_incremental_backup: u64,

    pub fn init() BackupManager {
        var manager = BackupManager{
            .backups = undefined,
            .backups_len = 0,
            .next_backup_id = 1,
            .last_full_backup = 0,
            .last_incremental_backup = 0,
        };
        var i: u32 = 0;
        while (i < MAX_BACKUP_FILES) : (i += 1) {
            manager.backups[i] = BackupMetadata.init();
        }
        return manager;
    }

    pub fn create_backup(
        self: *BackupManager,
        backup_type: BackupType,
        filename: []const u8,
        timestamp: u64,
    ) ?*BackupMetadata {
        std.debug.assert(filename.len > 0);
        std.debug.assert(timestamp > 0);
        if (self.backups_len >= MAX_BACKUP_FILES) {
            return null;
        }
        const backup_id = self.next_backup_id;
        self.next_backup_id += 1;
        self.backups[self.backups_len] = BackupMetadata.init();
        const backup = &self.backups[self.backups_len];
        backup.backup_id = backup_id;
        backup.backup_type = backup_type;
        _ = backup.set_filename(filename);
        backup.created_at = timestamp;
        backup.state = BackupState.pending;
        if (backup_type == BackupType.full) {
            self.last_full_backup = timestamp;
        } else {
            self.last_incremental_backup = timestamp;
        }
        self.backups_len += 1;
        return backup;
    }

    pub fn find_backup(
        self: *BackupManager,
        backup_id: u32,
    ) ?*BackupMetadata {
        std.debug.assert(backup_id > 0);
        var i: u32 = 0;
        while (i < self.backups_len) : (i += 1) {
            if (self.backups[i].backup_id == backup_id) {
                return &self.backups[i];
            }
        }
        return null;
    }

    pub fn update_backup_state(
        self: *BackupManager,
        backup_id: u32,
        state: BackupState,
        file_size: u64,
        checksum: []const u8,
    ) bool {
        std.debug.assert(backup_id > 0);
        std.debug.assert(checksum.len == file_storage.CHECKSUM_SIZE);
        if (self.find_backup(backup_id)) |backup| {
            backup.state = state;
            backup.file_size = file_size;
            var i: u32 = 0;
            while (i < file_storage.CHECKSUM_SIZE) : (i += 1) {
                backup.checksum[i] = checksum[i];
            }
            return true;
        }
        return false;
    }

    pub fn delete_backup(
        self: *BackupManager,
        backup_id: u32,
    ) bool {
        std.debug.assert(backup_id > 0);
        var i: u32 = 0;
        while (i < self.backups_len) : (i += 1) {
            if (self.backups[i].backup_id == backup_id) {
                var j: u32 = i;
                while (j < self.backups_len - 1) : (j += 1) {
                    self.backups[j] = self.backups[j + 1];
                }
                self.backups_len -= 1;
                return true;
            }
        }
        return false;
    }

    pub fn get_latest_full_backup(self: *const BackupManager) ?*const BackupMetadata {
        var latest: ?*const BackupMetadata = null;
        var latest_time: u64 = 0;
        var i: u32 = 0;
        while (i < self.backups_len) : (i += 1) {
            if (self.backups[i].backup_type == BackupType.full and
                self.backups[i].state == BackupState.completed and
                self.backups[i].created_at > latest_time)
            {
                latest = &self.backups[i];
                latest_time = self.backups[i].created_at;
            }
        }
        return latest;
    }

    pub fn should_schedule_backup(
        self: *const BackupManager,
        backup_type: BackupType,
        current_time: u64,
        full_backup_interval: u64,
        incremental_backup_interval: u64,
    ) bool {
        std.debug.assert(current_time > 0);
        std.debug.assert(full_backup_interval > 0);
        std.debug.assert(incremental_backup_interval > 0);
        if (backup_type == BackupType.full) {
            if (self.last_full_backup == 0) {
                return true;
            }
            return (current_time - self.last_full_backup) >= full_backup_interval;
        } else {
            if (self.last_incremental_backup == 0) {
                return true;
            }
            return (current_time - self.last_incremental_backup) >= incremental_backup_interval;
        }
    }
};
