//! Tests for Grain Database WAL (Write-Ahead Log).
//!
//! Why: Verify WAL operations (append, get, clear) for durability.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-163155-pst: Grain Database Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const WAL = grain_database.WAL;
const LogEntryType = grain_database.LogEntryType;

test "wal initialization" {
    const allocator = testing.allocator;
    var wal_log = try WAL.init(allocator);
    defer wal_log.deinit();

    try testing.expect(wal_log.entries_len == 0);
    try testing.expect(wal_log.next_entry_id == 1);
}

test "wal append entry" {
    const allocator = testing.allocator;
    var wal_log = try WAL.init(allocator);
    defer wal_log.deinit();

    const entry_id = try wal_log.append(
        LogEntryType.insert,
        1,
        "key1",
        "value1",
        100,
    );
    try testing.expect(entry_id == 1);
    try testing.expect(wal_log.entries_len == 1);
    try testing.expect(wal_log.next_entry_id == 2);
}

test "wal get entry" {
    const allocator = testing.allocator;
    var wal_log = try WAL.init(allocator);
    defer wal_log.deinit();

    _ = try wal_log.append(LogEntryType.insert, 1, "key1", "value1", 100);
    const entry = wal_log.get_entry(0);
    try testing.expect(entry != null);
    try testing.expect(entry.?.entry_type == LogEntryType.insert);
    try testing.expect(entry.?.record_id == 1);
    try testing.expect(std.mem.eql(u8, entry.?.key, "key1"));
    try testing.expect(std.mem.eql(u8, entry.?.value, "value1"));
    try testing.expect(entry.?.transaction_id == 100);
}

test "wal multiple entries" {
    const allocator = testing.allocator;
    var wal_log = try WAL.init(allocator);
    defer wal_log.deinit();

    _ = try wal_log.append(LogEntryType.insert, 1, "key1", "value1", 100);
    _ = try wal_log.append(LogEntryType.update, 1, "key1", "value2", 100);
    _ = try wal_log.append(LogEntryType.delete, 1, "key1", "", 100);
    try testing.expect(wal_log.entries_len == 3);

    const entry1 = wal_log.get_entry(0);
    try testing.expect(entry1 != null);
    try testing.expect(entry1.?.entry_type == LogEntryType.insert);

    const entry2 = wal_log.get_entry(1);
    try testing.expect(entry2 != null);
    try testing.expect(entry2.?.entry_type == LogEntryType.update);

    const entry3 = wal_log.get_entry(2);
    try testing.expect(entry3 != null);
    try testing.expect(entry3.?.entry_type == LogEntryType.delete);
}

test "wal clear" {
    const allocator = testing.allocator;
    var wal_log = try WAL.init(allocator);
    defer wal_log.deinit();

    _ = try wal_log.append(LogEntryType.insert, 1, "key1", "value1", 100);
    _ = try wal_log.append(LogEntryType.insert, 2, "key2", "value2", 100);
    try testing.expect(wal_log.entries_len == 2);

    wal_log.clear();
    try testing.expect(wal_log.entries_len == 0);
    try testing.expect(wal_log.next_entry_id == 1);
}

test "wal get entry out of bounds" {
    const allocator = testing.allocator;
    var wal_log = try WAL.init(allocator);
    defer wal_log.deinit();

    _ = try wal_log.append(LogEntryType.insert, 1, "key1", "value1", 100);
    const entry = wal_log.get_entry(999);
    try testing.expect(entry == null);
}

