//! Process ELF Loading Tests
//! Why: Comprehensive TigerStyle tests for process management with ELF support.
//! Grain Style: Explicit types (u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const ProcessContext = basin_kernel.basin_kernel.ProcessContext;
const RawIO = @import("basin_kernel").basin_kernel.RawIO;

// Test process context initialization.
test "process context init" {
    const context = ProcessContext.init(0x10000, 0x400000, 0x10000);
    
    // Assert: Context must be initialized.
    try std.testing.expect(context.initialized);
    try std.testing.expect(context.pc == 0x10000);
    try std.testing.expect(context.sp == 0x400000);
    try std.testing.expect(context.entry_point == 0x10000);
}

// Test process context update PC.
test "process context update pc" {
    var context = ProcessContext.init(0x10000, 0x400000, 0x10000);
    
    context.update_pc(0x10010);
    
    // Assert: PC must be updated.
    try std.testing.expect(context.get_pc() == 0x10010);
    try std.testing.expect(context.get_sp() == 0x400000);
    try std.testing.expect(context.entry_point == 0x10000);
}

// Test process context reset.
test "process context reset" {
    var context = ProcessContext.init(0x10000, 0x400000, 0x10000);
    
    context.update_pc(0x10010);
    context.reset();
    
    // Assert: PC must be reset to entry point.
    try std.testing.expect(context.get_pc() == 0x10000);
    try std.testing.expect(context.entry_point == 0x10000);
}

// Test kernel spawn with process context.
test "kernel spawn process context" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    var kernel = BasinKernel.init();
    
    // Spawn a process.
    const executable: u64 = 0x1000;
    // Use syscall number directly (spawn = 1)
    const result = kernel.handle_syscall(
        1, // spawn syscall
        executable,
        0,
        0,
        0,
    );
    
    // Assert: Spawn must succeed.
    const result_unwrapped = try result;
    try std.testing.expect(result_unwrapped == .success or result_unwrapped == .err);
    if (result_unwrapped == .err) return error.TestUnexpectedError;
    
    const pid = result_unwrapped.success;
    
    // Assert: Process must be current.
    try std.testing.expect(kernel.scheduler.is_current(pid));
    
    // Find process in process table.
    var found: ?usize = null;
    for (0..16) |i| {
        if (kernel.processes[i].allocated and kernel.processes[i].id == pid) {
            found = i;
            break;
        }
    }
    
    // Assert: Process must be found.
    try std.testing.expect(found != null);
    
    const idx = found.?;
    const process = &kernel.processes[idx];
    
    // Assert: Process must be allocated and running.
    try std.testing.expect(process.allocated);
    try std.testing.expect(process.state == .running);
    try std.testing.expect(process.executable_ptr == executable);
    
    // Set process context (simulating ELF loading).
    const entry_point: u64 = 0x10000;
    const stack_pointer: u64 = 0x400000;
    process.entry_point = entry_point;
    process.stack_pointer = stack_pointer;
    process.context = ProcessContext.init(entry_point, stack_pointer, entry_point);
    
    // Assert: Context must be set.
    try std.testing.expect(process.entry_point == entry_point);
    try std.testing.expect(process.stack_pointer == stack_pointer);
    
    const context = process.context;
    
    // Assert: Context must be available.
    try std.testing.expect(context != null);
    try std.testing.expect(context.?.get_pc() == entry_point);
    try std.testing.expect(context.?.get_sp() == stack_pointer);
}

// Test process context after exit.
test "process context after exit" {
    var kernel = BasinKernel.init();
    
    // Spawn a process.
    const executable: u64 = 0x1000;
    // Use syscall number directly (spawn = 1)
    const spawn_result = kernel.handle_syscall(
        1, // spawn syscall
        executable,
        0,
        0,
        0,
    );
    
    const spawn_result_unwrapped = try spawn_result;
    try std.testing.expect(spawn_result_unwrapped == .success or spawn_result_unwrapped == .err);
    if (spawn_result_unwrapped == .err) return error.TestUnexpectedError;
    const pid = spawn_result_unwrapped.success;
    
    // Set process context.
    var found: ?usize = null;
    for (0..16) |i| {
        if (kernel.processes[i].allocated and kernel.processes[i].id == pid) {
            found = i;
            break;
        }
    }
    
    try std.testing.expect(found != null);
    const process_instance = &kernel.processes[found.?];
    // Set context using ProcessContext.init()
    process_instance.context = ProcessContext.init(0x10000, 0x400000, 0x10000);
    
    // Exit process.
    // Use syscall number directly (exit = 2)
    const exit_result = kernel.handle_syscall(
        2, // exit syscall
        42,
        0,
        0,
        0,
    );
    
    const exit_result_unwrapped = try exit_result;
    try std.testing.expect(exit_result_unwrapped == .success);
    
    // Assert: Process must be exited.
    try std.testing.expect(process_instance.state == .exited);
    try std.testing.expect(process_instance.exit_status == 42);
    
    // Assert: Context should still be available (for debugging).
    try std.testing.expect(process_instance.context != null);
}

// Test multiple processes with contexts.
test "multiple processes contexts" {
    var kernel = BasinKernel.init();
    
    // Spawn first process.
    const exec1: u64 = 0x1000;
    // Use syscall number directly (spawn = 1)
    const result1 = kernel.handle_syscall(
        1, // spawn syscall
        exec1,
        0,
        0,
        0,
    );
    
    const result1_unwrapped = try result1;
    try std.testing.expect(result1_unwrapped == .success or result1_unwrapped == .err);
    if (result1_unwrapped == .err) return error.TestUnexpectedError;
    const pid1 = result1_unwrapped.success;
    
    // Spawn second process.
    const exec2: u64 = 0x2000;
    const result2 = kernel.handle_syscall(
        1, // spawn syscall
        exec2,
        0,
        0,
        0,
    );
    
    const result2_unwrapped = try result2;
    try std.testing.expect(result2_unwrapped == .success or result2_unwrapped == .err);
    if (result2_unwrapped == .err) return error.TestUnexpectedError;
    const pid2 = result2_unwrapped.success;
    
    // Assert: Both processes must have unique IDs.
    try std.testing.expect(pid1 != pid2);
    
    // Set contexts for both processes.
    var found1: ?usize = null;
    var found2: ?usize = null;
    for (0..16) |i| {
        if (kernel.processes[i].allocated and kernel.processes[i].id == pid1) {
            found1 = i;
        }
        if (kernel.processes[i].allocated and kernel.processes[i].id == pid2) {
            found2 = i;
        }
    }
    
    try std.testing.expect(found1 != null);
    try std.testing.expect(found2 != null);
    
    if (kernel.processes[found1.?].context) |*ctx1| {
        ctx1.update_pc(0x10000);
        ctx1.sp = 0x400000;
    }
    if (kernel.processes[found2.?].context) |*ctx2| {
        ctx2.update_pc(0x20000);
        ctx2.sp = 0x500000;
    }
    
    // Assert: Contexts must be different.
    const ctx1 = kernel.processes[found1.?].context;
    const ctx2 = kernel.processes[found2.?].context;
    
    try std.testing.expect(ctx1 != null);
    try std.testing.expect(ctx2 != null);
    try std.testing.expect(ctx1.?.get_pc() == 0x10000);
    try std.testing.expect(ctx2.?.get_pc() == 0x20000);
    try std.testing.expect(ctx1.?.get_sp() == 0x400000);
    try std.testing.expect(ctx2.?.get_sp() == 0x500000);
}

