//! Test: Syscall Performance Benchmark
//!
//! Objective: Collect performance data for syscalls to identify hot paths and optimization opportunities.
//! Why: Enable profiling, run comprehensive syscall benchmarks, collect performance metrics.
//! GrainStyle: Comprehensive test coverage, deterministic behavior, explicit types.

const std = @import("std");
const testing = std.testing;
const BasinKernel = @import("basin_kernel.zig").BasinKernel;
const Syscall = @import("basin_kernel.zig").Syscall;
const BasinError = @import("basin_kernel.zig").BasinError;

// Test: Enable profiling and collect performance data for common syscalls.
test "syscall performance benchmark" {
    var kernel = BasinKernel.init();
    
    // Enable profiling.
    kernel.syscall_profiler.enable();
    try testing.expect(kernel.syscall_profiler.enabled);
    
    // Run common syscalls multiple times to collect performance data.
    const iterations: u32 = 100;
    
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        // Test yield syscall (common, lightweight).
        _ = kernel.handle_syscall(
            @intFromEnum(Syscall.yield),
            0,
            0,
            0,
            0,
        ) catch |err| {
            // Yield may fail if no process is running, that's okay.
            _ = err;
        };
        
        // Test sysinfo syscall (common, lightweight).
        _ = kernel.handle_syscall(
            @intFromEnum(Syscall.sysinfo),
            0x1000, // Valid pointer in VM memory
            0,
            0,
            0,
        ) catch |err| {
            // May fail if pointer validation fails, that's okay.
            _ = err;
        };
        
        // Test health_check syscall (common, lightweight).
        _ = kernel.handle_syscall(
            @intFromEnum(Syscall.health_check),
            0,
            0,
            0,
            0,
        ) catch |err| {
            // Should not fail, but handle error if it does.
            _ = err;
        };
    }
    
    // Get profiling summary.
    const summary = kernel.get_profiler_summary();
    
    // Assert: Profiling must be enabled.
    try testing.expect(summary.enabled);
    
    // Assert: Some syscalls must have been executed.
    // Note: Exact count depends on which syscalls succeeded.
    try testing.expect(summary.total_syscall_count > 0);
    
    // Assert: Total execution time must be positive.
    try testing.expect(summary.total_execution_time_ns > 0);
}

// Test: Identify hot paths (most frequently called syscalls).
test "identify hot paths" {
    var kernel = BasinKernel.init();
    kernel.syscall_profiler.enable();
    
    // Run different syscalls with varying frequencies.
    // Simulate realistic workload: yield is called most often.
    const yield_iterations: u32 = 200;
    const sysinfo_iterations: u32 = 50;
    const health_check_iterations: u32 = 10;
    
    var i: u32 = 0;
    while (i < yield_iterations) : (i += 1) {
        _ = kernel.handle_syscall(@intFromEnum(Syscall.yield), 0, 0, 0, 0) catch {};
    }
    
    i = 0;
    while (i < sysinfo_iterations) : (i += 1) {
        _ = kernel.handle_syscall(@intFromEnum(Syscall.sysinfo), 0x1000, 0, 0, 0) catch {};
    }
    
    i = 0;
    while (i < health_check_iterations) : (i += 1) {
        _ = kernel.handle_syscall(@intFromEnum(Syscall.health_check), 0, 0, 0, 0) catch {};
    }
    
    // Get metrics for each syscall.
    const yield_metrics = kernel.syscall_profiler.get_metrics(@intFromEnum(Syscall.yield));
    const sysinfo_metrics = kernel.syscall_profiler.get_metrics(@intFromEnum(Syscall.sysinfo));
    const health_check_metrics = kernel.syscall_profiler.get_metrics(@intFromEnum(Syscall.health_check));
    
    // Assert: Yield should have highest call count (hot path).
    if (yield_metrics) |ym| {
        if (sysinfo_metrics) |sm| {
            try testing.expect(ym.call_count >= sm.call_count);
        }
        if (health_check_metrics) |hm| {
            try testing.expect(ym.call_count >= hm.call_count);
        }
    }
}

// Test: Identify slow paths (syscalls with highest execution time).
test "identify slow paths" {
    var kernel = BasinKernel.init();
    kernel.syscall_profiler.enable();
    
    // Run various syscalls to collect timing data.
    const syscalls_to_test = [_]Syscall{
        .yield,
        .sysinfo,
        .health_check,
        .get_priority,
        .enumerate_processes,
    };
    
    for (syscalls_to_test) |syscall| {
        var i: u32 = 0;
        while (i < 10) : (i += 1) {
            _ = kernel.handle_syscall(
                @intFromEnum(syscall),
                0x1000, // Valid pointer for syscalls that need it
                0,
                0,
                0,
            ) catch {};
        }
    }
    
    // Get summary to verify data collection.
    const summary = kernel.get_profiler_summary();
    
    // Assert: Some syscalls must have been executed.
    try testing.expect(summary.total_syscall_count > 0);
    
    // Assert: Total execution time must be positive.
    try testing.expect(summary.total_execution_time_ns > 0);
}

// Test: Profiler reset and new measurement period.
test "profiler reset new measurement" {
    var kernel = BasinKernel.init();
    kernel.syscall_profiler.enable();
    
    // Run some syscalls.
    _ = kernel.handle_syscall(@intFromEnum(Syscall.yield), 0, 0, 0, 0) catch {};
    
    const summary1 = kernel.get_profiler_summary();
    try testing.expect(summary1.total_syscall_count > 0);
    
    // Reset profiler.
    kernel.syscall_profiler.reset();
    
    const summary2 = kernel.get_profiler_summary();
    try testing.expect(summary2.total_syscall_count == 0);
    try testing.expect(summary2.total_execution_time_ns == 0);
    
    // Run syscalls again in new measurement period.
    _ = kernel.handle_syscall(@intFromEnum(Syscall.yield), 0, 0, 0, 0) catch {};
    
    const summary3 = kernel.get_profiler_summary();
    try testing.expect(summary3.total_syscall_count > 0);
}

// Test: Find hot path (most frequently called syscall).
test "find hot path" {
    var kernel = BasinKernel.init();
    kernel.syscall_profiler.enable();
    
    // Run yield syscall many times (hot path).
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        _ = kernel.handle_syscall(@intFromEnum(Syscall.yield), 0, 0, 0, 0) catch {};
    }
    
    // Run sysinfo syscall fewer times.
    i = 0;
    while (i < 10) : (i += 1) {
        _ = kernel.handle_syscall(@intFromEnum(Syscall.sysinfo), 0x1000, 0, 0, 0) catch {};
    }
    
    const hot_path = kernel.find_profiler_hot_path();
    try testing.expect(hot_path != null);
    try testing.expect(hot_path.?.call_count >= 100);
}

// Test: Find slow path (syscall with highest average execution time).
test "find slow path" {
    var kernel = BasinKernel.init();
    kernel.syscall_profiler.enable();
    
    // Run various syscalls to collect timing data.
    _ = kernel.handle_syscall(@intFromEnum(Syscall.yield), 0, 0, 0, 0) catch {};
    _ = kernel.handle_syscall(@intFromEnum(Syscall.sysinfo), 0x1000, 0, 0, 0) catch {};
    _ = kernel.handle_syscall(@intFromEnum(Syscall.health_check), 0, 0, 0, 0) catch {};
    
    const slow_path = kernel.find_profiler_slow_path();
    // May or may not be null depending on which syscalls succeeded.
    // If not null, should have positive average time.
    if (slow_path) |sp| {
        try testing.expect(sp.avg_time_ns > 0);
    }
}
