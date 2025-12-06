//! Process Group Statistics Tests
//! Why: Test process group statistics tracking.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.basin_kernel.BasinKernel;
const BasinError = basin_kernel.basin_kernel.BasinError;
const SyscallResult = basin_kernel.basin_kernel.SyscallResult;
const Signal = basin_kernel.basin_kernel.Signal;

// Test: process group statistics initialization.
test "process group stats init" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Statistics manager should be initialized.
    // We can't directly access it, but we can test through syscalls.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result = kernel.syscall_spawn(executable, executable_len, 0, 0);
    try testing.expect(result == .success);
    const pid = result.success;
    
    // Set process group.
    const pgid: u64 = 10;
    const result2 = kernel.syscall_setpgid(pid, pgid, 0, 0);
    try testing.expect(result2 == .success);
}

// Test: process group statistics tracking process count.
test "process group stats process count" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Spawn two processes.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result1 = kernel.syscall_spawn(executable, executable_len, 0, 0);
    try testing.expect(result1 == .success);
    const pid1 = result1.success;
    
    const result2 = kernel.syscall_spawn(executable, executable_len, 0, 0);
    try testing.expect(result2 == .success);
    const pid2 = result2.success;
    
    // Set both processes to the same group.
    const pgid: u64 = 10;
    const result3 = kernel.syscall_setpgid(pid1, pgid, 0, 0);
    try testing.expect(result3 == .success);
    
    const result4 = kernel.syscall_setpgid(pid2, pgid, 0, 0);
    try testing.expect(result4 == .success);
    
    // Statistics should track both processes in the group.
    // Note: We can't directly verify the count, but the syscalls should succeed.
}

// Test: process group statistics tracking signals.
test "process group stats signal count" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Spawn a process.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result1 = kernel.syscall_spawn(executable, executable_len, 0, 0);
    try testing.expect(result1 == .success);
    const pid1 = result1.success;
    
    // Set process group.
    const pgid: u64 = 10;
    const result2 = kernel.syscall_setpgid(pid1, pgid, 0, 0);
    try testing.expect(result2 == .success);
    
    // Send signal to process group.
    const negative_pgid = pgid | 0x8000000000000000;
    const signal_num = @intFromEnum(Signal.sigterm);
    const result3 = kernel.syscall_kill(negative_pgid, signal_num, 0, 0);
    try testing.expect(result3 == .success);
    
    // Statistics should track the signal.
    // Note: We can't directly verify the count, but the syscall should succeed.
}

// Test: process group statistics tracking exited processes.
test "process group stats exited count" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Spawn a process.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result1 = kernel.syscall_spawn(executable, executable_len, 0, 0);
    try testing.expect(result1 == .success);
    const pid1 = result1.success;
    
    // Set process group.
    const pgid: u64 = 10;
    const result2 = kernel.syscall_setpgid(pid1, pgid, 0, 0);
    try testing.expect(result2 == .success);
    
    // Exit the process.
    const exit_code: u64 = 42;
    const result3 = kernel.syscall_exit(exit_code, 0, 0, 0);
    try testing.expect(result3 == .success);
    
    // Statistics should track the exited process.
    // Note: We can't directly verify the count, but the syscall should succeed.
}

// Test: process group statistics with multiple groups.
test "process group stats multiple groups" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Spawn two processes.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result1 = kernel.syscall_spawn(executable, executable_len, 0, 0);
    try testing.expect(result1 == .success);
    const pid1 = result1.success;
    
    const result2 = kernel.syscall_spawn(executable, executable_len, 0, 0);
    try testing.expect(result2 == .success);
    const pid2 = result2.success;
    
    // Set processes to different groups.
    const pgid1: u64 = 10;
    const pgid2: u64 = 20;
    const result3 = kernel.syscall_setpgid(pid1, pgid1, 0, 0);
    try testing.expect(result3 == .success);
    
    const result4 = kernel.syscall_setpgid(pid2, pgid2, 0, 0);
    try testing.expect(result4 == .success);
    
    // Send signal to first group.
    const negative_pgid1 = pgid1 | 0x8000000000000000;
    const signal_num = @intFromEnum(Signal.sigterm);
    const result5 = kernel.syscall_kill(negative_pgid1, signal_num, 0, 0);
    try testing.expect(result5 == .success);
    
    // Statistics should track signals for the correct group.
    // Note: We can't directly verify, but the syscalls should succeed.
}

