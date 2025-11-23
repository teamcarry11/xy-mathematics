//! Enhanced Process Execution Tests (Phase 3.13)
//! Why: Test ELF parsing and process context setup in syscall_spawn.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const BasinKernel = @import("basin_kernel").BasinKernel;
const BasinError = @import("basin_kernel").BasinError;
const ProcessContext = @import("process").ProcessContext;

// Test: syscall_spawn with valid ELF header.
test "syscall_spawn parses ELF header and sets up process context" {
    // Create kernel instance.
    var kernel = BasinKernel.init();
    
    // Create mock ELF header (valid RISC-V64 ELF).
    // Why: Test ELF parsing in syscall_spawn.
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
    
    // Entry point: 0x10000 (little-endian u64 at offset 24)
    const entry_point: u64 = 0x10000;
    var i: u32 = 0;
    while (i < 8) : (i += 1) {
        elf_header[24 + i] = @truncate((entry_point >> @as(u6, @intCast(i * 8))) & 0xFF);
    }
    
    // Create VM memory reader callback.
    // Why: Mock VM memory access for ELF parsing.
    const vm_memory_reader = struct {
        fn read(addr: u64, len: u32, buffer: []u8) ?u32 {
            _ = addr;
            if (len > buffer.len) {
                return null;
            }
            if (len > 64) {
                return null;
            }
            @memcpy(buffer[0..len], elf_header[0..len]);
            return len;
        }
    }.read;
    
    // Set VM memory reader in kernel.
    kernel.vm_memory_reader = vm_memory_reader;
    
    // Call syscall_spawn with ELF header address.
    const executable_ptr: u64 = 0x1000;
    const args_ptr: u64 = 0;
    const args_len: u64 = 0;
    const result = kernel.syscall_spawn(executable_ptr, args_ptr, args_len, 0);
    
    // Assert: syscall_spawn must succeed.
    try testing.expect(result == .success);
    
    // Assert: Process ID must be non-zero.
    const process_id = result.success;
    try testing.expect(process_id != 0);
    
    // Find process in process table.
    var process_found = false;
    var process_idx: ?usize = null;
    for (0..16) |i| {
        if (kernel.processes[i].allocated and kernel.processes[i].id == process_id) {
            process_found = true;
            process_idx = i;
            break;
        }
    }
    
    // Assert: Process must be found.
    try testing.expect(process_found);
    try testing.expect(process_idx != null);
    
    const idx = process_idx.?;
    const process = &kernel.processes[idx];
    
    // Assert: Process must have correct entry point.
    try testing.expect(process.entry_point == entry_point);
    
    // Assert: Process must have stack pointer.
    const DEFAULT_STACK_POINTER: u64 = 0x3ff000;
    try testing.expect(process.stack_pointer == DEFAULT_STACK_POINTER);
    
    // Assert: Process must have context.
    try testing.expect(process.context != null);
    
    if (process.context) |ctx| {
        // Assert: Context must be initialized.
        try testing.expect(ctx.initialized);
        
        // Assert: Context must have correct PC.
        try testing.expect(ctx.pc == entry_point);
        
        // Assert: Context must have correct SP.
        try testing.expect(ctx.sp == DEFAULT_STACK_POINTER);
        
        // Assert: Context must have correct entry point.
        try testing.expect(ctx.entry_point == entry_point);
    }
}

// Test: syscall_spawn with invalid ELF header.
test "syscall_spawn rejects invalid ELF header" {
    // Create kernel instance.
    var kernel = BasinKernel.init();
    
    // Create invalid ELF header (wrong magic).
    var invalid_elf_header: [64]u8 = undefined;
    @memset(&invalid_elf_header, 0);
    invalid_elf_header[0] = 0x00; // Invalid magic
    
    // Create VM memory reader callback.
    const vm_memory_reader = struct {
        fn read(addr: u64, len: u32, buffer: []u8) ?u32 {
            _ = addr;
            if (len > buffer.len) {
                return null;
            }
            if (len > 64) {
                return null;
            }
            @memcpy(buffer[0..len], invalid_elf_header[0..len]);
            return len;
        }
    }.read;
    
    // Set VM memory reader in kernel.
    kernel.vm_memory_reader = vm_memory_reader;
    
    // Call syscall_spawn with invalid ELF header.
    const executable_ptr: u64 = 0x1000;
    const args_ptr: u64 = 0;
    const args_len: u64 = 0;
    const result = kernel.syscall_spawn(executable_ptr, args_ptr, args_len, 0);
    
    // Assert: syscall_spawn must fail with invalid_argument.
    try testing.expect(result == .failure);
    try testing.expect(result.failure == BasinError.invalid_argument);
}

