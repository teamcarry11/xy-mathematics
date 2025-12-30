//! Syscall Performance Profiler
//! Why: Track syscall execution times to identify hot paths and optimize performance.
//! Grain Style: Explicit types, static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");
const types = @import("basin_kernel_types.zig");
const Syscall = types.Syscall;

/// Maximum number of syscalls to track.
/// Why: Bounded allocation, static array size.
pub const MAX_SYSCALLS: u32 = 150;

/// Syscall performance metrics.
/// Why: Track timing and call count for each syscall.
/// Grain Style: Explicit types, static allocation.
pub const SyscallMetrics = struct {
    /// Total call count for this syscall.
    /// Why: Track how many times syscall was invoked.
    call_count: u64,
    
    /// Total execution time (nanoseconds).
    /// Why: Track cumulative execution time for average calculation.
    total_time_ns: u64,
    
    /// Minimum execution time (nanoseconds).
    /// Why: Track fastest execution time.
    min_time_ns: u64,
    
    /// Maximum execution time (nanoseconds).
    /// Why: Track slowest execution time.
    max_time_ns: u64,
    
    /// Initialize syscall metrics.
    /// Why: Set up metrics with zero counters.
    pub fn init() SyscallMetrics {
        return SyscallMetrics{
            .call_count = 0,
            .total_time_ns = 0,
            .min_time_ns = 0,
            .max_time_ns = 0,
        };
    }
    
    /// Record syscall execution time.
    /// Why: Update metrics with execution time.
    /// Contract: time_ns must be valid (non-zero for first call).
    pub fn record_execution(self: *SyscallMetrics, time_ns: u64) void {
        // Assert: Time must be valid (non-zero for first call).
        Debug.kassert(time_ns > 0, "Time is zero", .{});
        
        self.call_count += 1;
        self.total_time_ns += time_ns;
        
        // Update min/max on first call or when new extreme found.
        if (self.call_count == 1) {
            self.min_time_ns = time_ns;
            self.max_time_ns = time_ns;
        } else {
            if (time_ns < self.min_time_ns) {
                self.min_time_ns = time_ns;
            }
            if (time_ns > self.max_time_ns) {
                self.max_time_ns = time_ns;
            }
        }
        
        // Assert: Metrics must be valid (postcondition).
        Debug.kassert(self.call_count > 0, "Call count not incremented", .{});
        Debug.kassert(self.total_time_ns >= time_ns, "Total time invalid", .{});
    }
    
    /// Get average execution time (nanoseconds).
    /// Why: Calculate average for performance analysis.
    /// Returns: Average time in nanoseconds, or 0 if no calls.
    pub fn get_average_time_ns(self: *const SyscallMetrics) u64 {
        if (self.call_count == 0) {
            return 0;
        }
        
        const avg = self.total_time_ns / self.call_count;
        
        // Assert: Average must be valid (postcondition).
        Debug.kassert(avg >= self.min_time_ns, "Avg < min", .{});
        Debug.kassert(avg <= self.max_time_ns, "Avg > max", .{});
        
        return avg;
    }
};

