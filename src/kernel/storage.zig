//! Grain Basin Storage Filesystem
//! Why: In-memory filesystem for kernel file I/O operations.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

/// Maximum file size (bytes).
/// Why: Bounded file size for safety and static allocation.
pub const MAX_FILE_SIZE: u32 = 64 * 1024; // 64KB

/// Maximum file name length (bytes, including null terminator).
/// Why: Bounded file name length for safety.
pub const MAX_FILENAME_LEN: u32 = 256;

/// Maximum directory entries.
/// Why: Bounded directory size for safety and static allocation.
pub const MAX_DIR_ENTRIES: u32 = 64;

/// File entry in filesystem.
/// Why: Store file data and metadata.
/// Grain Style: Static allocation, bounded size.
pub const FileEntry = struct {
    /// File name (null-terminated).
    name: [MAX_FILENAME_LEN]u8,
    /// Name length (bytes, excluding null terminator).
    name_len: u32,
    /// File data (bounded size).
    data: [MAX_FILE_SIZE]u8,
    /// Data length (bytes, <= MAX_FILE_SIZE).
    data_len: u32,
    /// Whether file is allocated (in use).
    allocated: bool,
    
    /// Initialize empty file entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() FileEntry {
        return FileEntry{
            .name = [_]u8{0} ** MAX_FILENAME_LEN,
            .name_len = 0,
            .data = [_]u8{0} ** MAX_FILE_SIZE,
            .data_len = 0,
            .allocated = false,
        };
    }
    
    /// Set file name.
    /// Why: Update file name with validation.
    /// Contract: name must be non-empty, <= MAX_FILENAME_LEN-1.
    pub fn set_name(self: *FileEntry, name: []const u8) bool {
        // Assert: Name length must be > 0.
        if (name.len == 0) {
            return false; // Empty name
        }
        
        // Assert: Name length must be <= MAX_FILENAME_LEN-1 (leave room for null terminator).
        if (name.len >= MAX_FILENAME_LEN) {
            return false; // Name too long
        }
        
        // Copy name and null-terminate.
        @memcpy(self.name[0..name.len], name);
        self.name[name.len] = 0;
        self.name_len = @as(u32, @intCast(name.len));
        
        // Assert: Name must be set correctly.
        Debug.kassert(self.name_len == @as(u32, @intCast(name.len)), "Name len mismatch", .{});
        Debug.kassert(self.name[name.len] == 0, "Name not null-terminated", .{});
        
        return true;
    }
    
    /// Write data to file.
    /// Why: Update file contents.
    /// Contract: data must be <= MAX_FILE_SIZE.
    /// Returns: bytes written if successful, 0 if file full.
    pub fn write(self: *FileEntry, data: []const u8) u32 {
        // Assert: File must be allocated.
        Debug.kassert(self.allocated, "File not allocated", .{});
        
        // Assert: Data length must be <= MAX_FILE_SIZE.
        if (data.len > MAX_FILE_SIZE) {
            return 0; // Data too large
        }
        
        // Copy data to file.
        @memcpy(self.data[0..data.len], data);
        self.data_len = @as(u32, @intCast(data.len));
        
        // Assert: Data must be written correctly.
        Debug.kassert(self.data_len == @as(u32, @intCast(data.len)), "Data len mismatch", .{});
        Debug.kassert(self.data_len <= MAX_FILE_SIZE, "Data len > MAX", .{});
        
        return self.data_len;
    }
    
    /// Read data from file.
    /// Why: Get file contents.
    /// Contract: buffer must be >= MAX_FILE_SIZE.
    /// Returns: bytes read.
    pub fn read(self: *const FileEntry, buffer: []u8) u32 {
        // Assert: File must be allocated.
        Debug.kassert(self.allocated, "File not allocated", .{});
        
        // Assert: Buffer must be >= MAX_FILE_SIZE.
        Debug.kassert(buffer.len >= MAX_FILE_SIZE, "Buffer too small", .{});
        
        // Copy file data to buffer.
        const bytes_to_copy = @min(self.data_len, @as(u32, @intCast(buffer.len)));
        @memcpy(buffer[0..bytes_to_copy], self.data[0..bytes_to_copy]);
        
        // Assert: Bytes copied must be <= data_len.
        Debug.kassert(bytes_to_copy <= self.data_len, "Bytes copied > data_len", .{});
        
        return bytes_to_copy;
    }
    
    /// Get file size.
    /// Why: Query file size without reading.
    /// Contract: File must be allocated.
    pub fn get_size(self: *const FileEntry) u32 {
        // Assert: File must be allocated.
        Debug.kassert(self.allocated, "File not allocated", .{});
        
        // Assert: Data length must be <= MAX_FILE_SIZE.
        Debug.kassert(self.data_len <= MAX_FILE_SIZE, "Data len > MAX", .{});
        
        return self.data_len;
    }
};

