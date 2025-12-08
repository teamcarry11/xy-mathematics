//! Memory Usage Statistics Tracking System
//!
//! Objective: Track memory usage, mapped pages, and allocation patterns for monitoring and debugging.
//! Why: Monitor memory consumption, identify memory leaks, validate memory management, and optimize memory usage.
//! GrainStyle: Static allocation, bounded counters, explicit types, deterministic tracking.
//!
//! Methodology:
//! - Track total memory size and used memory
//! - Track number of mapped pages and unmapped pages
//! - Track memory allocation patterns (by permission type)
//! - Track memory fragmentation metrics
//! - Provide statistics interface for querying memory data
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
//! GrainStyle: Comprehensive memory tracking, deterministic behavior, explicit limits

const std = @import("std");
const Debug = @import("debug.zig");

/// Page size (4KB, standard RISC-V page size).
/// Why: Explicit constant for page size, matches RISC-V standard.
const PAGE_SIZE: u64 = 4096;

/// Maximum number of pages in VM memory (4MB / 4KB = 1024 pages).
/// Why: Bounded allocation, prevents unbounded growth.
const MAX_PAGES: u32 = 1024;

/// Memory usage statistics tracker.
/// Why: Track memory usage, mapped pages, and allocation patterns for monitoring.
/// GrainStyle: Explicit types, bounded counters, deterministic tracking.
pub const MemoryStats = struct {
    /// Total memory size in bytes.
    /// Why: Track total available memory.
    total_memory_bytes: u64 = 0,
    
    /// Number of mapped pages.
    /// Why: Track how many pages are currently mapped.
    mapped_pages: u32 = 0,
    
    /// Number of unmapped pages.
    /// Why: Track how many pages are available for allocation.
    unmapped_pages: u32 = 0,
    
    /// Pages with read permission.
    /// Why: Track memory allocation by permission type.
    pages_read: u32 = 0,
    
    /// Pages with write permission.
    /// Why: Track memory allocation by permission type.
    pages_write: u32 = 0,
    
    /// Pages with execute permission.
    /// Why: Track memory allocation by permission type.
    pages_execute: u32 = 0,
    
    /// Total number of memory mappings.
    /// Why: Track number of distinct memory regions allocated.
    total_mappings: u32 = 0,
    
    /// Whether statistics tracker is initialized.
    /// Why: Track initialization state for safety.
    initialized: bool = false,
    
    /// Initialize memory statistics tracker.
    /// Why: Set up statistics tracker state.
    /// Contract: Must be called once before use.
    pub fn init() MemoryStats {
        return MemoryStats{
            .total_memory_bytes = 0,
            .mapped_pages = 0,
            .unmapped_pages = MAX_PAGES,
            .pages_read = 0,
            .pages_write = 0,
            .pages_execute = 0,
            .total_mappings = 0,
            .initialized = true,
        };
    }
    
    /// Update statistics from page table.
    /// Why: Refresh statistics based on current page table state.
    /// Contract: Page table must be valid, statistics tracker must be initialized.
    /// Note: Uses type-erased pointer to avoid circular dependencies with page_table module.
    pub fn update_from_page_table(
        self: *MemoryStats,
        page_table_ptr: *const anyopaque,
        total_memory_bytes: u64,
    ) void {
        // Assert: Statistics tracker must be initialized (precondition).
        Debug.kassert(self.initialized, "Memory stats not initialized", .{});
        
        // Assert: Page table pointer must be valid (precondition).
        const table_ptr = @intFromPtr(page_table_ptr);
        Debug.kassert(table_ptr != 0, "Page table ptr is null", .{});
        
        // Assert: Total memory must be valid (precondition).
        Debug.kassert(total_memory_bytes > 0, "Total memory is zero", .{});
        Debug.kassert(total_memory_bytes <= 4 * 1024 * 1024, "Total memory exceeds 4MB", .{});
        
        // Reset counters.
        self.total_memory_bytes = total_memory_bytes;
        self.mapped_pages = 0;
        self.unmapped_pages = 0;
        self.pages_read = 0;
        self.pages_write = 0;
        self.pages_execute = 0;
        
        // Count pages by state and permissions.
        // Note: We access the page table structure directly via pointer casting to avoid circular dependencies.
        // The page table structure has a 'pages' field at offset 0 which is an array of PageEntry.
        // PageEntry structure: { flags: { read, write, execute, shared, _padding }, mapped: bool }
        const PageEntry = struct {
            flags: struct {
                read: bool,
                write: bool,
                execute: bool,
                shared: bool,
                _padding: u28,
            },
            mapped: bool,
        };
        
        // Access page table pages via type-erased pointer (pages array is at offset 0).
        const pages_ptr = @as(*const [MAX_PAGES]PageEntry, @ptrCast(@alignCast(page_table_ptr)));
        
        // Count pages by state and permissions.
        for (pages_ptr.*) |page| {
            if (page.mapped) {
                self.mapped_pages += 1;
                
                // Count permissions.
                if (page.flags.read) {
                    self.pages_read += 1;
                }
                if (page.flags.write) {
                    self.pages_write += 1;
                }
                if (page.flags.execute) {
                    self.pages_execute += 1;
                }
            } else {
                self.unmapped_pages += 1;
            }
        }
        
        // Assert: Page counts must be consistent (postcondition).
        Debug.kassert(self.mapped_pages + self.unmapped_pages == MAX_PAGES, "Page count mismatch", .{});
        Debug.kassert(self.mapped_pages <= MAX_PAGES, "Mapped pages exceed max", .{});
        Debug.kassert(self.unmapped_pages <= MAX_PAGES, "Unmapped pages exceed max", .{});
    }
    
    /// Update statistics from mapping count.
    /// Why: Track number of distinct memory mappings.
    /// Contract: Mapping count must be valid.
    pub fn update_mapping_count(self: *MemoryStats, mapping_count: u32) void {
        // Assert: Statistics tracker must be initialized (precondition).
        Debug.kassert(self.initialized, "Memory stats not initialized", .{});
        
        // Assert: Mapping count must be valid (precondition).
        Debug.kassert(mapping_count <= 256, "Mapping count exceeds max", .{});
        
        self.total_mappings = mapping_count;
        
        // Assert: Mapping count must be set correctly (postcondition).
        Debug.kassert(self.total_mappings == mapping_count, "Mapping count not set", .{});
    }
    
    /// Get memory usage percentage.
    /// Why: Calculate memory usage as percentage of total.
    /// Returns: Memory usage percentage (0.0 to 100.0).
    pub fn get_usage_percentage(self: *const MemoryStats) f64 {
        // Assert: Statistics tracker must be initialized (precondition).
        Debug.kassert(self.initialized, "Memory stats not initialized", .{});
        
        if (self.total_memory_bytes == 0) {
            return 0.0;
        }
        
        const mapped_bytes = @as(u64, self.mapped_pages) * PAGE_SIZE;
        const usage_percent = (@as(f64, @floatFromInt(mapped_bytes)) * 100.0) / @as(f64, @floatFromInt(self.total_memory_bytes));
        
        // Assert: Usage percentage must be valid (postcondition).
        Debug.kassert(usage_percent >= 0.0, "Usage percentage negative", .{});
        Debug.kassert(usage_percent <= 100.0, "Usage percentage exceeds 100", .{});
        
        return usage_percent;
    }
    
    /// Get memory fragmentation metric.
    /// Why: Calculate memory fragmentation (ratio of unmapped pages to total pages).
    /// Returns: Fragmentation ratio (0.0 to 1.0, higher = more fragmented).
    pub fn get_fragmentation_ratio(self: *const MemoryStats) f64 {
        // Assert: Statistics tracker must be initialized (precondition).
        Debug.kassert(self.initialized, "Memory stats not initialized", .{});
        
        if (MAX_PAGES == 0) {
            return 0.0;
        }
        
        const fragmentation = @as(f64, @floatFromInt(self.unmapped_pages)) / @as(f64, @floatFromInt(MAX_PAGES));
        
        // Assert: Fragmentation ratio must be valid (postcondition).
        Debug.kassert(fragmentation >= 0.0, "Fragmentation ratio negative", .{});
        Debug.kassert(fragmentation <= 1.0, "Fragmentation ratio exceeds 1", .{});
        
        return fragmentation;
    }
    
    /// Reset memory statistics.
    /// Why: Clear statistics for new measurement period.
    pub fn reset(self: *MemoryStats) void {
        // Assert: Statistics tracker must be initialized (precondition).
        Debug.kassert(self.initialized, "Memory stats not initialized", .{});
        
        // Reset all counters.
        self.total_memory_bytes = 0;
        self.mapped_pages = 0;
        self.unmapped_pages = MAX_PAGES;
        self.pages_read = 0;
        self.pages_write = 0;
        self.pages_execute = 0;
        self.total_mappings = 0;
        
        // Assert: All counters must be reset (postcondition).
        Debug.kassert(self.mapped_pages == 0, "Mapped pages not reset", .{});
        Debug.kassert(self.unmapped_pages == MAX_PAGES, "Unmapped pages not reset", .{});
        Debug.kassert(self.total_mappings == 0, "Total mappings not reset", .{});
    }
};

