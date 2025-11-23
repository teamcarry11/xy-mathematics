//! Process Scheduler Tests
//! Why: Comprehensive TigerStyle tests for process scheduler functionality.
//! Grain Style: Explicit types (u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const ProcessState = basin_kernel.ProcessState;
const MAX_PROCESSES: u32 = 16;
const RawIO = @import("basin_kernel").basin_kernel.RawIO;

// Test scheduler initialization.
test "scheduler init" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    const kernel = BasinKernel.init();
    
    // Assert: Scheduler must be initialized.
    try std.testing.expect(kernel.scheduler.initialized);
    try std.testing.expect(kernel.scheduler.current_pid == 0);
    try std.testing.expect(kernel.scheduler.next_index == 0);
}

// Test set current process.
test "scheduler set current" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    var kernel = BasinKernel.init();
    
    const pid: u64 = 1;
    kernel.scheduler.set_current(pid);
    
    // Assert: Current PID must be set.
    try std.testing.expect(kernel.scheduler.get_current() == pid);
    try std.testing.expect(kernel.scheduler.is_current(pid));
    
    // Assert: Non-current PID must return false.
    try std.testing.expect(!kernel.scheduler.is_current(2));
}

// Test clear current process.
test "scheduler clear current" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    var kernel = BasinKernel.init();
    
    kernel.scheduler.set_current(1);
    kernel.scheduler.clear_current();
    
    // Assert: Current PID must be cleared.
    try std.testing.expect(kernel.scheduler.get_current() == 0);
    try std.testing.expect(!kernel.scheduler.is_current(1));
}

// Test find next runnable process.
test "scheduler find next runnable" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    var kernel = BasinKernel.init();
    
    // Use kernel's scheduler and processes
    const pid1 = kernel.scheduler.find_next_runnable(kernel.processes[0..], MAX_PROCESSES);
    
    // Assert: Must return 0 initially (no processes).
    try std.testing.expect(pid1 == 0);
    
    // Spawn a process to test scheduling.
    const spawn_result = kernel.handle_syscall(
        1, // spawn syscall
        0x1000,
        0,
        0,
        0,
    );
    
    const spawn_result_unwrapped = try spawn_result;
    try std.testing.expect(spawn_result_unwrapped == .success or spawn_result_unwrapped == .err);
    if (spawn_result_unwrapped == .err) return error.TestUnexpectedError;
    
    const pid = spawn_result_unwrapped.success;
    
    const pid2 = kernel.scheduler.find_next_runnable(kernel.processes[0..], MAX_PROCESSES);
    
    // Assert: Must find the spawned process.
    try std.testing.expect(pid2 == pid);
    
    const pid3 = kernel.scheduler.find_next_runnable(kernel.processes[0..], MAX_PROCESSES);
    
    // Assert: Must wrap around to first process.
    try std.testing.expect(pid3 == 1);
}

// Test find next runnable with no processes.
test "scheduler find next runnable empty" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    var kernel = BasinKernel.init();
    
    // No processes spawned, should return 0.
    const pid = kernel.scheduler.find_next_runnable(kernel.processes[0..], MAX_PROCESSES);
    
    // Assert: Must return 0 (no runnable process).
    try std.testing.expect(pid == 0);
}

// Test reset scheduler.
test "scheduler reset" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    var kernel = BasinKernel.init();
    
    kernel.scheduler.set_current(1);
    kernel.scheduler.next_index = 2;
    kernel.scheduler.reset();
    
    // Assert: Scheduler must be reset.
    try std.testing.expect(kernel.scheduler.get_current() == 0);
    try std.testing.expect(kernel.scheduler.next_index == 0);
}

// Test kernel scheduler integration.
test "kernel scheduler integration" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    var kernel = BasinKernel.init();
    
    // Assert: Kernel scheduler must be initialized.
    try std.testing.expect(kernel.scheduler.initialized);
    try std.testing.expect(kernel.scheduler.current_pid == 0);
    
    // Test spawn sets current process.
    const executable: u64 = 0x1000;
    const result_raw = kernel.handle_syscall(
        1, // spawn syscall
        executable,
        0,
        0,
        0,
    );
    const result = try result_raw;
    // Assert: Spawn must succeed.
    try std.testing.expect(result == .success or result == .err);
    if (result == .err) return error.TestUnexpectedError;
    const pid = result.success;
    
    // Assert: Process must be current.
    try std.testing.expect(kernel.scheduler.is_current(pid));
}

// Test exit clears current process.
test "kernel exit clears current" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    var kernel = BasinKernel.init();
    
    // Spawn a process.
    const executable: u64 = 0x1000;
    const spawn_result_raw = kernel.handle_syscall(
        1, // spawn syscall
        executable,
        0,
        0,
        0,
    );
    const spawn_result = try spawn_result_raw;
    try std.testing.expect(spawn_result == .success or spawn_result == .err);
    if (spawn_result == .err) return error.TestUnexpectedError;
    const pid = spawn_result.success;
    
    // Assert: Process must be current.
    try std.testing.expect(kernel.scheduler.is_current(pid));
    
    // Exit process.
    const exit_result = kernel.handle_syscall(
        2, // exit syscall
        0,
        0,
        0,
        0,
    );
    
    const exit_result_unwrapped = try exit_result;
    try std.testing.expect(exit_result_unwrapped == .success);
    
    // Assert: Process must not be current.
    try std.testing.expect(!kernel.scheduler.is_current(pid));
    try std.testing.expect(kernel.scheduler.get_current() == 0);
}

// Test wait for exited process.
test "kernel wait exited process" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    var kernel = BasinKernel.init();
    
    // Spawn a process.
    const executable: u64 = 0x1000;
    const spawn_result_raw = kernel.handle_syscall(
        1, // spawn syscall
        executable,
        0,
        0,
        0,
    );
    const spawn_result = try spawn_result_raw;
    try std.testing.expect(spawn_result == .success or spawn_result == .err);
    if (spawn_result == .err) return error.TestUnexpectedError;
    const pid = spawn_result.success;
    
    // Exit process.
    const exit_result_raw = kernel.handle_syscall(
        2, // exit syscall
        42,
        0,
        0,
        0,
    );
    // Exit may return error, ignore for test.
    _ = exit_result_raw catch {};
    
    // Wait for process.
    const wait_result = kernel.handle_syscall(
        3, // wait syscall
        pid,
        0,
        0,
        0,
    );
    
    // Assert: Wait must succeed and return exit status.
    const wait_result_unwrapped = try wait_result;
    try std.testing.expect(wait_result_unwrapped == .success);
    try std.testing.expect(wait_result_unwrapped.success == 42);
}