/// Directory entry in filesystem.
/// Why: Store directory structure and file references.
/// Grain Style: Static allocation, bounded entries.
pub const DirectoryEntry = struct {
    /// Directory name (null-terminated).
    name: [MAX_FILENAME_LEN]u8,
    /// Name length (bytes, excluding null terminator).
    name_len: u32,
    /// File indices (references to FileEntry array).
    file_indices: [MAX_DIR_ENTRIES]u32,
    /// Number of files in directory.
    file_count: u32,
    /// Whether directory is allocated (in use).
    allocated: bool,
    
    /// Initialize empty directory entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() DirectoryEntry {
        return DirectoryEntry{
            .name = [_]u8{0} ** MAX_FILENAME_LEN,
            .name_len = 0,
            .file_indices = [_]u32{0} ** MAX_DIR_ENTRIES,
            .file_count = 0,
            .allocated = false,
        };
    }
    
    /// Set directory name.
    /// Why: Update directory name with validation.
    /// Contract: name must be non-empty, <= MAX_FILENAME_LEN-1.
    pub fn set_name(self: *DirectoryEntry, name: []const u8) bool {
        // Assert: Name length must be > 0.
        if (name.len == 0) {
            return false; // Empty name
        }
        
        // Assert: Name length must be <= MAX_FILENAME_LEN-1.
        if (name.len >= MAX_FILENAME_LEN) {
            return false; // Name too long
        }
        
        // Copy name and null-terminate.
        @memcpy(self.name[0..name.len], name);
        self.name[name.len] = 0;
        self.name_len = @as(u32, @intCast(name.len));
        
        // Assert: Name must be set correctly.
        Debug.kassert(self.name_len == @as(u32, @intCast(name.len)), "Name len mismatch", .{});
        
        return true;
    }
    
    /// Add file to directory.
    /// Why: Track file in directory.
    /// Contract: file_index must be valid, directory must not be full.
    /// Returns: true if added, false if directory full.
    pub fn add_file(self: *DirectoryEntry, file_index: u32) bool {
        // Assert: Directory must be allocated.
        Debug.kassert(self.allocated, "Directory not allocated", .{});
        
        // Assert: File index must be valid (non-zero).
        Debug.kassert(file_index != 0, "File index is 0", .{});
        
        // Check if directory is full.
        if (self.file_count >= MAX_DIR_ENTRIES) {
            return false; // Directory full
        }
        
        // Add file index.
        self.file_indices[self.file_count] = file_index;
        self.file_count += 1;
        
        // Assert: File count must be <= MAX_DIR_ENTRIES.
        Debug.kassert(self.file_count <= MAX_DIR_ENTRIES, "File count > MAX", .{});
        
        return true;
    }
    
    /// Get file count.
    /// Why: Query number of files in directory.
    /// Contract: Directory must be allocated.
    pub fn get_file_count(self: *const DirectoryEntry) u32 {
        // Assert: Directory must be allocated.
        Debug.kassert(self.allocated, "Directory not allocated", .{});
        
        // Assert: File count must be <= MAX_DIR_ENTRIES.
        Debug.kassert(self.file_count <= MAX_DIR_ENTRIES, "File count > MAX", .{});
        
        return self.file_count;
    }
};

