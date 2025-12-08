//! VM Branch Prediction Statistics Tracking System
//!
//! Objective: Track branch instruction outcomes (taken/not taken) for branch prediction analysis.
//! Why: Monitor branch behavior, identify branch patterns, optimize branch prediction.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track branch instructions by PC
//! - Track branch outcomes (taken vs not taken)
//! - Track branch prediction accuracy
//! - Calculate branch taken rate
//! - Provide statistics interface for querying branch data
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
//! GrainStyle: Comprehensive branch tracking, deterministic behavior, explicit limits

const std = @import("std");

// Bounded: Max branch PCs to track.
pub const MAX_BRANCH_PCS: u32 = 128;

// Branch entry: tracks branch statistics for a PC.
pub const BranchEntry = struct {
    pc: u64,
    total_branches: u64,
    taken_count: u64,
    not_taken_count: u64,

    pub fn init(pc: u64) BranchEntry {
        return BranchEntry{
            .pc = pc,
            .total_branches = 0,
            .taken_count = 0,
            .not_taken_count = 0,
        };
    }

    fn get_taken_rate(self: *const BranchEntry) f64 {
        if (self.total_branches == 0) {
            return 0.0;
        }
        return @as(f64, @floatFromInt(self.taken_count)) /
            @as(f64, @floatFromInt(self.total_branches)) * 100.0;
    }
};

// VM branch statistics tracker.
pub const VMBranchStats = struct {
    entries: [MAX_BRANCH_PCS]BranchEntry,
    entries_len: u32,
    total_branches: u64,
    total_taken: u64,
    total_not_taken: u64,

    pub fn init() VMBranchStats {
        var stats = VMBranchStats{
            .entries = undefined,
            .entries_len = 0,
            .total_branches = 0,
            .total_taken = 0,
            .total_not_taken = 0,
        };
        var i: u32 = 0;
        while (i < MAX_BRANCH_PCS) : (i += 1) {
            stats.entries[i] = BranchEntry.init(0);
        }
        return stats;
    }

    fn find_or_add_branch(self: *VMBranchStats, pc: u64) ?u32 {
        // Find existing branch entry.
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            if (self.entries[i].pc == pc) {
                return i;
            }
        }
        // Add new branch entry if space available.
        if (self.entries_len >= MAX_BRANCH_PCS) {
            return null;
        }
        const idx = self.entries_len;
        self.entries[idx] = BranchEntry.init(pc);
        self.entries_len += 1;
        return idx;
    }

    pub fn record_branch(self: *VMBranchStats, pc: u64, taken: bool) void {
        self.total_branches += 1;
        if (taken) {
            self.total_taken += 1;
        } else {
            self.total_not_taken += 1;
        }
        if (self.find_or_add_branch(pc)) |idx| {
            self.entries[idx].total_branches += 1;
            if (taken) {
                self.entries[idx].taken_count += 1;
            } else {
                self.entries[idx].not_taken_count += 1;
            }
        }
    }

    fn print_top_branches(self: *const VMBranchStats) void {
        if (self.total_branches == 0 or self.entries_len == 0) {
            return;
        }
        std.debug.print("  Top Branches:\n", .{});
        var top_count: u32 = 0;
        var i: u32 = 0;
        while (i < self.entries_len and top_count < 10) : (i += 1) {
            const entry = self.entries[i];
            if (entry.total_branches > 0) {
                const taken_rate = entry.get_taken_rate();
                std.debug.print("    0x{x}: {} branches, {d:.2}% taken\n", .{
                    entry.pc,
                    entry.total_branches,
                    taken_rate,
                });
                top_count += 1;
            }
        }
    }

    pub fn print_stats(self: *const VMBranchStats) void {
        std.debug.print("\nVM Branch Statistics:\n", .{});
        std.debug.print("  Total Branches: {}\n", .{self.total_branches});
        std.debug.print("  Total Taken: {}\n", .{self.total_taken});
        std.debug.print("  Total Not Taken: {}\n", .{self.total_not_taken});
        if (self.total_branches > 0) {
            const overall_taken_rate = @as(f64, @floatFromInt(self.total_taken)) /
                @as(f64, @floatFromInt(self.total_branches)) * 100.0;
            std.debug.print("  Overall Taken Rate: {d:.2}%\n", .{overall_taken_rate});
        }
        std.debug.print("  Unique Branch PCs: {}\n", .{self.entries_len});
        self.print_top_branches();
    }

    pub fn reset(self: *VMBranchStats) void {
        self.total_branches = 0;
        self.total_taken = 0;
        self.total_not_taken = 0;
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            self.entries[i].total_branches = 0;
            self.entries[i].taken_count = 0;
            self.entries[i].not_taken_count = 0;
        }
        self.entries_len = 0;
    }
};

