//! Grain OS File Manager: File and directory management.
//!
//! Why: Provide file management functionality for file operations.
//! Architecture: File metadata, directory navigation, file operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max files in directory.
pub const MAX_FILES: u32 = 512;

// Bounded: Max file path length.
pub const MAX_PATH_LEN: u32 = 512;

// Bounded: Max file name length.
pub const MAX_NAME_LEN: u32 = 256;

// File type.
pub const FileType = enum(u8) {
    unknown,
    regular,
    directory,
    symlink,
    device,
    socket,
    fifo,
};

// File entry: represents a file or directory.
pub const FileEntry = struct {
    entry_id: u32,
    name: [MAX_NAME_LEN]u8,
    name_len: u32,
    path: [MAX_PATH_LEN]u8,
    path_len: u32,
    file_type: FileType,
    size: u64,
    modified_time: u64,
    active: bool,

    pub fn init() FileEntry {
        var entry = FileEntry{
            .entry_id = 0,
            .name = undefined,
            .name_len = 0,
            .path = undefined,
            .path_len = 0,
            .file_type = FileType.unknown,
            .size = 0,
            .modified_time = 0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_NAME_LEN) : (i += 1) {
            entry.name[i] = 0;
        }
        i = 0;
        while (i < MAX_PATH_LEN) : (i += 1) {
            entry.path[i] = 0;
        }
        return entry;
    }
};

// File manager: manages file operations.
pub const FileManager = struct {
    files: [MAX_FILES]FileEntry,
    files_len: u32,
    next_entry_id: u32,
    current_directory: [MAX_PATH_LEN]u8,
    current_directory_len: u32,

    pub fn init() FileManager {
        var manager = FileManager{
            .files = undefined,
            .files_len = 0,
            .next_entry_id = 1,
            .current_directory = undefined,
            .current_directory_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_FILES) : (i += 1) {
            manager.files[i] = FileEntry.init();
        }
        i = 0;
        while (i < MAX_PATH_LEN) : (i += 1) {
            manager.current_directory[i] = 0;
        }
        const root_path = "/";
        i = 0;
        while (i < root_path.len) : (i += 1) {
            manager.current_directory[i] = root_path[i];
        }
        manager.current_directory_len = @intCast(root_path.len);
        return manager;
    }

    // Add file entry.
    pub fn add_file_entry(
        self: *FileManager,
        name: []const u8,
        path: []const u8,
        file_type: FileType,
        size: u64,
        modified_time: u64,
    ) ?u32 {
        if (self.files_len >= MAX_FILES) {
            return null;
        }
        if (name.len > MAX_NAME_LEN) {
            return null;
        }
        if (path.len > MAX_PATH_LEN) {
            return null;
        }
        const entry_id = self.next_entry_id;
        self.next_entry_id += 1;
        self.files[self.files_len] = FileEntry.init();
        self.files[self.files_len].entry_id = entry_id;
        self.files[self.files_len].file_type = file_type;
        self.files[self.files_len].size = size;
        self.files[self.files_len].modified_time = modified_time;
        self.files[self.files_len].active = true;
        var i: u32 = 0;
        while (i < MAX_NAME_LEN) : (i += 1) {
            self.files[self.files_len].name[i] = 0;
        }
        const name_len = @min(name.len, MAX_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.files[self.files_len].name[i] = name[i];
        }
        self.files[self.files_len].name_len = @intCast(name_len);
        i = 0;
        while (i < MAX_PATH_LEN) : (i += 1) {
            self.files[self.files_len].path[i] = 0;
        }
        const path_len = @min(path.len, MAX_PATH_LEN);
        i = 0;
        while (i < path_len) : (i += 1) {
            self.files[self.files_len].path[i] = path[i];
        }
        self.files[self.files_len].path_len = @intCast(path_len);
        self.files_len += 1;
        return entry_id;
    }

    // Find file entry by ID.
    pub fn find_file_entry(
        self: *FileManager,
        entry_id: u32,
    ) ?*FileEntry {
        std.debug.assert(entry_id > 0);
        var i: u32 = 0;
        while (i < self.files_len) : (i += 1) {
            if (self.files[i].entry_id == entry_id and self.files[i].active) {
                return &self.files[i];
            }
        }
        return null;
    }

    // Find file entry by path.
    pub fn find_file_entry_by_path(
        self: *FileManager,
        path: []const u8,
    ) ?*FileEntry {
        var i: u32 = 0;
        while (i < self.files_len) : (i += 1) {
            if (self.files[i].active) {
                const file_path = self.files[i].path[0..self.files[i].path_len];
                if (std.mem.eql(u8, file_path, path)) {
                    return &self.files[i];
                }
            }
        }
        return null;
    }

    // Set current directory.
    pub fn set_current_directory(self: *FileManager, path: []const u8) bool {
        if (path.len > MAX_PATH_LEN) {
            return false;
        }
        var i: u32 = 0;
        while (i < MAX_PATH_LEN) : (i += 1) {
            self.current_directory[i] = 0;
        }
        const path_len = @min(path.len, MAX_PATH_LEN);
        i = 0;
        while (i < path_len) : (i += 1) {
            self.current_directory[i] = path[i];
        }
        self.current_directory_len = @intCast(path_len);
        return true;
    }

    // Get current directory.
    pub fn get_current_directory(self: *const FileManager) []const u8 {
        return self.current_directory[0..self.current_directory_len];
    }

    // Remove file entry.
    pub fn remove_file_entry(self: *FileManager, entry_id: u32) bool {
        std.debug.assert(entry_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.files_len) : (i += 1) {
            if (self.files[i].entry_id == entry_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining entries left.
        while (i < self.files_len - 1) : (i += 1) {
            self.files[i] = self.files[i + 1];
        }
        self.files_len -= 1;
        return true;
    }

    // Clear all file entries.
    pub fn clear_all(self: *FileManager) void {
        self.files_len = 0;
    }

    // Get file count.
    pub fn get_file_count(self: *const FileManager) u32 {
        return self.files_len;
    }
};

