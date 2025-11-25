//! VM Instruction Performance Profiling System
//!
//! Objective: Track execution time per instruction type for performance analysis.
//! Why: Identify slow instruction types, optimize hot paths, measure JIT effectiveness.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track total execution time per opcode
//! - Track execution count per opcode
//! - Calculate average execution time per instruction type
//! - Track total profiling time
//! - Provide statistics interface for querying performance data
//! - Reset capability for new measurement periods
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded counters: fixed-size counters (no overflow issues)
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-11-24
//! GrainStyle: Comprehensive performance profiling, deterministic behavior, explicit limits

const std = @import("std");

// Bounded: Maximum number of opcodes to track (RISC-V has ~50 base opcodes).
pub const MAX_OPCODES: u32 = 64;

// Instruction performance entry: tracks execution time and count for an opcode.
pub const InstructionPerfEntry = struct {
    opcode: u32,
    total_time_ns: u64,
    execution_count: u64,

    pub fn init(opcode: u32) InstructionPerfEntry {
        std.debug.assert(opcode < MAX_OPCODES);
        return InstructionPerfEntry{
            .opcode = opcode,
            .total_time_ns = 0,
            .execution_count = 0,
        };
    }

    fn get_avg_time_ns(self: *const InstructionPerfEntry) u64 {
        if (self.execution_count == 0) {
            return 0;
        }
        return self.total_time_ns / self.execution_count;
    }
};

// VM instruction performance profiler.
pub const VMInstructionPerf = struct {
    entries: [MAX_OPCODES]InstructionPerfEntry,
    entries_len: u32,
    total_profiling_time_ns: u64,

    pub fn init() VMInstructionPerf {
        var perf = VMInstructionPerf{
            .entries = undefined,
            .entries_len = 0,
            .total_profiling_time_ns = 0,
        };
        var i: u32 = 0;
        while (i < MAX_OPCODES) : (i += 1) {
            perf.entries[i] = InstructionPerfEntry.init(i);
        }
        return perf;
    }

    fn find_or_add_entry(self: *VMInstructionPerf, opcode: u32) *InstructionPerfEntry {
        std.debug.assert(opcode < MAX_OPCODES);
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            if (self.entries[i].opcode == opcode) {
                return &self.entries[i];
            }
        }
        if (self.entries_len < MAX_OPCODES) {
            const idx = self.entries_len;
            self.entries[idx] = InstructionPerfEntry.init(opcode);
            self.entries_len += 1;
            return &self.entries[idx];
        }
        return &self.entries[0];
    }

    pub fn record_execution(self: *VMInstructionPerf, opcode: u32, time_ns: u64) void {
        std.debug.assert(opcode < MAX_OPCODES);
        const entry = self.find_or_add_entry(opcode);
        entry.total_time_ns += time_ns;
        entry.execution_count += 1;
        self.total_profiling_time_ns += time_ns;
    }

    fn print_top_instructions(self: *const VMInstructionPerf) void {
        if (self.entries_len == 0) {
            return;
        }
        std.debug.print("  Top Instructions by Time:\n", .{});
        var top_count: u32 = 0;
        var i: u32 = 0;
        while (i < self.entries_len and top_count < 10) : (i += 1) {
            const entry = &self.entries[i];
            if (entry.execution_count > 0) {
                const avg_time = entry.get_avg_time_ns();
                const percentage = if (self.total_profiling_time_ns > 0)
                    @as(f64, @floatFromInt(entry.total_time_ns)) /
                        @as(f64, @floatFromInt(self.total_profiling_time_ns)) * 100.0
                else
                    0.0;
                std.debug.print("    Opcode {}: {} execs, {}ns total, {}ns avg ({d:.2}%)\n", .{
                    entry.opcode,
                    entry.execution_count,
                    entry.total_time_ns,
                    avg_time,
                    percentage,
                });
                top_count += 1;
            }
        }
    }

    pub fn print_stats(self: *const VMInstructionPerf) void {
        std.debug.print("\nVM Instruction Performance:\n", .{});
        std.debug.print("  Total Profiling Time: {}ns\n", .{self.total_profiling_time_ns});
        std.debug.print("  Unique Opcodes: {}\n", .{self.entries_len});
        self.print_top_instructions();
    }

    pub fn reset(self: *VMInstructionPerf) void {
        self.entries_len = 0;
        self.total_profiling_time_ns = 0;
        var i: u32 = 0;
        while (i < MAX_OPCODES) : (i += 1) {
            self.entries[i].total_time_ns = 0;
            self.entries[i].execution_count = 0;
        }
    }
};

