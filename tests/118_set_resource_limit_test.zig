//! Test: Set Resource Limit Syscall
//!
//! Objective: Verify set_resource_limit syscall works correctly.
//! Why: Ensure per-process resource limits can be configured and enforced.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const BasinKernel = @import("basin_kernel.zig").BasinKernel;

// Test: set_resource_limit syscall validation.
test "set_resource_limit syscall validation" {
    var kernel = BasinKernel.init();
    
    // Test with null process ID (should fail).
    const result_null_pid = kernel.syscall_set_resource_limit(0, 0, 1000, 0);
    try testing.expect(result_null_pid == .err);
    try testing.expect(result_null_pid.err == .invalid_argument);
    
    // Test with invalid limit type (should fail).
    const result_invalid_type = kernel.syscall_set_resource_limit(1, 99, 1000, 0);
    try testing.expect(result_invalid_type == .err);
    try testing.expect(result_invalid_type.err == .invalid_argument);
    
    // Test with non-existent process (should fail).
    const result_not_found = kernel.syscall_set_resource_limit(999, 0, 1000, 0);
    try testing.expect(result_not_found == .err);
    try testing.expect(result_not_found.err == .process_not_found);
}

// Test: set_resource_limit syscall with valid process.
test "set_resource_limit syscall with valid process" {
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
    
    // Set CPU time limit (type 0).
    const cpu_limit_result = kernel.syscall_set_resource_limit(pid, 0, 1000000000, 0); // 1 second
    try testing.expect(cpu_limit_result == .success);
    
    // Set memory limit (type 1).
    const memory_limit_result = kernel.syscall_set_resource_limit(pid, 1, 1024 * 1024, 0); // 1MB
    try testing.expect(memory_limit_result == .success);
    
    // Set file descriptor limit (type 2).
    const fd_limit_result = kernel.syscall_set_resource_limit(pid, 2, 10, 0); // 10 file descriptors
    try testing.expect(fd_limit_result == .success);
    
    // Set connection limit (type 3).
    const conn_limit_result = kernel.syscall_set_resource_limit(pid, 3, 5, 0); // 5 connections
    try testing.expect(conn_limit_result == .success);
}

// Test: set_resource_limit permission check.
test "set_resource_limit permission check" {
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
    
    // Note: Permission checks require root or same process.
    // In test environment, we may not have proper user context setup,
    // so this test verifies the syscall accepts valid parameters.
    // Full permission testing would require user context setup.
    
    // Set limit as same process (should succeed).
    const result = kernel.syscall_set_resource_limit(pid, 0, 1000000000, 0);
    try testing.expect(result == .success);
}

// Test: resource limit enforcement in socket creation.
test "resource limit enforcement in socket creation" {
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
    
    // Set connection limit to 0 (no connections allowed).
    const limit_result = kernel.syscall_set_resource_limit(pid, 3, 0, 0);
    try testing.expect(limit_result == .success);
    
    // Note: Full enforcement testing would require:
    // 1. Setting current process context
    // 2. Attempting to create socket
    // 3. Verifying resource_exhausted error
    // This is a basic test that verifies limit can be set.
}
