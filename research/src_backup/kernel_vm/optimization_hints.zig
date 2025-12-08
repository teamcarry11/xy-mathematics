//! VM Performance Optimization Hints System
//!
//! Objective: Analyze collected VM statistics and provide optimization recommendations.
//! Why: Enable automatic detection of performance bottlenecks and optimization opportunities.
//! GrainStyle: Static allocation, bounded buffers, explicit types, deterministic analysis.
//!
//! Methodology:
//! - Analyze instruction statistics (identify hot instructions)
//! - Analyze memory access patterns (identify cache misses, hot memory regions)
//! - Analyze branch patterns (identify mispredicted branches)
//! - Analyze register usage (identify register pressure)
//! - Generate optimization hints (JIT optimization, memory layout, register allocation)
//! - Bounded hint buffer (MAX_HINTS: 32)
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded buffers: fixed-size hint buffer
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-12-02
//! GrainStyle: Comprehensive optimization hints, deterministic behavior, explicit limits

const std = @import("std");
const VM = @import("vm.zig").VM;
const stats_aggregator_mod = @import("stats_aggregator.zig");

// Bounded: Maximum number of optimization hints.
pub const MAX_HINTS: u32 = 32;

// Optimization hint type.
pub const OptimizationHintType = enum {
    hot_instruction,
    memory_hot_spot,
    branch_misprediction,
    register_pressure,
    cache_miss,
    jit_opportunity,
};

// Optimization hint.
pub const OptimizationHint = struct {
    hint_type: OptimizationHintType,
    address: u64,
    description: [128]u8,
    description_len: u32,
    priority: u32,

    pub fn init() OptimizationHint {
        return OptimizationHint{
            .hint_type = .hot_instruction,
            .address = 0,
            .description = [_]u8{0} ** 128,
            .description_len = 0,
            .priority = 0,
        };
    }
};

