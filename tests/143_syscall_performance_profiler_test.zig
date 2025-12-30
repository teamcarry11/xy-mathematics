//! Test: Syscall Performance Profiler
//!
//! Objective: Verify syscall performance profiler tracks execution times correctly.
//! Why: Ensure performance profiling infrastructure works for optimization work.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const BasinKernel = @import("basin_kernel.zig").BasinKernel;
const Syscall = @import("basin_kernel.zig").Syscall;
const syscall_performance_profiler = @import("syscall_performance_profiler.zig");
const SyscallPerformanceProfiler = syscall_performance_profiler.SyscallPerformanceProfiler;
const SyscallMetrics = syscall_performance_profiler.SyscallMetrics;

// Test: Profiler initialization.
test "profiler init" {
    var profiler = SyscallPerformanceProfiler.init();
    
    // Assert: Profiler must be initialized.
    try testing.expect(!profiler.enabled);
    try testing.expect(profiler.metrics[0].call_count == 0);
}

// Test: Enable/disable profiling.
test "profiler enable disable" {
    var profiler = SyscallPerformanceProfiler.init();
    
    profiler.enable();
    try testing.expect(profiler.enabled);
    
    profiler.disable();
    try testing.expect(!profiler.enabled);
}

// Test: Record syscall execution.
test "profiler record syscall" {
    var profiler = SyscallPerformanceProfiler.init();
    profiler.enable();
    
    const syscall_num: u32 = 10; // map syscall
    const time_ns: u64 = 1000;
    
    profiler.record_syscall(syscall_num, time_ns);
    
    const metrics = profiler.get_metrics(syscall_num);
    try testing.expect(metrics != null);
    try testing.expect(metrics.?.call_count == 1);
    try testing.expect(metrics.?.total_time_ns == time_ns);
    try testing.expect(metrics.?.min_time_ns == time_ns);
    try testing.expect(metrics.?.max_time_ns == time_ns);
}

// Test: Average time calculation.
test "profiler average time" {
    var profiler = SyscallPerformanceProfiler.init();
    profiler.enable();
    
    const syscall_num: u32 = 10;
    profiler.record_syscall(syscall_num, 1000);
    profiler.record_syscall(syscall_num, 2000);
    profiler.record_syscall(syscall_num, 3000);
    
    const metrics = profiler.get_metrics(syscall_num);
    try testing.expect(metrics != null);
    try testing.expect(metrics.?.call_count == 3);
    try testing.expect(metrics.?.get_average_time_ns() == 2000);
    try testing.expect(metrics.?.min_time_ns == 1000);
    try testing.expect(metrics.?.max_time_ns == 3000);
}

// Test: Profiler disabled (no overhead).
test "profiler disabled no overhead" {
    var profiler = SyscallPerformanceProfiler.init();
    // Profiler disabled by default
    
    const syscall_num: u32 = 10;
    profiler.record_syscall(syscall_num, 1000);
    
    const metrics = profiler.get_metrics(syscall_num);
    try testing.expect(metrics != null);
    try testing.expect(metrics.?.call_count == 0); // Not recorded when disabled
}

// Test: Profiler reset.
test "profiler reset" {
    var profiler = SyscallPerformanceProfiler.init();
    profiler.enable();
    
    const syscall_num: u32 = 10;
    profiler.record_syscall(syscall_num, 1000);
    
    var metrics = profiler.get_metrics(syscall_num);
    try testing.expect(metrics.?.call_count == 1);
    
    profiler.reset();
    
    metrics = profiler.get_metrics(syscall_num);
    try testing.expect(metrics.?.call_count == 0);
}

// Test: Kernel profiler integration.
test "kernel profiler integration" {
    var kernel = BasinKernel.init();
    
    // Assert: Profiler must be initialized.
    try testing.expect(!kernel.syscall_profiler.enabled);
    
    // Enable profiling.
    kernel.syscall_profiler.enable();
    try testing.expect(kernel.syscall_profiler.enabled);
    
    // Disable profiling.
    kernel.syscall_profiler.disable();
    try testing.expect(!kernel.syscall_profiler.enabled);
}

// Test: Syscall metrics initialization.
test "syscall metrics init" {
    var metrics = SyscallMetrics.init();
    
    // Assert: Metrics must be initialized.
    try testing.expect(metrics.call_count == 0);
    try testing.expect(metrics.total_time_ns == 0);
    try testing.expect(metrics.min_time_ns == 0);
    try testing.expect(metrics.max_time_ns == 0);
}

// Test: Syscall metrics recording.
test "syscall metrics record" {
    var metrics = SyscallMetrics.init();
    
    metrics.record_execution(1000);
    try testing.expect(metrics.call_count == 1);
    try testing.expect(metrics.total_time_ns == 1000);
    try testing.expect(metrics.min_time_ns == 1000);
    try testing.expect(metrics.max_time_ns == 1000);
    
    metrics.record_execution(2000);
    try testing.expect(metrics.call_count == 2);
    try testing.expect(metrics.total_time_ns == 3000);
    try testing.expect(metrics.min_time_ns == 1000);
    try testing.expect(metrics.max_time_ns == 2000);
}

// Test: Average time calculation edge cases.
test "syscall metrics average edge cases" {
    var metrics = SyscallMetrics.init();
    
    // No calls: average should be 0.
    try testing.expect(metrics.get_average_time_ns() == 0);
    
    // Single call: average should equal that call.
    metrics.record_execution(5000);
    try testing.expect(metrics.get_average_time_ns() == 5000);
}

// Test: Profiler summary statistics.
test "profiler summary statistics" {
    var profiler = SyscallPerformanceProfiler.init();
    profiler.enable();
    
    // Record some syscalls.
    profiler.record_syscall(10, 1000);
    profiler.record_syscall(10, 2000);
    profiler.record_syscall(20, 3000);
    
    const total_count = profiler.get_total_syscall_count();
    const total_time = profiler.get_total_execution_time_ns();
    
    try testing.expect(total_count == 3);
    try testing.expect(total_time == 6000);
}

// Test: Kernel profiler summary.
test "kernel profiler summary" {
    var kernel = BasinKernel.init();
    
    const summary = kernel.get_profiler_summary();
    try testing.expect(!summary.enabled);
    try testing.expect(summary.total_syscall_count == 0);
    try testing.expect(summary.total_execution_time_ns == 0);
    
    // Enable profiling and record some syscalls.
    kernel.syscall_profiler.enable();
    kernel.syscall_profiler.record_syscall(10, 1000);
    kernel.syscall_profiler.record_syscall(20, 2000);
    
    const summary2 = kernel.get_profiler_summary();
    try testing.expect(summary2.enabled);
    try testing.expect(summary2.total_syscall_count == 2);
    try testing.expect(summary2.total_execution_time_ns == 3000);
}
