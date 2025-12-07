//! Grain Database Persistence: File-based database persistence.
//!
//! Why: Integrate Grain Core file storage, WAL, index manager, and backup manager.
//! Architecture: Database file format, transaction logging, index persistence, backups.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-06-135508-pst: Grain Silo Agent

const std = @import("std");
const grain_core = @import("grain_core");
const file_storage = grain_core.file_storage;
const wal_manager = grain_core.wal_manager;
const index_manager = grain_core.index_manager;
const backup_manager = grain_core.backup_manager;
const record_serialization = @import("record_serialization.zig");
const index_entry_serialization = @import("index_entry_serialization.zig");
const multi_page_record = @import("multi_page_record.zig");
const storage_engine = @import("storage_engine.zig");

// Database persistence manager.
pub const PersistenceManager = struct {
    file_storage_manager: file_storage.FileStorageManager,
    wal_manager: wal_manager.WalManager,
    index_manager: index_manager.IndexManager,
    backup_manager: backup_manager.BackupManager,
    multi_page_manager: multi_page_record.MultiPageRecordManager,
    database_filename: [file_storage.MAX_FILENAME_LEN]u8,
    database_filename_len: u32,
    is_initialized: bool,

    // Initialize persistence manager.
    pub fn init(
        database_filename: []const u8,
    ) PersistenceManager {
        std.debug.assert(database_filename.len > 0);
        std.debug.assert(database_filename.len <= file_storage.MAX_FILENAME_LEN);
        var manager = PersistenceManager{
            .file_storage_manager = file_storage.FileStorageManager.init(),
            .wal_manager = wal_manager.WalManager.init(),
            .index_manager = index_manager.IndexManager.init(),
            .backup_manager = backup_manager.BackupManager.init(),
            .database_filename = undefined,
            .database_filename_len = 0,
            .is_initialized = false,
        };
        const filename_len = @min(database_filename.len, file_storage.MAX_FILENAME_LEN);
        var i: u32 = 0;
        while (i < file_storage.MAX_FILENAME_LEN) : (i += 1) {
            manager.database_filename[i] = 0;
        }
        std.mem.copyForwards(u8, &manager.database_filename, database_filename[0..filename_len]);
        manager.database_filename_len = filename_len;
        std.debug.assert(manager.database_filename_len > 0);
        return manager;
    }

    // Open database file.
    pub fn open_database_file(
        self: *PersistenceManager,
        mode: file_storage.FileMode,
    ) bool {
        std.debug.assert(self.database_filename_len > 0);
        const filename = self.database_filename[0..self.database_filename_len];
        const current_time = @as(u64, @intCast(std.time.timestamp()));
        const handle = self.file_storage_manager.open_file(filename, mode, current_time);
        if (handle == null) {
            return false;
        }
        self.is_initialized = true;
        std.debug.assert(self.is_initialized);
        return true;
    }

    // Create database file with header.
    pub fn create_database_file(
        self: *PersistenceManager,
    ) bool {
        std.debug.assert(self.database_filename_len > 0);
        const filename = self.database_filename[0..self.database_filename_len];
        const current_time = @as(u64, @intCast(std.time.timestamp()));
        const handle = self.file_storage_manager.open_file(filename, file_storage.FileMode.create, current_time);
        if (handle == null) {
            return false;
        }
        var header = file_storage.DatabaseFileHeader.init();
        header.created_at = current_time;
        header.updated_at = current_time;
        header.total_pages = 0;
        header.page_size = file_storage.PAGE_SIZE;
        header.version = 1;
        self.is_initialized = true;
        std.debug.assert(self.is_initialized);
        std.debug.assert(header.version == 1);
        std.debug.assert(header.page_size == file_storage.PAGE_SIZE);
        return true;
    }

    // Append WAL entry.
    pub fn append_wal_entry(
        self: *PersistenceManager,
        entry_type: wal_manager.WalEntryType,
        table_id: u32,
        record_id: u64,
        data: []const u8,
    ) ?*wal_manager.WalEntry {
        std.debug.assert(self.is_initialized);
        std.debug.assert(data.len <= wal_manager.MAX_WAL_ENTRY_SIZE);
        const timestamp = @as(u64, @intCast(std.time.timestamp()));
        return self.wal_manager.add_entry(entry_type, table_id, record_id, data, timestamp);
    }

    // Create index.
    pub fn create_index(
        self: *PersistenceManager,
        table_id: u32,
        index_type: index_manager.IndexType,
        name: []const u8,
    ) ?*index_manager.Index {
        std.debug.assert(self.is_initialized);
        std.debug.assert(table_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= 64);
        const timestamp = @as(u64, @intCast(std.time.timestamp()));
        return self.index_manager.create_index(table_id, index_type, name, timestamp);
    }

    // Add index entry.
    pub fn add_index_entry(
        self: *PersistenceManager,
        table_id: u32,
        index_name: []const u8,
        key: []const u8,
        value: []const u8,
        record_id: u64,
    ) bool {
        std.debug.assert(self.is_initialized);
        std.debug.assert(table_id > 0);
        std.debug.assert(index_name.len > 0);
        std.debug.assert(key.len > 0);
        std.debug.assert(key.len <= index_manager.MAX_INDEX_KEY_SIZE);
        std.debug.assert(value.len <= index_manager.MAX_INDEX_VALUE_SIZE);
        std.debug.assert(record_id > 0);
        const index = self.index_manager.find_index(table_id, index_name);
        if (index == null) {
            return false;
        }
        const timestamp = @as(u64, @intCast(std.time.timestamp()));
        return index.?.add_entry(key, value, record_id, timestamp);
    }

    // Create backup.
    pub fn create_backup(
        self: *PersistenceManager,
        backup_type: backup_manager.BackupType,
        filename: []const u8,
    ) ?*backup_manager.BackupMetadata {
        std.debug.assert(self.is_initialized);
        std.debug.assert(filename.len > 0);
        std.debug.assert(filename.len <= backup_manager.MAX_BACKUP_FILENAME_LEN);
        const current_time = @as(u64, @intCast(std.time.timestamp()));
        return self.backup_manager.create_backup(backup_type, filename, current_time);
    }

    // Get latest full backup.
    pub fn get_latest_full_backup(
        self: *const PersistenceManager,
    ) ?*const backup_manager.BackupMetadata {
        std.debug.assert(self.is_initialized);
        return self.backup_manager.get_latest_full_backup();
    }

    // Check if WAL checkpoint needed.
    pub fn needs_wal_checkpoint(
        self: *const PersistenceManager,
    ) bool {
        std.debug.assert(self.is_initialized);
        return self.wal_manager.needs_checkpoint();
    }

    // Perform WAL checkpoint.
    pub fn perform_wal_checkpoint(
        self: *PersistenceManager,
    ) bool {
        std.debug.assert(self.is_initialized);
        const current_time = @as(u64, @intCast(std.time.timestamp()));
        return self.wal_manager.checkpoint(current_time);
    }

    // Get WAL entries for recovery.
    pub fn get_wal_recovery_entries(
        self: *const PersistenceManager,
        entries_out: []wal_manager.WalEntry,
    ) u32 {
        std.debug.assert(self.is_initialized);
        std.debug.assert(entries_out.len >= wal_manager.MAX_WAL_ENTRIES);
        return self.wal_manager.get_recovery_entries(entries_out);
    }

    // Check if backup should be scheduled.
    pub fn should_schedule_backup(
        self: *const PersistenceManager,
        backup_type: backup_manager.BackupType,
        full_backup_interval: u64,
        incremental_backup_interval: u64,
    ) bool {
        std.debug.assert(self.is_initialized);
        std.debug.assert(full_backup_interval > 0);
        std.debug.assert(incremental_backup_interval > 0);
        const current_time = @as(u64, @intCast(std.time.timestamp()));
        return self.backup_manager.should_schedule_backup(
            backup_type,
            current_time,
            full_backup_interval,
            incremental_backup_interval,
        );
    }

    // Update backup state.
    pub fn update_backup_state(
        self: *PersistenceManager,
        backup_id: u32,
        state: backup_manager.BackupState,
        file_size: u64,
        checksum: []const u8,
    ) bool {
        std.debug.assert(self.is_initialized);
        std.debug.assert(backup_id > 0);
        std.debug.assert(checksum.len == file_storage.CHECKSUM_SIZE);
        return self.backup_manager.update_backup_state(backup_id, state, file_size, checksum);
    }

    // Find backup by ID.
    pub fn find_backup(
        self: *PersistenceManager,
        backup_id: u32,
    ) ?*backup_manager.BackupMetadata {
        std.debug.assert(self.is_initialized);
        std.debug.assert(backup_id > 0);
        return self.backup_manager.find_backup(backup_id);
    }

    // Get database file handle ID.
    pub fn get_database_handle_id(
        self: *PersistenceManager,
    ) ?u32 {
        std.debug.assert(self.is_initialized);
        const filename = self.database_filename[0..self.database_filename_len];
        const current_time = @as(u64, @intCast(std.time.timestamp()));
        const handle = self.file_storage_manager.open_file(
            filename,
            file_storage.FileMode.read_write,
            current_time,
        );
        if (handle == null) {
            return null;
        }
        return handle.?.handle_id;
    }

    // Lock database file.
    pub fn lock_database_file(
        self: *PersistenceManager,
        handle_id: u32,
    ) bool {
        std.debug.assert(self.is_initialized);
        std.debug.assert(handle_id > 0);
        return self.file_storage_manager.lock_file(handle_id);
    }

    // Unlock database file.
    pub fn unlock_database_file(
        self: *PersistenceManager,
        handle_id: u32,
    ) bool {
        std.debug.assert(self.is_initialized);
        std.debug.assert(handle_id > 0);
        return self.file_storage_manager.unlock_file(handle_id);
    }

    // Close database file.
    pub fn close_database_file(
        self: *PersistenceManager,
        handle_id: u32,
    ) bool {
        std.debug.assert(self.is_initialized);
        std.debug.assert(handle_id > 0);
        return self.file_storage_manager.close_file(handle_id);
    }

    // Validate database file header.
    pub fn validate_database_header(
        self: *const PersistenceManager,
        header: *const file_storage.DatabaseFileHeader,
    ) bool {
        std.debug.assert(self.is_initialized);
        std.debug.assert(header != null);
        return header.validate();
    }

    // Write record to file page.
    pub fn write_record_to_page(
        self: *PersistenceManager,
        record: *const storage_engine.Record,
        page: *file_storage.FilePage,
        offset: u32,
    ) bool {
        std.debug.assert(self.is_initialized);
        std.debug.assert(record != null);
        std.debug.assert(page != null);
        std.debug.assert(offset < file_storage.PAGE_SIZE);
        const serialized_size = record_serialization.calculate_serialized_size(
            record.key_len,
            record.value_len,
        );
        if (offset + serialized_size > file_storage.PAGE_SIZE) {
            return false;
        }
        const written = record_serialization.serialize_record(
            record,
            page.data[offset..],
        );
        if (written != serialized_size) {
            return false;
        }
        page.is_dirty = true;
        page.calculate_checksum();
        std.debug.assert(written == serialized_size);
        return true;
    }

    // Read record from file page.
    pub fn read_record_from_page(
        self: *PersistenceManager,
        allocator: std.mem.Allocator,
        page: *const file_storage.FilePage,
        offset: u32,
    ) ?storage_engine.Record {
        std.debug.assert(self.is_initialized);
        std.debug.assert(page != null);
        std.debug.assert(offset < file_storage.PAGE_SIZE);
        if (offset + record_serialization.RECORD_HEADER_SIZE > file_storage.PAGE_SIZE) {
            return null;
        }
        const key_len = std.mem.readInt(u32, page.data[offset + 8..][0..4], .little);
        const value_len = std.mem.readInt(u64, page.data[offset + 12..][0..8], .little);
        const serialized_size = record_serialization.calculate_serialized_size(
            key_len,
            value_len,
        );
        if (offset + serialized_size > file_storage.PAGE_SIZE) {
            return null;
        }
        const record = record_serialization.deserialize_record(
            allocator,
            page.data[offset..][0..serialized_size],
        ) catch return null;
        return record;
    }

    // Find record offset in page.
    pub fn find_record_offset_in_page(
        self: *const PersistenceManager,
        page: *const file_storage.FilePage,
        record_id: u64,
    ) ?u32 {
        std.debug.assert(self.is_initialized);
        std.debug.assert(page != null);
        std.debug.assert(record_id > 0);
        var offset: u32 = 0;
        while (offset < file_storage.PAGE_SIZE) {
            if (offset + record_serialization.RECORD_HEADER_SIZE > file_storage.PAGE_SIZE) {
                break;
            }
            const page_record_id = std.mem.readInt(u64, page.data[offset..][0..8], .little);
            if (page_record_id == 0) {
                break;
            }
            if (page_record_id == record_id) {
                return offset;
            }
            const key_len = std.mem.readInt(u32, page.data[offset + 8..][0..4], .little);
            const value_len = std.mem.readInt(u64, page.data[offset + 12..][0..8], .little);
            const record_size = record_serialization.calculate_serialized_size(
                key_len,
                value_len,
            );
            offset += record_size;
        }
        return null;
    }

    // Write index entry to file page.
    pub fn write_index_entry_to_page(
        self: *PersistenceManager,
        entry: *const index_manager.IndexEntry,
        page: *file_storage.FilePage,
        offset: u32,
    ) bool {
        std.debug.assert(self.is_initialized);
        std.debug.assert(entry != null);
        std.debug.assert(page != null);
        std.debug.assert(offset < file_storage.PAGE_SIZE);
        const serialized_size = index_entry_serialization.calculate_serialized_size(
            entry.key_len,
            entry.value_len,
        );
        if (offset + serialized_size > file_storage.PAGE_SIZE) {
            return false;
        }
        const written = index_entry_serialization.serialize_index_entry(
            entry,
            page.data[offset..],
        );
        if (written != serialized_size) {
            return false;
        }
        page.is_dirty = true;
        page.calculate_checksum();
        std.debug.assert(written == serialized_size);
        return true;
    }

    // Read index entry from file page.
    pub fn read_index_entry_from_page(
        self: *PersistenceManager,
        page: *const file_storage.FilePage,
        offset: u32,
    ) ?index_manager.IndexEntry {
        std.debug.assert(self.is_initialized);
        std.debug.assert(page != null);
        std.debug.assert(offset < file_storage.PAGE_SIZE);
        if (offset + index_entry_serialization.INDEX_ENTRY_HEADER_SIZE > file_storage.PAGE_SIZE) {
            return null;
        }
        const key_len = std.mem.readInt(u32, page.data[offset + 8..][0..4], .little);
        const value_len = std.mem.readInt(u32, page.data[offset + 12..][0..4], .little);
        const serialized_size = index_entry_serialization.calculate_serialized_size(
            key_len,
            value_len,
        );
        if (offset + serialized_size > file_storage.PAGE_SIZE) {
            return null;
        }
        const entry = index_entry_serialization.deserialize_index_entry(
            page.data[offset..][0..serialized_size],
        );
        return entry;
    }

    // Find index entry offset in page by record_id.
    pub fn find_index_entry_offset_in_page(
        self: *const PersistenceManager,
        page: *const file_storage.FilePage,
        record_id: u64,
    ) ?u32 {
        std.debug.assert(self.is_initialized);
        std.debug.assert(page != null);
        std.debug.assert(record_id > 0);
        var offset: u32 = 0;
        while (offset < file_storage.PAGE_SIZE) {
            if (offset + index_entry_serialization.INDEX_ENTRY_HEADER_SIZE > file_storage.PAGE_SIZE) {
                break;
            }
            const page_record_id = std.mem.readInt(u64, page.data[offset..][0..8], .little);
            if (page_record_id == 0) {
                break;
            }
            if (page_record_id == record_id) {
                return offset;
            }
            const key_len = std.mem.readInt(u32, page.data[offset + 8..][0..4], .little);
            const value_len = std.mem.readInt(u32, page.data[offset + 12..][0..4], .little);
            const entry_size = index_entry_serialization.calculate_serialized_size(
                key_len,
                value_len,
            );
            offset += entry_size;
        }
        return null;
    }
};

