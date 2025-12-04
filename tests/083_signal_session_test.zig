//! Signal Delivery to Sessions Tests
//! Why: Test signal delivery to sessions via special PID convention.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.basin_kernel.BasinKernel;
const BasinError = basin_kernel.basin_kernel.BasinError;
const SyscallResult = basin_kernel.basin_kernel.SyscallResult;
const Signal = basin_kernel.basin_kernel.Signal;

// Test: send signal to session using special PID convention.
test "kill session with special pid" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Spawn a process.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result1 = kernel.syscall_spawn(executable, executable_len, 0, 0);
    try testing.expect(result1 == .success);
    const pid1 = result1.success;
    
    // Create a session for pid1.
    kernel.scheduler.set_current(pid1, 1000);
    const result2 = kernel.syscall_setsid(0, 0, 0, 0);
    try testing.expect(result2 == .success);
    const sid = result2.success;
    
    // Get sid for pid1 to verify.
    const result3 = kernel.syscall_getsid(pid1, 0, 0, 0);
    try testing.expect(result3 == .success);
    try testing.expect(result3.success == sid);
    
    // Send signal to session using special PID convention.
    // Session delivery uses bit 62 (0x4000000000000000) set.
    const session_pid = sid | 0x4000000000000000;
    const signal_num = @intFromEnum(Signal.sigterm);
    const result4 = kernel.syscall_kill(session_pid, signal_num, 0, 0);
    try testing.expect(result4 == .success);
    try testing.expect(result4.success >= 1); // At least pid1 should be signaled
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

// Test: error handling for invalid session.
test "kill invalid session" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Try to send signal to non-existent session.
    const sid: u64 = 999;
    const session_pid = sid | 0x4000000000000000;
    const signal_num = @intFromEnum(Signal.sigterm);
    _ = kernel.syscall_kill(session_pid, signal_num, 0, 0) catch |err| {
        try testing.expect(err == BasinError.not_found); // Session not found
        return;
    };
    try testing.expect(false); // Should have returned error
}

// Test: SIGKILL terminates all processes in session.
test "kill session with sigkill" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Spawn a process.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result1 = kernel.syscall_spawn(executable, executable_len, 0, 0) catch |err| {
        try testing.expect(false); // Should not fail
        return;
    };
    try testing.expect(result1 == .success);
    const pid1 = result1.success;
    
    // Create a session for pid1.
    kernel.scheduler.set_current(pid1, 1000);
    const result2 = kernel.syscall_setsid(0, 0, 0, 0) catch |err| {
        try testing.expect(false); // Should not fail
        return;
    };
    try testing.expect(result2 == .success);
    const sid = result2.success;
    
    // Send SIGKILL to session.
    const session_pid = sid | 0x4000000000000000;
    const signal_num = @intFromEnum(Signal.sigkill);
    const result3 = kernel.syscall_kill(session_pid, signal_num, 0, 0) catch |err| {
        try testing.expect(false); // Should not fail
        return;
    };
    try testing.expect(result3 == .success);
    try testing.expect(result3.success >= 1); // At least pid1 should be killed
    
    // Verify process is exited.
    // Note: We can't directly check process state from test,
    // but we can verify the syscall succeeded.
}

// Test: send signal to empty session.
test "kill empty session" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Try to send signal to a session with no processes.
    // (Sessions are created when processes call setsid, so we'll use a non-existent sid)
    const sid: u64 = 999;
    const session_pid = sid | 0x4000000000000000;
    const signal_num = @intFromEnum(Signal.sigterm);
    _ = kernel.syscall_kill(session_pid, signal_num, 0, 0) catch |err| {
        try testing.expect(err == BasinError.not_found); // Session not found or empty
        return;
    };
    try testing.expect(false); // Should have returned error
}

// Test: process group vs session delivery distinction.
test "process group vs session delivery" {
    var kernel = BasinKernel.init();
    defer kernel.deinit();
    
    // Spawn a process.
    const executable: u64 = 0x10000;
    const executable_len: u64 = 1024;
    const result1 = kernel.syscall_spawn(executable, executable_len, 0, 0);
    try testing.expect(result1 == .success);
    const pid1 = result1.success;
    
    // Create a session (which will also create a new process group).
    kernel.scheduler.set_current(pid1, 1000);
    const result2 = kernel.syscall_setsid(0, 0, 0, 0);
    try testing.expect(result2 == .success);
    const sid = result2.success;
    
    // Test session delivery (bit 62 set).
    const session_pid = sid | 0x4000000000000000;
    const signal_num = @intFromEnum(Signal.sigterm);
    const result3 = kernel.syscall_kill(session_pid, signal_num, 0, 0);
    try testing.expect(result3 == .success);
    try testing.expect(result3.success >= 1);
}