/// Storage filesystem for kernel.
/// Why: Manage files and directories for file I/O syscalls.
/// Grain Style: Static allocation, bounded tables.
pub const Storage = struct {
    /// File table (static allocation).
    files: [128]FileEntry,
    /// Number of allocated files.
    file_count: u32,
    /// Next file index (starts at 1, 0 is invalid).
    next_file_index: u32,
    
    /// Directory table (static allocation).
    directories: [32]DirectoryEntry,
    /// Number of allocated directories.
    directory_count: u32,
    /// Next directory index (starts at 1, 0 is invalid).
    next_directory_index: u32,
    
    /// Initialize storage filesystem.
    /// Why: Set up filesystem state.
    pub fn init() Storage {
        return Storage{
            .files = [_]FileEntry{FileEntry.init()} ** 128,
            .file_count = 0,
            .next_file_index = 1,
            .directories = [_]DirectoryEntry{DirectoryEntry.init()} ** 32,
            .directory_count = 0,
            .next_directory_index = 1,
        };
    }
    
    /// Create file.
    /// Why: Allocate file entry for new file.
    /// Contract: name must be non-empty, <= MAX_FILENAME_LEN-1.
    /// Returns: File index if created, 0 if table full or invalid name.
    pub fn create_file(self: *Storage, name: []const u8) u32 {
        // Assert: Name must be non-empty.
        if (name.len == 0) {
            return 0; // Empty name
        }
        
        // Assert: File count must be < max files.
        Debug.kassert(self.file_count < 128, "File table full", .{});
        
        // Find free file slot.
        var slot: ?u32 = null;
        for (0..128) |i| {
            if (!self.files[i].allocated) {
                slot = @as(u32, @intCast(i));
                break;
            }
        }
        
        if (slot == null) {
            return 0; // No free slot
        }
        
        const idx = slot.?;
        
        // Set file name.
        const name_set = self.files[idx].set_name(name);
        if (!name_set) {
            return 0; // Invalid name
        }
        
        // Allocate file.
        self.files[idx].allocated = true;
        self.files[idx].data_len = 0;
        self.file_count += 1;
        
        // Assert: File must be allocated.
        Debug.kassert(self.files[idx].allocated, "File not allocated", .{});
        Debug.kassert(self.files[idx].name_len > 0, "File name not set", .{});
        
        // Return file index (1-based).
        const file_index = self.next_file_index;
        self.next_file_index += 1;
        
        return file_index;
    }
    
    /// Find file by name.
    /// Why: Look up file for read/write operations.
    /// Contract: name must be non-empty.
    /// Returns: File index if found, 0 if not found.
    pub fn find_file(self: *const Storage, name: []const u8) u32 {
        // Assert: Name must be non-empty.
        if (name.len == 0) {
            return 0; // Empty name
        }
        
        // Search for file by name.
        for (0..128) |i| {
            if (self.files[i].allocated) {
                // Compare names.
                if (self.files[i].name_len == @as(u32, @intCast(name.len))) {
                    if (std.mem.eql(u8, self.files[i].name[0..self.files[i].name_len], name)) {
                        // Assert: File must be allocated.
                        Debug.kassert(self.files[i].allocated, "File not allocated", .{});
                        
                        // Return file index (1-based, using array index + 1).
                        return @as(u32, @intCast(i)) + 1;
                    }
                }
            }
        }
        
        return 0; // Not found
    }
    
    /// Get file by index.
    /// Why: Access file entry by index.
    /// Contract: file_index must be valid (1-based, 0 is invalid).
    /// Returns: File entry pointer if found, null otherwise.
    pub fn get_file(self: *Storage, file_index: u32) ?*FileEntry {
        // Assert: File index must be valid (non-zero, within bounds).
        if (file_index == 0) {
            return null; // Invalid index
        }
        
        const idx = file_index - 1; // Convert to 0-based
        if (idx >= 128) {
            return null; // Out of bounds
        }
        
        if (!self.files[idx].allocated) {
            return null; // Not allocated
        }
        
        // Assert: File must be allocated.
        Debug.kassert(self.files[idx].allocated, "File not allocated", .{});
        
        return &self.files[idx];
    }
    
    /// Delete file.
    /// Why: Remove file from filesystem.
    /// Contract: file_index must be valid.
    /// Returns: true if deleted, false if not found.
    pub fn delete_file(self: *Storage, file_index: u32) bool {
        // Assert: File index must be valid (non-zero).
        if (file_index == 0) {
            return false; // Invalid index
        }
        
        const idx = file_index - 1; // Convert to 0-based
        if (idx >= 128) {
            return false; // Out of bounds
        }
        
        if (!self.files[idx].allocated) {
            return false; // Not allocated
        }
        
        // Clear file entry.
        self.files[idx].allocated = false;
        self.files[idx].name_len = 0;
        self.files[idx].data_len = 0;
        self.file_count -= 1;
        
        // Assert: File must be cleared.
        Debug.kassert(!self.files[idx].allocated, "File still allocated", .{});
        Debug.kassert(self.files[idx].name_len == 0, "File name not cleared", .{});
        
        return true;
    }
    
    /// Create directory.
    /// Why: Allocate directory entry for new directory.
    /// Contract: name must be non-empty, <= MAX_FILENAME_LEN-1.
    /// Returns: Directory index if created, 0 if table full or invalid name.
    pub fn create_directory(self: *Storage, name: []const u8) u32 {
        // Assert: Name must be non-empty.
        if (name.len == 0) {
            return 0; // Empty name
        }
        
        // Assert: Directory count must be < max directories.
        Debug.kassert(self.directory_count < 32, "Directory table full", .{});
        
        // Find free directory slot.
        var slot: ?u32 = null;
        for (0..32) |i| {
            if (!self.directories[i].allocated) {
                slot = @as(u32, @intCast(i));
                break;
            }
        }
        
        if (slot == null) {
            return 0; // No free slot
        }
        
        const idx = slot.?;
        
        // Set directory name.
        const name_set = self.directories[idx].set_name(name);
        if (!name_set) {
            return 0; // Invalid name
        }
        
        // Allocate directory.
        self.directories[idx].allocated = true;
        self.directories[idx].file_count = 0;
        self.directory_count += 1;
        
        // Assert: Directory must be allocated.
        Debug.kassert(self.directories[idx].allocated, "Directory not allocated", .{});
        Debug.kassert(self.directories[idx].name_len > 0, "Directory name not set", .{});
        
        // Return directory index (1-based).
        const dir_index = self.next_directory_index;
        self.next_directory_index += 1;
        
        return dir_index;
    }
    
    /// Get file count.
    /// Why: Query number of allocated files.
    pub fn get_file_count(self: *const Storage) u32 {
        // Assert: File count must be <= 128.
        Debug.kassert(self.file_count <= 128, "File count > 128", .{});
        
        return self.file_count;
    }
    
    /// Get directory count.
    /// Why: Query number of allocated directories.
    pub fn get_directory_count(self: *const Storage) u32 {
        // Assert: Directory count must be <= 32.
        Debug.kassert(self.directory_count <= 32, "Directory count > 32", .{});
        
        return self.directory_count;
    }
};

