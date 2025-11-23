//! Page Table Tests
//! Why: Comprehensive TigerStyle tests for page-level memory protection.
//! Grain Style: Explicit types (u32/u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const page_table = @import("page_table");
const PageTable = page_table.PageTable;
const PageFlags = page_table.PageFlags;
const PAGE_SIZE = page_table.PAGE_SIZE;

// Test page table initialization.
test "page table init" {
    const table = PageTable.init();
    
    // Assert: Table must be initialized (precondition).
    try std.testing.expect(table.pages.len == 1024);
    
    // Assert: All pages must be unmapped initially (postcondition).
    for (table.pages) |page| {
        try std.testing.expect(!page.mapped);
        try std.testing.expect(!page.flags.read);
        try std.testing.expect(!page.flags.write);
        try std.testing.expect(!page.flags.execute);
    }
}

// Test page table map pages.
test "page table map pages" {
    var table = PageTable.init();
    
    // Assert: Table must be initialized (precondition).
    try std.testing.expect(table.pages.len == 1024);
    
    // Map 1 page with read/write permissions.
    const addr: u64 = 0x100000; // User space
    const size: u64 = PAGE_SIZE; // 1 page
    const flags = PageFlags.init(.{ .read = true, .write = true, .execute = false });
    
    table.map_pages(addr, size, flags);
    
    // Check permissions for mapped page.
    const permissions = table.check_permission(addr);
    
    // Assert: Page must be mapped with correct permissions (postcondition).
    try std.testing.expect(permissions != null);
    if (permissions) |perm_flags| {
        try std.testing.expect(perm_flags.read == true);
        try std.testing.expect(perm_flags.write == true);
        try std.testing.expect(perm_flags.execute == false);
    }
}

// Test page table unmap pages.
test "page table unmap pages" {
    var table = PageTable.init();
    
    // Assert: Table must be initialized (precondition).
    try std.testing.expect(table.pages.len == 1024);
    
    // Map 1 page.
    const addr: u64 = 0x100000; // User space
    const size: u64 = PAGE_SIZE; // 1 page
    const flags = PageFlags.init(.{ .read = true, .write = true, .execute = false });
    
    table.map_pages(addr, size, flags);
    
    // Assert: Page must be mapped (precondition).
    const permissions_before = table.check_permission(addr);
    try std.testing.expect(permissions_before != null);
    
    // Unmap page.
    table.unmap_pages(addr, size);
    
    // Assert: Page must be unmapped (postcondition).
    const permissions_after = table.check_permission(addr);
    try std.testing.expect(permissions_after == null);
}

// Test page table protect pages.
test "page table protect pages" {
    var table = PageTable.init();
    
    // Assert: Table must be initialized (precondition).
    try std.testing.expect(table.pages.len == 1024);
    
    // Map 1 page with read/write permissions.
    const addr: u64 = 0x100000; // User space
    const size: u64 = PAGE_SIZE; // 1 page
    const flags1 = PageFlags.init(.{ .read = true, .write = true, .execute = false });
    
    table.map_pages(addr, size, flags1);
    
    // Assert: Page must be mapped with initial permissions (precondition).
    const permissions_before = table.check_permission(addr);
    try std.testing.expect(permissions_before != null);
    if (permissions_before) |perm_flags| {
        try std.testing.expect(perm_flags.write == true);
    }
    
    // Protect page with read-only permissions.
    const flags2 = PageFlags.init(.{ .read = true, .write = false, .execute = false });
    table.protect_pages(addr, size, flags2);
    
    // Assert: Page must have new permissions (postcondition).
    const permissions_after = table.check_permission(addr);
    try std.testing.expect(permissions_after != null);
    if (permissions_after) |perm_flags| {
        try std.testing.expect(perm_flags.read == true);
        try std.testing.expect(perm_flags.write == false);
        try std.testing.expect(perm_flags.execute == false);
    }
}

// Test page table kernel space permissions.
test "page table kernel space" {
    var table = PageTable.init();
    
    // Assert: Table must be initialized (precondition).
    try std.testing.expect(table.pages.len == 1024);
    
    // Kernel space (0x80000000+) should always have all permissions.
    const kernel_addr: u64 = 0x80000000;
    
    const permissions = table.check_permission(kernel_addr);
    
    // Assert: Kernel space must have all permissions (postcondition).
    try std.testing.expect(permissions != null);
    if (permissions) |flags| {
        try std.testing.expect(flags.read == true);
        try std.testing.expect(flags.write == true);
        try std.testing.expect(flags.execute == true);
    }
}

// Test page table framebuffer permissions.
test "page table framebuffer" {
    var table = PageTable.init();
    
    // Assert: Table must be initialized (precondition).
    try std.testing.expect(table.pages.len == 1024);
    
    // Framebuffer space (0x90000000+) should always have read/write permissions.
    const fb_addr: u64 = 0x90000000;
    
    const permissions = table.check_permission(fb_addr);
    
    // Assert: Framebuffer must have read/write permissions (postcondition).
    try std.testing.expect(permissions != null);
    if (permissions) |flags| {
        try std.testing.expect(flags.read == true);
        try std.testing.expect(flags.write == true);
        try std.testing.expect(flags.execute == false);
    }
}

// Test page table multiple pages.
test "page table multiple pages" {
    var table = PageTable.init();
    
    // Assert: Table must be initialized (precondition).
    try std.testing.expect(table.pages.len == 1024);
    
    // Map 4 pages with read/write permissions.
    const addr: u64 = 0x100000; // User space
    const size: u64 = 4 * PAGE_SIZE; // 4 pages
    const flags = PageFlags.init(.{ .read = true, .write = true, .execute = false });
    
    table.map_pages(addr, size, flags);
    
    // Check permissions for all 4 pages.
    for (0..4) |i| {
        const page_addr = addr + @as(u64, @intCast(i * PAGE_SIZE));
        const permissions = table.check_permission(page_addr);
        
        // Assert: Each page must be mapped with correct permissions (postcondition).
        try std.testing.expect(permissions != null);
        if (permissions) |perm_flags| {
            try std.testing.expect(perm_flags.read == true);
            try std.testing.expect(perm_flags.write == true);
        }
    }
}

// Test page table unmapped address.
test "page table unmapped address" {
    var table = PageTable.init();
    
    // Assert: Table must be initialized (precondition).
    try std.testing.expect(table.pages.len == 1024);
    
    // Unmapped address in user space should return null.
    const unmapped_addr: u64 = 0x200000; // User space, not mapped
    
    const permissions = table.check_permission(unmapped_addr);
    
    // Assert: Unmapped address must return null (postcondition).
    try std.testing.expect(permissions == null);
}

