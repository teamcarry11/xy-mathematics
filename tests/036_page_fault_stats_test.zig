//! Page Fault Statistics Tests
//! Why: Comprehensive TigerStyle tests for page fault statistics tracking.
//! Grain Style: Explicit types (u32/u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const page_fault_stats = @import("page_fault_stats");
const PageFaultStats = page_fault_stats.PageFaultStats;
const PageFaultType = page_fault_stats.PageFaultType;
const PageFaultStatsSnapshot = page_fault_stats.PageFaultStatsSnapshot;

// Test page fault statistics initialization.
test "page fault stats init" {
    const stats = PageFaultStats.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Assert: All counters must be zero initially (postcondition).
    try std.testing.expect(stats.get_total_count() == 0);
    try std.testing.expect(stats.get_count(.instruction) == 0);
    try std.testing.expect(stats.get_count(.load) == 0);
    try std.testing.expect(stats.get_count(.store) == 0);
}

// Test page fault statistics record instruction page fault.
test "page fault stats record instruction" {
    var stats = PageFaultStats.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Record instruction page fault.
    const fault_addr: u64 = 0x80000000;
    stats.record_page_fault(.instruction, fault_addr);
    
    // Assert: Instruction page fault count must be incremented (postcondition).
    try std.testing.expect(stats.get_count(.instruction) == 1);
    try std.testing.expect(stats.get_total_count() == 1);
}

// Test page fault statistics record load page fault.
test "page fault stats record load" {
    var stats = PageFaultStats.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Record load page fault.
    const fault_addr: u64 = 0x100000;
    stats.record_page_fault(.load, fault_addr);
    
    // Assert: Load page fault count must be incremented (postcondition).
    try std.testing.expect(stats.get_count(.load) == 1);
    try std.testing.expect(stats.get_total_count() == 1);
}

// Test page fault statistics record store page fault.
test "page fault stats record store" {
    var stats = PageFaultStats.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Record store page fault.
    const fault_addr: u64 = 0x100000;
    stats.record_page_fault(.store, fault_addr);
    
    // Assert: Store page fault count must be incremented (postcondition).
    try std.testing.expect(stats.get_count(.store) == 1);
    try std.testing.expect(stats.get_total_count() == 1);
}

// Test page fault statistics multiple faults.
test "page fault stats multiple faults" {
    var stats = PageFaultStats.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Record multiple page faults.
    stats.record_page_fault(.instruction, 0x80000000);
    stats.record_page_fault(.load, 0x100000);
    stats.record_page_fault(.store, 0x200000);
    stats.record_page_fault(.load, 0x300000);
    
    // Assert: All counts must be correct (postcondition).
    try std.testing.expect(stats.get_count(.instruction) == 1);
    try std.testing.expect(stats.get_count(.load) == 2);
    try std.testing.expect(stats.get_count(.store) == 1);
    try std.testing.expect(stats.get_total_count() == 4);
}

// Test page fault statistics reset.
test "page fault stats reset" {
    var stats = PageFaultStats.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Record some page faults.
    stats.record_page_fault(.instruction, 0x80000000);
    stats.record_page_fault(.load, 0x100000);
    
    // Assert: Counts must be non-zero (precondition).
    try std.testing.expect(stats.get_total_count() > 0);
    
    // Reset statistics.
    stats.reset();
    
    // Assert: All counts must be zero after reset (postcondition).
    try std.testing.expect(stats.get_total_count() == 0);
    try std.testing.expect(stats.get_count(.instruction) == 0);
    try std.testing.expect(stats.get_count(.load) == 0);
    try std.testing.expect(stats.get_count(.store) == 0);
}

// Test page fault statistics snapshot.
test "page fault stats snapshot" {
    var stats = PageFaultStats.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Record some page faults.
    stats.record_page_fault(.instruction, 0x80000000);
    stats.record_page_fault(.load, 0x100000);
    stats.record_page_fault(.store, 0x200000);
    
    // Create snapshot.
    const snapshot = PageFaultStatsSnapshot.create(&stats);
    
    // Assert: Snapshot must have correct counts (postcondition).
    try std.testing.expect(snapshot.instruction_count == 1);
    try std.testing.expect(snapshot.load_count == 1);
    try std.testing.expect(snapshot.store_count == 1);
    try std.testing.expect(snapshot.total_count == 3);
}

// Test page fault statistics recent addresses.
test "page fault stats recent addresses" {
    var stats = PageFaultStats.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Record page faults with different addresses.
    stats.record_page_fault(.load, 0x100000);
    stats.record_page_fault(.load, 0x200000);
    stats.record_page_fault(.load, 0x300000);
    
    // Get recent addresses.
    const recent = stats.get_recent_addresses();
    
    // Assert: Recent addresses must be tracked (postcondition).
    try std.testing.expect(recent.len == 16); // MAX_RECENT_FAULTS
    try std.testing.expect(recent[0] == 0x100000);
    try std.testing.expect(recent[1] == 0x200000);
    try std.testing.expect(recent[2] == 0x300000);
}