/// Syscall performance profiler.
/// Why: Track performance metrics for all syscalls.
/// Grain Style: Static allocation, explicit types.
pub const SyscallPerformanceProfiler = struct {
    /// Performance metrics for each syscall.
    /// Why: Track metrics indexed by syscall number.
    /// Grain Style: Static allocation, bounded array.
    metrics: [MAX_SYSCALLS]SyscallMetrics = [_]SyscallMetrics{SyscallMetrics.init()} ** MAX_SYSCALLS,
    
    /// Whether profiling is enabled.
    /// Why: Allow enabling/disabling profiling to reduce overhead.
    enabled: bool,
    
    /// Initialize profiler.
    /// Why: Set up profiler with disabled state (enable when needed).
    pub fn init() SyscallPerformanceProfiler {
        return SyscallPerformanceProfiler{
            .metrics = [_]SyscallMetrics{SyscallMetrics.init()} ** MAX_SYSCALLS,
            .enabled = false, // Disabled by default to avoid overhead
        };
    }
    
    /// Enable profiling.
    /// Why: Turn on profiling when needed for performance analysis.
    pub fn enable(self: *SyscallPerformanceProfiler) void {
        self.enabled = true;
        
        // Assert: Profiling must be enabled (postcondition).
        Debug.kassert(self.enabled, "Profiling not enabled", .{});
    }
    
    /// Disable profiling.
    /// Why: Turn off profiling to reduce overhead.
    pub fn disable(self: *SyscallPerformanceProfiler) void {
        self.enabled = false;
        
        // Assert: Profiling must be disabled (postcondition).
        Debug.kassert(!self.enabled, "Profiling not disabled", .{});
    }
    
    /// Record syscall execution time.
    /// Why: Update metrics for a syscall execution.
    /// Contract: syscall_num must be valid (< MAX_SYSCALLS), time_ns > 0.
    pub fn record_syscall(
        self: *SyscallPerformanceProfiler,
        syscall_num: u32,
        time_ns: u64,
    ) void {
        // Assert: Profiling must be enabled.
        if (!self.enabled) {
            return; // Skip if disabled to avoid overhead
        }
        
        // Assert: Syscall number must be valid.
        Debug.kassert(syscall_num < MAX_SYSCALLS, "Syscall num too large", .{});
        
        // Assert: Time must be valid.
        Debug.kassert(time_ns > 0, "Time is zero", .{});
        
        const idx: u32 = @intCast(syscall_num);
        self.metrics[idx].record_execution(time_ns);
        
        // Assert: Metrics must be updated (postcondition).
        Debug.kassert(self.metrics[idx].call_count > 0, "Metrics not updated", .{});
    }
    
    /// Get metrics for a syscall.
    /// Why: Query performance metrics for analysis.
    /// Contract: syscall_num must be valid (< MAX_SYSCALLS).
    pub fn get_metrics(
        self: *const SyscallPerformanceProfiler,
        syscall_num: u32,
    ) ?*const SyscallMetrics {
        // Assert: Syscall number must be valid.
        if (syscall_num >= MAX_SYSCALLS) {
            return null;
        }
        
        const idx: u32 = @intCast(syscall_num);
        return &self.metrics[idx];
    }
    
    /// Reset all metrics.
    /// Why: Clear metrics for new measurement period.
    pub fn reset(self: *SyscallPerformanceProfiler) void {
        var i: u32 = 0;
        while (i < MAX_SYSCALLS) : (i += 1) {
            self.metrics[i] = SyscallMetrics.init();
        }
        
        // Assert: All metrics must be reset (postcondition).
        Debug.kassert(self.metrics[0].call_count == 0, "Metrics not reset", .{});
    }
    
    /// Get total syscall count across all syscalls.
    /// Why: Provide aggregate statistics for analysis.
    pub fn get_total_syscall_count(self: *const SyscallPerformanceProfiler) u64 {
        var total: u64 = 0;
        var i: u32 = 0;
        while (i < MAX_SYSCALLS) : (i += 1) {
            total += self.metrics[i].call_count;
        }
        
        // Assert: Total must be non-negative (postcondition).
        Debug.kassert(total >= 0, "Total count negative", .{});
        
        return total;
    }
    
    /// Get total execution time across all syscalls (nanoseconds).
    /// Why: Provide aggregate statistics for analysis.
    pub fn get_total_execution_time_ns(self: *const SyscallPerformanceProfiler) u64 {
        var total: u64 = 0;
        var i: u32 = 0;
        while (i < MAX_SYSCALLS) : (i += 1) {
            total += self.metrics[i].total_time_ns;
        }
        
        // Assert: Total must be non-negative (postcondition).
        Debug.kassert(total >= 0, "Total time negative", .{});
        
        return total;
    }
    
    /// Find syscall with highest call count (hot path).
    /// Why: Identify most frequently called syscall for optimization.
    /// Returns: Syscall number and call count, or null if no syscalls recorded.
    pub fn find_hot_path(self: *const SyscallPerformanceProfiler) ?struct {
        syscall_num: u32,
        call_count: u64,
    } {
        var max_calls: u64 = 0;
        var hot_syscall: ?u32 = null;
        
        var i: u32 = 0;
        while (i < MAX_SYSCALLS) : (i += 1) {
            if (self.metrics[i].call_count > max_calls) {
                max_calls = self.metrics[i].call_count;
                hot_syscall = i;
            }
        }
        
        if (hot_syscall) |syscall| {
            // Assert: Hot path must have calls (postcondition).
            Debug.kassert(max_calls > 0, "Hot path has no calls", .{});
            return .{
                .syscall_num = syscall,
                .call_count = max_calls,
            };
        }
        
        return null;
    }
    
    /// Find syscall with highest average execution time (slow path).
    /// Why: Identify slowest syscall for optimization.
    /// Returns: Syscall number and average time, or null if no syscalls recorded.
    pub fn find_slow_path(self: *const SyscallPerformanceProfiler) ?struct {
        syscall_num: u32,
        avg_time_ns: u64,
    } {
        var max_avg: u64 = 0;
        var slow_syscall: ?u32 = null;
        
        var i: u32 = 0;
        while (i < MAX_SYSCALLS) : (i += 1) {
            const avg = self.metrics[i].get_average_time_ns();
            if (avg > max_avg) {
                max_avg = avg;
                slow_syscall = i;
            }
        }
        
        if (slow_syscall) |syscall| {
            // Assert: Slow path must have execution time (postcondition).
            Debug.kassert(max_avg > 0, "Slow path has no time", .{});
            return .{
                .syscall_num = syscall,
                .avg_time_ns = max_avg,
            };
        }
        
        return null;
    }
};

// Test: Profiler initialization.
test "profiler init" {
    var profiler = SyscallPerformanceProfiler.init();
    
    // Assert: Profiler must be initialized.
    try std.testing.expect(!profiler.enabled);
    try std.testing.expect(profiler.metrics[0].call_count == 0);
}

// Test: Enable/disable profiling.
test "profiler enable disable" {
    var profiler = SyscallPerformanceProfiler.init();
    
    profiler.enable();
    try std.testing.expect(profiler.enabled);
    
    profiler.disable();
    try std.testing.expect(!profiler.enabled);
}

// Test: Record syscall execution.
test "profiler record syscall" {
    var profiler = SyscallPerformanceProfiler.init();
    profiler.enable();
    
    const syscall_num: u32 = 10; // map syscall
    const time_ns: u64 = 1000;
    
    profiler.record_syscall(syscall_num, time_ns);
    
    const metrics = profiler.get_metrics(syscall_num);
    try std.testing.expect(metrics != null);
    try std.testing.expect(metrics.?.call_count == 1);
    try std.testing.expect(metrics.?.total_time_ns == time_ns);
    try std.testing.expect(metrics.?.min_time_ns == time_ns);
    try std.testing.expect(metrics.?.max_time_ns == time_ns);
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
    try std.testing.expect(metrics != null);
    try std.testing.expect(metrics.?.call_count == 3);
    try std.testing.expect(metrics.?.get_average_time_ns() == 2000);
}
