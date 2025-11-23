//! Page Fault Statistics Tracking System
//!
//! Objective: Track page fault counts by type for debugging and monitoring.
//! Why: Monitor page fault frequency, identify memory access patterns, and validate page table behavior.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track page fault counts by type (instruction, load, store)
//! - Track total page fault count
//! - Track page fault addresses (for debugging)
//! - Provide statistics interface for querying page fault data
//! - Reset capability for new measurement periods
//!
//! TigerStyle Principles:
//! - Explicit types: u32/u64 instead of usize
//! - Bounded counters: fixed-size counters (no overflow issues)
//! - Pair assertions: preconditions and postconditions
//! - Comments explain why: methodology and rationale documented
//! - Static allocation: no dynamic allocation after initialization
//!
//! Date: 2025-01-XX
//! GrainStyle: Comprehensive page fault tracking, deterministic behavior, explicit limits

const std = @import("std");
const Debug = @import("debug.zig");

/// Maximum number of page fault types (instruction, load, store).
/// Why: Bounded array size for page fault counters.
const MAX_PAGE_FAULT_TYPES: u32 = 3;

/// Maximum number of recent page fault addresses to track (for debugging).
/// Why: Bounded buffer for recent page fault addresses.
const MAX_RECENT_FAULTS: u32 = 16;

/// Page fault type.
/// Why: Explicit page fault types for type safety.
pub const PageFaultType = enum(u32) {
    /// Instruction page fault (code 12).
    instruction = 12,
    /// Load page fault (code 13).
    load = 13,
    /// Store page fault (code 15).
    store = 15,
};

/// Page fault statistics tracker.
/// Why: Track page fault counts by type for debugging and monitoring.
/// GrainStyle: Explicit types, bounded counters, deterministic tracking.
pub const PageFaultStats = struct {
    /// Page fault counts by type.
    /// Why: Track how many times each page fault type occurs.
    fault_counts: [MAX_PAGE_FAULT_TYPES]u64 = [_]u64{0} ** MAX_PAGE_FAULT_TYPES,
    
    /// Total page fault count (sum of all types).
    /// Why: Quick access to total page fault count.
    total_count: u64 = 0,
    
    /// Recent page fault addresses (circular buffer).
    /// Why: Track recent page fault addresses for debugging.
    recent_addresses: [MAX_RECENT_FAULTS]u64 = [_]u64{0} ** MAX_RECENT_FAULTS,
    
    /// Write index for recent addresses (circular buffer).
    /// Why: Track next position to write in circular buffer.
    recent_write_idx: u32 = 0,
    
    /// Whether statistics tracker is initialized.
    /// Why: Track initialization state for safety.
    initialized: bool = false,
    
    /// Initialize page fault statistics tracker.
    /// Why: Set up statistics tracker state.
    /// Contract: Must be called once before use.
    pub fn init() PageFaultStats {
        return PageFaultStats{
            .fault_counts = [_]u64{0} ** MAX_PAGE_FAULT_TYPES,
            .total_count = 0,
            .recent_addresses = [_]u64{0} ** MAX_RECENT_FAULTS,
            .recent_write_idx = 0,
            .initialized = true,
        };
    }
    
    /// Record page fault occurrence.
    /// Why: Track page fault for statistics.
    /// Contract: Page fault type must be valid (instruction, load, or store).
    pub fn record_page_fault(
        self: *PageFaultStats,
        fault_type: PageFaultType,
        fault_address: u64,
    ) void {
        // Assert: Statistics tracker must be initialized (precondition).
        Debug.kassert(self.initialized, "Page fault stats not initialized", .{});
        
        // Assert: Fault address must be valid (precondition).
        Debug.kassert(fault_address < 0x100000000, "Fault address out of bounds", .{});
        
        // Get fault type index (0=instruction, 1=load, 2=store).
        const fault_idx: u32 = switch (fault_type) {
            .instruction => 0,
            .load => 1,
            .store => 2,
        };
        
        // Assert: Fault index must be valid (postcondition).
        Debug.kassert(fault_idx < MAX_PAGE_FAULT_TYPES, "Fault index out of bounds", .{});
        
        // Increment page fault count for this type.
        self.fault_counts[fault_idx] += 1;
        self.total_count += 1;
        
        // Record recent page fault address (circular buffer).
        self.recent_addresses[self.recent_write_idx] = fault_address;
        self.recent_write_idx = (self.recent_write_idx + 1) % MAX_RECENT_FAULTS;
        
        // Assert: Counters must be consistent (postcondition).
        Debug.kassert(self.fault_counts[fault_idx] > 0, "Fault count not incremented", .{});
        Debug.kassert(self.total_count > 0, "Total count not incremented", .{});
        Debug.kassert(self.total_count >= self.fault_counts[fault_idx], "Total count inconsistent", .{});
    }
    
    /// Get page fault count for specific type.
    /// Why: Query page fault frequency for specific page fault type.
    /// Contract: Page fault type must be valid.
    pub fn get_count(self: *const PageFaultStats, fault_type: PageFaultType) u64 {
        // Assert: Statistics tracker must be initialized (precondition).
        Debug.kassert(self.initialized, "Page fault stats not initialized", .{});
        
        // Get fault type index.
        const fault_idx: u32 = switch (fault_type) {
            .instruction => 0,
            .load => 1,
            .store => 2,
        };
        
        // Assert: Fault index must be valid (postcondition).
        Debug.kassert(fault_idx < MAX_PAGE_FAULT_TYPES, "Fault index out of bounds", .{});
        
        const count = self.fault_counts[fault_idx];
        
        // Assert: Count must be valid (postcondition).
        Debug.kassert(count <= self.total_count, "Fault count exceeds total", .{});
        
        return count;
    }
    
    /// Get total page fault count.
    /// Why: Query total page fault frequency.
    pub fn get_total_count(self: *const PageFaultStats) u64 {
        // Assert: Statistics tracker must be initialized (precondition).
        Debug.kassert(self.initialized, "Page fault stats not initialized", .{});
        
        return self.total_count;
    }
    
    /// Get recent page fault addresses.
    /// Why: Query recent page fault addresses for debugging.
    /// Returns: Slice of recent page fault addresses (up to MAX_RECENT_FAULTS).
    pub fn get_recent_addresses(self: *const PageFaultStats) []const u64 {
        // Assert: Statistics tracker must be initialized (precondition).
        Debug.kassert(self.initialized, "Page fault stats not initialized", .{});
        
        return &self.recent_addresses;
    }
    
    /// Reset page fault statistics.
    /// Why: Clear statistics for new measurement period.
    pub fn reset(self: *PageFaultStats) void {
        // Assert: Statistics tracker must be initialized (precondition).
        Debug.kassert(self.initialized, "Page fault stats not initialized", .{});
        
        // Reset all counters.
        for (0..MAX_PAGE_FAULT_TYPES) |i| {
            self.fault_counts[i] = 0;
        }
        self.total_count = 0;
        
        // Reset recent addresses buffer.
        for (0..MAX_RECENT_FAULTS) |i| {
            self.recent_addresses[i] = 0;
        }
        self.recent_write_idx = 0;
        
        // Assert: All counters must be reset (postcondition).
        Debug.kassert(self.total_count == 0, "Total count not reset", .{});
        for (0..MAX_PAGE_FAULT_TYPES) |i| {
            Debug.kassert(self.fault_counts[i] == 0, "Fault count not reset", .{});
        }
    }
};

