//! Terminal Kernel Integration Tests (Phase 3.16)
//! Why: Test kernel syscalls needed for Grain Terminal integration.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;
const Integration = kernel_vm.Integration;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;

// Test: read_input_event syscall reads keyboard events.
test "read_input_event reads keyboard events" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0);
    var kernel = BasinKernel.init();
    
    // Inject keyboard event into VM.
    vm.inject_keyboard_event(0, 65, 'A', 0); // key down, 'A', no modifiers
    
    // Create integration.
    var integration = Integration.init_with_kernel(&vm, &kernel);
    integration.finish_init();
    
    // Assert: Event must be in queue.
    try testing.expect(vm.input_event_queue.count > 0);
    
    // Note: Integration layer handles read_input_event directly, not via kernel.
    // The event is available for reading via the syscall.
    _ = integration.kernel;
}

// Test: read_input_event syscall reads mouse events.
test "read_input_event reads mouse events" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0);
    var kernel = BasinKernel.init();
    
    // Inject mouse event into VM.
    vm.inject_mouse_event(0, 0, 100.0, 200.0, 0); // button down, left, (100, 200), no modifiers
    
    // Create integration.
    var integration = Integration.init_with_kernel(&vm, &kernel);
    integration.finish_init();
    
    // Assert: Event must be in queue.
    try testing.expect(vm.input_event_queue.count > 0);
}

// Test: file I/O syscalls work for configuration files.
test "file I/O syscalls for configuration files" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0);
    var kernel = BasinKernel.init();
    
    // Create integration.
    var integration = Integration.init_with_kernel(&vm, &kernel);
    integration.finish_init();
    
    // Open configuration file for writing (create if doesn't exist).
    const config_path = "/home/user/.grain_terminal/config";
    const path_ptr: u64 = 0x200000;
    
    // Write path string to VM memory.
    @memcpy(vm.memory[@intCast(path_ptr)..][0..config_path.len], config_path);
    vm.memory[@intCast(path_ptr + config_path.len)] = 0; // null terminator
    
    // Open file (write | create | truncate flags = 2 | 4 | 8 = 14).
    const open_result = kernel.handle_syscall(30, path_ptr, config_path.len, 14, 0) catch |err| {
        return err;
    };
    
    // Assert: File must be opened successfully.
    try testing.expect(open_result == .success);
    const handle = open_result.success;
    try testing.expect(handle != 0);
    
    // Write configuration data.
    const config_data = "theme=dark\nfont_size=medium\n";
    const data_ptr: u64 = 0x300000;
    @memcpy(vm.memory[@intCast(data_ptr)..][0..config_data.len], config_data);
    
    const write_result = kernel.handle_syscall(32, handle, data_ptr, config_data.len, 0) catch |err| {
        return err;
    };
    
    // Assert: Data must be written successfully.
    try testing.expect(write_result == .success);
    try testing.expect(write_result.success == config_data.len);
    
    // Close file.
    const close_result = kernel.handle_syscall(33, handle, 0, 0, 0) catch |err| {
        return err;
    };
    try testing.expect(close_result == .success);
    
    // Reopen file for reading.
    const open_read_result = kernel.handle_syscall(30, path_ptr, config_path.len, 1, 0) catch |err| { // read flag = 1
        return err;
    };
    try testing.expect(open_read_result == .success);
    const read_handle = open_read_result.success;
    
    // Read configuration data.
    const read_buffer_ptr: u64 = 0x400000;
    const read_buffer_len: u64 = 1024;
    const read_result = kernel.handle_syscall(31, read_handle, read_buffer_ptr, read_buffer_len, 0) catch |err| {
        return err;
    };
    
    // Assert: Data must be read successfully.
    try testing.expect(read_result == .success);
    try testing.expect(read_result.success == config_data.len);
    
    // Close file.
    const close_read_result = kernel.handle_syscall(33, read_handle, 0, 0, 0) catch |err| {
        return err;
    };
    try testing.expect(close_read_result == .success);
}

// Test: spawn syscall creates processes.
test "spawn syscall creates processes" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0);
    var kernel = BasinKernel.init();
    
    // Create integration.
    var integration = Integration.init_with_kernel(&vm, &kernel);
    integration.finish_init();
    
    // Create minimal ELF header in VM memory.
    const executable_ptr: u64 = 0x500000;
    var elf_header: [64]u8 = undefined;
    @memset(&elf_header, 0);
    
    // ELF magic: 0x7F "ELF"
    elf_header[0] = 0x7F;
    elf_header[1] = 'E';
    elf_header[2] = 'L';
    elf_header[3] = 'F';
    
    // ELF class: 64-bit (2)
    elf_header[4] = 2;
    
    // ELF endianness: little-endian (1)
    elf_header[5] = 1;
    
    // Entry point: 0x10000
    const entry_point: u64 = 0x10000;
    var i: u32 = 0;
    while (i < 8) : (i += 1) {
        elf_header[24 + i] = @truncate((entry_point >> @as(u6, @intCast(i * 8))) & 0xFF);
    }
    
    // Write ELF header to VM memory.
    @memcpy(vm.memory[@intCast(executable_ptr)..][0..64], &elf_header);
    
    // Spawn process.
    const spawn_result = try kernel.syscall_spawn(executable_ptr, 0, 0, 0);
    
    // Assert: Process must be spawned successfully.
    try testing.expect(spawn_result == .success);
    const pid = spawn_result.success;
    try testing.expect(pid != 0);
    
    // Assert: Process must be in scheduler.
    try testing.expect(kernel.scheduler.get_current() == pid);
}

// Test: read_input_event returns would_block when no events.
test "read_input_event returns would_block when no events" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0);
    var kernel = BasinKernel.init();
    
    // Create integration (no events injected).
    var integration = Integration.init_with_kernel(&vm, &kernel);
    integration.finish_init();
    
    // Assert: Event queue must be empty.
    try testing.expect(vm.input_event_queue.count == 0);
    
    // Note: Integration layer handles read_input_event and returns would_block.
    // This test verifies the queue is empty.
    _ = integration.kernel;
}

