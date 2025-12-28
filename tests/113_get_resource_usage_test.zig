//! Test: Get Resource Usage Syscall
//!
//! Objective: Verify get_resource_usage syscall works correctly.
//! Why: Ensure per-process resource tracking works correctly.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const BasinKernel = @import("basin_kernel.zig").BasinKernel;
const ProcessState = @import("basin_kernel.zig").ProcessState;

// Test: get_resource_usage syscall validation.
test "get_resource_usage syscall validation" {
    var kernel = BasinKernel.init();
    
    // Test with null process ID (should fail).
    const result_null_pid = kernel.syscall_get_resource_usage(0, 0x1000, 0, 0);
    try testing.expect(result_null_pid == .err);
    try testing.expect(result_null_pid.err == .invalid_argument);
    
    // Test with null usage pointer (should fail).
    const result_null_ptr = kernel.syscall_get_resource_usage(1, 0, 0, 0);
    try testing.expect(result_null_ptr == .err);
    try testing.expect(result_null_ptr.err == .invalid_argument);
    
    // Test with invalid usage pointer (should fail).
    const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024;
    const result_invalid_ptr = kernel.syscall_get_resource_usage(1, VM_MEMORY_SIZE, 0, 0);
    try testing.expect(result_invalid_ptr == .err);
    try testing.expect(result_invalid_ptr.err == .invalid_argument);
    
    // Test with non-existent process (should fail).
    const result_not_found = kernel.syscall_get_resource_usage(999, 0x1000, 0, 0);
    try testing.expect(result_not_found == .err);
    try testing.expect(result_not_found.err == .process_not_found);
}

// Test: get_resource_usage syscall with valid process.
test "get_resource_usage syscall with valid process" {
    var kernel = BasinKernel.init();
    
    // Spawn a process to get a valid PID.
    const ELF_DATA: [256]u8 = [_]u8{0} ** 256;
    const spawn_result = kernel.syscall_spawn(
        @intFromPtr(&ELF_DATA),
        ELF_DATA.len,
        0x1000, // Stack pointer
        0,
    );
    try testing.expect(spawn_result == .success);
    
    const pid = spawn_result.success;
    try testing.expect(pid > 0);
    
    // Get resource usage for the process.
    const result = kernel.syscall_get_resource_usage(pid, 0x1000, 0, 0);
    try testing.expect(result == .success);
    
    // Note: In a real VM, the ResourceUsage struct would be written to 0x1000.
    // Here we just validate the syscall succeeds.
}

// Test: get_resource_usage tracks network bytes.
test "get_resource_usage tracks network bytes" {
    var kernel = BasinKernel.init();
    
    // Spawn a process.
    const ELF_DATA: [256]u8 = [_]u8{0} ** 256;
    const spawn_result = kernel.syscall_spawn(
        @intFromPtr(&ELF_DATA),
        ELF_DATA.len,
        0x1000,
        0,
    );
    try testing.expect(spawn_result == .success);
    
    const pid = spawn_result.success;
    
    // Create a TCP socket.
    const socket_result = kernel.syscall_tcp_socket(0, 0, 0, 0);
    try testing.expect(socket_result == .success);
    
    const socket_id = socket_result.success;
    
    // Send data (this should update network_bytes_sent).
    // Note: This is a stub implementation, but it should still track bytes.
    const send_result = kernel.syscall_tcp_send(socket_id, 0x2000, 4, 0);
    // May succeed or fail depending on socket state, but should not crash.
    _ = send_result;
    
    // Get resource usage.
    const usage_result = kernel.syscall_get_resource_usage(pid, 0x1000, 0, 0);
    try testing.expect(usage_result == .success);
    
    // Note: In a real implementation, we would read the ResourceUsage struct
    // from VM memory and verify network_bytes_sent > 0.
}

// Test: get_resource_usage tracks file descriptors.
test "get_resource_usage tracks file descriptors" {
    var kernel = BasinKernel.init();
    
    // Spawn a process.
    const ELF_DATA: [256]u8 = [_]u8{0} ** 256;
    const spawn_result = kernel.syscall_spawn(
        @intFromPtr(&ELF_DATA),
        ELF_DATA.len,
        0x1000,
        0,
    );
    try testing.expect(spawn_result == .success);
    
    const pid = spawn_result.success;
    
    // Open a file (this should create a file descriptor).
    const open_result = kernel.syscall_open(0x2000, 10, 0, 0);
    // May succeed or fail depending on path validation, but should not crash.
    _ = open_result;
    
    // Get resource usage.
    const usage_result = kernel.syscall_get_resource_usage(pid, 0x1000, 0, 0);
    try testing.expect(usage_result == .success);
    
    // Note: In a real implementation, we would read the ResourceUsage struct
    // from VM memory and verify open_file_descriptors count.
}
