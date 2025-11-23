//! Grain Basin Memory Allocator
//! Why: Kernel-side memory allocation with page-based management.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");

/// Page size in bytes (4KB, standard RISC-V page size).
/// Why: Standard page size for RISC-V architecture.
pub const PAGE_SIZE: u64 = 4096;

/// Maximum number of pages to track.
/// Why: Bounded page table for safety and static allocation.
pub const MAX_PAGES: u32 = 1024;

/// Maximum memory pool size (4MB, matches VM memory size).
/// Why: Bounded memory pool for kernel allocations.
pub const MAX_POOL_SIZE: u64 = 4 * 1024 * 1024;

/// Page state (free or allocated).
/// Why: Explicit page state enumeration.
pub const PageState = enum(u8) {
    free = 0,
    allocated = 1,
};

/// Memory pool for kernel allocations.
/// Why: Provide kernel-side memory allocation without external allocator.
/// Grain Style: Static allocation, bounded pool, explicit types.
pub const MemoryPool = struct {
    /// Memory pool buffer (static allocation).
    /// Why: Pre-allocated memory for kernel use.
    /// Grain Style: Static allocation, max 4MB.
    buffer: [MAX_POOL_SIZE]u8,
    
    /// Page state table (tracks which pages are allocated).
    /// Why: Track page allocation state for management.
    /// Grain Style: Static allocation, max 1024 pages.
    page_states: [MAX_PAGES]PageState,
    
    /// Number of allocated pages.
    /// Why: Track allocation count for bounds checking.
    allocated_pages: u32,
    
    /// Next free page index (for simple allocation).
    /// Why: Track allocation position for sequential allocation.
    next_free_page: u32,
    
    /// Initialize memory pool.
    /// Why: Set up memory pool state.
    pub fn init() MemoryPool {
        return MemoryPool{
            .buffer = [_]u8{0} ** MAX_POOL_SIZE,
            .page_states = [_]PageState{.free} ** MAX_PAGES,
            .allocated_pages = 0,
            .next_free_page = 0,
        };
    }
    
    /// Allocate pages.
    /// Why: Allocate contiguous pages for kernel use.
    /// Contract: num_pages must be > 0, <= MAX_PAGES.
    /// Returns: Page index if allocated, null if insufficient pages.
    pub fn allocate_pages(self: *MemoryPool, num_pages: u32) ?u32 {
        // Assert: Number of pages must be > 0.
        if (num_pages == 0) {
            return null; // Invalid request
        }
        
        // Assert: Number of pages must be <= MAX_PAGES.
        if (num_pages > MAX_PAGES) {
            return null; // Too many pages
        }
        
        // Assert: Allocated pages must be <= MAX_PAGES.
        Debug.kassert(self.allocated_pages <= MAX_PAGES, "Allocated pages > MAX", .{});
        
        // Find contiguous free pages (simple first-fit algorithm).
        var start_page: ?u32 = null;
        var consecutive_free: u32 = 0;
        
        for (0..MAX_PAGES) |i| {
            const page_idx = @as(u32, @intCast(i));
            
            if (self.page_states[page_idx] == .free) {
                if (consecutive_free == 0) {
                    start_page = page_idx;
                }
                consecutive_free += 1;
                
                if (consecutive_free >= num_pages) {
                    break; // Found enough contiguous pages
                }
            } else {
                consecutive_free = 0;
                start_page = null;
            }
        }
        
        if (start_page == null or consecutive_free < num_pages) {
            return null; // Insufficient contiguous pages
        }
        
        const start = start_page.?;
        
        // Mark pages as allocated.
        for (0..num_pages) |i| {
            const page_idx = start + @as(u32, @intCast(i));
            self.page_states[page_idx] = .allocated;
        }
        
        self.allocated_pages += num_pages;
        
        // Assert: Pages must be allocated.
        for (0..num_pages) |i| {
            const page_idx = start + @as(u32, @intCast(i));
            Debug.kassert(self.page_states[page_idx] == .allocated, "Page not allocated", .{});
        }
        Debug.kassert(self.allocated_pages <= MAX_PAGES, "Allocated pages > MAX", .{});
        
        return start;
    }
    
    /// Deallocate pages.
    /// Why: Free pages for reuse.
    /// Contract: start_page must be valid, num_pages must be > 0.
    /// Returns: true if deallocated, false if invalid.
    pub fn deallocate_pages(self: *MemoryPool, start_page: u32, num_pages: u32) bool {
        // Assert: Start page must be < MAX_PAGES.
        if (start_page >= MAX_PAGES) {
            return false; // Invalid page index
        }
        
        // Assert: Number of pages must be > 0.
        if (num_pages == 0) {
            return false; // Invalid request
        }
        
        // Assert: End page must be <= MAX_PAGES.
        if (start_page + num_pages > MAX_PAGES) {
            return false; // Out of bounds
        }
        
        // Assert: Allocated pages must be >= num_pages.
        Debug.kassert(self.allocated_pages >= num_pages, "Allocated pages < num_pages", .{});
        
        // Mark pages as free.
        for (0..num_pages) |i| {
            const page_idx = start_page + @as(u32, @intCast(i));
            
            // Assert: Page must be allocated before deallocation.
            if (self.page_states[page_idx] != .allocated) {
                return false; // Page not allocated
            }
            
            self.page_states[page_idx] = .free;
        }
        
        self.allocated_pages -= num_pages;
        
        // Assert: Pages must be freed.
        for (0..num_pages) |i| {
            const page_idx = start_page + @as(u32, @intCast(i));
            Debug.kassert(self.page_states[page_idx] == .free, "Page not freed", .{});
        }
        Debug.kassert(self.allocated_pages <= MAX_PAGES, "Allocated pages > MAX", .{});
        
        return true;
    }
    
    /// Get page address.
    /// Why: Convert page index to physical address.
    /// Contract: page_idx must be < MAX_PAGES.
    /// Returns: Physical address of page.
    pub fn get_page_address(self: *const MemoryPool, page_idx: u32) u64 {
        _ = self; // Unused, but kept for consistency
        
        // Assert: Page index must be < MAX_PAGES.
        Debug.kassert(page_idx < MAX_PAGES, "Page idx >= MAX_PAGES", .{});
        
        // Calculate physical address (page index * PAGE_SIZE).
        const address = @as(u64, page_idx) * PAGE_SIZE;
        
        // Assert: Address must be within pool bounds.
        Debug.kassert(address < MAX_POOL_SIZE, "Address >= MAX_POOL_SIZE", .{});
        
        return address;
    }
    
    /// Get allocated page count.
    /// Why: Query number of allocated pages.
    /// Returns: Number of allocated pages.
    pub fn get_allocated_pages(self: *const MemoryPool) u32 {
        // Assert: Allocated pages must be <= MAX_PAGES.
        Debug.kassert(self.allocated_pages <= MAX_PAGES, "Allocated pages > MAX", .{});
        
        return self.allocated_pages;
    }
    
    /// Get free page count.
    /// Why: Query number of free pages.
    /// Returns: Number of free pages.
    pub fn get_free_pages(self: *const MemoryPool) u32 {
        // Assert: Allocated pages must be <= MAX_PAGES.
        Debug.kassert(self.allocated_pages <= MAX_PAGES, "Allocated pages > MAX", .{});
        
        const free = MAX_PAGES - self.allocated_pages;
        
        // Assert: Free pages must be <= MAX_PAGES.
        Debug.kassert(free <= MAX_PAGES, "Free pages > MAX", .{});
        
        return free;
    }
    
    /// Allocate memory (convenience function).
    /// Why: Allocate memory in bytes (converts to pages).
    /// Contract: size must be > 0, <= MAX_POOL_SIZE.
    /// Returns: Page index if allocated, null if insufficient memory.
    pub fn allocate(self: *MemoryPool, size: u64) ?u32 {
        // Assert: Size must be > 0.
        if (size == 0) {
            return null; // Invalid request
        }
        
        // Assert: Size must be <= MAX_POOL_SIZE.
        if (size > MAX_POOL_SIZE) {
            return null; // Too large
        }
        
        // Calculate number of pages needed (round up).
        const num_pages = @as(u32, @intCast((size + PAGE_SIZE - 1) / PAGE_SIZE));
        
        // Assert: Number of pages must be <= MAX_PAGES.
        Debug.kassert(num_pages <= MAX_PAGES, "Num pages > MAX", .{});
        
        return self.allocate_pages(num_pages);
    }
    
    /// Deallocate memory (convenience function).
    /// Why: Deallocate memory in bytes (converts to pages).
    /// Contract: start_page must be valid, size must be > 0.
    /// Returns: true if deallocated, false if invalid.
    pub fn deallocate(self: *MemoryPool, start_page: u32, size: u64) bool {
        // Assert: Size must be > 0.
        if (size == 0) {
            return false; // Invalid request
        }
        
        // Calculate number of pages (round up).
        const num_pages = @as(u32, @intCast((size + PAGE_SIZE - 1) / PAGE_SIZE));
        
        // Assert: Number of pages must be <= MAX_PAGES.
        Debug.kassert(num_pages <= MAX_PAGES, "Num pages > MAX", .{});
        
        return self.deallocate_pages(start_page, num_pages);
    }
};