/// Page fault statistics snapshot (for diagnostics).
/// Why: Capture page fault statistics at a point in time.
/// GrainStyle: Static allocation, explicit types.
pub const PageFaultStatsSnapshot = struct {
    /// Instruction page fault count.
    instruction_count: u64,
    /// Load page fault count.
    load_count: u64,
    /// Store page fault count.
    store_count: u64,
    /// Total page fault count.
    total_count: u64,
    
    /// Create page fault statistics snapshot.
    /// Why: Capture current page fault statistics state.
    /// Contract: Page fault stats must be initialized.
    pub fn create(stats: *const PageFaultStats) PageFaultStatsSnapshot {
        // Assert: Statistics tracker must be initialized (precondition).
        Debug.kassert(stats.initialized, "Page fault stats not initialized", .{});
        
        return PageFaultStatsSnapshot{
            .instruction_count = stats.get_count(.instruction),
            .load_count = stats.get_count(.load),
            .store_count = stats.get_count(.store),
            .total_count = stats.get_total_count(),
        };
    }
    
    /// Print page fault statistics snapshot.
    /// Why: Display page fault statistics for debugging.
    pub fn print(self: *const PageFaultStatsSnapshot) void {
        // Assert: Snapshot must be valid (precondition).
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Snapshot ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(PageFaultStatsSnapshot) == 0, "Snapshot ptr unaligned", .{});
        
        Debug.kprint("Page Fault Statistics:\n", .{});
        Debug.kprint("  Instruction page faults: {d}\n", .{self.instruction_count});
        Debug.kprint("  Load page faults: {d}\n", .{self.load_count});
        Debug.kprint("  Store page faults: {d}\n", .{self.store_count});
        Debug.kprint("  Total page faults: {d}\n", .{self.total_count});
    }
};

