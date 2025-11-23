//! Memory Usage Statistics Tests
//! Why: Comprehensive TigerStyle tests for memory usage statistics tracking.
//! Grain Style: Explicit types (u32/u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const memory_stats = @import("memory_stats");
const MemoryStats = memory_stats.MemoryStats;
const MemoryStatsSnapshot = memory_stats.MemoryStatsSnapshot;
const page_table = @import("page_table");
const PageTable = page_table.PageTable;
const PageFlags = page_table.PageFlags;
const PAGE_SIZE = page_table.PAGE_SIZE;

// Test memory statistics initialization.
test "memory stats init" {
    const stats = MemoryStats.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Assert: All counters must be zero initially (postcondition).
    try std.testing.expect(stats.total_memory_bytes == 0);
    try std.testing.expect(stats.mapped_pages == 0);
    try std.testing.expect(stats.unmapped_pages == 1024); // MAX_PAGES
    try std.testing.expect(stats.total_mappings == 0);
}

// Test memory statistics update from page table.
test "memory stats update from page table" {
    var stats = MemoryStats.init();
    var table = PageTable.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Map 2 pages with read/write permissions.
    const addr: u64 = 0x100000;
    const size: u64 = 2 * PAGE_SIZE;
    const flags = PageFlags.init(.{ .read = true, .write = true, .execute = false });
    table.map_pages(addr, size, flags);
    
    // Update statistics from page table.
    const total_memory: u64 = 4 * 1024 * 1024; // 4MB
    stats.update_from_page_table(&table, total_memory);
    
    // Assert: Statistics must be updated correctly (postcondition).
    try std.testing.expect(stats.total_memory_bytes == total_memory);
    try std.testing.expect(stats.mapped_pages == 2);
    try std.testing.expect(stats.unmapped_pages == 1022); // 1024 - 2
    try std.testing.expect(stats.pages_read == 2);
    try std.testing.expect(stats.pages_write == 2);
    try std.testing.expect(stats.pages_execute == 0);
}

// Test memory statistics update mapping count.
test "memory stats update mapping count" {
    var stats = MemoryStats.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Update mapping count.
    const mapping_count: u32 = 5;
    stats.update_mapping_count(mapping_count);
    
    // Assert: Mapping count must be updated correctly (postcondition).
    try std.testing.expect(stats.total_mappings == mapping_count);
}

// Test memory statistics usage percentage.
test "memory stats usage percentage" {
    var stats = MemoryStats.init();
    var table = PageTable.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Map 1 page (4KB).
    const addr: u64 = 0x100000;
    const size: u64 = PAGE_SIZE;
    const flags = PageFlags.init(.{ .read = true, .write = true, .execute = false });
    table.map_pages(addr, size, flags);
    
    // Update statistics.
    const total_memory: u64 = 4 * 1024 * 1024; // 4MB
    stats.update_from_page_table(&table, total_memory);
    
    // Get usage percentage.
    const usage_percent = stats.get_usage_percentage();
    
    // Assert: Usage percentage must be valid (postcondition).
    try std.testing.expect(usage_percent >= 0.0);
    try std.testing.expect(usage_percent <= 100.0);
    // 4KB / 4MB = 0.1%
    try std.testing.expect(usage_percent > 0.0);
    try std.testing.expect(usage_percent < 1.0);
}

// Test memory statistics fragmentation ratio.
test "memory stats fragmentation ratio" {
    var stats = MemoryStats.init();
    var table = PageTable.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Map 1 page.
    const addr: u64 = 0x100000;
    const size: u64 = PAGE_SIZE;
    const flags = PageFlags.init(.{ .read = true, .write = true, .execute = false });
    table.map_pages(addr, size, flags);
    
    // Update statistics.
    const total_memory: u64 = 4 * 1024 * 1024; // 4MB
    stats.update_from_page_table(&table, total_memory);
    
    // Get fragmentation ratio.
    const fragmentation = stats.get_fragmentation_ratio();
    
    // Assert: Fragmentation ratio must be valid (postcondition).
    try std.testing.expect(fragmentation >= 0.0);
    try std.testing.expect(fragmentation <= 1.0);
    // 1023 unmapped / 1024 total = ~0.999
    try std.testing.expect(fragmentation > 0.9);
}

