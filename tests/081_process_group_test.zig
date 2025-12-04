//! Process Group and Session Management Tests
//! Why: Test process group and session syscalls.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.basin_kernel.BasinKernel;
const BasinError = basin_kernel.basin_kernel.BasinError;
const SyscallResult = basin_kernel.basin_kernel.SyscallResult;

// Test: set process group ID.
test "set process group id" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Spawn a process first.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result = kernel.syscall_spawn(executable, executable_len, 0, 0);
    try testing.expect(result == .success);
    const pid = result.success;
    
    // Set process group ID.
    const pgid: u64 = 10;
    const result2 = kernel.syscall_setpgid(pid, pgid, 0, 0);
    try testing.expect(result2 == .success);
    
    // Get process group ID to verify.
    const result3 = kernel.syscall_getpgid(pid, 0, 0, 0);
    try testing.expect(result3 == .success);
    try testing.expect(result3.success == pgid);
}

// Test: get process group ID.
test "get process group id" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Spawn a process first.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result = kernel.syscall_spawn(executable, executable_len, 0, 0);
    try testing.expect(result == .success);
    const pid = result.success;
    
    // Get process group ID (should be 0 by default).
    const result2 = kernel.syscall_getpgid(pid, 0, 0, 0);
    try testing.expect(result2 == .success);
    try testing.expect(result2.success == 0); // Default is 0
}

// Test: create new session.
test "create new session" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Spawn a process first.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result = kernel.syscall_spawn(executable, executable_len, 0, 0);
    try testing.expect(result == .success);
    const pid = result.success;
    
    // Set as current process (required for setsid).
    kernel.scheduler.set_current(pid, 1000);
    
    // Create new session.
    const result2 = kernel.syscall_setsid(0, 0, 0, 0);
    try testing.expect(result2 == .success);
    const sid = result2.success;
    try testing.expect(sid != 0);
    
    // Get session ID to verify.
    const result3 = kernel.syscall_getsid(pid, 0, 0, 0);
    try testing.expect(result3 == .success);
    try testing.expect(result3.success == sid);
}

// Test: get session ID.
test "get session id" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Spawn a process first.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result = kernel.syscall_spawn(executable, executable_len, 0, 0);
    try testing.expect(result == .success);
    const pid = result.success;
    
    // Get session ID (should be 0 by default).
    const result2 = kernel.syscall_getsid(pid, 0, 0, 0);
    try testing.expect(result2 == .success);
    try testing.expect(result2.success == 0); // Default is 0
}

// Test: error handling for invalid process ID.
test "setpgid invalid process id" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Test with invalid process ID (0).
    const result = kernel.syscall_setpgid(0, 10, 0, 0);
    try testing.expect(result.err == BasinError.invalid_argument);
}

// Test: error handling for invalid process group ID.
test "setpgid invalid group id" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Spawn a process first.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result = kernel.syscall_spawn(executable, executable_len, 0, 0);
    try testing.expect(result == .success);
    const pid = result.success;
    
    // Test with invalid process group ID (0).
    const result2 = kernel.syscall_setpgid(pid, 0, 0, 0);
    try testing.expect(result2.err == BasinError.invalid_argument);
}

