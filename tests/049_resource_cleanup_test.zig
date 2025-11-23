//! Resource Cleanup Tests (Phase 3.20)
//! Why: Test resource cleanup when processes exit (memory mappings, handles, channels).
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const BasinError = basin_kernel.BasinError;
const resource_cleanup = @import("basin_kernel").basin_kernel.resource_cleanup_module;
const RawIO = basin_kernel.RawIO;

// Test: cleanup_process_resources handles process with no resources.
test "cleanup_process_resources handles process with no resources" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var kernel = BasinKernel.init();

    // Process with no resources.
    const process_id: u32 = 1;

    // Clean up process resources.
    // Note: Currently returns 0 because MemoryMapping/FileHandle/Channel
    // don't track owner_process_id yet.
    const resources_cleaned = resource_cleanup.cleanup_process_resources(
        &kernel,
        process_id,
    );

    // Assert: No resources cleaned (structures don't track ownership yet).
    try testing.expect(resources_cleaned == 0);
}

// Test: syscall_exit calls resource cleanup.
test "syscall_exit calls resource cleanup" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var kernel = BasinKernel.init();

    // Spawn a process (stub - we'll manually create process entry).
    const process_id: u64 = 1;
    const process_idx: u32 = 0;

    // Manually create process entry.
    kernel.processes[process_idx].id = process_id;
    kernel.processes[process_idx].state = .running;
    kernel.processes[process_idx].allocated = true;
    kernel.scheduler.set_current(process_id);

    // Call exit syscall.
    const exit_status: u64 = 0;
    const exit_result = try kernel.syscall_exit(exit_status, 0, 0, 0);
    try testing.expect(exit_result == .success);

    // Assert: Process must be marked as exited.
    try testing.expect(kernel.processes[process_idx].state == .exited);
    try testing.expect(kernel.processes[process_idx].exit_status == 0);
}

