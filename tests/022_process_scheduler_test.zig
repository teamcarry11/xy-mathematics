//! Process Scheduler Tests
//! Why: Comprehensive TigerStyle tests for process scheduler functionality.
//! Grain Style: Explicit types (u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const Scheduler = @import("../src/kernel/scheduler.zig").Scheduler;
const ProcessState = @import("../src/kernel/basin_kernel.zig").ProcessState;
const BasinKernel = @import("../src/kernel/basin_kernel.zig").BasinKernel;

// Test scheduler initialization.
test "scheduler init" {
    const scheduler = Scheduler.init();
    
    // Assert: Scheduler must be initialized.
    try std.testing.expect(scheduler.initialized);
    try std.testing.expect(scheduler.current_pid == 0);
    try std.testing.expect(scheduler.next_index == 0);
}

// Test set current process.
test "scheduler set current" {
    var scheduler = Scheduler.init();
    
    const pid: u64 = 1;
    scheduler.set_current(pid);
    
    // Assert: Current PID must be set.
    try std.testing.expect(scheduler.get_current() == pid);
    try std.testing.expect(scheduler.is_current(pid));
    
    // Assert: Non-current PID must return false.
    try std.testing.expect(!scheduler.is_current(2));
}

// Test clear current process.
test "scheduler clear current" {
    var scheduler = Scheduler.init();
    
    scheduler.set_current(1);
    scheduler.clear_current();
    
    // Assert: Current PID must be cleared.
    try std.testing.expect(scheduler.get_current() == 0);
    try std.testing.expect(!scheduler.is_current(1));
}

// Test find next runnable process.
test "scheduler find next runnable" {
    var scheduler = Scheduler.init();
    
    const Process = struct {
        id: u64,
        state: ProcessState,
        allocated: bool,
    };
    
    var processes = [_]Process{
        Process{ .id = 0, .state = .free, .allocated = false },
        Process{ .id = 1, .state = .running, .allocated = true },
        Process{ .id = 0, .state = .free, .allocated = false },
        Process{ .id = 2, .state = .running, .allocated = true },
    };
    
    const pid1 = scheduler.find_next_runnable(&processes, 4);
    
    // Assert: Must find first runnable process.
    try std.testing.expect(pid1 == 1);
    
    const pid2 = scheduler.find_next_runnable(&processes, 4);
    
    // Assert: Must find next runnable process (round-robin).
    try std.testing.expect(pid2 == 2);
    
    const pid3 = scheduler.find_next_runnable(&processes, 4);
    
    // Assert: Must wrap around to first process.
    try std.testing.expect(pid3 == 1);
}

// Test find next runnable with no processes.
test "scheduler find next runnable empty" {
    var scheduler = Scheduler.init();
    
    const Process = struct {
        id: u64,
        state: ProcessState,
        allocated: bool,
    };
    
    var processes = [_]Process{
        Process{ .id = 0, .state = .free, .allocated = false },
        Process{ .id = 0, .state = .free, .allocated = false },
    };
    
    const pid = scheduler.find_next_runnable(&processes, 2);
    
    // Assert: Must return 0 (no runnable process).
    try std.testing.expect(pid == 0);
}

// Test reset scheduler.
test "scheduler reset" {
    var scheduler = Scheduler.init();
    
    scheduler.set_current(1);
    scheduler.next_index = 2;
    scheduler.reset();
    
    // Assert: Scheduler must be reset.
    try std.testing.expect(scheduler.get_current() == 0);
    try std.testing.expect(scheduler.next_index == 0);
}

// Test kernel scheduler integration.
test "kernel scheduler integration" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel scheduler must be initialized.
    try std.testing.expect(kernel.scheduler.initialized);
    try std.testing.expect(kernel.scheduler.current_pid == 0);
    
    // Test spawn sets current process.
    const executable: u64 = 0x1000;
    const result = kernel.handle_syscall(
        @intFromEnum(kernel.Syscall.spawn),
        executable,
        0,
        0,
        0,
    );
    
    // Assert: Spawn must succeed.
    try std.testing.expect(result == .success);
    
    const pid = result.success;
    
    // Assert: Process must be current.
    try std.testing.expect(kernel.scheduler.is_current(pid));
}

// Test exit clears current process.
test "kernel exit clears current" {
    var kernel = BasinKernel.init();
    
    // Spawn a process.
    const executable: u64 = 0x1000;
    const spawn_result = kernel.handle_syscall(
        @intFromEnum(kernel.Syscall.spawn),
        executable,
        0,
        0,
        0,
    );
    
    try std.testing.expect(spawn_result == .success);
    const pid = spawn_result.success;
    
    // Assert: Process must be current.
    try std.testing.expect(kernel.scheduler.is_current(pid));
    
    // Exit process.
    const exit_result = kernel.handle_syscall(
        @intFromEnum(kernel.Syscall.exit),
        0,
        0,
        0,
        0,
    );
    
    try std.testing.expect(exit_result == .success);
    
    // Assert: Process must not be current.
    try std.testing.expect(!kernel.scheduler.is_current(pid));
    try std.testing.expect(kernel.scheduler.get_current() == 0);
}

// Test wait for exited process.
test "kernel wait exited process" {
    var kernel = BasinKernel.init();
    
    // Spawn a process.
    const executable: u64 = 0x1000;
    const spawn_result = kernel.handle_syscall(
        @intFromEnum(kernel.Syscall.spawn),
        executable,
        0,
        0,
        0,
    );
    
    try std.testing.expect(spawn_result == .success);
    const pid = spawn_result.success;
    
    // Exit process.
    _ = kernel.handle_syscall(
        @intFromEnum(kernel.Syscall.exit),
        42,
        0,
        0,
        0,
    );
    
    // Wait for process.
    const wait_result = kernel.handle_syscall(
        @intFromEnum(kernel.Syscall.wait),
        pid,
        0,
        0,
        0,
    );
    
    // Assert: Wait must succeed and return exit status.
    try std.testing.expect(wait_result == .success);
    try std.testing.expect(wait_result.success == 42);
}