// Test: syscall_spawn without VM memory reader (backward compatibility).
test "syscall_spawn works without VM memory reader" {
    // Create kernel instance (no VM memory reader).
    var kernel = BasinKernel.init();
    
    // Call syscall_spawn without VM memory reader.
    const executable_ptr: u64 = 0x1000;
    const args_ptr: u64 = 0;
    const args_len: u64 = 0;
    const result = kernel.syscall_spawn(executable_ptr, args_ptr, args_len, 0);
    
    // Assert: syscall_spawn must succeed (backward compatibility).
    try testing.expect(result == .success);
    
    // Assert: Process ID must be non-zero.
    const process_id = result.success;
    try testing.expect(process_id != 0);
    
    // Find process in process table.
    var process_found = false;
    var process_idx: ?usize = null;
    for (0..16) |i| {
        if (kernel.processes[i].allocated and kernel.processes[i].id == process_id) {
            process_found = true;
            process_idx = i;
            break;
        }
    }
    
    // Assert: Process must be found.
    try testing.expect(process_found);
    try testing.expect(process_idx != null);
    
    const idx = process_idx.?;
    const process = &kernel.processes[idx];
    
    // Assert: Process must have entry point (stub value).
    try testing.expect(process.entry_point == executable_ptr);
    
    // Assert: Process must have stack pointer.
    const DEFAULT_STACK_POINTER: u64 = 0x3ff000;
    try testing.expect(process.stack_pointer == DEFAULT_STACK_POINTER);
    
    // Assert: Process must have context.
    try testing.expect(process.context != null);
}

// Test: syscall_spawn with multiple processes.
test "syscall_spawn creates multiple processes with different contexts" {
    // Create kernel instance.
    var kernel = BasinKernel.init();
    
    // Create mock ELF headers with different entry points.
    var elf_header_1: [64]u8 = undefined;
    var elf_header_2: [64]u8 = undefined;
    @memset(&elf_header_1, 0);
    @memset(&elf_header_2, 0);
    
    // ELF magic and format.
    elf_header_1[0] = 0x7F;
    elf_header_1[1] = 'E';
    elf_header_1[2] = 'L';
    elf_header_1[3] = 'F';
    elf_header_1[4] = 2;
    elf_header_1[5] = 1;
    
    elf_header_2[0] = 0x7F;
    elf_header_2[1] = 'E';
    elf_header_2[2] = 'L';
    elf_header_2[3] = 'F';
    elf_header_2[4] = 2;
    elf_header_2[5] = 1;
    
    // Entry points: 0x10000 and 0x20000
    const entry_point_1: u64 = 0x10000;
    const entry_point_2: u64 = 0x20000;
    
    var i: u32 = 0;
    while (i < 8) : (i += 1) {
        elf_header_1[24 + i] = @truncate((entry_point_1 >> @as(u6, @intCast(i * 8))) & 0xFF);
        elf_header_2[24 + i] = @truncate((entry_point_2 >> @as(u6, @intCast(i * 8))) & 0xFF);
    }
    
    // Create VM memory reader callback (returns different headers based on address).
    const vm_memory_reader = struct {
        fn read(addr: u64, len: u32, buffer: []u8) ?u32 {
            if (len > buffer.len) {
                return null;
            }
            if (len > 64) {
                return null;
            }
            if (addr == 0x1000) {
                @memcpy(buffer[0..len], elf_header_1[0..len]);
            } else if (addr == 0x2000) {
                @memcpy(buffer[0..len], elf_header_2[0..len]);
            } else {
                return null;
            }
            return len;
        }
    }.read;
    
    // Set VM memory reader in kernel.
    kernel.vm_memory_reader = vm_memory_reader;
    
    // Spawn first process.
    const result1 = kernel.syscall_spawn(0x1000, 0, 0, 0);
    try testing.expect(result1 == .success);
    const process_id_1 = result1.success;
    
    // Spawn second process.
    const result2 = kernel.syscall_spawn(0x2000, 0, 0, 0);
    try testing.expect(result2 == .success);
    const process_id_2 = result2.success;
    
    // Assert: Process IDs must be different.
    try testing.expect(process_id_1 != process_id_2);
    
    // Find processes in process table.
    var process_1: ?*BasinKernel.Process = null;
    var process_2: ?*BasinKernel.Process = null;
    
    for (0..16) |i| {
        if (kernel.processes[i].allocated) {
            if (kernel.processes[i].id == process_id_1) {
                process_1 = &kernel.processes[i];
            } else if (kernel.processes[i].id == process_id_2) {
                process_2 = &kernel.processes[i];
            }
        }
    }
    
    // Assert: Both processes must be found.
    try testing.expect(process_1 != null);
    try testing.expect(process_2 != null);
    
    const p1 = process_1.?;
    const p2 = process_2.?;
    
    // Assert: Processes must have different entry points.
    try testing.expect(p1.entry_point == entry_point_1);
    try testing.expect(p2.entry_point == entry_point_2);
    
    // Assert: Processes must have different contexts.
    try testing.expect(p1.context != null);
    try testing.expect(p2.context != null);
    
    if (p1.context) |ctx1| {
        if (p2.context) |ctx2| {
            // Assert: Contexts must have different PCs.
            try testing.expect(ctx1.pc == entry_point_1);
            try testing.expect(ctx2.pc == entry_point_2);
        }
    }
}