// Test memory pool initialization.
test "memory pool init" {
    const pool = MemoryPool.init();
    
    // Assert: Pool must be initialized.
    try std.testing.expect(pool.allocated_pages == 0);
    try std.testing.expect(pool.get_free_pages() == MAX_PAGES);
    
    // Assert: All pages must be free.
    for (0..MAX_PAGES) |i| {
        try std.testing.expect(pool.page_states[i] == .free);
    }
}

// Test page allocation.
test "memory pool allocate pages" {
    var pool = MemoryPool.init();
    
    const page_idx = pool.allocate_pages(1);
    
    // Assert: Page must be allocated.
    try std.testing.expect(page_idx != null);
    try std.testing.expect(pool.get_allocated_pages() == 1);
    try std.testing.expect(pool.get_free_pages() == MAX_PAGES - 1);
}

// Test page deallocation.
test "memory pool deallocate pages" {
    var pool = MemoryPool.init();
    
    const page_idx = pool.allocate_pages(1);
    try std.testing.expect(page_idx != null);
    
    const deallocated = pool.deallocate_pages(page_idx.?, 1);
    
    // Assert: Page must be deallocated.
    try std.testing.expect(deallocated);
    try std.testing.expect(pool.get_allocated_pages() == 0);
    try std.testing.expect(pool.get_free_pages() == MAX_PAGES);
}

