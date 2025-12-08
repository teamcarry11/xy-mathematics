//! Process Group Statistics
//! Why: Track statistics for process groups for monitoring and debugging.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

/// Process group statistics entry.
/// Why: Track statistics for a single process group.
/// Grain Style: Static allocation, explicit types.
pub const ProcessGroupStats = struct {
    /// Process group ID.
    pgid: u64,
    
    /// Number of processes in this group.
    process_count: u32,
    
    /// Total CPU time used by all processes in this group (nanoseconds).
    total_cpu_time_ns: u64,
    
    /// Total memory used by all processes in this group (bytes).
    total_memory_used: u64,
    
    /// Number of signals sent to this group.
    signals_sent: u32,
    
    /// Number of processes that have exited in this group.
    exited_count: u32,
    
    /// Whether this entry is allocated (in use).
    allocated: bool,
    
    /// Initialize empty process group statistics entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() ProcessGroupStats {
        return ProcessGroupStats{
            .pgid = 0,
            .process_count = 0,
            .total_cpu_time_ns = 0,
            .total_memory_used = 0,
            .signals_sent = 0,
            .exited_count = 0,
            .allocated = false,
        };
    }
    
    /// Reset statistics for this entry.
    /// Why: Clear statistics while keeping entry allocated.
    pub fn reset(self: *ProcessGroupStats) void {
        // Assert: Entry must be allocated.
        Debug.kassert(self.allocated, "Entry not allocated", .{});
        
        self.process_count = 0;
        self.total_cpu_time_ns = 0;
        self.total_memory_used = 0;
        self.signals_sent = 0;
        self.exited_count = 0;
    }
};

/// Maximum number of process group statistics entries.
/// Why: Bounded allocation for statistics tracking.
const MAX_PROCESS_GROUP_STATS: u32 = 64;

