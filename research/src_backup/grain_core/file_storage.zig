//! Grain Core File Storage: Database file format and storage management.
//!
//! Why: Provide file-based storage for database persistence (Silo Agent).
//! Architecture: Page-based storage, file locking, integrity checks, WAL support.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");

// Bounded: Max file size (1TB).
pub const MAX_FILE_SIZE: u64 = 1024 * 1024 * 1024 * 1024;

// Bounded: Page size (4KB).
pub const PAGE_SIZE: u32 = 4096;

// Bounded: Max pages per file.
pub const MAX_PAGES: u32 = MAX_FILE_SIZE / PAGE_SIZE;

// Bounded: Max filename length.
pub const MAX_FILENAME_LEN: u32 = 256;

// Bounded: Max file handles.
pub const MAX_FILE_HANDLES: u32 = 128;

// Bounded: Checksum size (SHA-256).
pub const CHECKSUM_SIZE: u32 = 32;

// File storage mode.
pub const FileMode = enum(u8) {
    read_only,
    read_write,
    create,
};

// File handle state.
pub const FileHandleState = enum(u8) {
    closed,
    open,
    locked,
    error_state,
};

// Database file header.
pub const DatabaseFileHeader = struct {
    magic: [4]u8,
    version: u32,
    page_size: u32,
    total_pages: u32,
    checksum: [CHECKSUM_SIZE]u8,
    created_at: u64,
    updated_at: u64,

    pub fn init() DatabaseFileHeader {
        var header = DatabaseFileHeader{
            .magic = undefined,
            .version = 1,
            .page_size = PAGE_SIZE,
            .total_pages = 0,
            .checksum = undefined,
            .created_at = 0,
            .updated_at = 0,
        };
        const magic_str = "GDBF";
        var i: u32 = 0;
        while (i < 4) : (i += 1) {
            header.magic[i] = magic_str[i];
        }
        i = 0;
        while (i < CHECKSUM_SIZE) : (i += 1) {
            header.checksum[i] = 0;
        }
        return header;
    }

    pub fn validate(self: *const DatabaseFileHeader) bool {
        const expected_magic = "GDBF";
        var i: u32 = 0;
        while (i < 4) : (i += 1) {
            if (self.magic[i] != expected_magic[i]) {
                return false;
            }
        }
        if (self.version == 0) {
            return false;
        }
        if (self.page_size != PAGE_SIZE) {
            return false;
        }
        if (self.total_pages > MAX_PAGES) {
            return false;
        }
        return true;
    }
};

// File page.
pub const FilePage = struct {
    page_id: u32,
    data: [PAGE_SIZE]u8,
    checksum: [CHECKSUM_SIZE]u8,
    is_dirty: bool,

    pub fn init(page_id: u32) FilePage {
        std.debug.assert(page_id < MAX_PAGES);
        var page = FilePage{
            .page_id = page_id,
            .data = undefined,
            .checksum = undefined,
            .is_dirty = false,
        };
        var i: u32 = 0;
        while (i < PAGE_SIZE) : (i += 1) {
            page.data[i] = 0;
        }
        i = 0;
        while (i < CHECKSUM_SIZE) : (i += 1) {
            page.checksum[i] = 0;
        }
        return page;
    }

    pub fn calculate_checksum(self: *FilePage) void {
        var hash: [CHECKSUM_SIZE]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&self.data, &hash, .{});
        var i: u32 = 0;
        while (i < CHECKSUM_SIZE) : (i += 1) {
            self.checksum[i] = hash[i];
        }
    }

    pub fn verify_checksum(self: *const FilePage) bool {
        var computed: [CHECKSUM_SIZE]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&self.data, &computed, .{});
        var i: u32 = 0;
        while (i < CHECKSUM_SIZE) : (i += 1) {
            if (computed[i] != self.checksum[i]) {
                return false;
            }
        }
        return true;
    }
};

