//! Copy-on-Write (COW) Memory Sharing Tests
//! Why: Comprehensive TigerStyle tests for COW memory sharing system.
//! Grain Style: Explicit types (u32/u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const cow = @import("cow");
const CowTable = cow.CowTable;
const CowPageEntry = cow.CowPageEntry;
const PAGE_SIZE = cow.PAGE_SIZE;

// Test COW table initialization.
test "cow table init" {
    const table = CowTable.init();
    
    // Assert: All pages must be initialized (precondition).
    for (table.pages) |page| {
        try std.testing.expect(page.ref_count == 0);
        try std.testing.expect(!page.cow_marked);
    }
}

// Test COW page entry initialization.
test "cow page entry init" {
    const entry = CowPageEntry.init();
    
    // Assert: Entry must be initialized correctly (postcondition).
    try std.testing.expect(entry.ref_count == 0);
    try std.testing.expect(!entry.cow_marked);
    try std.testing.expect(!entry.is_shared());
    try std.testing.expect(!entry.should_copy_on_write());
}

// Test COW page entry is_shared.
test "cow page entry is shared" {
    var entry = CowPageEntry.init();
    try std.testing.expect(!entry.is_shared());
    
    entry.ref_count = 1;
    try std.testing.expect(!entry.is_shared());
    
    entry.ref_count = 2;
    try std.testing.expect(entry.is_shared());
    
    entry.ref_count = 3;
    try std.testing.expect(entry.is_shared());
}

// Test COW page entry should_copy_on_write.
test "cow page entry should copy on write" {
    var entry = CowPageEntry.init();
    try std.testing.expect(!entry.should_copy_on_write());
    
    entry.ref_count = 1;
    entry.cow_marked = true;
    try std.testing.expect(!entry.should_copy_on_write());
    
    entry.ref_count = 2;
    entry.cow_marked = true;
    try std.testing.expect(entry.should_copy_on_write());
    
    entry.cow_marked = false;
    try std.testing.expect(!entry.should_copy_on_write());
}

// Test COW table increment refs.
test "cow table increment refs" {
    var table = CowTable.init();
    
    // Assert: Table must be initialized (precondition).
    try std.testing.expect(table.pages[0].ref_count == 0);
    
    const addr: u64 = 0x100000;
    const size: u64 = PAGE_SIZE * 2; // 2 pages
    table.increment_refs(addr, size, false);
    
    // Assert: Reference counts must be incremented (postcondition).
    try std.testing.expect(table.pages[0x100].ref_count == 1);
    try std.testing.expect(table.pages[0x101].ref_count == 1);
    try std.testing.expect(!table.pages[0x100].cow_marked);
    try std.testing.expect(!table.pages[0x101].cow_marked);
    
    // Increment again with COW mark.
    table.increment_refs(addr, size, true);
    
    // Assert: Reference counts must be incremented again (postcondition).
    try std.testing.expect(table.pages[0x100].ref_count == 2);
    try std.testing.expect(table.pages[0x101].ref_count == 2);
    try std.testing.expect(table.pages[0x100].cow_marked);
    try std.testing.expect(table.pages[0x101].cow_marked);
}

// Test COW table decrement refs.
test "cow table decrement refs" {
    var table = CowTable.init();
    
    // Assert: Table must be initialized (precondition).
    try std.testing.expect(table.pages[0x100].ref_count == 0);
    
    const addr: u64 = 0x100000;
    const size: u64 = PAGE_SIZE * 2; // 2 pages
    table.increment_refs(addr, size, true);
    table.increment_refs(addr, size, false);
    
    // Assert: Reference counts must be 2 (precondition).
    try std.testing.expect(table.pages[0x100].ref_count == 2);
    try std.testing.expect(table.pages[0x101].ref_count == 2);
    try std.testing.expect(table.pages[0x100].cow_marked);
    
    // Decrement reference counts.
    table.decrement_refs(addr, size);
    
    // Assert: Reference counts must be decremented (postcondition).
    try std.testing.expect(table.pages[0x100].ref_count == 1);
    try std.testing.expect(table.pages[0x101].ref_count == 1);
    try std.testing.expect(!table.pages[0x100].cow_marked);
    try std.testing.expect(!table.pages[0x101].cow_marked);
    
    // Decrement again.
    table.decrement_refs(addr, size);
    
    // Assert: Reference counts must be zero (postcondition).
    try std.testing.expect(table.pages[0x100].ref_count == 0);
    try std.testing.expect(table.pages[0x101].ref_count == 0);
}

