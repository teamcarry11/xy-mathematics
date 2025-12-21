//! Tests for Grain Database Storage Engine.
//!
//! Why: Verify key-value storage operations (create, read, update, delete).
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-163155-pst: Grain Database Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const StorageEngine = grain_database.StorageEngine;

test "storage engine initialization" {
    const allocator = testing.allocator;
    var engine = try StorageEngine.init(allocator, 1024 * 1024);
    defer engine.deinit();

    try testing.expect(engine.records_len == 0);
    try testing.expect(engine.next_record_id == 1);
}

test "create record" {
    const allocator = testing.allocator;
    var engine = try StorageEngine.init(allocator, 1024 * 1024);
    defer engine.deinit();

    const record_id = try engine.create_record("key1", "value1");
    try testing.expect(record_id == 1);
    try testing.expect(engine.records_len == 1);
    try testing.expect(engine.next_record_id == 2);
}

test "read record by key" {
    const allocator = testing.allocator;
    var engine = try StorageEngine.init(allocator, 1024 * 1024);
    defer engine.deinit();

    _ = try engine.create_record("key1", "value1");
    const record = engine.read_record_by_key("key1");
    try testing.expect(record != null);
    try testing.expect(std.mem.eql(u8, record.?.key, "key1"));
    try testing.expect(std.mem.eql(u8, record.?.value, "value1"));
}

test "read record by id" {
    const allocator = testing.allocator;
    var engine = try StorageEngine.init(allocator, 1024 * 1024);
    defer engine.deinit();

    const record_id = try engine.create_record("key1", "value1");
    const record = engine.read_record_by_id(record_id);
    try testing.expect(record != null);
    try testing.expect(record.?.record_id == record_id);
    try testing.expect(std.mem.eql(u8, record.?.key, "key1"));
}

test "update record" {
    const allocator = testing.allocator;
    var engine = try StorageEngine.init(allocator, 1024 * 1024);
    defer engine.deinit();

    _ = try engine.create_record("key1", "value1");
    try engine.update_record("key1", "value2");
    const record = engine.read_record_by_key("key1");
    try testing.expect(record != null);
    try testing.expect(std.mem.eql(u8, record.?.value, "value2"));
}

test "delete record" {
    const allocator = testing.allocator;
    var engine = try StorageEngine.init(allocator, 1024 * 1024);
    defer engine.deinit();

    _ = try engine.create_record("key1", "value1");
    try testing.expect(engine.records_len == 1);
    try engine.delete_record("key1");
    try testing.expect(engine.records_len == 0);
    const record = engine.read_record_by_key("key1");
    try testing.expect(record == null);
}

test "duplicate key error" {
    const allocator = testing.allocator;
    var engine = try StorageEngine.init(allocator, 1024 * 1024);
    defer engine.deinit();

    _ = try engine.create_record("key1", "value1");
    const result = engine.create_record("key1", "value2");
    try testing.expectError(error.RecordExists, result);
}

test "record not found error" {
    const allocator = testing.allocator;
    var engine = try StorageEngine.init(allocator, 1024 * 1024);
    defer engine.deinit();

    const result = engine.update_record("nonexistent", "value");
    try testing.expectError(error.RecordNotFound, result);
}

test "multiple records" {
    const allocator = testing.allocator;
    var engine = try StorageEngine.init(allocator, 1024 * 1024);
    defer engine.deinit();

    _ = try engine.create_record("key1", "value1");
    _ = try engine.create_record("key2", "value2");
    _ = try engine.create_record("key3", "value3");
    try testing.expect(engine.records_len == 3);

    const record1 = engine.read_record_by_key("key1");
    try testing.expect(record1 != null);
    try testing.expect(std.mem.eql(u8, record1.?.value, "value1"));

    const record2 = engine.read_record_by_key("key2");
    try testing.expect(record2 != null);
    try testing.expect(std.mem.eql(u8, record2.?.value, "value2"));
}

test "batch create records" {
    const allocator = testing.allocator;
    var engine = try StorageEngine.init(allocator, 1024 * 1024);
    defer engine.deinit();

    const keys = [_][]const u8{ "batch1", "batch2", "batch3" };
    const values = [_][]const u8{ "value1", "value2", "value3" };
    var output_record_ids: [10]u64 = undefined;
    const count = try engine.batch_create_records(&keys, &values, &output_record_ids);
    try testing.expect(count == 3);
    try testing.expect(engine.records_len == 3);
    try testing.expect(output_record_ids[0] > 0);
    try testing.expect(output_record_ids[1] > 0);
    try testing.expect(output_record_ids[2] > 0);
    const record1 = engine.read_record_by_key("batch1");
    try testing.expect(record1 != null);
    try testing.expect(std.mem.eql(u8, record1.?.value, "value1"));
}

test "batch create records with duplicates" {
    const allocator = testing.allocator;
    var engine = try StorageEngine.init(allocator, 1024 * 1024);
    defer engine.deinit();

    _ = try engine.create_record("existing", "value");
    const keys = [_][]const u8{ "existing", "new1", "new2" };
    const values = [_][]const u8{ "duplicate", "value1", "value2" };
    var output_record_ids: [10]u64 = undefined;
    const count = try engine.batch_create_records(&keys, &values, &output_record_ids);
    try testing.expect(count == 2);
    try testing.expect(engine.records_len == 3);
}

test "storage engine statistics" {
    const allocator = testing.allocator;
    var engine = try StorageEngine.init(allocator, 1024 * 1024);
    defer engine.deinit();

    try testing.expect(engine.get_record_count() == 0);
    try testing.expect(engine.get_total_storage_size() == 0);
    try testing.expect(engine.get_average_record_size() == 0);
    try testing.expect(engine.get_next_record_id() == 1);

    _ = try engine.create_record("key1", "value1");
    _ = try engine.create_record("key2", "value2");

    try testing.expect(engine.get_record_count() == 2);
    try testing.expect(engine.get_total_storage_size() > 0);
    try testing.expect(engine.get_average_record_size() > 0);
    try testing.expect(engine.get_next_record_id() == 3);
}

test "storage engine validation" {
    const allocator = testing.allocator;
    var engine = try StorageEngine.init(allocator, 1024 * 1024);
    defer engine.deinit();

    try testing.expect(StorageEngine.validate_key("valid_key"));
    try testing.expect(!StorageEngine.validate_key(""));
    try testing.expect(StorageEngine.validate_value("valid_value"));
    try testing.expect(StorageEngine.validate_value(""));

    _ = try engine.create_record("test_key", "test_value");
    try testing.expect(engine.has_record("test_key"));
    try testing.expect(!engine.has_record("nonexistent"));
    const record_id = try engine.create_record("test_key2", "test_value2");
    try testing.expect(engine.has_record_by_id(record_id));
    try testing.expect(!engine.has_record_by_id(999999));
}