/// Memory statistics snapshot (for diagnostics).
/// Why: Capture memory statistics at a point in time.
/// GrainStyle: Static allocation, explicit types.
pub const MemoryStatsSnapshot = struct {
    /// Total memory size in bytes.
    total_memory_bytes: u64,
    /// Number of mapped pages.
    mapped_pages: u32,
    /// Number of unmapped pages.
    unmapped_pages: u32,
    /// Pages with read permission.
    pages_read: u32,
    /// Pages with write permission.
    pages_write: u32,
    /// Pages with execute permission.
    pages_execute: u32,
    /// Total number of memory mappings.
    total_mappings: u32,
    /// Memory usage percentage.
    usage_percentage: f64,
    /// Memory fragmentation ratio.
    fragmentation_ratio: f64,
    
    /// Create memory statistics snapshot.
    /// Why: Capture current memory statistics state.
    /// Contract: Memory stats must be initialized.
    pub fn create(stats: *const MemoryStats) MemoryStatsSnapshot {
        // Assert: Statistics tracker must be initialized (precondition).
        Debug.kassert(stats.initialized, "Memory stats not initialized", .{});
        
        return MemoryStatsSnapshot{
            .total_memory_bytes = stats.total_memory_bytes,
            .mapped_pages = stats.mapped_pages,
            .unmapped_pages = stats.unmapped_pages,
            .pages_read = stats.pages_read,
            .pages_write = stats.pages_write,
            .pages_execute = stats.pages_execute,
            .total_mappings = stats.total_mappings,
            .usage_percentage = stats.get_usage_percentage(),
            .fragmentation_ratio = stats.get_fragmentation_ratio(),
        };
    }
    
    /// Print memory statistics snapshot.
    /// Why: Display memory statistics for debugging.
    pub fn print(self: *const MemoryStatsSnapshot) void {
        // Assert: Snapshot must be valid (precondition).
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Snapshot ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(MemoryStatsSnapshot) == 0, "Snapshot ptr unaligned", .{});
        
        Debug.kprint("Memory Statistics:\n", .{});
        Debug.kprint("  Total memory: {d} bytes\n", .{self.total_memory_bytes});
        Debug.kprint("  Mapped pages: {d}\n", .{self.mapped_pages});
        Debug.kprint("  Unmapped pages: {d}\n", .{self.unmapped_pages});
        Debug.kprint("  Pages with read: {d}\n", .{self.pages_read});
        Debug.kprint("  Pages with write: {d}\n", .{self.pages_write});
        Debug.kprint("  Pages with execute: {d}\n", .{self.pages_execute});
        Debug.kprint("  Total mappings: {d}\n", .{self.total_mappings});
        Debug.kprint("  Usage percentage: {d:.2}%\n", .{self.usage_percentage});
        Debug.kprint("  Fragmentation ratio: {d:.3}\n", .{self.fragmentation_ratio});
    }
};

