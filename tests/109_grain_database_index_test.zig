//! Tests for Grain Database Index (Hash and B-tree).
//!
//! Why: Verify index operations (insert, lookup) for fast queries.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-163155-pst: Grain Database Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const HashIndex = grain_database.HashIndex;
const BTreeIndex = grain_database.BTreeIndex;

test "hash index initialization" {
    const allocator = testing.allocator;
    var index = try HashIndex.init(allocator);
    defer index.deinit();

    try testing.expect(index.entries_len == 0);
}

test "hash index insert and lookup" {
    const allocator = testing.allocator;
    var index = try HashIndex.init(allocator);
    defer index.deinit();

    try index.insert(1, 100);
    try index.insert(2, 200);
    try index.insert(3, 300);

    const ptr1 = index.lookup(1);
    try testing.expect(ptr1 != null);
    try testing.expect(ptr1.? == 100);

    const ptr2 = index.lookup(2);
    try testing.expect(ptr2 != null);
    try testing.expect(ptr2.? == 200);

    const ptr3 = index.lookup(3);
    try testing.expect(ptr3 != null);
    try testing.expect(ptr3.? == 300);
}

test "hash index lookup nonexistent" {
    const allocator = testing.allocator;
    var index = try HashIndex.init(allocator);
    defer index.deinit();

    try index.insert(1, 100);
    const ptr = index.lookup(999);
    try testing.expect(ptr == null);
}

test "b-tree index initialization" {
    const allocator = testing.allocator;
    var index = try BTreeIndex.init(allocator);
    defer index.deinit();

    try testing.expect(index.nodes_len == 0);
    try testing.expect(index.root_idx == null);
}

test "b-tree index insert and lookup" {
    const allocator = testing.allocator;
    var index = try BTreeIndex.init(allocator);
    defer index.deinit();

    try index.insert(10, 100);
    try index.insert(20, 200);
    try index.insert(30, 300);

    const val1 = index.lookup(10);
    try testing.expect(val1 != null);
    try testing.expect(val1.? == 100);

    const val2 = index.lookup(20);
    try testing.expect(val2 != null);
    try testing.expect(val2.? == 200);

    const val3 = index.lookup(30);
    try testing.expect(val3 != null);
    try testing.expect(val3.? == 300);
}

test "b-tree index lookup nonexistent" {
    const allocator = testing.allocator;
    var index = try BTreeIndex.init(allocator);
    defer index.deinit();

    try index.insert(10, 100);
    const val = index.lookup(999);
    try testing.expect(val == null);
}

test "b-tree index ordered insert" {
    const allocator = testing.allocator;
    var index = try BTreeIndex.init(allocator);
    defer index.deinit();

    try index.insert(30, 300);
    try index.insert(10, 100);
    try index.insert(20, 200);

    const val1 = index.lookup(10);
    try testing.expect(val1 != null);
    try testing.expect(val1.? == 100);

    const val2 = index.lookup(20);
    try testing.expect(val2 != null);
    try testing.expect(val2.? == 200);

    const val3 = index.lookup(30);
    try testing.expect(val3 != null);
    try testing.expect(val3.? == 300);
}

