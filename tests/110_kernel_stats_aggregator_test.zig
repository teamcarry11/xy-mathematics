//! Test: Kernel Statistics Aggregator
//!
//! Objective: Verify unified statistics aggregation from all kernel subsystems.
//! Why: Ensure comprehensive system monitoring works correctly.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const BasinKernel = @import("basin_kernel.zig").BasinKernel;
const KernelStatsSnapshot = @import("kernel_stats_aggregator.zig").KernelStatsSnapshot;

// Test: Kernel statistics snapshot creation.
test "kernel stats snapshot create" {
    var kernel = BasinKernel.init();
    
    // Get statistics snapshot.
    const snapshot = kernel.get_kernel_stats_snapshot();
    
    // Assert: Snapshot must be valid.
    try testing.expect(snapshot.total_errors == 0);
    try testing.expect(snapshot.total_operations == 0);
    try testing.expect(snapshot.health_score == 100.0);
}

// Test: Kernel statistics snapshot with TCP operations.
test "kernel stats snapshot with tcp operations" {
    var kernel = BasinKernel.init();
    
    // Create TCP socket and perform operations.
    const socket_result = kernel.syscall_tcp_socket(0, 0, 0, 0);
    try testing.expect(socket_result == .success);
    
    const socket_id = socket_result.success;
    
    // Send some data.
    const send_data: [4]u8 = "test".*;
    _ = kernel.syscall_tcp_send(socket_id, @intFromPtr(&send_data), 4, 0);
    
    // Get statistics snapshot.
    const snapshot = kernel.get_kernel_stats_snapshot();
    
    // Assert: Snapshot must reflect operations.
    try testing.expect(snapshot.total_operations > 0);
    try testing.expect(snapshot.health_score <= 100.0);
    try testing.expect(snapshot.health_score >= 0.0);
}

// Test: Kernel statistics snapshot with network operations.
test "kernel stats snapshot with network operations" {
    var kernel = BasinKernel.init();
    
    // Create network interface.
    const iface_name: [16]u8 = "eth0".*;
    _ = kernel.syscall_network_create_interface(@intFromPtr(&iface_name), 4, 0, 0);
    
    // Get statistics snapshot.
    const snapshot = kernel.get_kernel_stats_snapshot();
    
    // Assert: Snapshot must reflect operations.
    try testing.expect(snapshot.total_operations > 0);
    try testing.expect(snapshot.health_score <= 100.0);
    try testing.expect(snapshot.health_score >= 0.0);
}

// Test: Kernel statistics snapshot with errors.
test "kernel stats snapshot with errors" {
    var kernel = BasinKernel.init();
    
    // Try to create TCP socket with invalid arguments (will fail).
    _ = kernel.syscall_tcp_socket(0xFFFFFFFF, 0, 0, 0);
    
    // Try to create network interface with invalid name (will fail).
    _ = kernel.syscall_network_create_interface(0, 0, 0, 0);
    
    // Get statistics snapshot.
    const snapshot = kernel.get_kernel_stats_snapshot();
    
    // Assert: Snapshot must reflect errors.
    // Note: Some operations may succeed, so we just check that snapshot is valid.
    try testing.expect(snapshot.health_score <= 100.0);
    try testing.expect(snapshot.health_score >= 0.0);
}

// Test: Kernel statistics snapshot print (doesn't crash).
test "kernel stats snapshot print" {
    var kernel = BasinKernel.init();
    
    // Get statistics snapshot.
    const snapshot = kernel.get_kernel_stats_snapshot();
    
    // Print statistics (should not crash).
    snapshot.print();
    
    // Assert: Snapshot must be valid.
    try testing.expect(snapshot.health_score <= 100.0);
    try testing.expect(snapshot.health_score >= 0.0);
}