// File handle.
pub const FileHandle = struct {
    handle_id: u32,
    filename: [MAX_FILENAME_LEN]u8,
    filename_len: u32,
    mode: FileMode,
    state: FileHandleState,
    file_size: u64,
    page_count: u32,
    created_at: u64,
    last_access: u64,
    active: bool,

    pub fn init(handle_id: u32) FileHandle {
        std.debug.assert(handle_id > 0);
        var handle = FileHandle{
            .handle_id = handle_id,
            .filename = undefined,
            .filename_len = 0,
            .mode = FileMode.read_only,
            .state = FileHandleState.closed,
            .file_size = 0,
            .page_count = 0,
            .created_at = 0,
            .last_access = 0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_FILENAME_LEN) : (i += 1) {
            handle.filename[i] = 0;
        }
        return handle;
    }
};

// File storage manager.
pub const FileStorageManager = struct {
    handles: [MAX_FILE_HANDLES]FileHandle,
    handles_len: u32,
    next_handle_id: u32,

    pub fn init() FileStorageManager {
        var manager = FileStorageManager{
            .handles = undefined,
            .handles_len = 0,
            .next_handle_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_FILE_HANDLES) : (i += 1) {
            manager.handles[i] = FileHandle.init(0);
        }
        return manager;
    }

    // Open file.
    pub fn open_file(
        self: *FileStorageManager,
        filename: []const u8,
        mode: FileMode,
        current_time: u64,
    ) ?*FileHandle {
        std.debug.assert(filename.len > 0);
        std.debug.assert(filename.len <= MAX_FILENAME_LEN);
        if (self.handles_len >= MAX_FILE_HANDLES) {
            return null;
        }
        const handle_id = self.next_handle_id;
        self.next_handle_id += 1;
        self.handles[self.handles_len] = FileHandle.init(handle_id);
        const handle = &self.handles[self.handles_len];
        const filename_len = @min(filename.len, MAX_FILENAME_LEN);
        var i: u32 = 0;
        while (i < MAX_FILENAME_LEN) : (i += 1) {
            handle.filename[i] = 0;
        }
        i = 0;
        while (i < filename_len) : (i += 1) {
            handle.filename[i] = filename[i];
        }
        handle.filename_len = filename_len;
        handle.mode = mode;
        handle.state = FileHandleState.open;
        handle.created_at = current_time;
        handle.last_access = current_time;
        handle.active = true;
        self.handles_len += 1;
        return handle;
    }

    // Close file.
    pub fn close_file(
        self: *FileStorageManager,
        handle_id: u32,
    ) bool {
        std.debug.assert(handle_id > 0);
        var i: u32 = 0;
        while (i < self.handles_len) : (i += 1) {
            if (self.handles[i].handle_id == handle_id) {
                self.handles[i].state = FileHandleState.closed;
                self.handles[i].active = false;
                var j: u32 = i;
                while (j < self.handles_len - 1) : (j += 1) {
                    self.handles[j] = self.handles[j + 1];
                }
                self.handles_len -= 1;
                return true;
            }
        }
        return false;
    }

    // Find file handle by ID.
    pub fn find_handle(
        self: *FileStorageManager,
        handle_id: u32,
    ) ?*FileHandle {
        std.debug.assert(handle_id > 0);
        var i: u32 = 0;
        while (i < self.handles_len) : (i += 1) {
            if (self.handles[i].handle_id == handle_id) {
                return &self.handles[i];
            }
        }
        return null;
    }

    // Lock file.
    pub fn lock_file(
        self: *FileStorageManager,
        handle_id: u32,
    ) bool {
        std.debug.assert(handle_id > 0);
        if (self.find_handle(handle_id)) |handle| {
            if (handle.state == FileHandleState.open) {
                handle.state = FileHandleState.locked;
                return true;
            }
        }
        return false;
    }

    // Unlock file.
    pub fn unlock_file(
        self: *FileStorageManager,
        handle_id: u32,
    ) bool {
        std.debug.assert(handle_id > 0);
        if (self.find_handle(handle_id)) |handle| {
            if (handle.state == FileHandleState.locked) {
                handle.state = FileHandleState.open;
                return true;
            }
        }
        return false;
    }
};

