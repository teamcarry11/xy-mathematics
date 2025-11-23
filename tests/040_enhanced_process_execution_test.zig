//! Enhanced Process Execution Tests (Phase 3.13)
//! Why: Test ELF parsing and process context setup in syscall_spawn.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const BasinKernel = @import("basin_kernel").BasinKernel;
const BasinError = @import("basin_kernel").BasinError;
const ProcessContext = @import("basin_kernel").ProcessContext;
const Process = @import("basin_kernel").Process;

// Thread-local storage for test headers (avoids capture issues).
threadlocal var test_header: [64]u8 = undefined;
threadlocal var test_header2: [64]u8 = undefined;

// Helper: Create test ELF header.
fn create_test_elf_header(entry_point: u64) [64]u8 {
    var h: [64]u8 = undefined;
    @memset(&h, 0);
    h[0] = 0x7F;
    h[1] = 'E';
    h[2] = 'L';
    h[3] = 'F';
    h[4] = 2; // 64-bit
    h[5] = 1; // little-endian
    // Entry point at offset 24
    var i: u32 = 0;
    while (i < 8) : (i += 1) {
        h[24 + i] = @truncate((entry_point >> @as(u6, @intCast(i * 8))) & 0xFF);
    }
    // Program header table offset at offset 32 (set to 64 = after header)
    const phoff: u64 = 64;
    i = 0;
    while (i < 8) : (i += 1) {
        h[32 + i] = @truncate((phoff >> @as(u6, @intCast(i * 8))) & 0xFF);
    }
    // Program header entry size at offset 54 (56 bytes for ELF64)
    const phentsize: u16 = 56;
    h[54] = @truncate(phentsize & 0xFF);
    h[55] = @truncate((phentsize >> 8) & 0xFF);
    // Program header count at offset 56 (0 for minimal test)
    h[56] = 0;
    h[57] = 0;
    return h;
}

// Test: syscall_spawn with valid ELF header.
test "syscall_spawn parses ELF header and sets up process context" {
    var kernel = BasinKernel.init();
    
    const entry_point: u64 = 0x10000;
    const elf_header = create_test_elf_header(entry_point);
    test_header = elf_header;
    
    const read_fn = struct {
        fn read(addr: u64, len: u32, buffer: []u8) ?u32 {
            _ = addr;
            if (len > buffer.len or len > 64) return null;
            @memcpy(buffer[0..len], test_header[0..len]);
            return len;
        }
    }.read;
    
    kernel.vm_memory_reader = read_fn;
    
    const result = kernel.syscall_spawn(0x1000, 0, 0, 0) catch {
        try testing.expect(false);
        return;
    };
    
    try testing.expect(result == .success);
    const process_id = result.success;
    try testing.expect(process_id != 0);
    
    var process_idx: ?usize = null;
    for (0..16) |idx| {
        if (kernel.processes[idx].allocated and kernel.processes[idx].id == process_id) {
            process_idx = idx;
            break;
        }
    }
    try testing.expect(process_idx != null);
    
    const process = &kernel.processes[process_idx.?];
    try testing.expect(process.entry_point == entry_point);
    try testing.expect(process.stack_pointer == 0x3ff000);
    try testing.expect(process.context != null);
    if (process.context) |ctx| {
        try testing.expect(ctx.pc == entry_point);
        try testing.expect(ctx.sp == 0x3ff000);
    }
}

// Test: syscall_spawn with invalid ELF header.
test "syscall_spawn rejects invalid ELF header" {
    var kernel = BasinKernel.init();
    
    var invalid_header: [64]u8 = undefined;
    @memset(&invalid_header, 0);
    invalid_header[0] = 0x00; // Invalid magic
    test_header = invalid_header;
    
    const read_fn = struct {
        fn read(addr: u64, len: u32, buffer: []u8) ?u32 {
            _ = addr;
            if (len > buffer.len or len > 64) return null;
            @memcpy(buffer[0..len], test_header[0..len]);
            return len;
        }
    }.read;
    
    kernel.vm_memory_reader = read_fn;
    
    const result = kernel.syscall_spawn(0x1000, 0, 0, 0);
    if (result) |res| {
        try testing.expect(res == .err);
        try testing.expect(res.err == BasinError.invalid_argument);
    } else |err| {
        try testing.expect(err == BasinError.invalid_argument);
    }
}

// Test: syscall_spawn without VM memory reader (backward compatibility).
test "syscall_spawn works without VM memory reader" {
    var kernel = BasinKernel.init();
    
    const result = kernel.syscall_spawn(0x1000, 0, 0, 0) catch {
        try testing.expect(false);
        return;
    };
    
    try testing.expect(result == .success);
    const process_id = result.success;
    try testing.expect(process_id != 0);
    
    var process_idx: ?usize = null;
    for (0..16) |idx| {
        if (kernel.processes[idx].allocated and kernel.processes[idx].id == process_id) {
            process_idx = idx;
            break;
        }
    }
    try testing.expect(process_idx != null);
    
    const process = &kernel.processes[process_idx.?];
    try testing.expect(process.entry_point == 0x1000); // Stub value
    try testing.expect(process.context != null);
}

// Test: syscall_spawn with multiple processes.
test "syscall_spawn creates multiple processes with different contexts" {
    var kernel = BasinKernel.init();
    
    const entry_point_1: u64 = 0x10000;
    const entry_point_2: u64 = 0x20000;
    test_header = create_test_elf_header(entry_point_1);
    test_header2 = create_test_elf_header(entry_point_2);
    
    const read_fn = struct {
        fn read(addr: u64, len: u32, buffer: []u8) ?u32 {
            if (len > buffer.len or len > 64) return null;
            if (addr == 0x1000) {
                @memcpy(buffer[0..len], test_header[0..len]);
            } else if (addr == 0x2000) {
                @memcpy(buffer[0..len], test_header2[0..len]);
            } else {
                return null;
            }
            return len;
        }
    }.read;
    
    kernel.vm_memory_reader = read_fn;
    
    const result1 = kernel.syscall_spawn(0x1000, 0, 0, 0) catch {
        try testing.expect(false);
        return;
    };
    try testing.expect(result1 == .success);
    const process_id_1 = result1.success;
    
    const result2 = kernel.syscall_spawn(0x2000, 0, 0, 0) catch {
        try testing.expect(false);
        return;
    };
    try testing.expect(result2 == .success);
    const process_id_2 = result2.success;
    
    try testing.expect(process_id_1 != process_id_2);
    
    var p1: ?*const Process = null;
    var p2: ?*const Process = null;
    for (0..16) |idx| {
        if (kernel.processes[idx].allocated) {
            if (kernel.processes[idx].id == process_id_1) {
                p1 = &kernel.processes[idx];
            } else if (kernel.processes[idx].id == process_id_2) {
                p2 = &kernel.processes[idx];
            }
        }
    }
    
    try testing.expect(p1 != null);
    try testing.expect(p2 != null);
    try testing.expect(p1.?.entry_point == entry_point_1);
    try testing.expect(p2.?.entry_point == entry_point_2);
}
