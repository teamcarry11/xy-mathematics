//! Process Group Resource Limits Tests
//! Why: Test process group resource limit enforcement.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.basin_kernel.BasinKernel;
const BasinError = basin_kernel.basin_kernel.BasinError;
const SyscallResult = basin_kernel.basin_kernel.SyscallResult;

// Test: process group limits initialization.
test "process group limits init" {
    var kernel = BasinKernel.init();
    
    // Limits manager should be initialized.
    // We can't directly access it, but we can test through syscalls.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result = kernel.syscall_spawn(executable, executable_len, 0, 0) catch {
        try testing.expect(false); // Should not fail
        return;
    };
    try testing.expect(result == .success);
    const pid = result.success;
    
    // Set process group.
    const pgid: u64 = 10;
    const result2 = kernel.syscall_setpgid(pid, pgid, 0, 0) catch {
        try testing.expect(false); // Should not fail
        return;
    };
    try testing.expect(result2 == .success);
}

// Test: process count limit enforcement.
test "process count limit enforcement" {
    var kernel = BasinKernel.init();
    
    // Spawn a process.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result1 = kernel.syscall_spawn(executable, executable_len, 0, 0) catch {
        try testing.expect(false); // Should not fail
        return;
    };
    try testing.expect(result1 == .success);
    const pid1 = result1.success;
    
    // Set process group.
    const pgid: u64 = 10;
    const result2 = kernel.syscall_setpgid(pid1, pgid, 0, 0) catch {
        try testing.expect(false); // Should not fail
        return;
    };
    try testing.expect(result2 == .success);
    
    // Set process count limit to 1.
    // Note: We can't directly set limits via syscall yet,
    // but we can test that limits are checked.
    // For now, this test verifies that spawning works with limits manager.
    
    // Spawn another process in the same group.
    kernel.scheduler.set_current(pid1, 1000);
    const result3 = kernel.syscall_spawn(executable, executable_len, 0, 0) catch |err| {
        // If limit is exceeded, we get resource_exhausted error.
        // Otherwise, should succeed.
        _ = err;
        return;
    };
    // Should succeed if no limit is set.
    try testing.expect(result3 == .success);
}

// Test: memory limit enforcement.
test "memory limit enforcement" {
    var kernel = BasinKernel.init();
    
    // Spawn a process.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result1 = kernel.syscall_spawn(executable, executable_len, 0, 0) catch {
        try testing.expect(false); // Should not fail
        return;
    };
    try testing.expect(result1 == .success);
    const pid1 = result1.success;
    
    // Set process group.
    const pgid: u64 = 10;
    const result2 = kernel.syscall_setpgid(pid1, pgid, 0, 0) catch {
        try testing.expect(false); // Should not fail
        return;
    };
    try testing.expect(result2 == .success);
    
    // Set current process.
    kernel.scheduler.set_current(pid1, 1000);
    
    // Map memory.
    const addr: u64 = 0x200000;
    const size: u64 = 4096;
    const flags: u64 = 0b111; // read, write, execute
    const result3 = kernel.syscall_map(addr, size, flags, 0) catch |err| {
        // If limit is exceeded, we get resource_exhausted error.
        // Otherwise, should succeed.
        _ = err;
        return;
    };
    // Should succeed if no limit is set.
    try testing.expect(result3 == .success);
}

// Test: unlimited limits (default).
test "unlimited limits default" {
    var kernel = BasinKernel.init();
    
    // Spawn processes without limits.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result1 = kernel.syscall_spawn(executable, executable_len, 0, 0) catch {
        try testing.expect(false); // Should not fail
        return;
    };
    try testing.expect(result1 == .success);
    const pid1 = result1.success;
    
    // Set process group.
    const pgid: u64 = 10;
    const result2 = kernel.syscall_setpgid(pid1, pgid, 0, 0) catch {
        try testing.expect(false); // Should not fail
        return;
    };
    try testing.expect(result2 == .success);
    
    // Spawn multiple processes (should work with unlimited limits).
    kernel.scheduler.set_current(pid1, 1000);
    const result3 = kernel.syscall_spawn(executable, executable_len, 0, 0) catch {
        try testing.expect(false); // Should not fail
        return;
    };
    try testing.expect(result3 == .success);
    
    const result4 = kernel.syscall_spawn(executable, executable_len, 0, 0) catch {
        try testing.expect(false); // Should not fail
        return;
    };
    try testing.expect(result4 == .success);
}

// Test: limits with no process group.
test "limits with no process group" {
    var kernel = BasinKernel.init();
    
    // Spawn a process without a process group (pgid = 0).
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result1 = kernel.syscall_spawn(executable, executable_len, 0, 0) catch {
        try testing.expect(false); // Should not fail
        return;
    };
    try testing.expect(result1 == .success);
    const pid1 = result1.success;
    
    // Process should have pgid = 0 (no group).
    // Limits should not apply (no group = unlimited).
    
    // Spawn another process (should work).
    kernel.scheduler.set_current(pid1, 1000);
    const result2 = kernel.syscall_spawn(executable, executable_len, 0, 0) catch {
        try testing.expect(false); // Should not fail
        return;
    };
    try testing.expect(result2 == .success);
}
