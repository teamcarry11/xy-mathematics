//! Storage Filesystem Tests
//! Why: Comprehensive TigerStyle tests for storage/filesystem functionality.
//! Grain Style: Explicit types (u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const Storage = basin_kernel.basin_kernel.Storage;
const FileEntry = basin_kernel.basin_kernel.FileEntry;
const DirectoryEntry = basin_kernel.basin_kernel.DirectoryEntry;
const MAX_FILE_SIZE = basin_kernel.basin_kernel.MAX_FILE_SIZE;

// Test storage initialization.
test "storage init" {
    const storage_instance = Storage.init();
    
    // Assert: Storage must be initialized.
    try std.testing.expect(storage_instance.file_count == 0);
    try std.testing.expect(storage_instance.directory_count == 0);
    try std.testing.expect(storage_instance.next_file_index == 1);
    try std.testing.expect(storage_instance.next_directory_index == 1);
}

// Test file creation.
test "storage create file" {
    var storage_instance = Storage.init();
    
    const file_index = storage_instance.create_file("test.txt");
    
    // Assert: File must be created.
    try std.testing.expect(file_index != 0);
    try std.testing.expect(storage_instance.file_count == 1);
    
    const file = storage_instance.get_file(file_index);
    
    // Assert: File must be found.
    try std.testing.expect(file != null);
    try std.testing.expect(file.?.allocated);
    try std.testing.expect(file.?.name_len > 0);
}

// Test file write and read.
test "storage file write read" {
    var storage_instance = Storage.init();
    
    const file_index = storage_instance.create_file("test.txt");
    try std.testing.expect(file_index != 0);
    
    const file = storage_instance.get_file(file_index);
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
    var storage_instance = Storage.init();
    
    const file_index = storage_instance.create_file("test.txt");
    try std.testing.expect(file_index != 0);
    
    const found = storage_instance.find_file("test.txt");
    
    // Assert: File must be found.
    try std.testing.expect(found == file_index);
    
    const not_found = storage_instance.find_file("nonexistent.txt");
    
    // Assert: Non-existent file must not be found.
    try std.testing.expect(not_found == 0);
}

// Test file delete.
test "storage delete file" {
    var storage_instance = Storage.init();
    
    const file_index = storage_instance.create_file("test.txt");
    try std.testing.expect(file_index != 0);
    try std.testing.expect(storage_instance.file_count == 1);
    
    const deleted = storage_instance.delete_file(file_index);
    
    // Assert: File must be deleted.
    try std.testing.expect(deleted);
    try std.testing.expect(storage_instance.file_count == 0);
    
    const file = storage_instance.get_file(file_index);
    
    // Assert: File must not be found after deletion.
    try std.testing.expect(file == null);
}

// Test directory creation.
test "storage create directory" {
    var storage_instance = Storage.init();
    
    const dir_index = storage_instance.create_directory("test_dir");
    
    // Assert: Directory must be created.
    try std.testing.expect(dir_index != 0);
    try std.testing.expect(storage_instance.directory_count == 1);
}

// Test multiple files.
test "storage multiple files" {
    var storage_instance = Storage.init();
    
    const file1 = storage_instance.create_file("file1.txt");
    const file2 = storage_instance.create_file("file2.txt");
    const file3 = storage_instance.create_file("file3.txt");
    
    // Assert: All files must be created with unique indices.
    try std.testing.expect(file1 != 0);
    try std.testing.expect(file2 != 0);
    try std.testing.expect(file3 != 0);
    try std.testing.expect(file1 != file2);
    try std.testing.expect(file2 != file3);
    try std.testing.expect(file1 != file3);
    try std.testing.expect(storage_instance.file_count == 3);
}

// Test file entry set name.
test "file entry set name" {
    var file = FileEntry.init();
    file.allocated = true;
    
    const name_set = file.set_name("test.txt");
    
    // Assert: Name must be set.
    try std.testing.expect(name_set);
    try std.testing.expect(file.name_len > 0);
}

// Test file entry write read.
test "file entry write read" {
    var file = FileEntry.init();
    file.allocated = true;
    
    const data = "Test data";
    const written = file.write(data);
    
    // Assert: Data must be written.
    try std.testing.expect(written == data.len);
    
    var buffer: [MAX_FILE_SIZE]u8 = undefined;
    const read = file.read(&buffer);
    
    // Assert: Data must be read correctly.
    try std.testing.expect(read == data.len);
    try std.testing.expect(std.mem.eql(u8, buffer[0..read], data));
}

// Test directory entry add file.
test "directory entry add file" {
    var dir = DirectoryEntry.init();
    dir.allocated = true;
    
    const added = dir.add_file(1);
    
    // Assert: File must be added.
    try std.testing.expect(added);
    try std.testing.expect(dir.file_count == 1);
    try std.testing.expect(dir.get_file_count() == 1);
}

// Test kernel storage integration.
test "kernel storage integration" {
    var kernel = BasinKernel.init();
    
    // Assert: Storage must be initialized.
    try std.testing.expect(kernel.storage.file_count == 0);
    try std.testing.expect(kernel.storage.directory_count == 0);
    
    // Create file via storage.
    const file_index = kernel.storage.create_file("test.txt");
    
    // Assert: File must be created.
    try std.testing.expect(file_index != 0);
    try std.testing.expect(kernel.storage.file_count == 1);
}

// Test storage file operations.
test "storage file operations" {
    var storage_instance = Storage.init();
    
    // Create file.
    const file_index = storage_instance.create_file("data.txt");
    try std.testing.expect(file_index != 0);
    
    // Write data.
    const file = storage_instance.get_file(file_index);
    try std.testing.expect(file != null);
    
    const data1 = "First line\n";
    const written1 = file.?.write(data1);
    try std.testing.expect(written1 == data1.len);
    
    // Read data.
    var buffer: [MAX_FILE_SIZE]u8 = undefined;
    const read1 = file.?.read(&buffer);
    try std.testing.expect(read1 == data1.len);
    try std.testing.expect(std.mem.eql(u8, buffer[0..read1], data1));
    
    // Overwrite data.
    const data2 = "Second line\n";
    const written2 = file.?.write(data2);
    try std.testing.expect(written2 == data2.len);
    
    // Read new data.
    const read2 = file.?.read(&buffer);
    try std.testing.expect(read2 == data2.len);
    try std.testing.expect(std.mem.eql(u8, buffer[0..read2], data2));
}

// Test storage directory operations.
test "storage directory operations" {
    var storage_instance = Storage.init();
    
    // Create directory.
    const dir_index = storage_instance.create_directory("docs");
    try std.testing.expect(dir_index != 0);
    try std.testing.expect(storage_instance.directory_count == 1);
    
    // Create files in directory.
    const file1 = storage_instance.create_file("file1.txt");
    const file2 = storage_instance.create_file("file2.txt");
    
    try std.testing.expect(file1 != 0);
    try std.testing.expect(file2 != 0);
    
    // Note: Directory file tracking would be implemented in full filesystem.
    // For now, we just verify directory creation works.
}

