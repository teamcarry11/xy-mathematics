//! File System Integration Test
//! Why: Verify file system operations work end-to-end with VM integration.
//! Grain Style: Explicit types (u32/u64), comprehensive assertions, bounded allocations.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.basin_kernel.BasinKernel;
const BasinError = basin_kernel.basin_kernel.BasinError;
const Syscall = basin_kernel.basin_kernel.Syscall;
const RawIO = basin_kernel.basin_kernel.RawIO;

// Test: File system operations with VM integration.
test "file system integration: open write read close" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    // Set up VM memory.
    var vm_memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024);
    var kernel = BasinKernel.init();
    
    // Create VM memory reader/writer.
    const VmAccess = struct {
        threadlocal var mem: *[4 * 1024 * 1024]u8 = undefined;
        fn read(addr: u64, len: u32, buffer: []u8) ?u32 {
            const mem_ptr = mem;
            if (addr + len > mem_ptr.len) return null;
            @memcpy(buffer[0..len], mem_ptr[@intCast(addr)..][0..len]);
            return len;
        }
        fn write(addr: u64, len: u32, data: []const u8) ?u32 {
            const mem_ptr = mem;
            if (addr + len > mem_ptr.len) return null;
            @memcpy(mem_ptr[@intCast(addr)..][0..len], data[0..len]);
            return len;
        }
    };
    VmAccess.mem = &vm_memory;
    
    kernel.vm_memory_reader = VmAccess.read;
    kernel.vm_memory_writer = VmAccess.write;
    
    // Set up process.
    const process_id: u64 = 1;
    const process_idx: u32 = 0;
    
    kernel.processes[process_idx].id = process_id;
    kernel.processes[process_idx].state = .running;
    kernel.processes[process_idx].allocated = true;
    kernel.scheduler.set_current(process_id);
    
    // Test 1: Open file for writing (create if doesn't exist).
    const file_path = "test_file.txt";
    const path_ptr: u64 = 0x100000;
    @memcpy(vm_memory[@intCast(path_ptr)..][0..file_path.len], file_path);
    
    const open_flags: u64 = 0x6; // write (0x2) + create (0x4)
    const open_result = try kernel.handle_syscall(
        @intFromEnum(Syscall.open),
        path_ptr,
        @as(u64, @intCast(file_path.len)),
        open_flags,
        0, // mode (not used)
    );
    
    // Assert: File must be opened successfully.
    try testing.expect(open_result == .success);
    const handle = open_result.success;
    try testing.expect(handle > 0);
    
    // Test 2: Write data to file.
    const write_data = "Hello, Grain OS!";
    const data_ptr: u64 = 0x200000;
    @memcpy(vm_memory[@intCast(data_ptr)..][0..write_data.len], write_data);
    
    const write_result = try kernel.handle_syscall(
        @intFromEnum(Syscall.write),
        handle,
        data_ptr,
        @as(u64, @intCast(write_data.len)),
        0, // offset (not used)
    );
    
    // Assert: Data must be written successfully.
    try testing.expect(write_result == .success);
    try testing.expect(write_result.success == write_data.len);
    
    // Test 3: Read data from file.
    const read_buffer_ptr: u64 = 0x300000;
    const read_buffer_len: u64 = 4096;
    
    const read_result = try kernel.handle_syscall(
        @intFromEnum(Syscall.read),
        handle,
        read_buffer_ptr,
        read_buffer_len,
        0, // offset (not used)
    );
    
    // Assert: Data must be read successfully.
    try testing.expect(read_result == .success);
    try testing.expect(read_result.success == write_data.len);
    
    // Verify data matches.
    var read_data: [4096]u8 = undefined;
    @memcpy(read_data[0..write_data.len], vm_memory[@intCast(read_buffer_ptr)..][0..write_data.len]);
    try testing.expect(std.mem.eql(u8, read_data[0..write_data.len], write_data));
    
    // Test 4: Close file.
    const close_result = try kernel.handle_syscall(
        @intFromEnum(Syscall.close),
        handle,
        0,
        0,
        0,
    );
    
    // Assert: File must be closed successfully.
    try testing.expect(close_result == .success);
}