/// Process group statistics manager.
/// Why: Track statistics for all process groups.
/// Grain Style: Static allocation, bounded operations.
pub const ProcessGroupStatsManager = struct {
    /// Statistics entries.
    stats: [MAX_PROCESS_GROUP_STATS]ProcessGroupStats,
    
    /// Whether manager is initialized.
    initialized: bool,
    
    /// Initialize process group statistics manager.
    /// Why: Set up manager state.
    pub fn init() ProcessGroupStatsManager {
        const manager = ProcessGroupStatsManager{
            .stats = [_]ProcessGroupStats{ProcessGroupStats.init()} ** MAX_PROCESS_GROUP_STATS,
            .initialized = true,
        };
        
        return manager;
    }
    
    /// Get or create statistics entry for a process group.
    /// Why: Track statistics for a process group.
    /// Contract: pgid must be valid (non-zero).
    /// Returns: Pointer to statistics entry, or null if no free slot.
    pub fn get_or_create_stats(
        self: *ProcessGroupStatsManager,
        pgid: u64,
    ) ?*ProcessGroupStats {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Process group ID must be valid (non-zero).
        Debug.kassert(pgid != 0, "Process group ID is 0", .{});
        
        // Try to find existing entry for this process group.
        var idx: u32 = 0;
        while (idx < MAX_PROCESS_GROUP_STATS) : (idx += 1) {
            if (self.stats[idx].allocated and self.stats[idx].pgid == pgid) {
                return &self.stats[idx];
            }
        }
        
        // No existing entry found, create new one.
        idx = 0;
        while (idx < MAX_PROCESS_GROUP_STATS) : (idx += 1) {
            if (!self.stats[idx].allocated) {
                self.stats[idx].pgid = pgid;
                self.stats[idx].process_count = 0;
                self.stats[idx].total_cpu_time_ns = 0;
                self.stats[idx].total_memory_used = 0;
                self.stats[idx].signals_sent = 0;
                self.stats[idx].exited_count = 0;
                self.stats[idx].allocated = true;
                
                return &self.stats[idx];
            }
        }
        
        // No free slot found.
        return null;
    }
    
    /// Get statistics entry for a process group.
    /// Why: Retrieve statistics for a process group.
    /// Contract: pgid must be valid (non-zero).
    /// Returns: Pointer to statistics entry, or null if not found.
    pub fn get_stats(
        self: *ProcessGroupStatsManager,
        pgid: u64,
    ) ?*ProcessGroupStats {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Process group ID must be valid (non-zero).
        Debug.kassert(pgid != 0, "Process group ID is 0", .{});
        
        // Find existing entry for this process group.
        var idx: u32 = 0;
        while (idx < MAX_PROCESS_GROUP_STATS) : (idx += 1) {
            if (self.stats[idx].allocated and self.stats[idx].pgid == pgid) {
                return &self.stats[idx];
            }
        }
        
        // Entry not found.
        return null;
    }
    
    /// Update process count for a process group.
    /// Why: Track number of processes in a group.
    /// Contract: pgid must be valid (non-zero).
    pub fn update_process_count(
        self: *ProcessGroupStatsManager,
        pgid: u64,
        count: u32,
    ) void {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Process group ID must be valid (non-zero).
        Debug.kassert(pgid != 0, "Process group ID is 0", .{});
        
        const stats_entry = self.get_or_create_stats(pgid);
        if (stats_entry) |entry| {
            entry.process_count = count;
        }
    }
    
    /// Add CPU time to a process group.
    /// Why: Track CPU time usage for a process group.
    /// Contract: pgid must be valid (non-zero), cpu_time_ns must be valid.
    pub fn add_cpu_time(
        self: *ProcessGroupStatsManager,
        pgid: u64,
        cpu_time_ns: u64,
    ) void {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Process group ID must be valid (non-zero).
        Debug.kassert(pgid != 0, "Process group ID is 0", .{});
        
        const stats_entry = self.get_or_create_stats(pgid);
        if (stats_entry) |entry| {
            // Saturating add to prevent overflow.
            entry.total_cpu_time_ns = entry.total_cpu_time_ns +% cpu_time_ns;
        }
    }
    
    /// Add memory usage to a process group.
    /// Why: Track memory usage for a process group.
    /// Contract: pgid must be valid (non-zero), memory_bytes must be valid.
    pub fn add_memory_used(
        self: *ProcessGroupStatsManager,
        pgid: u64,
        memory_bytes: u64,
    ) void {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Process group ID must be valid (non-zero).
        Debug.kassert(pgid != 0, "Process group ID is 0", .{});
        
        const stats_entry = self.get_or_create_stats(pgid);
        if (stats_entry) |entry| {
            // Saturating add to prevent overflow.
            entry.total_memory_used = entry.total_memory_used +% memory_bytes;
        }
    }
    
    /// Increment signal count for a process group.
    /// Why: Track number of signals sent to a process group.
    /// Contract: pgid must be valid (non-zero).
    pub fn increment_signal_count(
        self: *ProcessGroupStatsManager,
        pgid: u64,
    ) void {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Process group ID must be valid (non-zero).
        Debug.kassert(pgid != 0, "Process group ID is 0", .{});
        
        const stats_entry = self.get_or_create_stats(pgid);
        if (stats_entry) |entry| {
            // Saturating increment to prevent overflow.
            entry.signals_sent = entry.signals_sent +% 1;
        }
    }
    
    /// Increment exited count for a process group.
    /// Why: Track number of processes that have exited in a group.
    /// Contract: pgid must be valid (non-zero).
    pub fn increment_exited_count(
        self: *ProcessGroupStatsManager,
        pgid: u64,
    ) void {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        // Assert: Process group ID must be valid (non-zero).
        Debug.kassert(pgid != 0, "Process group ID is 0", .{});
        
        const stats_entry = self.get_or_create_stats(pgid);
        if (stats_entry) |entry| {
            // Saturating increment to prevent overflow.
            entry.exited_count = entry.exited_count +% 1;
        }
    }
    
    /// Reset all statistics.
    /// Why: Clear all statistics entries.
    pub fn reset_all(self: *ProcessGroupStatsManager) void {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        var idx: u32 = 0;
        while (idx < MAX_PROCESS_GROUP_STATS) : (idx += 1) {
            if (self.stats[idx].allocated) {
                self.stats[idx].reset();
            }
        }
    }
    
    /// Print statistics for all process groups.
    /// Why: Debug output for process group statistics.
    pub fn print_stats(self: *const ProcessGroupStatsManager) void {
        // Assert: Manager must be initialized.
        Debug.kassert(self.initialized, "Manager not initialized", .{});
        
        var active_count: u32 = 0;
        var idx: u32 = 0;
        while (idx < MAX_PROCESS_GROUP_STATS) : (idx += 1) {
            if (self.stats[idx].allocated) {
                active_count += 1;
            }
        }
        
        std.debug.print("Process Group Statistics:\n", .{});
        std.debug.print("  Active groups: {d}\n", .{active_count});
        
        idx = 0;
        while (idx < MAX_PROCESS_GROUP_STATS) : (idx += 1) {
            if (self.stats[idx].allocated) {
                const entry = &self.stats[idx];
                std.debug.print("  PGID {d}:\n", .{entry.pgid});
                std.debug.print("    Processes: {d}\n", .{entry.process_count});
                std.debug.print("    CPU time: {d} ns\n", .{entry.total_cpu_time_ns});
                std.debug.print("    Memory: {d} bytes\n", .{entry.total_memory_used});
                std.debug.print("    Signals sent: {d}\n", .{entry.signals_sent});
                std.debug.print("    Exited: {d}\n", .{entry.exited_count});
            }
        }
    }
};