// Test storage initialization.
test "storage init" {
    const storage = Storage.init();
    
    // Assert: Storage must be initialized.
    try std.testing.expect(storage.file_count == 0);
    try std.testing.expect(storage.directory_count == 0);
    try std.testing.expect(storage.next_file_index == 1);
    try std.testing.expect(storage.next_directory_index == 1);
}

// Test file creation.
test "storage create file" {
    var storage = Storage.init();
    
    const file_index = storage.create_file("test.txt");
    
    // Assert: File must be created.
    try std.testing.expect(file_index != 0);
    try std.testing.expect(storage.file_count == 1);
    
    const file = storage.get_file(file_index);
    
    // Assert: File must be found.
    try std.testing.expect(file != null);
    try std.testing.expect(file.?.allocated);
}

// Test file write and read.
test "storage file write read" {
    var storage = Storage.init();
    
    const file_index = storage.create_file("test.txt");
    try std.testing.expect(file_index != 0);
    
    const file = storage.get_file(file_index);
    try std.testing.expect(file != null);
    
    const data = "Hello, World!";
    const written = file.?.write(data);
    
    // Assert: Data must be written.
    try std.testing.expect(written == data.len);
    try std.testing.expect(file.?.get_size() == data.len);
    
    var buffer: [MAX_FILE_SIZE]u8 = undefined;
    const read = file.?.read(&buffer);
    
    // Assert: Data must be read correctly.
    try std.testing.expect(read == data.len);
    try std.testing.expect(std.mem.eql(u8, buffer[0..read], data));
}

// Test file find.
test "storage find file" {
    var storage = Storage.init();
    
    const file_index = storage.create_file("test.txt");
    try std.testing.expect(file_index != 0);
    
    const found = storage.find_file("test.txt");
    
    // Assert: File must be found.
    try std.testing.expect(found == file_index);
    
    const not_found = storage.find_file("nonexistent.txt");
    
    // Assert: Non-existent file must not be found.
    try std.testing.expect(not_found == 0);
}

// Test file delete.
test "storage delete file" {
    var storage = Storage.init();
    
    const file_index = storage.create_file("test.txt");
    try std.testing.expect(file_index != 0);
    try std.testing.expect(storage.file_count == 1);
    
    const deleted = storage.delete_file(file_index);
    
    // Assert: File must be deleted.
    try std.testing.expect(deleted);
    try std.testing.expect(storage.file_count == 0);
    
    const file = storage.get_file(file_index);
    
    // Assert: File must not be found after deletion.
    try std.testing.expect(file == null);
}

// Test directory creation.
test "storage create directory" {
    var storage = Storage.init();
    
    const dir_index = storage.create_directory("test_dir");
    
    // Assert: Directory must be created.
    try std.testing.expect(dir_index != 0);
    try std.testing.expect(storage.directory_count == 1);
}

