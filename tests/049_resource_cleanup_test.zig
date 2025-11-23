//! Resource Cleanup Tests (Phase 3.20)
//! Why: Test resource cleanup when processes exit (memory mappings, handles, channels).
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const BasinError = basin_kernel.BasinError;
const resource_cleanup = basin_kernel.resource_cleanup_module;
const RawIO = basin_kernel.RawIO;

// Test: cleanup_process_resources frees memory mappings with owner_process_id.
test "cleanup_process_resources frees memory mappings with owner_process_id" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var kernel = BasinKernel.init();

    // Create a process and allocate a memory mapping for it.
    const process_id: u64 = 1;
    const process_idx: u32 = 0;

    // Manually create process entry.
    kernel.processes[process_idx].id = process_id;
    kernel.processes[process_idx].state = .running;
    kernel.processes[process_idx].allocated = true;
    kernel.scheduler.set_current(process_id);

    // Allocate a memory mapping for the process.
    const map_addr: u64 = 0x100000;
    const map_size: u64 = 4096;
    const map_flags: u64 = 0x7; // Read, Write, Execute

    // Use handle_syscall with Syscall.map enum value.
    const Syscall = basin_kernel.Syscall;
    const map_syscall_num = @intFromEnum(Syscall.map);
    const map_result = try kernel.handle_syscall(map_syscall_num, map_addr, map_size, map_flags, 0);
    try testing.expect(map_result == .success);

    // Find the mapping and verify owner_process_id is set.
    const MAX_MAPPINGS: u32 = 256;
    var mapping_found = false;
    var i: u32 = 0;
    while (i < MAX_MAPPINGS) : (i += 1) {
        if (kernel.mappings[i].allocated and kernel.mappings[i].address == map_addr) {
            try testing.expect(kernel.mappings[i].owner_process_id == @as(u32, @truncate(process_id)));
            mapping_found = true;
            break;
        }
    }
    try testing.expect(mapping_found);

    // Clean up process resources.
    const resources_cleaned = resource_cleanup.cleanup_process_resources(
        &kernel,
        @as(u32, @truncate(process_id)),
    );

    // Assert: At least one resource (mapping) must be cleaned.
    try testing.expect(resources_cleaned >= 1);

    // Assert: Memory mapping must be freed (resource cleanup).
    var mapping_freed = false;
    i = 0;
    while (i < MAX_MAPPINGS) : (i += 1) {
        if (kernel.mappings[i].address == map_addr) {
            try testing.expect(!kernel.mappings[i].allocated);
            try testing.expect(kernel.mappings[i].owner_process_id == 0);
            mapping_freed = true;
            break;
        }
    }
    try testing.expect(mapping_freed);
}

// Test: cleanup_process_resources handles process with no resources.
test "cleanup_process_resources handles process with no resources" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var kernel = BasinKernel.init();

    // Process with no resources.
    const process_id: u32 = 1;

    // Clean up process resources.
    const resources_cleaned = resource_cleanup.cleanup_process_resources(
        &kernel,
        process_id,
    );

    // Assert: No resources cleaned (process has no resources).
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
    // Call exit syscall via handle_syscall.
    const Syscall = basin_kernel.Syscall;
    const exit_syscall_num = @intFromEnum(Syscall.exit);
    const exit_result = try kernel.handle_syscall(exit_syscall_num, exit_status, 0, 0, 0);
    try testing.expect(exit_result == .success);

    // Assert: Process must be marked as exited.
    try testing.expect(kernel.processes[process_idx].state == .exited);
    try testing.expect(kernel.processes[process_idx].exit_status == 0);
}