// Test multiple page allocation.
test "memory pool multiple pages" {
    var pool = MemoryPool.init();
    
    const page1 = pool.allocate_pages(2);
    const page2 = pool.allocate_pages(3);
    
    // Assert: Both allocations must succeed.
    try std.testing.expect(page1 != null);
    try std.testing.expect(page2 != null);
    try std.testing.expect(page1.? != page2.?);
    try std.testing.expect(pool.get_allocated_pages() == 5);
}

// Test page address calculation.
test "memory pool page address" {
    var pool = MemoryPool.init();
    
    const page_idx: u32 = 10;
    const address = pool.get_page_address(page_idx);
    
    // Assert: Address must be correct.
    try std.testing.expect(address == page_idx * PAGE_SIZE);
}

// Test allocate convenience function.
test "memory pool allocate bytes" {
    var pool = MemoryPool.init();
    
    const page_idx = pool.allocate(8192); // 2 pages
    
    // Assert: Allocation must succeed.
    try std.testing.expect(page_idx != null);
    try std.testing.expect(pool.get_allocated_pages() >= 2);
}

// Test deallocate convenience function.
test "memory pool deallocate bytes" {
    var pool = MemoryPool.init();
    
    const page_idx = pool.allocate(8192);
    try std.testing.expect(page_idx != null);
    
    const deallocated = pool.deallocate(page_idx.?, 8192);
    
    // Assert: Deallocation must succeed.
    try std.testing.expect(deallocated);
    try std.testing.expect(pool.get_allocated_pages() == 0);
}

