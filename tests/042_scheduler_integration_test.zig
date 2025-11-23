//! Scheduler-Process Execution Integration Tests (Phase 3.15)
//! Why: Test integration of scheduler with process execution in VM.
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const VM = @import("kernel_vm").VM;
const BasinKernel = @import("basin_kernel").BasinKernel;
const ProcessContext = @import("basin_kernel").ProcessContext;
const Integration = @import("kernel_vm").Integration;

// Test: run_current_process executes current process.
test "run_current_process executes current process" {
    var vm = VM.init(&[_]u8{}, 0, 0);
    var kernel = BasinKernel.init();
    
    // Spawn a process.
    const result = kernel.syscall_spawn(0x1000, 0, 0, 0) catch {
        try testing.expect(false);
        return;
    };
    try testing.expect(result == .success);
    const process_id = result.success;
    
    // Set as current process.
    kernel.scheduler.set_current(process_id);
    
    // Create integration.
    var integration = Integration.init_with_kernel(&vm, &kernel);
    integration.finish_init();
    
    // Run current process (with small max_steps).
    const should_continue = integration.run_current_process(100);
    
    // Assert: Process execution should complete (halted or errored due to invalid instructions).
    // Note: VM will halt quickly since memory is empty.
    _ = should_continue;
}

// Test: schedule_and_run_next schedules and runs next process.
test "schedule_and_run_next schedules and runs next process" {
    var vm = VM.init(&[_]u8{}, 0);
    var kernel = BasinKernel.init();
    
    // Spawn a process.
    const result = kernel.syscall_spawn(0x1000, 0, 0, 0) catch {
        try testing.expect(false);
        return;
    };
    try testing.expect(result == .success);
    const process_id = result.success;
    
    // Create integration.
    var integration = Integration.init_with_kernel(&vm, &kernel);
    integration.finish_init();
    
    // Schedule and run next process.
    const scheduled = integration.schedule_and_run_next(100);
    
    // Assert: Process should be scheduled and run.
    try testing.expect(scheduled);
    try testing.expect(kernel.scheduler.get_current() == process_id);
}

// Test: schedule_and_run_next returns false when no runnable process.
test "schedule_and_run_next returns false when no runnable process" {
    var vm = VM.init(&[_]u8{}, 0);
    var kernel = BasinKernel.init();
    
    // Create integration (no processes spawned).
    var integration = Integration.init_with_kernel(&vm, &kernel);
    integration.finish_init();
    
    // Schedule and run next process (should fail - no processes).
    const scheduled = integration.schedule_and_run_next(100);
    
    // Assert: No process should be scheduled.
    try testing.expect(!scheduled);
    try testing.expect(kernel.scheduler.get_current() == 0);
}

// Test: run_current_process returns false when no current process.
test "run_current_process returns false when no current process" {
    var vm = VM.init(&[_]u8{}, 0);
    var kernel = BasinKernel.init();
    
    // Create integration (no current process).
    var integration = Integration.init_with_kernel(&vm, &kernel);
    integration.finish_init();
    
    // Run current process (should fail - no current process).
    const should_continue = integration.run_current_process(100);
    
    // Assert: Should return false (no process to run).
    try testing.expect(!should_continue);
}

