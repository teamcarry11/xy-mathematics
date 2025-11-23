//! Resource Cleanup for Process Termination
//! Why: Clean up process resources (memory mappings, handles, channels) when process exits.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");
const BasinKernel = @import("basin_kernel.zig").BasinKernel;
const ProcessState = @import("basin_kernel.zig").ProcessState;

/// Clean up all resources owned by a process.
/// Why: Free memory mappings, handles, and channels when process exits.
/// Contract: process_id must be valid, kernel must be initialized.
/// Returns: Number of resources cleaned up (mappings + handles + channels).
/// Grain Style: Explicit types, bounded operations, static allocation.
pub fn cleanup_process_resources(
    kernel: *BasinKernel,
    process_id: u32,
) u32 {
    // Assert: Kernel must be initialized (precondition).
    const kernel_ptr = @intFromPtr(kernel);
    Debug.kassert(kernel_ptr != 0, "Kernel ptr is null", .{});
    Debug.kassert(kernel_ptr % @alignOf(BasinKernel) == 0, "Kernel ptr unaligned", .{});

    // Assert: Process ID must be valid (non-zero).
    Debug.kassert(process_id != 0, "Process ID is 0", .{});

    // Clean up memory mappings owned by process.
    // Why: Free memory mappings when process exits.
    const mappings_freed = cleanup_process_mappings(kernel, process_id);

    // Clean up file handles owned by process.
    // Why: Close file handles when process exits.
    const handles_closed = cleanup_process_handles(kernel, process_id);

    // Clean up IPC channels owned by process.
    // Why: Close IPC channels when process exits.
    const channels_closed = cleanup_process_channels(kernel, process_id);

    // Assert: Resource counts must be reasonable (postcondition).
    const MAX_RESOURCES: u32 = 1000; // Reasonable limit
    Debug.kassert(mappings_freed <= MAX_RESOURCES, "Mappings freed too large", .{});
    Debug.kassert(handles_closed <= MAX_RESOURCES, "Handles closed too large", .{});
    Debug.kassert(channels_closed <= MAX_RESOURCES, "Channels closed too large", .{});

    const total_cleaned = mappings_freed + handles_closed + channels_closed;

    // Assert: Total cleaned must be reasonable (postcondition).
    Debug.kassert(total_cleaned <= MAX_RESOURCES * 3, "Total cleaned too large", .{});

    return total_cleaned;
}

/// Clean up memory mappings owned by a process.
/// Why: Free memory mappings when process exits.
/// Contract: process_id must be valid, kernel must be initialized.
/// Returns: Number of mappings freed.
/// Grain Style: Explicit types, bounded operations, static allocation.
fn cleanup_process_mappings(
    kernel: *BasinKernel,
    process_id: u32,
) u32 {
    // Assert: Kernel must be initialized (precondition).
    const kernel_ptr = @intFromPtr(kernel);
    Debug.kassert(kernel_ptr != 0, "Kernel ptr is null", .{});

    // Assert: Process ID must be valid (non-zero).
    Debug.kassert(process_id != 0, "Process ID is 0", .{});

    // Free all memory mappings owned by this process.
    // Why: Process memory mappings should be freed on exit.
    var mappings_freed: u32 = 0;
    const MAX_MAPPINGS: u32 = 256; // Matches MAX_MAPPINGS in basin_kernel.zig

    var i: u32 = 0;
    while (i < MAX_MAPPINGS) : (i += 1) {
        const mapping = &kernel.mappings[i];
        if (mapping.allocated and mapping.owner_process_id == process_id) {
            // Free mapping (mark as unallocated).
            // Why: Free memory mapping when process exits.
            mapping.allocated = false;
            mapping.owner_process_id = 0;
            mappings_freed += 1;

            // Assert: Mapping must be freed (postcondition).
            Debug.kassert(!mapping.allocated, "Mapping not freed", .{});
            Debug.kassert(mapping.owner_process_id == 0, "Owner not cleared", .{});
        }
    }

    // Assert: Mappings freed must be reasonable (postcondition).
    Debug.kassert(mappings_freed <= MAX_MAPPINGS, "Mappings freed too large", .{});

    return mappings_freed;
}

/// Clean up file handles owned by a process.
/// Why: Close file handles when process exits.
/// Contract: process_id must be valid, kernel must be initialized.
/// Returns: Number of handles closed.
/// Grain Style: Explicit types, bounded operations, static allocation.
fn cleanup_process_handles(
    kernel: *BasinKernel,
    process_id: u32,
) u32 {
    // Assert: Kernel must be initialized (precondition).
    const kernel_ptr = @intFromPtr(kernel);
    Debug.kassert(kernel_ptr != 0, "Kernel ptr is null", .{});

    // Assert: Process ID must be valid (non-zero).
    Debug.kassert(process_id != 0, "Process ID is 0", .{});

    // Close all file handles owned by this process.
    // Why: Process file handles should be closed on exit.
    var handles_closed: u32 = 0;
    const MAX_HANDLES: u32 = 256; // Matches MAX_HANDLES in basin_kernel.zig

    var i: u32 = 0;
    while (i < MAX_HANDLES) : (i += 1) {
        const handle = &kernel.handles[i];
        if (handle.allocated and handle.owner_process_id == process_id) {
            // Close handle (mark as unallocated).
            // Why: Close file handle when process exits.
            handle.allocated = false;
            handle.owner_process_id = 0;
            handles_closed += 1;

            // Assert: Handle must be closed (postcondition).
            Debug.kassert(!handle.allocated, "Handle not closed", .{});
            Debug.kassert(handle.owner_process_id == 0, "Owner not cleared", .{});
        }
    }

    // Assert: Handles closed must be reasonable (postcondition).
    Debug.kassert(handles_closed <= MAX_HANDLES, "Handles closed too large", .{});

    return handles_closed;
}

/// Clean up IPC channels owned by a process.
/// Why: Close IPC channels when process exits.
/// Contract: process_id must be valid, kernel must be initialized.
/// Returns: Number of channels closed.
/// Grain Style: Explicit types, bounded operations, static allocation.
fn cleanup_process_channels(
    kernel: *BasinKernel,
    process_id: u32,
) u32 {
    // Assert: Kernel must be initialized (precondition).
    const kernel_ptr = @intFromPtr(kernel);
    Debug.kassert(kernel_ptr != 0, "Kernel ptr is null", .{});

    // Assert: Process ID must be valid (non-zero).
    Debug.kassert(process_id != 0, "Process ID is 0", .{});

    // Close all IPC channels owned by this process.
    // Why: Process IPC channels should be closed on exit.
    var channels_closed: u32 = 0;
    const MAX_CHANNELS: u32 = 256; // Matches MAX_CHANNELS in basin_kernel.zig

    var i: u32 = 0;
    while (i < MAX_CHANNELS) : (i += 1) {
        const channel = &kernel.channels[i];
        if (channel.allocated and channel.owner_process_id == process_id) {
            // Close channel (mark as unallocated).
            // Why: Close IPC channel when process exits.
            channel.allocated = false;
            channel.owner_process_id = 0;
            channels_closed += 1;

            // Assert: Channel must be closed (postcondition).
            Debug.kassert(!channel.allocated, "Channel not closed", .{});
            Debug.kassert(channel.owner_process_id == 0, "Owner not cleared", .{});
        }
    }

    // Assert: Channels closed must be reasonable (postcondition).
    Debug.kassert(channels_closed <= MAX_CHANNELS, "Channels closed too large", .{});

    return channels_closed;
}

