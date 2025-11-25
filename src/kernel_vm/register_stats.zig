//! VM Register Usage Statistics Tracking System
//!
//! Objective: Track register read/write frequency for register usage analysis.
//! Why: Monitor which registers are used most, identify register pressure, optimize register allocation.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track read count per register (0-31)
//! - Track write count per register (0-31)
//! - Track total register operations
//! - Calculate register usage percentages
//! - Provide statistics interface for querying register data
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
//! GrainStyle: Comprehensive register tracking, deterministic behavior, explicit limits

const std = @import("std");

// Bounded: Number of registers in RISC-V (32 general-purpose registers).
pub const NUM_REGISTERS: u32 = 32;

// Register usage entry: tracks read/write counts for a register.
pub const RegisterEntry = struct {
    register_num: u32,
    read_count: u64,
    write_count: u64,

    pub fn init(register_num: u32) RegisterEntry {
        std.debug.assert(register_num < NUM_REGISTERS);
        return RegisterEntry{
            .register_num = register_num,
            .read_count = 0,
            .write_count = 0,
        };
    }

    fn get_total_ops(self: *const RegisterEntry) u64 {
        return self.read_count + self.write_count;
    }
};

// VM register statistics tracker.
pub const VMRegisterStats = struct {
    entries: [NUM_REGISTERS]RegisterEntry,
    total_reads: u64,
    total_writes: u64,

    pub fn init() VMRegisterStats {
        var stats = VMRegisterStats{
            .entries = undefined,
            .total_reads = 0,
            .total_writes = 0,
        };
        var i: u32 = 0;
        while (i < NUM_REGISTERS) : (i += 1) {
            stats.entries[i] = RegisterEntry.init(i);
        }
        return stats;
    }

    pub fn record_read(self: *VMRegisterStats, register_num: u32) void {
        std.debug.assert(register_num < NUM_REGISTERS);
        self.total_reads += 1;
        self.entries[register_num].read_count += 1;
    }

    pub fn record_write(self: *VMRegisterStats, register_num: u32) void {
        std.debug.assert(register_num < NUM_REGISTERS);
        self.total_writes += 1;
        self.entries[register_num].write_count += 1;
    }

    fn print_top_registers(self: *const VMRegisterStats) void {
        const total_ops = self.total_reads + self.total_writes;
        if (total_ops == 0) {
            return;
        }
        std.debug.print("  Top Registers:\n", .{});
        var top_count: u32 = 0;
        var i: u32 = 0;
        while (i < NUM_REGISTERS and top_count < 10) : (i += 1) {
            const entry = &self.entries[i];
            const ops = entry.get_total_ops();
            if (ops > 0) {
                const percentage = @as(f64, @floatFromInt(ops)) /
                    @as(f64, @floatFromInt(total_ops)) * 100.0;
                std.debug.print("    x{}: {} reads, {} writes ({d:.2}%)\n", .{
                    entry.register_num,
                    entry.read_count,
                    entry.write_count,
                    percentage,
                });
                top_count += 1;
            }
        }
    }

    pub fn print_stats(self: *const VMRegisterStats) void {
        std.debug.print("\nVM Register Statistics:\n", .{});
        std.debug.print("  Total Reads: {}\n", .{self.total_reads});
        std.debug.print("  Total Writes: {}\n", .{self.total_writes});
        const total_ops = self.total_reads + self.total_writes;
        std.debug.print("  Total Operations: {}\n", .{total_ops});
        if (total_ops > 0) {
            const read_pct = @as(f64, @floatFromInt(self.total_reads)) /
                @as(f64, @floatFromInt(total_ops)) * 100.0;
            const write_pct = @as(f64, @floatFromInt(self.total_writes)) /
                @as(f64, @floatFromInt(total_ops)) * 100.0;
            std.debug.print("  Read/Write Ratio: {d:.2}% reads, {d:.2}% writes\n", .{
                read_pct,
                write_pct,
            });
        }
        self.print_top_registers();
    }

    pub fn reset(self: *VMRegisterStats) void {
        self.total_reads = 0;
        self.total_writes = 0;
        var i: u32 = 0;
        while (i < NUM_REGISTERS) : (i += 1) {
            self.entries[i].read_count = 0;
            self.entries[i].write_count = 0;
        }
    }
};