// VM optimization hints analyzer.
pub const VMOptimizationHints = struct {
    hints: [MAX_HINTS]OptimizationHint,
    hints_count: u32,

    pub fn init() VMOptimizationHints {
        var analyzer = VMOptimizationHints{
            .hints = undefined,
            .hints_count = 0,
        };
        var i: u32 = 0;
        while (i < MAX_HINTS) : (i += 1) {
            analyzer.hints[i] = OptimizationHint.init();
        }
        return analyzer;
    }

    pub fn analyze_vm(self: *VMOptimizationHints, vm: *VM) void {
        self.hints_count = 0;
        self.analyze_hot_instructions(vm);
        self.analyze_memory_hot_spots(vm);
        self.analyze_branch_mispredictions(vm);
        self.analyze_register_pressure(vm);
        self.analyze_jit_opportunities(vm);
    }

    fn analyze_hot_instructions(self: *VMOptimizationHints, vm: *VM) void {
        const stats = &vm.instruction_stats;
        var max_count: u64 = 0;
        var hot_opcode: u32 = 0;
        var i: u32 = 0;
        while (i < stats.entries_len) : (i += 1) {
            const entry = &stats.entries[i];
            if (entry.count > max_count) {
                max_count = entry.count;
                hot_opcode = entry.opcode;
            }
        }
        if (max_count > 1000 and self.hints_count < MAX_HINTS) {
            const hint = &self.hints[self.hints_count];
            hint.hint_type = .hot_instruction;
            hint.address = 0;
            hint.priority = 3;
            const desc = std.fmt.bufPrint(hint.description[0..], "Hot instruction: opcode 0x{x} executed {} times", .{ hot_opcode, max_count }) catch "";
            hint.description_len = @as(u32, @intCast(desc.len));
            self.hints_count += 1;
        }
    }

    fn analyze_memory_hot_spots(self: *VMOptimizationHints, vm: *VM) void {
        const stats = &vm.memory_stats;
        var max_accesses: u64 = 0;
        var hot_region: u32 = 0;
        var i: u32 = 0;
        while (i < stats.regions_len) : (i += 1) {
            const region = &stats.regions[i];
            const total_accesses = region.read_count + region.write_count;
            if (total_accesses > max_accesses) {
                max_accesses = total_accesses;
                hot_region = i;
            }
        }
        if (max_accesses > 500 and self.hints_count < MAX_HINTS) {
            const region = &stats.regions[hot_region];
            const hint = &self.hints[self.hints_count];
            hint.hint_type = .memory_hot_spot;
            hint.address = region.start_address;
            hint.priority = 2;
            const desc = std.fmt.bufPrint(hint.description[0..], "Memory hot spot: 0x{x}-0x{x} accessed {} times", .{ region.start_address, region.end_address, max_accesses }) catch "";
            hint.description_len = @as(u32, @intCast(desc.len));
            self.hints_count += 1;
        }
    }

    fn analyze_branch_mispredictions(self: *VMOptimizationHints, vm: *VM) void {
        const stats = &vm.branch_stats;
        var worst_rate: f64 = 1.0;
        var worst_pc: u64 = 0;
        var i: u32 = 0;
        while (i < stats.entries_len) : (i += 1) {
            const entry = &stats.entries[i];
            const rate = stats.get_taken_rate(entry.pc);
            if (rate > 0.0 and rate < worst_rate) {
                worst_rate = rate;
                worst_pc = entry.pc;
            }
        }
        if (worst_rate < 0.3 and self.hints_count < MAX_HINTS) {
            const hint = &self.hints[self.hints_count];
            hint.hint_type = .branch_misprediction;
            hint.address = worst_pc;
            hint.priority = 1;
            const desc = std.fmt.bufPrint(hint.description[0..], "Branch misprediction: PC 0x{x} taken rate {d:.2}%", .{ worst_pc, worst_rate * 100.0 }) catch "";
            hint.description_len = @as(u32, @intCast(desc.len));
            self.hints_count += 1;
        }
    }

    fn analyze_register_pressure(self: *VMOptimizationHints, vm: *VM) void {
        const stats = &vm.register_stats;
        var max_usage: u64 = 0;
        var hot_register: u32 = 0;
        var i: u32 = 0;
        while (i < stats.entries_len) : (i += 1) {
            const entry = &stats.entries[i];
            const total_usage = entry.read_count + entry.write_count;
            if (total_usage > max_usage) {
                max_usage = total_usage;
                hot_register = i;
            }
        }
        if (max_usage > 10000 and self.hints_count < MAX_HINTS) {
            const hint = &self.hints[self.hints_count];
            hint.hint_type = .register_pressure;
            hint.address = hot_register;
            hint.priority = 2;
            const desc = std.fmt.bufPrint(hint.description[0..], "Register pressure: x{} accessed {} times", .{ hot_register, max_usage }) catch "";
            hint.description_len = @as(u32, @intCast(desc.len));
            self.hints_count += 1;
        }
    }

    fn analyze_jit_opportunities(self: *VMOptimizationHints, vm: *VM) void {
        if (vm.jit == null or !vm.jit_enabled) {
            return;
        }
        const jit_ctx = vm.jit.?;
        const cache_hit_rate: f64 = if (jit_ctx.perf_counters.cache_hits + jit_ctx.perf_counters.cache_misses > 0)
            @as(f64, @floatFromInt(jit_ctx.perf_counters.cache_hits)) / @as(f64, @floatFromInt(jit_ctx.perf_counters.cache_hits + jit_ctx.perf_counters.cache_misses))
        else
            0.0;
        if (cache_hit_rate < 0.5 and self.hints_count < MAX_HINTS) {
            const hint = &self.hints[self.hints_count];
            hint.hint_type = .jit_opportunity;
            hint.address = 0;
            hint.priority = 1;
            const desc = std.fmt.bufPrint(hint.description[0..], "JIT cache hit rate: {d:.2}% (low)", .{cache_hit_rate * 100.0}) catch "";
            hint.description_len = @as(u32, @intCast(desc.len));
            self.hints_count += 1;
        }
    }

    pub fn get_hints_count(self: *const VMOptimizationHints) u32 {
        return self.hints_count;
    }

    pub fn get_hint(self: *const VMOptimizationHints, index: u32) ?*const OptimizationHint {
        if (index >= self.hints_count) {
            return null;
        }
        return &self.hints[index];
    }

    pub fn print_hints(self: *const VMOptimizationHints) void {
        std.debug.print("\nVM Optimization Hints ({} hints):\n", .{self.hints_count});
        var i: u32 = 0;
        while (i < self.hints_count) : (i += 1) {
            const hint = &self.hints[i];
            std.debug.print("  [{:2}] Priority {}: ", .{ i, hint.priority });
            std.debug.print("{s}\n", .{hint.description[0..hint.description_len]});
        }
    }
};