// Test: Directory operations with VM integration.
test "file system integration: mkdir opendir readdir closedir" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    // Set up VM memory.
    var vm_memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024);
    var kernel = BasinKernel.init();
    
    // Create VM memory reader/writer.
    const VmAccess = struct {
        threadlocal var mem: *[4 * 1024 * 1024]u8 = undefined;
        fn read(addr: u64, len: u32, buffer: []u8) ?u32 {
            const mem_ptr = mem;
            if (addr + len > mem_ptr.len) return null;
            @memcpy(buffer[0..len], mem_ptr[@intCast(addr)..][0..len]);
            return len;
        }
        fn write(addr: u64, len: u32, data: []const u8) ?u32 {
            const mem_ptr = mem;
            if (addr + len > mem_ptr.len) return null;
            @memcpy(mem_ptr[@intCast(addr)..][0..len], data[0..len]);
            return len;
        }
    };
    VmAccess.mem = &vm_memory;
    
    kernel.vm_memory_reader = VmAccess.read;
    kernel.vm_memory_writer = VmAccess.write;
    
    // Set up process.
    const process_id: u64 = 1;
    const process_idx: u32 = 0;
    
    kernel.processes[process_idx].id = process_id;
    kernel.processes[process_idx].state = .running;
    kernel.processes[process_idx].allocated = true;
    kernel.scheduler.set_current(process_id);
    
    // Test 1: Create directory.
    const dir_path = "test_dir";
    const dir_path_ptr: u64 = 0x100000;
    @memcpy(vm_memory[@intCast(dir_path_ptr)..][0..dir_path.len], dir_path);
    
    const mkdir_result = try kernel.handle_syscall(
        @intFromEnum(Syscall.mkdir),
        dir_path_ptr,
        @as(u64, @intCast(dir_path.len)),
        0, // mode (not used)
        0,
    );
    
    // Assert: Directory must be created successfully.
    try testing.expect(mkdir_result == .success);
    
    // Test 2: Open directory.
    const opendir_result = try kernel.handle_syscall(
        @intFromEnum(Syscall.opendir),
        dir_path_ptr,
        @as(u64, @intCast(dir_path.len)),
        0,
        0,
    );
    
    // Assert: Directory must be opened successfully.
    try testing.expect(opendir_result == .success);
    const dir_handle = opendir_result.success;
    try testing.expect(dir_handle > 0);
    
    // Test 3: Read directory entry.
    const dirent_buffer_ptr: u64 = 0x200000;
    const dirent_buffer_len: u64 = 4096;
    
    const readdir_result = try kernel.handle_syscall(
        @intFromEnum(Syscall.readdir),
        dir_handle,
        dirent_buffer_ptr,
        dirent_buffer_len,
        0,
    );
    
    // Assert: Directory read must succeed (may return 0 if empty).
    try testing.expect(readdir_result == .success);
    
    // Test 4: Close directory.
    const closedir_result = try kernel.handle_syscall(
        @intFromEnum(Syscall.closedir),
        dir_handle,
        0,
        0,
        0,
    );
    
    // Assert: Directory must be closed successfully.
    try testing.expect(closedir_result == .success);
}

// Test: File rename and unlink operations with VM integration.
test "file system integration: rename unlink" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    // Set up VM memory.
    var vm_memory: [4 * 1024 * 1024]u8 = [_]u8{0} ** (4 * 1024 * 1024);
    var kernel = BasinKernel.init();
    
    // Create VM memory reader/writer.
    const VmAccess = struct {
        threadlocal var mem: *[4 * 1024 * 1024]u8 = undefined;
        fn read(addr: u64, len: u32, buffer: []u8) ?u32 {
            const mem_ptr = mem;
            if (addr + len > mem_ptr.len) return null;
            @memcpy(buffer[0..len], mem_ptr[@intCast(addr)..][0..len]);
            return len;
        }
        fn write(addr: u64, len: u32, data: []const u8) ?u32 {
            const mem_ptr = mem;
            if (addr + len > mem_ptr.len) return null;
            @memcpy(mem_ptr[@intCast(addr)..][0..len], data[0..len]);
            return len;
        }
    };
    VmAccess.mem = &vm_memory;
    
    kernel.vm_memory_reader = VmAccess.read;
    kernel.vm_memory_writer = VmAccess.write;
    
    // Set up process.
    const process_id: u64 = 1;
    const process_idx: u32 = 0;
    
    kernel.processes[process_idx].id = process_id;
    kernel.processes[process_idx].state = .running;
    kernel.processes[process_idx].allocated = true;
    kernel.scheduler.set_current(process_id);
    
    // Test 1: Create file.
    const old_path = "old_file.txt";
    const old_path_ptr: u64 = 0x100000;
    @memcpy(vm_memory[@intCast(old_path_ptr)..][0..old_path.len], old_path);
    
    const open_flags: u64 = 0x6; // write (0x2) + create (0x4)
    const open_result = try kernel.handle_syscall(
        @intFromEnum(Syscall.open),
        old_path_ptr,
        @as(u64, @intCast(old_path.len)),
        open_flags,
        0, // mode (not used)
    );
    
    // Assert: File must be opened successfully.
    try testing.expect(open_result == .success);
    const handle = open_result.success;
    
    // Close file.
    _ = try kernel.handle_syscall(
        @intFromEnum(Syscall.close),
        handle,
        0,
        0,
        0,
    );
    
    // Test 2: Rename file.
    const new_path = "new_file.txt";
    const new_path_ptr: u64 = 0x200000;
    @memcpy(vm_memory[@intCast(new_path_ptr)..][0..new_path.len], new_path);
    
    const rename_result = try kernel.handle_syscall(
        @intFromEnum(Syscall.rename),
        old_path_ptr,
        @as(u64, @intCast(old_path.len)),
        new_path_ptr,
        @as(u64, @intCast(new_path.len)),
    );
    
    // Assert: File must be renamed successfully.
    try testing.expect(rename_result == .success);
    
    // Test 3: Unlink (delete) file.
    const unlink_result = try kernel.handle_syscall(
        @intFromEnum(Syscall.unlink),
        new_path_ptr,
        @as(u64, @intCast(new_path.len)),
        0,
        0,
    );
    
    // Assert: File must be unlinked successfully.
    try testing.expect(unlink_result == .success);
}
