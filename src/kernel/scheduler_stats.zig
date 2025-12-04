//! Scheduler Statistics Tracking System
//!
//! Objective: Track scheduler behavior and performance for monitoring.
//! Why: Monitor scheduling decisions, preemptions, and context switches.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track total scheduling decisions
//! - Track preemptions and context switches
//! - Track priority-based vs round-robin selections
//! - Track time slice expirations
//! - Provide statistics interface for querying scheduler data
//! - Reset capability for new measurement periods
//!
//! GrainStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded counters: fixed-size counters (no overflow issues)
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-12-03
//! GrainStyle: Comprehensive scheduler tracking, deterministic behavior, explicit limits

const std = @import("std");
const Debug = @import("debug.zig");

/// Scheduler statistics tracker.
/// Why: Track scheduler behavior and performance metrics.
/// GrainStyle: Static allocation, bounded counters, explicit types.
pub const SchedulerStats = struct {
    /// Total scheduling decisions made.
    /// Why: Track how many times scheduler selected a process.
    total_scheduling_decisions: u64,
    
    /// Total preemptions (time slice expirations).
    /// Why: Track how many times processes were preempted.
    total_preemptions: u64,
    
    /// Total context switches (process switches).
    /// Why: Track how many times scheduler switched processes.
    total_context_switches: u64,
    
    /// Total processes scheduled.
    /// Why: Track how many unique processes were scheduled.
    total_processes_scheduled: u64,
    
    /// Total priority-based selections.
    /// Why: Track how many times priority-based selection was used.
    priority_based_selections: u64,
    
    /// Total round-robin selections.
    /// Why: Track how many times round-robin selection was used.
    round_robin_selections: u64,
    
    /// Total time slice expirations.
    /// Why: Track how many times time slices expired.
    time_slice_expirations: u64,
    
    /// Initialize scheduler statistics.
    /// Why: Set up statistics tracker with zero counters.
    pub fn init() SchedulerStats {
        return SchedulerStats{
            .total_scheduling_decisions = 0,
            .total_preemptions = 0,
            .total_context_switches = 0,
            .total_processes_scheduled = 0,
            .priority_based_selections = 0,
            .round_robin_selections = 0,
            .time_slice_expirations = 0,
        };
    }
    
    /// Record a scheduling decision.
    /// Why: Track when scheduler selects a process.
    pub fn record_scheduling_decision(self: *SchedulerStats) void {
        self.total_scheduling_decisions += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_scheduling_decisions > 0, "Counter not incremented", .{});
    }
    
    /// Record a preemption.
    /// Why: Track when a process is preempted.
    pub fn record_preemption(self: *SchedulerStats) void {
        self.total_preemptions += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_preemptions > 0, "Counter not incremented", .{});
    }
    
    /// Record a context switch.
    /// Why: Track when scheduler switches to a different process.
    pub fn record_context_switch(self: *SchedulerStats) void {
        self.total_context_switches += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_context_switches > 0, "Counter not incremented", .{});
    }
    
    /// Record a process scheduled.
    /// Why: Track when a process is scheduled for execution.
    pub fn record_process_scheduled(self: *SchedulerStats) void {
        self.total_processes_scheduled += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.total_processes_scheduled > 0, "Counter not incremented", .{});
    }
    
    /// Record a priority-based selection.
    /// Why: Track when priority-based selection is used.
    pub fn record_priority_selection(self: *SchedulerStats) void {
        self.priority_based_selections += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.priority_based_selections > 0, "Counter not incremented", .{});
    }
    
    /// Record a round-robin selection.
    /// Why: Track when round-robin selection is used.
    pub fn record_round_robin_selection(self: *SchedulerStats) void {
        self.round_robin_selections += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.round_robin_selections > 0, "Counter not incremented", .{});
    }
    
    /// Record a time slice expiration.
    /// Why: Track when a time slice expires.
    pub fn record_time_slice_expiration(self: *SchedulerStats) void {
        self.time_slice_expirations += 1;
        
        // Assert: Counter must be incremented (postcondition).
        Debug.kassert(self.time_slice_expirations > 0, "Counter not incremented", .{});
    }
    
    /// Print scheduler statistics.
    /// Why: Display scheduler behavior metrics for monitoring.
    pub fn print_stats(self: *const SchedulerStats) void {
        std.debug.print("\nScheduler Statistics:\n", .{});
        std.debug.print("  Total Scheduling Decisions: {}\n", .{self.total_scheduling_decisions});
        std.debug.print("  Total Preemptions: {}\n", .{self.total_preemptions});
        std.debug.print("  Total Context Switches: {}\n", .{self.total_context_switches});
        std.debug.print("  Total Processes Scheduled: {}\n", .{self.total_processes_scheduled});
        std.debug.print("  Priority-Based Selections: {}\n", .{self.priority_based_selections});
        std.debug.print("  Round-Robin Selections: {}\n", .{self.round_robin_selections});
        std.debug.print("  Time Slice Expirations: {}\n", .{self.time_slice_expirations});
        
        // Calculate percentages if applicable.
        if (self.total_scheduling_decisions > 0) {
            const priority_pct = @as(f64, @floatFromInt(self.priority_based_selections)) /
                @as(f64, @floatFromInt(self.total_scheduling_decisions)) * 100.0;
            const round_robin_pct = @as(f64, @floatFromInt(self.round_robin_selections)) /
                @as(f64, @floatFromInt(self.total_scheduling_decisions)) * 100.0;
            std.debug.print("  Priority Selection Rate: {d:.2}%\n", .{priority_pct});
            std.debug.print("  Round-Robin Selection Rate: {d:.2}%\n", .{round_robin_pct});
        }
    }
    
    /// Reset all statistics.
    /// Why: Clear counters for new measurement period.
    pub fn reset(self: *SchedulerStats) void {
        self.total_scheduling_decisions = 0;
        self.total_preemptions = 0;
        self.total_context_switches = 0;
        self.total_processes_scheduled = 0;
        self.priority_based_selections = 0;
        self.round_robin_selections = 0;
        self.time_slice_expirations = 0;
        
        // Assert: All counters must be zero (postcondition).
        Debug.kassert(self.total_scheduling_decisions == 0, "Counter not reset", .{});
        Debug.kassert(self.total_preemptions == 0, "Counter not reset", .{});
        Debug.kassert(self.total_context_switches == 0, "Counter not reset", .{});
    }
};

// Test: scheduler statistics initialization.
test "scheduler stats init" {
    const stats = SchedulerStats.init();
    
    // Assert: All counters must be zero.
    try std.testing.expect(stats.total_scheduling_decisions == 0);
    try std.testing.expect(stats.total_preemptions == 0);
    try std.testing.expect(stats.total_context_switches == 0);
}

// Test: scheduler statistics recording.
test "scheduler stats recording" {
    var stats = SchedulerStats.init();
    
    stats.record_scheduling_decision();
    try std.testing.expect(stats.total_scheduling_decisions == 1);
    
    stats.record_preemption();
    try std.testing.expect(stats.total_preemptions == 1);
    
    stats.record_context_switch();
    try std.testing.expect(stats.total_context_switches == 1);
}

// Test: scheduler statistics reset.
test "scheduler stats reset" {
    var stats = SchedulerStats.init();
    
    stats.record_scheduling_decision();
    stats.record_preemption();
    stats.reset();
    
    // Assert: All counters must be zero after reset.
    try std.testing.expect(stats.total_scheduling_decisions == 0);
    try std.testing.expect(stats.total_preemptions == 0);
}

