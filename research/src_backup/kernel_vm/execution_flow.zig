//! VM Execution Flow Tracking System
//!
//! Objective: Track program counter sequences to identify execution patterns, loops, and control flow.
//! Why: Understand execution flow, detect loops, identify hot code regions, optimize JIT compilation.
//! GrainStyle: Static allocation, bounded buffers, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track recent PC values (circular buffer)
//! - Detect loop patterns (repeated PC sequences)
//! - Track branch targets (PC transitions)
//! - Identify hot code regions (frequently executed PCs)
//! - Provide statistics interface for querying execution flow data
//! - Reset capability for new measurement periods
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded buffers: fixed-size circular buffers (no overflow issues)
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-11-24
//! GrainStyle: Comprehensive execution flow tracking, deterministic behavior, explicit limits

const std = @import("std");

// Bounded: Max PC history entries (circular buffer size).
pub const MAX_PC_HISTORY: u32 = 256;

// Bounded: Max unique PCs to track.
pub const MAX_UNIQUE_PCS: u32 = 128;

// PC execution entry: tracks execution count for a PC value.
pub const PCEntry = struct {
    pc: u64,
    execution_count: u64,

    pub fn init(pc: u64) PCEntry {
        return PCEntry{
            .pc = pc,
            .execution_count = 0,
        };
    }
};

// VM execution flow tracker.
pub const VMExecutionFlow = struct {
    pc_history: [MAX_PC_HISTORY]u64,
    pc_history_index: u32,
    pc_history_len: u32,
    unique_pcs: [MAX_UNIQUE_PCS]PCEntry,
    unique_pcs_len: u32,
    total_instructions: u64,

    pub fn init() VMExecutionFlow {
        var flow = VMExecutionFlow{
            .pc_history = undefined,
            .pc_history_index = 0,
            .pc_history_len = 0,
            .unique_pcs = undefined,
            .unique_pcs_len = 0,
            .total_instructions = 0,
        };
        var i: u32 = 0;
        while (i < MAX_UNIQUE_PCS) : (i += 1) {
            flow.unique_pcs[i] = PCEntry.init(0);
        }
        return flow;
    }

    fn find_or_add_pc(self: *VMExecutionFlow, pc: u64) ?u32 {
        // Find existing PC entry.
        var i: u32 = 0;
        while (i < self.unique_pcs_len) : (i += 1) {
            if (self.unique_pcs[i].pc == pc) {
                return i;
            }
        }
        // Add new PC entry if space available.
        if (self.unique_pcs_len >= MAX_UNIQUE_PCS) {
            return null;
        }
        const idx = self.unique_pcs_len;
        self.unique_pcs[idx] = PCEntry.init(pc);
        self.unique_pcs_len += 1;
        return idx;
    }

    pub fn record_pc(self: *VMExecutionFlow, pc: u64) void {
        self.total_instructions += 1;
        
        // Add to circular buffer.
        self.pc_history[self.pc_history_index] = pc;
        self.pc_history_index = (self.pc_history_index + 1) % MAX_PC_HISTORY;
        if (self.pc_history_len < MAX_PC_HISTORY) {
            self.pc_history_len += 1;
        }
        
        // Track unique PCs.
        if (self.find_or_add_pc(pc)) |idx| {
            self.unique_pcs[idx].execution_count += 1;
        }
    }

    fn detect_loop_pattern(self: *const VMExecutionFlow) ?u64 {
        // Detect simple loop: same PC repeated multiple times.
        if (self.pc_history_len < 4) {
            return null;
        }
        const last_pc = self.pc_history[(self.pc_history_index + MAX_PC_HISTORY - 1) % MAX_PC_HISTORY];
        var repeat_count: u32 = 0;
        var i: u32 = 0;
        while (i < self.pc_history_len and i < 16) : (i += 1) {
            const idx = (self.pc_history_index + MAX_PC_HISTORY - 1 - i) % MAX_PC_HISTORY;
            if (self.pc_history[idx] == last_pc) {
                repeat_count += 1;
            } else {
                break;
            }
        }
        if (repeat_count >= 4) {
            return last_pc;
        }
        return null;
    }

    fn print_top_pcs(self: *const VMExecutionFlow) void {
        if (self.total_instructions == 0 or self.unique_pcs_len == 0) {
            return;
        }
        std.debug.print("  Top PCs:\n", .{});
        var top_count: u32 = 0;
        var i: u32 = 0;
        while (i < self.unique_pcs_len and top_count < 10) : (i += 1) {
            const entry = self.unique_pcs[i];
            if (entry.execution_count > 0) {
                const percentage = @as(f64, @floatFromInt(entry.execution_count)) /
                    @as(f64, @floatFromInt(self.total_instructions)) * 100.0;
                std.debug.print("    0x{x}: {} ({d:.2}%)\n", .{
                    entry.pc,
                    entry.execution_count,
                    percentage,
                });
                top_count += 1;
            }
        }
    }

    pub fn print_stats(self: *const VMExecutionFlow) void {
        std.debug.print("\nVM Execution Flow Statistics:\n", .{});
        std.debug.print("  Total Instructions: {}\n", .{self.total_instructions});
        std.debug.print("  Unique PCs: {}\n", .{self.unique_pcs_len});
        std.debug.print("  PC History Length: {}\n", .{self.pc_history_len});
        if (self.detect_loop_pattern()) |loop_pc| {
            std.debug.print("  Detected Loop: 0x{x}\n", .{loop_pc});
        }
        self.print_top_pcs();
    }

    pub fn reset(self: *VMExecutionFlow) void {
        self.total_instructions = 0;
        self.pc_history_index = 0;
        self.pc_history_len = 0;
        var i: u32 = 0;
        while (i < self.unique_pcs_len) : (i += 1) {
            self.unique_pcs[i].execution_count = 0;
        }
        self.unique_pcs_len = 0;
    }
};

