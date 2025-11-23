//! Resource Cleanup Tests (Phase 3.20)
//! Why: Test resource cleanup when processes exit (memory mappings, handles, channels).
//! Grain Style: Comprehensive assertions, explicit types, bounded operations.

const std = @import("std");
const testing = std.testing;
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const BasinError = basin_kernel.BasinError;
const resource_cleanup = basin_kernel.basin_kernel.resource_cleanup;
const RawIO = basin_kernel.RawIO;

// Test: cleanup_process_resources frees memory mappings.
test "cleanup_process_resources frees memory mappings" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var kernel = BasinKernel.init();

    // Create a process and allocate a memory mapping for it.
    const process_id: u32 = 1;
    const map_addr: u64 = 0x100000;
    const map_size: u64 = 4096;
    const map_flags: u64 = 0x7; // Read, Write, Execute

    // Allocate memory mapping for process.
    const map_result = try kernel.syscall_map(map_addr, map_size, map_flags, 0);
    try testing.expect(map_result == .success);

    // Find the mapping and set owner_process_id.
    var mapping_found = false;
    const MAX_MAPPINGS: u32 = 256;
    var i: u32 = 0;
    while (i < MAX_MAPPINGS) : (i += 1) {
        if (kernel.mappings[i].allocated and kernel.mappings[i].address == map_addr) {
            kernel.mappings[i].owner_process_id = process_id;
            mapping_found = true;
            break;
        }
    }
    try testing.expect(mapping_found);

    // Clean up process resources.
    const resources_cleaned = resource_cleanup.cleanup_process_resources(
        &kernel,
        process_id,
    );

    // Assert: At least one resource (mapping) must be cleaned.
    try testing.expect(resources_cleaned >= 1);

    // Assert: Mapping must be freed (not allocated).
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

// Test: cleanup_process_resources closes file handles.
test "cleanup_process_resources closes file handles" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var kernel = BasinKernel.init();

    // Create a process and allocate a file handle for it.
    const process_id: u32 = 2;
    const path_ptr: u64 = 0x200000;
    const path_len: u64 = 5; // "/test"
    const flags: u64 = 0; // O_RDONLY

    // Write test path to VM memory (simulated).
    // Note: In real implementation, this would write to VM memory.
    // For this test, we'll just allocate a handle directly.

    // Allocate file handle for process.
    const MAX_HANDLES: u32 = 256;
    var handle_slot: ?u32 = null;
    var i: u32 = 0;
    while (i < MAX_HANDLES) : (i += 1) {
        if (!kernel.handles[i].allocated) {
            handle_slot = i;
            break;
        }
    }
    try testing.expect(handle_slot != null);

    const handle_idx = handle_slot.?;
    kernel.handles[handle_idx].allocated = true;
    kernel.handles[handle_idx].owner_process_id = process_id;
    kernel.handles[handle_idx].id = 1;

    // Clean up process resources.
    const resources_cleaned = resource_cleanup.cleanup_process_resources(
        &kernel,
        process_id,
    );

    // Assert: At least one resource (handle) must be cleaned.
    try testing.expect(resources_cleaned >= 1);

    // Assert: Handle must be closed (not allocated).
    try testing.expect(!kernel.handles[handle_idx].allocated);
    try testing.expect(kernel.handles[handle_idx].owner_process_id == 0);
}

// Test: cleanup_process_resources closes IPC channels.
test "cleanup_process_resources closes IPC channels" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var kernel = BasinKernel.init();

    // Create a process and allocate an IPC channel for it.
    const process_id: u32 = 3;
    const channel_id: u64 = 1;

    // Allocate IPC channel for process.
    const MAX_CHANNELS: u32 = 256;
    var channel_slot: ?u32 = null;
    var i: u32 = 0;
    while (i < MAX_CHANNELS) : (i += 1) {
        if (!kernel.channels[i].allocated) {
            channel_slot = i;
            break;
        }
    }
    try testing.expect(channel_slot != null);

    const channel_idx = channel_slot.?;
    kernel.channels[channel_idx].allocated = true;
    kernel.channels[channel_idx].owner_process_id = process_id;
    kernel.channels[channel_idx].id = channel_id;

    // Clean up process resources.
    const resources_cleaned = resource_cleanup.cleanup_process_resources(
        &kernel,
        process_id,
    );

    // Assert: At least one resource (channel) must be cleaned.
    try testing.expect(resources_cleaned >= 1);

    // Assert: Channel must be closed (not allocated).
    try testing.expect(!kernel.channels[channel_idx].allocated);
    try testing.expect(kernel.channels[channel_idx].owner_process_id == 0);
}

// Test: cleanup_process_resources handles process with no resources.
test "cleanup_process_resources handles process with no resources" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();

    var kernel = BasinKernel.init();

    // Process with no resources.
    const process_id: u32 = 4;

    // Clean up process resources.
    const resources_cleaned = resource_cleanup.cleanup_process_resources(
        &kernel,
        process_id,
    );

    // Assert: No resources cleaned (process has no resources).
    try testing.expect(resources_cleaned == 0);
}

// Test: syscall_exit cleans up process resources.
test "syscall_exit cleans up process resources" {
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

    // Allocate a memory mapping for the process.
    const map_addr: u64 = 0x100000;
    const map_size: u64 = 4096;
    const map_flags: u64 = 0x7; // Read, Write, Execute

    const map_result = try kernel.syscall_map(map_addr, map_size, map_flags, 0);
    try testing.expect(map_result == .success);

    // Find the mapping and set owner_process_id.
    const MAX_MAPPINGS: u32 = 256;
    var i: u32 = 0;
    while (i < MAX_MAPPINGS) : (i += 1) {
        if (kernel.mappings[i].allocated and kernel.mappings[i].address == map_addr) {
            kernel.mappings[i].owner_process_id = @as(u32, @truncate(process_id));
            break;
        }
    }

    // Call exit syscall.
    const exit_status: u64 = 0;
    const exit_result = try kernel.syscall_exit(exit_status, 0, 0, 0);
    try testing.expect(exit_result == .success);

    // Assert: Process must be marked as exited.
    try testing.expect(kernel.processes[process_idx].state == .exited);
    try testing.expect(kernel.processes[process_idx].exit_status == 0);

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

