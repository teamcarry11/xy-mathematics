//! Test: Kernel Statistics and Health Check Syscalls
//!
//! Objective: Verify kernel_get_stats and health_check syscalls work correctly.
//! Why: Ensure comprehensive system monitoring works correctly.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const BasinKernel = @import("basin_kernel.zig").BasinKernel;

// Test: kernel_get_stats syscall validation.
test "kernel_get_stats syscall validation" {
    var kernel = BasinKernel.init();
    
    // Test with null pointer (should fail).
    const result_null = kernel.syscall_kernel_get_stats(0, 0, 0, 0);
    try testing.expect(result_null == .err);
    try testing.expect(result_null.err == .invalid_argument);
    
    // Test with invalid pointer (should fail).
    const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024;
    const result_invalid = kernel.syscall_kernel_get_stats(VM_MEMORY_SIZE, 0, 0, 0);
    try testing.expect(result_invalid == .err);
    try testing.expect(result_invalid.err == .invalid_argument);
    
    // Test with valid pointer (should succeed).
    // Note: Integration layer will write stats, but we validate pointer here.
    const result_valid = kernel.syscall_kernel_get_stats(0x1000, 0, 0, 0);
    try testing.expect(result_valid == .success);
}

// Test: health_check syscall returns valid status.
test "health_check syscall returns valid status" {
    var kernel = BasinKernel.init();
    
    // Get health status.
    const result = kernel.syscall_health_check(0, 0, 0, 0);
    try testing.expect(result == .success);
    
    const health_status = result.success;
    
    // Assert: Health status must be 0 (healthy), 1 (degraded), or 2 (unhealthy).
    try testing.expect(health_status <= 2);
    
    // With fresh kernel, should be healthy (health_score = 100.0).
    try testing.expect(health_status == 0);
}

// Test: health_check syscall with operations.
test "health_check syscall with operations" {
    var kernel = BasinKernel.init();
    
    // Create some operations to affect health score.
    const socket_result = kernel.syscall_tcp_socket(0, 0, 0, 0);
    try testing.expect(socket_result == .success);
    
    // Get health status (should still be healthy with no errors).
    const result = kernel.syscall_health_check(0, 0, 0, 0);
    try testing.expect(result == .success);
    
    const health_status = result.success;
    
    // Assert: Health status must be valid.
    try testing.expect(health_status <= 2);
}

// Test: kernel_get_stats and health_check integration.
test "kernel_get_stats and health_check integration" {
    var kernel = BasinKernel.init();
    
    // Get health status.
    const health_result = kernel.syscall_health_check(0, 0, 0, 0);
    try testing.expect(health_result == .success);
    
    // Get kernel stats (pointer validation).
    const stats_result = kernel.syscall_kernel_get_stats(0x1000, 0, 0, 0);
    try testing.expect(stats_result == .success);
    
    // Both should succeed.
    try testing.expect(health_result == .success);
    try testing.expect(stats_result == .success);
}
