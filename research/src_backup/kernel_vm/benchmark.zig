//! VM Performance Benchmarking Framework
//!
//! Objective: Provide benchmarking framework for VM performance evaluation.
//! Why: Enable systematic performance testing, comparison, and regression detection.
//! GrainStyle: Static allocation, bounded buffers, explicit types, deterministic benchmarking.
//!
//! Methodology:
//! - Benchmark execution (run test programs and measure performance)
//! - Performance metrics collection (instructions, cycles, memory, JIT stats)
//! - Benchmark comparison (compare current vs baseline results)
//! - Performance regression detection (detect performance degradation)
//! - Bounded benchmark results (MAX_BENCHMARKS: 64)
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded buffers: fixed-size benchmark result arrays
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-12-02
//! GrainStyle: Comprehensive benchmarking framework, deterministic behavior, explicit limits

const std = @import("std");
const VM = @import("vm.zig").VM;
const VMError = @import("vm.zig").VM.VMError;

// Bounded: Maximum number of benchmarks.
pub const MAX_BENCHMARKS: u32 = 64;

// Benchmark result.
pub const BenchmarkResult = struct {
    name: [64]u8,
    name_len: u32,
    instructions_executed: u64,
    cycles_simulated: u64,
    memory_reads: u64,
    memory_writes: u64,
    syscalls: u64,
    execution_time_ns: u64,
    jit_cache_hit_rate: f64,
    passed: bool,

    pub fn init() BenchmarkResult {
        return BenchmarkResult{
            .name = [_]u8{0} ** 64,
            .name_len = 0,
            .instructions_executed = 0,
            .cycles_simulated = 0,
            .memory_reads = 0,
            .memory_writes = 0,
            .syscalls = 0,
            .execution_time_ns = 0,
            .jit_cache_hit_rate = 0.0,
            .passed = false,
        };
    }
};

// VM benchmark runner.
pub const VMBenchmark = struct {
    results: [MAX_BENCHMARKS]BenchmarkResult,
    results_count: u32,

    pub fn init() VMBenchmark {
        var benchmark = VMBenchmark{
            .results = undefined,
            .results_count = 0,
        };
        var i: u32 = 0;
        while (i < MAX_BENCHMARKS) : (i += 1) {
            benchmark.results[i] = BenchmarkResult.init();
        }
        return benchmark;
    }

    pub fn run_benchmark(self: *VMBenchmark, vm: *VM, name: []const u8, max_steps: u64) VMError!BenchmarkResult {
        if (self.results_count >= MAX_BENCHMARKS) {
            return VMError.invalid_memory_access;
        }
        if (name.len > 64) {
            return VMError.invalid_memory_access;
        }
        var result = BenchmarkResult.init();
        @memcpy(result.name[0..name.len], name);
        result.name_len = @as(u32, @intCast(name.len));
        const perf_before = vm.performance;
        const start_time = std.time.nanoTimestamp();
        vm.start();
        var steps: u64 = 0;
        while (vm.state == .running and steps < max_steps) : (steps += 1) {
            try vm.step_jit();
        }
        const end_time = std.time.nanoTimestamp();
        const execution_time: i64 = end_time - start_time;
        result.execution_time_ns = if (execution_time > 0) @as(u64, @intCast(execution_time)) else 0;
        result.instructions_executed = vm.performance.instructions_executed - perf_before.instructions_executed;
        result.cycles_simulated = vm.performance.cycles_simulated - perf_before.cycles_simulated;
        result.memory_reads = vm.performance.memory_reads - perf_before.memory_reads;
        result.memory_writes = vm.performance.memory_writes - perf_before.memory_writes;
        result.syscalls = vm.performance.syscalls - perf_before.syscalls;
        if (vm.jit) |jit_ctx| {
            const total_ops = jit_ctx.perf_counters.cache_hits + jit_ctx.perf_counters.cache_misses;
            result.jit_cache_hit_rate = if (total_ops > 0)
                @as(f64, @floatFromInt(jit_ctx.perf_counters.cache_hits)) / @as(f64, @floatFromInt(total_ops))
            else
                0.0;
        }
        result.passed = (vm.state == .halted);
        const idx = self.results_count;
        self.results[idx] = result;
        self.results_count += 1;
        return result;
    }

    pub fn compare_results(self: *const VMBenchmark, baseline: *const VMBenchmark) void {
        std.debug.print("\n=== Benchmark Comparison ===\n", .{});
        var i: u32 = 0;
        while (i < self.results_count) : (i += 1) {
            const current = &self.results[i];
            var found = false;
            var j: u32 = 0;
            while (j < baseline.results_count) : (j += 1) {
                const base = &baseline.results[j];
                if (std.mem.eql(u8, current.name[0..current.name_len], base.name[0..base.name_len])) {
                    found = true;
                    const speedup = if (current.execution_time_ns > 0)
                        @as(f64, @floatFromInt(base.execution_time_ns)) / @as(f64, @floatFromInt(current.execution_time_ns))
                    else
                        0.0;
                    std.debug.print("  {}: {d:.2}x speedup\n", .{ current.name[0..current.name_len], speedup });
                    break;
                }
            }
            if (!found) {
                std.debug.print("  {}: (no baseline)\n", .{current.name[0..current.name_len]});
            }
        }
    }

    pub fn print_results(self: *const VMBenchmark) void {
        std.debug.print("\n=== Benchmark Results ===\n", .{});
        var i: u32 = 0;
        while (i < self.results_count) : (i += 1) {
            const result = &self.results[i];
            std.debug.print("  {}: ", .{result.name[0..result.name_len]});
            std.debug.print("{} instructions, ", .{result.instructions_executed});
            std.debug.print("{} ns, ", .{result.execution_time_ns});
            std.debug.print("JIT hit rate: {d:.2}%, ", .{result.jit_cache_hit_rate * 100.0});
            std.debug.print("Status: {s}\n", .{if (result.passed) "PASS" else "FAIL"});
        }
    }

    pub fn get_results_count(self: *const VMBenchmark) u32 {
        return self.results_count;
    }

    pub fn get_result(self: *const VMBenchmark, index: u32) ?*const BenchmarkResult {
        if (index >= self.results_count) {
            return null;
        }
        return &self.results[index];
    }

    pub fn clear_results(self: *VMBenchmark) void {
        self.results_count = 0;
    }
};

