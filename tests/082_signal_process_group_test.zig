//! Signal Delivery to Process Groups Tests
//! Why: Test signal delivery to process groups via negative PID.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.basin_kernel.BasinKernel;
const BasinError = basin_kernel.basin_kernel.BasinError;
const SyscallResult = basin_kernel.basin_kernel.SyscallResult;
const Signal = basin_kernel.basin_kernel.Signal;

// Test: send signal to process group using negative PID.
test "kill process group with negative pid" {
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
    
    // Set both processes to the same process group.
    const pgid: u64 = 10;
    const result3 = kernel.syscall_setpgid(pid1, pgid, 0, 0);
    try testing.expect(result3 == .success);
    
    const result4 = kernel.syscall_setpgid(pid2, pgid, 0, 0);
    try testing.expect(result4 == .success);
    
    // Send signal to process group using negative PID.
    // Negative PID = process group ID (POSIX convention).
    // We use bit manipulation to create a negative value in u64.
    const negative_pgid = @as(u64, @bitCast(@as(i64, -@as(i64, @intCast(pgid)))));
    const signal_num = @intFromEnum(Signal.sigterm);
    const result5 = kernel.syscall_kill(negative_pgid, signal_num, 0, 0);
    try testing.expect(result5 == .success);
    try testing.expect(result5.success == 2); // Both processes signaled
    
    // Verify signals were sent to both processes.
    // Note: We can't directly check signal pending state from test,
    // but we can verify the syscall succeeded.
}

// Test: send signal to single process (positive PID).
test "kill single process with positive pid" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Spawn a process.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result = kernel.syscall_spawn(executable, executable_len, 0, 0);
    try testing.expect(result == .success);
    const pid = result.success;
    
    // Send signal to single process (positive PID).
    const signal_num = @intFromEnum(Signal.sigterm);
    const result2 = kernel.syscall_kill(pid, signal_num, 0, 0);
    try testing.expect(result2 == .success);
    try testing.expect(result2.success == 0); // Single process signaled
}

// Test: error handling for invalid process group.
test "kill invalid process group" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Try to send signal to non-existent process group.
    const pgid: u64 = 999;
    const negative_pgid = @as(u64, @bitCast(@as(i64, -@as(i64, @intCast(pgid)))));
    const signal_num = @intFromEnum(Signal.sigterm);
    const result = kernel.syscall_kill(negative_pgid, signal_num, 0, 0);
    try testing.expect(result.err == BasinError.not_found); // Process group not found
}

// Test: SIGKILL terminates all processes in group.
test "kill process group with sigkill" {
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
    
    // Set both processes to the same process group.
    const pgid: u64 = 10;
    const result3 = kernel.syscall_setpgid(pid1, pgid, 0, 0);
    try testing.expect(result3 == .success);
    
    const result4 = kernel.syscall_setpgid(pid2, pgid, 0, 0);
    try testing.expect(result4 == .success);
    
    // Send SIGKILL to process group.
    const negative_pgid = @as(u64, @bitCast(@as(i64, -@as(i64, @intCast(pgid)))));
    const signal_num = @intFromEnum(Signal.sigkill);
    const result5 = kernel.syscall_kill(negative_pgid, signal_num, 0, 0);
    try testing.expect(result5 == .success);
    try testing.expect(result5.success == 2); // Both processes killed
    
    // Verify both processes are exited.
    // Note: We can't directly check process state from test,
    // but we can verify the syscall succeeded.
}

// Test: send signal to empty process group.
test "kill empty process group" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Create a process group but don't add any processes to it.
    // (Process groups are created when processes are assigned to them)
    // So we'll use a non-existent group ID.
    const pgid: u64 = 999;
    const negative_pgid = @as(u64, @bitCast(@as(i64, -@as(i64, @intCast(pgid)))));
    const signal_num = @intFromEnum(Signal.sigterm);
    const result = kernel.syscall_kill(negative_pgid, signal_num, 0, 0);
    try testing.expect(result.err == BasinError.not_found); // Process group not found or empty
}

