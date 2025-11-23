//! Memory Allocator Tests
//! Why: Comprehensive TigerStyle tests for memory allocator functionality.
//! Grain Style: Explicit types (u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const basin_kernel = @import("basin_kernel");
const MemoryPool = basin_kernel.basin_kernel.MemoryPool;
const PAGE_SIZE = basin_kernel.basin_kernel.PAGE_SIZE;
const MAX_PAGES = basin_kernel.basin_kernel.MAX_PAGES;
const BasinKernel = basin_kernel.BasinKernel;

// Test memory pool initialization.
test "memory pool init" {
    const pool = MemoryPool.init();
    
    // Assert: Pool must be initialized.
    try std.testing.expect(pool.allocated_pages == 0);
    try std.testing.expect(pool.get_free_pages() == MAX_PAGES);
    try std.testing.expect(pool.get_allocated_pages() == 0);
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

// Test contiguous page allocation.
test "memory pool contiguous pages" {
    var pool = MemoryPool.init();
    
    const page_idx = pool.allocate_pages(5);
    
    // Assert: Contiguous pages must be allocated.
    try std.testing.expect(page_idx != null);
    try std.testing.expect(pool.get_allocated_pages() == 5);
    
    // Verify pages are contiguous.
    const start = page_idx.?;
    for (0..5) |i| {
        const page_addr = pool.get_page_address(start + @as(u32, @intCast(i)));
        try std.testing.expect(page_addr == (start + @as(u32, @intCast(i))) * PAGE_SIZE);
    }
}

// Test page address calculation.
test "memory pool page address" {
    var pool = MemoryPool.init();
    
    const page_idx: u32 = 10;
    const address = pool.get_page_address(page_idx);
    
    // Assert: Address must be correct.
    try std.testing.expect(address == page_idx * PAGE_SIZE);
    try std.testing.expect(address < 4 * 1024 * 1024); // Within pool size
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

// Test allocation failure (too many pages).
test "memory pool allocation failure" {
    var pool = MemoryPool.init();
    
    // Try to allocate more pages than available.
    const page_idx = pool.allocate_pages(MAX_PAGES + 1);
    
    // Assert: Allocation must fail.
    try std.testing.expect(page_idx == null);
    try std.testing.expect(pool.get_allocated_pages() == 0);
}

// Test deallocation failure (invalid page).
test "memory pool deallocation failure" {
    var pool = MemoryPool.init();
    
    // Try to deallocate unallocated page.
    const deallocated = pool.deallocate_pages(0, 1);
    
    // Assert: Deallocation must fail.
    try std.testing.expect(!deallocated);
    try std.testing.expect(pool.get_allocated_pages() == 0);
}

// Test kernel memory pool integration.
test "kernel memory pool integration" {
    var kernel = BasinKernel.init();
    
    // Assert: Memory pool must be initialized.
    try std.testing.expect(kernel.memory_pool.get_allocated_pages() == 0);
    try std.testing.expect(kernel.memory_pool.get_free_pages() == MAX_PAGES);
}

// Test allocate and deallocate sequence.
test "memory pool allocate deallocate sequence" {
    var pool = MemoryPool.init();
    
    // Allocate multiple blocks.
    const page1 = pool.allocate_pages(2);
    const page2 = pool.allocate_pages(3);
    const page3 = pool.allocate_pages(1);
    
    // Assert: All allocations must succeed.
    try std.testing.expect(page1 != null);
    try std.testing.expect(page2 != null);
    try std.testing.expect(page3 != null);
    try std.testing.expect(pool.get_allocated_pages() == 6);
    
    // Deallocate middle block.
    const deallocated = pool.deallocate_pages(page2.?, 3);
    try std.testing.expect(deallocated);
    try std.testing.expect(pool.get_allocated_pages() == 3);
    
    // Deallocate remaining blocks.
    const deallocated1 = pool.deallocate_pages(page1.?, 2);
    const deallocated3 = pool.deallocate_pages(page3.?, 1);
    
    // Assert: All deallocations must succeed.
    try std.testing.expect(deallocated1);
    try std.testing.expect(deallocated3);
    try std.testing.expect(pool.get_allocated_pages() == 0);
}

// Test byte allocation with rounding.
test "memory pool byte allocation rounding" {
    var pool = MemoryPool.init();
    
    // Allocate 1 byte (should round up to 1 page).
    const page_idx = pool.allocate(1);
    
    // Assert: Allocation must succeed and use 1 page.
    try std.testing.expect(page_idx != null);
    try std.testing.expect(pool.get_allocated_pages() == 1);
    
    // Allocate PAGE_SIZE + 1 bytes (should round up to 2 pages).
    const page_idx2 = pool.allocate(PAGE_SIZE + 1);
    
    // Assert: Allocation must succeed and use 2 pages.
    try std.testing.expect(page_idx2 != null);
    try std.testing.expect(pool.get_allocated_pages() == 3);
}

