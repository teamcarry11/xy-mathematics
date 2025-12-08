//! VM Syscall Execution Statistics Tracking System
//!
//! Objective: Track syscall execution frequency and patterns for VM monitoring.
//! Why: Monitor which syscalls are executed most, identify kernel usage patterns.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track execution count per syscall number
//! - Track total syscalls executed
//! - Track syscall categories (process, memory, I/O, IPC, system)
//! - Provide statistics interface for querying syscall data
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
//! GrainStyle: Comprehensive syscall tracking, deterministic behavior, explicit limits

const std = @import("std");

// Bounded: Max syscall numbers to track (kernel has ~20 syscalls).
pub const MAX_SYSCALLS: u32 = 32;

// Syscall category enumeration.
pub const SyscallCategory = enum(u8) {
    process = 0,
    memory = 1,
    io = 2,
    ipc = 3,
    system = 4,
    other = 5,
};

// Syscall execution entry: tracks execution count for a syscall number.
pub const SyscallEntry = struct {
    syscall_number: u32,
    execution_count: u64,
    category: SyscallCategory,

    pub fn init(syscall_number: u32, category: SyscallCategory) SyscallEntry {
        std.debug.assert(syscall_number < 256);
        return SyscallEntry{
            .syscall_number = syscall_number,
            .execution_count = 0,
            .category = category,
        };
    }
};

// VM syscall statistics tracker.
pub const VMSyscallStats = struct {
    entries: [MAX_SYSCALLS]SyscallEntry,
    entries_len: u32,
    total_syscalls: u64,

    pub fn init() VMSyscallStats {
        var stats = VMSyscallStats{
            .entries = undefined,
            .entries_len = 0,
            .total_syscalls = 0,
        };
        var i: u32 = 0;
        while (i < MAX_SYSCALLS) : (i += 1) {
            stats.entries[i] = SyscallEntry.init(0, .other);
        }
        return stats;
    }

    fn get_category_for_syscall(syscall_number: u32) SyscallCategory {
        // Categorize kernel syscalls.
        switch (syscall_number) {
            0, 1, 2, 3 => return .process, // spawn, exit, yield, wait
            4, 5, 6 => return .memory, // map, unmap, protect
            7, 8, 9 => return .io, // open, read, write, close
            10, 11, 12 => return .ipc, // channel_create, channel_send, channel_recv
            13, 14, 15 => return .system, // clock_gettime, sleep_until, sysinfo
            else => return .other,
        }
    }

    fn find_or_add_entry(self: *VMSyscallStats, syscall_number: u32) ?u32 {
        std.debug.assert(syscall_number < 256);
        // Find existing entry.
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            if (self.entries[i].syscall_number == syscall_number) {
                return i;
            }
        }
        // Add new entry if space available.
        if (self.entries_len >= MAX_SYSCALLS) {
            return null;
        }
        const idx = self.entries_len;
        const category = get_category_for_syscall(syscall_number);
        self.entries[idx] = SyscallEntry.init(syscall_number, category);
        self.entries_len += 1;
        return idx;
    }

    pub fn record_syscall(self: *VMSyscallStats, syscall_number: u32) void {
        std.debug.assert(syscall_number < 256);
        self.total_syscalls += 1;
        if (self.find_or_add_entry(syscall_number)) |idx| {
            self.entries[idx].execution_count += 1;
        }
    }

    fn get_category_string(category: SyscallCategory) []const u8 {
        return switch (category) {
            .process => "process",
            .memory => "memory",
            .io => "io",
            .ipc => "ipc",
            .system => "system",
            .other => "other",
        };
    }

    fn print_top_syscalls(self: *const VMSyscallStats) void {
        if (self.total_syscalls == 0 or self.entries_len == 0) {
            return;
        }
        std.debug.print("  Top Syscalls:\n", .{});
        var top_count: u32 = 0;
        var i: u32 = 0;
        while (i < self.entries_len and top_count < 10) : (i += 1) {
            const entry = self.entries[i];
            if (entry.execution_count > 0) {
                const percentage = @as(f64, @floatFromInt(entry.execution_count)) /
                    @as(f64, @floatFromInt(self.total_syscalls)) * 100.0;
                const category_str = get_category_string(entry.category);
                std.debug.print("    syscall {}: {} ({d:.2}%) [{}]\n", .{
                    entry.syscall_number,
                    entry.execution_count,
                    percentage,
                    category_str,
                });
                top_count += 1;
            }
        }
    }

    pub fn print_stats(self: *const VMSyscallStats) void {
        std.debug.print("\nVM Syscall Statistics:\n", .{});
        std.debug.print("  Total Syscalls: {}\n", .{self.total_syscalls});
        std.debug.print("  Unique Syscalls: {}\n", .{self.entries_len});
        self.print_top_syscalls();
    }

    pub fn reset(self: *VMSyscallStats) void {
        self.total_syscalls = 0;
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            self.entries[i].execution_count = 0;
        }
    }
};

