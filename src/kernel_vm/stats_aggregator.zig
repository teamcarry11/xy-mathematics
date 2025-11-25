//! VM Statistics Aggregator System
//!
//! Objective: Unified statistics reporting that aggregates all VM statistics modules.
//! Why: Provide comprehensive VM execution analysis in a single interface.
//! GrainStyle: Static allocation, explicit types, deterministic reporting.
//!
//! Methodology:
//! - Aggregate statistics from all VM tracking modules
//! - Provide unified print interface
//! - Calculate derived metrics (ratios, percentages, averages)
//! - Format statistics for easy analysis
//! - Reset all statistics in one call
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded operations: no dynamic allocation
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-11-24
//! GrainStyle: Comprehensive statistics aggregation, deterministic behavior

const std = @import("std");
const VM = @import("vm.zig").VM;

// VM statistics aggregator.
pub const VMStatsAggregator = struct {
    vm: *VM,

    pub fn init(vm: *VM) VMStatsAggregator {
        return VMStatsAggregator{
            .vm = vm,
        };
    }

    fn print_performance_summary(self: *const VMStatsAggregator) void {
        const perf = &self.vm.performance;
        std.debug.print("\n=== Performance Metrics ===\n", .{});
        std.debug.print("  Instructions Executed: {}\n", .{perf.instructions_executed});
        std.debug.print("  Cycles Simulated: {}\n", .{perf.cycles_simulated});
        std.debug.print("  Memory Reads: {}\n", .{perf.memory_reads});
        std.debug.print("  Memory Writes: {}\n", .{perf.memory_writes});
        std.debug.print("  Syscalls: {}\n", .{perf.syscalls});
    }

    fn print_exception_summary(self: *const VMStatsAggregator) void {
        const exc = &self.vm.exception_stats;
        if (exc.total_count == 0) {
            return;
        }
        std.debug.print("\n=== Exception Statistics ===\n", .{});
        std.debug.print("  Total Exceptions: {}\n", .{exc.total_count});
        exc.print_stats();
    }

    fn print_memory_summary(self: *const VMStatsAggregator) void {
        const mem = &self.vm.memory_stats;
        std.debug.print("\n=== Memory Statistics ===\n", .{});
        std.debug.print("  Total Memory: {} bytes\n", .{mem.total_memory_bytes});
        std.debug.print("  Used Memory: {} bytes\n", .{mem.used_memory_bytes});
        if (mem.total_memory_bytes > 0) {
            const usage_pct = @as(f64, @floatFromInt(mem.used_memory_bytes)) /
                @as(f64, @floatFromInt(mem.total_memory_bytes)) * 100.0;
            std.debug.print("  Memory Usage: {d:.2}%\n", .{usage_pct});
        }
        std.debug.print("  Total Reads: {}\n", .{mem.total_reads});
        std.debug.print("  Total Writes: {}\n", .{mem.total_writes});
    }

    fn print_instruction_summary(self: *const VMStatsAggregator) void {
        const inst = &self.vm.instruction_stats;
        if (inst.total_instructions == 0) {
            return;
        }
        std.debug.print("\n=== Instruction Statistics ===\n", .{});
        inst.print_stats();
    }

    fn print_syscall_summary(self: *const VMStatsAggregator) void {
        const sys = &self.vm.syscall_stats;
        if (sys.total_syscalls == 0) {
            return;
        }
        std.debug.print("\n=== Syscall Statistics ===\n", .{});
        sys.print_stats();
    }

    fn print_execution_flow_summary(self: *const VMStatsAggregator) void {
        const flow = &self.vm.execution_flow;
        if (flow.total_instructions == 0) {
            return;
        }
        std.debug.print("\n=== Execution Flow Statistics ===\n", .{});
        flow.print_stats();
    }

    pub fn print_all_stats(self: *const VMStatsAggregator) void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║         VM Statistics Summary                        ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════╝\n", .{});
        self.print_performance_summary();
        self.print_exception_summary();
        self.print_memory_summary();
        self.print_instruction_summary();
        self.print_syscall_summary();
        self.print_execution_flow_summary();
        std.debug.print("\n", .{});
    }

    pub fn reset_all_stats(self: *VMStatsAggregator) void {
        self.vm.performance = .{};
        self.vm.exception_stats = exception_stats_mod.ExceptionStats.init();
        self.vm.memory_stats.reset();
        self.vm.instruction_stats.reset();
        self.vm.syscall_stats.reset();
        self.vm.execution_flow.reset();
    }
};

const exception_stats_mod = @import("exception_stats.zig");