// Test memory statistics reset.
test "memory stats reset" {
    var stats = MemoryStats.init();
    var table = PageTable.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Map some pages and update statistics.
    const addr: u64 = 0x100000;
    const size: u64 = PAGE_SIZE;
    const flags = PageFlags.init(.{ .read = true, .write = true, .execute = false });
    table.map_pages(addr, size, flags);
    
    const total_memory: u64 = 4 * 1024 * 1024;
    stats.update_from_page_table(&table, total_memory);
    stats.update_mapping_count(1);
    
    // Assert: Statistics must be non-zero (precondition).
    try std.testing.expect(stats.mapped_pages > 0);
    try std.testing.expect(stats.total_mappings > 0);
    
    // Reset statistics.
    stats.reset();
    
    // Assert: All counters must be reset (postcondition).
    try std.testing.expect(stats.total_memory_bytes == 0);
    try std.testing.expect(stats.mapped_pages == 0);
    try std.testing.expect(stats.unmapped_pages == 1024);
    try std.testing.expect(stats.total_mappings == 0);
}

// Test memory statistics snapshot.
test "memory stats snapshot" {
    var stats = MemoryStats.init();
    var table = PageTable.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Map some pages and update statistics.
    const addr: u64 = 0x100000;
    const size: u64 = 2 * PAGE_SIZE;
    const flags = PageFlags.init(.{ .read = true, .write = true, .execute = true });
    table.map_pages(addr, size, flags);
    
    const total_memory: u64 = 4 * 1024 * 1024;
    stats.update_from_page_table(&table, total_memory);
    stats.update_mapping_count(1);
    
    // Create snapshot.
    const snapshot = MemoryStatsSnapshot.create(&stats);
    
    // Assert: Snapshot must have correct values (postcondition).
    try std.testing.expect(snapshot.total_memory_bytes == total_memory);
    try std.testing.expect(snapshot.mapped_pages == 2);
    try std.testing.expect(snapshot.unmapped_pages == 1022);
    try std.testing.expect(snapshot.pages_read == 2);
    try std.testing.expect(snapshot.pages_write == 2);
    try std.testing.expect(snapshot.pages_execute == 2);
    try std.testing.expect(snapshot.total_mappings == 1);
    try std.testing.expect(snapshot.usage_percentage >= 0.0);
    try std.testing.expect(snapshot.fragmentation_ratio >= 0.0);
}

// Test memory statistics multiple mappings.
test "memory stats multiple mappings" {
    var stats = MemoryStats.init();
    var table = PageTable.init();
    
    // Assert: Statistics tracker must be initialized (precondition).
    try std.testing.expect(stats.initialized);
    
    // Map multiple pages at different addresses.
    table.map_pages(0x100000, PAGE_SIZE, PageFlags.init(.{ .read = true, .write = false, .execute = false }));
    table.map_pages(0x200000, PAGE_SIZE, PageFlags.init(.{ .read = true, .write = true, .execute = false }));
    table.map_pages(0x300000, PAGE_SIZE, PageFlags.init(.{ .read = true, .write = true, .execute = true }));
    
    // Update statistics.
    const total_memory: u64 = 4 * 1024 * 1024;
    stats.update_from_page_table(&table, total_memory);
    stats.update_mapping_count(3);
    
    // Assert: Statistics must reflect multiple mappings (postcondition).
    try std.testing.expect(stats.mapped_pages == 3);
    try std.testing.expect(stats.unmapped_pages == 1021);
    try std.testing.expect(stats.pages_read == 3);
    try std.testing.expect(stats.pages_write == 2);
    try std.testing.expect(stats.pages_execute == 1);
    try std.testing.expect(stats.total_mappings == 3);
}