// Test COW table should_copy_on_write.
test "cow table should copy on write" {
    var table = CowTable.init();
    
    // Assert: Table must be initialized (precondition).
    const addr: u64 = 0x100000;
    try std.testing.expect(!table.should_copy_on_write(addr));
    
    // Increment with COW mark.
    table.increment_refs(addr, PAGE_SIZE, true);
    try std.testing.expect(!table.should_copy_on_write(addr)); // ref_count = 1
    
    // Increment again.
    table.increment_refs(addr, PAGE_SIZE, false);
    try std.testing.expect(table.should_copy_on_write(addr)); // ref_count = 2, cow_marked = true
    
    // Decrement.
    table.decrement_refs(addr, PAGE_SIZE);
    try std.testing.expect(!table.should_copy_on_write(addr)); // ref_count = 1
}

// Test COW table get_ref_count.
test "cow table get ref count" {
    var table = CowTable.init();
    
    // Assert: Table must be initialized (precondition).
    const addr: u64 = 0x100000;
    try std.testing.expect(table.get_ref_count(addr) == 0);
    
    // Increment reference count.
    table.increment_refs(addr, PAGE_SIZE, false);
    try std.testing.expect(table.get_ref_count(addr) == 1);
    
    // Increment again.
    table.increment_refs(addr, PAGE_SIZE, false);
    try std.testing.expect(table.get_ref_count(addr) == 2);
    
    // Decrement.
    table.decrement_refs(addr, PAGE_SIZE);
    try std.testing.expect(table.get_ref_count(addr) == 1);
}

// Test COW table is_shared.
test "cow table is shared" {
    var table = CowTable.init();
    
    // Assert: Table must be initialized (precondition).
    const addr: u64 = 0x100000;
    try std.testing.expect(!table.is_shared(addr));
    
    // Increment reference count to 1.
    table.increment_refs(addr, PAGE_SIZE, false);
    try std.testing.expect(!table.is_shared(addr)); // ref_count = 1
    
    // Increment reference count to 2.
    table.increment_refs(addr, PAGE_SIZE, false);
    try std.testing.expect(table.is_shared(addr)); // ref_count = 2
    
    // Decrement.
    table.decrement_refs(addr, PAGE_SIZE);
    try std.testing.expect(!table.is_shared(addr)); // ref_count = 1
}

// Test COW table multiple pages.
test "cow table multiple pages" {
    var table = CowTable.init();
    
    // Assert: Table must be initialized (precondition).
    const addr: u64 = 0x100000;
    const size: u64 = PAGE_SIZE * 3; // 3 pages
    table.increment_refs(addr, size, true);
    
    // Assert: All pages must have correct reference counts (postcondition).
    try std.testing.expect(table.pages[0x100].ref_count == 1);
    try std.testing.expect(table.pages[0x101].ref_count == 1);
    try std.testing.expect(table.pages[0x102].ref_count == 1);
    try std.testing.expect(table.pages[0x100].cow_marked);
    try std.testing.expect(table.pages[0x101].cow_marked);
    try std.testing.expect(table.pages[0x102].cow_marked);
    
    // Increment again.
    table.increment_refs(addr, size, false);
    
    // Assert: All pages must have ref_count = 2 (postcondition).
    try std.testing.expect(table.pages[0x100].ref_count == 2);
    try std.testing.expect(table.pages[0x101].ref_count == 2);
    try std.testing.expect(table.pages[0x102].ref_count == 2);
    try std.testing.expect(table.pages[0x100].cow_marked);
    
    // Decrement.
    table.decrement_refs(addr, size);
    
    // Assert: All pages must have ref_count = 1 (postcondition).
    try std.testing.expect(table.pages[0x100].ref_count == 1);
    try std.testing.expect(table.pages[0x101].ref_count == 1);
    try std.testing.expect(table.pages[0x102].ref_count == 1);
    try std.testing.expect(!table.pages[0x100].cow_marked);
}

