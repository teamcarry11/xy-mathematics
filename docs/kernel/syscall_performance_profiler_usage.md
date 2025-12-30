# Syscall Performance Profiler Usage Guide

**Purpose**: Track syscall execution times to identify hot paths and optimize kernel performance.

**Status**: ✅ **READY FOR USE** — Profiler infrastructure complete, disabled by default

---

## Overview

The syscall performance profiler tracks execution time for each syscall, providing:
- Call count per syscall
- Total execution time per syscall
- Minimum, maximum, and average execution times
- Aggregate statistics across all syscalls

**Key Features**:
- Disabled by default (zero overhead when not in use)
- Nanosecond precision timing
- Bounded allocations (static arrays, no heap allocation)
- Grain Style compliant (explicit types, comprehensive assertions)

---

## Basic Usage

### Enable Profiling

```zig
var kernel = BasinKernel.init();

// Enable profiling
kernel.syscall_profiler.enable();
```

### Disable Profiling

```zig
// Disable profiling (reduce overhead)
kernel.syscall_profiler.disable();
```

### Get Summary Statistics

```zig
const summary = kernel.get_profiler_summary();

// summary.total_syscall_count - Total number of syscalls executed
// summary.total_execution_time_ns - Total execution time (nanoseconds)
// summary.enabled - Whether profiling is currently enabled
```

### Get Metrics for Specific Syscall

```zig
const syscall_num: u32 = @intFromEnum(Syscall.read); // Example: read syscall

const metrics = kernel.syscall_profiler.get_metrics(syscall_num);
if (metrics) |m| {
    // m.call_count - Number of times this syscall was executed
    // m.total_time_ns - Total execution time (nanoseconds)
    // m.min_time_ns - Fastest execution time
    // m.max_time_ns - Slowest execution time
    // m.get_average_time_ns() - Average execution time
}
```

### Reset Metrics

```zig
// Clear all metrics for new measurement period
kernel.syscall_profiler.reset();
```

---

## Example: Profiling Workflow

```zig
// 1. Initialize kernel
var kernel = BasinKernel.init();

// 2. Enable profiling
kernel.syscall_profiler.enable();

// 3. Run workload (syscalls will be automatically profiled)
// ... execute syscalls ...

// 4. Get summary
const summary = kernel.get_profiler_summary();
std.debug.print("Total syscalls: {}\n", .{summary.total_syscall_count});
std.debug.print("Total time: {} ns\n", .{summary.total_execution_time_ns});

// 5. Analyze specific syscalls
const read_metrics = kernel.syscall_profiler.get_metrics(@intFromEnum(Syscall.read));
if (read_metrics) |m| {
    std.debug.print("Read syscall:\n", .{});
    std.debug.print("  Calls: {}\n", .{m.call_count});
    std.debug.print("  Avg time: {} ns\n", .{m.get_average_time_ns()});
    std.debug.print("  Min time: {} ns\n", .{m.min_time_ns});
    std.debug.print("  Max time: {} ns\n", .{m.max_time_ns});
}

// 6. Reset for next measurement period
kernel.syscall_profiler.reset();
```

---

## Performance Analysis Workflow

### Step 1: Enable Profiling and Run Workload

```zig
kernel.syscall_profiler.enable();
// ... run typical workload ...
```

### Step 2: Identify Hot Paths

```zig
// Find syscalls with highest call counts
var max_calls: u64 = 0;
var hot_syscall: u32 = 0;

var i: u32 = 0;
while (i < MAX_SYSCALLS) : (i += 1) {
    const metrics = kernel.syscall_profiler.get_metrics(i);
    if (metrics) |m| {
        if (m.call_count > max_calls) {
            max_calls = m.call_count;
            hot_syscall = i;
        }
    }
}
```

### Step 3: Identify Slow Syscalls

```zig
// Find syscalls with highest average execution time
var max_avg: u64 = 0;
var slow_syscall: u32 = 0;

var i: u32 = 0;
while (i < MAX_SYSCALLS) : (i += 1) {
    const metrics = kernel.syscall_profiler.get_metrics(i);
    if (metrics) |m| {
        const avg = m.get_average_time_ns();
        if (avg > max_avg) {
            max_avg = avg;
            slow_syscall = i;
        }
    }
}
```

### Step 4: Optimize Based on Findings

- Focus optimization efforts on syscalls with:
  - High call counts (hot paths)
  - High average execution times (slow operations)
  - High total execution time (significant impact)

---

## Integration Notes

**Automatic Profiling**: When profiling is enabled, all syscalls are automatically timed in `handle_syscall()`.

**Overhead**: 
- When disabled: Zero overhead (single boolean check)
- When enabled: Minimal overhead (~2 timer calls per syscall)

**Thread Safety**: Profiler uses static allocation and is designed for single-threaded kernel execution.

---

## File Locations

- **Profiler Module**: `src/kernel/syscall_performance_profiler.zig`
- **Kernel Integration**: `src/kernel/basin_kernel.zig` (handle_syscall)
- **Kernel Core**: `src/kernel/basin_kernel_core.zig` (BasinKernel struct, get_profiler_summary)
- **Tests**: `tests/143_syscall_performance_profiler_test.zig`

---

## Next Steps for Optimization

1. **Enable profiling** during typical workloads
2. **Collect performance data** for representative scenarios
3. **Identify hot paths** (high call count syscalls)
4. **Identify slow operations** (high average execution time)
5. **Optimize** based on profiling data:
   - Optimize hot path syscalls (reduce overhead)
   - Optimize slow syscalls (improve algorithms)
   - Reduce syscall overhead (argument validation, routing)

---

**Last Updated**: 2025-12-29  
**Agent**: Grain Basin Kernel Agent (3a)  
**Status**: ✅ Ready for use
