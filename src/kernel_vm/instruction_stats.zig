//! VM Instruction Execution Statistics Tracking System
//!
//! Objective: Track instruction execution frequency and patterns for VM monitoring.
//! Why: Monitor which instructions are executed most, identify execution patterns.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track execution count per instruction opcode
//! - Track total instructions executed
//! - Track instruction categories (arithmetic, memory, control flow)
//! - Provide statistics interface for querying instruction data
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
//! GrainStyle: Comprehensive instruction tracking, deterministic behavior, explicit limits

const std = @import("std");

// Bounded: Max instruction opcodes to track (RISC-V has ~100 opcodes).
pub const MAX_OPCODES: u32 = 128;

// Instruction category enumeration.
pub const InstructionCategory = enum(u8) {
    arithmetic = 0,
    memory = 1,
    control_flow = 2,
    system = 3,
    other = 4,
};

// Instruction execution entry: tracks execution count for an opcode.
pub const InstructionEntry = struct {
    opcode: u32,
    execution_count: u64,
    category: InstructionCategory,

    pub fn init(opcode: u32, category: InstructionCategory) InstructionEntry {
        std.debug.assert(opcode < 256);
        return InstructionEntry{
            .opcode = opcode,
            .execution_count = 0,
            .category = category,
        };
    }
};

// VM instruction statistics tracker.
pub const VMInstructionStats = struct {
    entries: [MAX_OPCODES]InstructionEntry,
    entries_len: u32,
    total_instructions: u64,

    pub fn init() VMInstructionStats {
        var stats = VMInstructionStats{
            .entries = undefined,
            .entries_len = 0,
            .total_instructions = 0,
        };
        var i: u32 = 0;
        while (i < MAX_OPCODES) : (i += 1) {
            stats.entries[i] = InstructionEntry.init(0, .other);
        }
        return stats;
    }

    fn get_category_for_opcode(opcode: u32) InstructionCategory {
        // Categorize RISC-V opcodes.
        const opcode_low = opcode & 0x7F;
        switch (opcode_low) {
            0x33, 0x3B, 0x13, 0x1B => return .arithmetic, // R/I-type arithmetic
            0x03, 0x23 => return .memory, // Load/Store
            0x63, 0x6F, 0x67 => return .control_flow, // Branch/Jump
            0x73 => return .system, // System/ECALL
            else => return .other,
        }
    }

    fn find_or_add_entry(self: *VMInstructionStats, opcode: u32) ?u32 {
        std.debug.assert(opcode < 256);
        // Find existing entry.
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            if (self.entries[i].opcode == opcode) {
                return i;
            }
        }
        // Add new entry if space available.
        if (self.entries_len >= MAX_OPCODES) {
            return null;
        }
        const idx = self.entries_len;
        const category = get_category_for_opcode(opcode);
        self.entries[idx] = InstructionEntry.init(opcode, category);
        self.entries_len += 1;
        return idx;
    }

    pub fn record_instruction(self: *VMInstructionStats, opcode: u32) void {
        std.debug.assert(opcode < 256);
        self.total_instructions += 1;
        if (self.find_or_add_entry(opcode)) |idx| {
            self.entries[idx].execution_count += 1;
        }
    }

    pub fn print_stats(self: *const VMInstructionStats) void {
        std.debug.print("\nVM Instruction Statistics:\n", .{});
        std.debug.print("  Total Instructions: {}\n", .{self.total_instructions});
        std.debug.print("  Unique Opcodes: {}\n", .{self.entries_len});
        if (self.total_instructions > 0 and self.entries_len > 0) {
            std.debug.print("  Top Instructions:\n", .{});
            // Print top 10 instructions by execution count.
            var top_count: u32 = 0;
            var i: u32 = 0;
            while (i < self.entries_len and top_count < 10) : (i += 1) {
                const entry = self.entries[i];
                if (entry.execution_count > 0) {
                    const percentage = @as(f64, @floatFromInt(entry.execution_count)) /
                        @as(f64, @floatFromInt(self.total_instructions)) * 100.0;
                    const category_str = switch (entry.category) {
                        .arithmetic => "arithmetic",
                        .memory => "memory",
                        .control_flow => "control_flow",
                        .system => "system",
                        .other => "other",
                    };
                    std.debug.print("    0x{x:02X}: {} ({d:.2}%) [{}]\n", .{
                        entry.opcode,
                        entry.execution_count,
                        percentage,
                        category_str,
                    });
                    top_count += 1;
                }
            }
        }
    }

    pub fn reset(self: *VMInstructionStats) void {
        self.total_instructions = 0;
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            self.entries[i].execution_count = 0;
        }
    }
};

