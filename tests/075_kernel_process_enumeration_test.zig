//! Tests for process enumeration syscall.
//! Why: Verify kernel can enumerate processes for Grain OS integration.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");

test "process enumeration syscall" {
    var kernel = basin_kernel.BasinKernel.init();
    defer kernel.deinit();
    
    // Create a test process by spawning (simplified - just test the syscall interface).
    // Note: Actual process spawning requires ELF loading, so we'll test the enumeration
    // interface with empty process table for now.
    
    // Test enumerate_processes with empty process table.
    const buffer_ptr: u64 = 0x1000; // Valid VM memory address
    const buffer_len: u64 = 1024; // Enough for multiple ProcessInfo structures
    const max_processes: u64 = 16;
    
    const result = kernel.syscall_enumerate_processes(buffer_ptr, buffer_len, max_processes, 0);
    
    // Should succeed even with empty process table.
    try testing.expect(result == .success);
    try testing.expect(result.success == 0); // No processes found
}

test "process enumeration with invalid buffer" {
    var kernel = basin_kernel.BasinKernel.init();
    defer kernel.deinit();
    
    // Test with null buffer pointer.
    const result1 = kernel.syscall_enumerate_processes(0, 1024, 16, 0);
    try testing.expect(result1 == .err);
    try testing.expect(result1.err == basin_kernel.BasinError.invalid_argument);
    
    // Test with buffer too small.
    const buffer_ptr: u64 = 0x1000;
    const PROCESS_INFO_SIZE: u64 = 32;
    const result2 = kernel.syscall_enumerate_processes(buffer_ptr, PROCESS_INFO_SIZE - 1, 16, 0);
    try testing.expect(result2 == .err);
    try testing.expect(result2.err == basin_kernel.BasinError.invalid_argument);
}

test "get process info syscall" {
    var kernel = basin_kernel.BasinKernel.init();
    defer kernel.deinit();
    
    // Test with invalid process ID.
    const info_ptr: u64 = 0x1000;
    const result1 = kernel.syscall_get_process_info(0, info_ptr, 0, 0);
    try testing.expect(result1 == .err);
    try testing.expect(result1.err == basin_kernel.BasinError.invalid_argument);
    
    // Test with non-existent process.
    const result2 = kernel.syscall_get_process_info(999, info_ptr, 0, 0);
    try testing.expect(result2 == .err);
    try testing.expect(result2.err == basin_kernel.BasinError.not_found);
    
    // Test with null info pointer.
    const result3 = kernel.syscall_get_process_info(1, 0, 0, 0);
    try testing.expect(result3 == .err);
    try testing.expect(result3.err == basin_kernel.BasinError.invalid_argument);
}

test "process info structure layout" {
    // Verify ProcessInfo structure size and layout.
    const info = basin_kernel.ProcessInfo.init();
    
    // Structure should be 32 bytes:
    // pid: u32 (4) + parent_pid: u32 (4) + state: u8 (1) + padding (3) = 12
    // cpu_time_ns: u64 (8) = 20 (but u64 alignment means offset 16)
    // memory_used: u64 (8) = 28 (but u64 alignment means offset 24)
    // Total: 32 bytes with padding
    
    try testing.expect(@sizeOf(basin_kernel.ProcessInfo) == 32);
    try testing.expect(info.pid == 0);
    try testing.expect(info.parent_pid == 0);
    try testing.expect(info.state == 0);
    try testing.expect(info.cpu_time_ns == 0);
    try testing.expect(info.memory_used == 0);
}

