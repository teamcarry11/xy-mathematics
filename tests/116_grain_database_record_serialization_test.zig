//! Tests for Grain Database Record Serialization.
//!
//! Why: Verify record serialization/deserialization for file page storage.
//! Architecture: Comprehensive test coverage for serialization module.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-024322-pst: Grain Silo Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const StorageEngine = grain_database.StorageEngine;
const serialize_record = grain_database.serialize_record;
const deserialize_record = grain_database.deserialize_record;
const calculate_serialized_size = grain_database.calculate_serialized_size;
const RECORD_HEADER_SIZE = grain_database.RECORD_HEADER_SIZE;

test "serialize and deserialize record" {
    var storage_engine = try StorageEngine.init(testing.allocator, 1024);
    defer storage_engine.deinit();
    const record_id = try storage_engine.create_record("test_key", "test_value");
    const record = storage_engine.read_record_by_id(record_id);
    try testing.expect(record != null);
    var serialized: [4096]u8 = undefined;
    const serialized_len = serialize_record(record.?, &serialized);
    try testing.expect(serialized_len > 0);
    const deserialized = try deserialize_record(testing.allocator, serialized[0..serialized_len]);
    defer deserialized.deinit();
    try testing.expect(deserialized.record_id == record.?.record_id);
    try testing.expect(std.mem.eql(u8, deserialized.key, record.?.key));
    try testing.expect(std.mem.eql(u8, deserialized.value, record.?.value));
    try testing.expect(deserialized.created_at == record.?.created_at);
    try testing.expect(deserialized.updated_at == record.?.updated_at);
}

test "calculate serialized size" {
    const key_len: u32 = 8;
    const value_len: u64 = 9;
    const size = calculate_serialized_size(key_len, value_len);
    try testing.expect(size == RECORD_HEADER_SIZE + key_len + 9);
}

test "serialize record with large value" {
    var storage_engine = try StorageEngine.init(testing.allocator, 1024);
    defer storage_engine.deinit();
    var large_value_buf: [1000]u8 = undefined;
    var i: u32 = 0;
    while (i < 1000) : (i += 1) {
        large_value_buf[i] = 'x';
    }
    const large_value = large_value_buf[0..];
    const record_id = try storage_engine.create_record("key", large_value);
    const record = storage_engine.read_record_by_id(record_id);
    try testing.expect(record != null);
    var serialized: [4096]u8 = undefined;
    const serialized_len = serialize_record(record.?, &serialized);
    try testing.expect(serialized_len > RECORD_HEADER_SIZE);
    const deserialized = try deserialize_record(testing.allocator, serialized[0..serialized_len]);
    defer deserialized.deinit();
    try testing.expect(std.mem.eql(u8, deserialized.value, large_value));
}

test "serialize multiple records" {
    var storage_engine = try StorageEngine.init(testing.allocator, 1024);
    defer storage_engine.deinit();
    const record_id1 = try storage_engine.create_record("key1", "value1");
    const record_id2 = try storage_engine.create_record("key2", "value2");
    const record1 = storage_engine.read_record_by_id(record_id1);
    const record2 = storage_engine.read_record_by_id(record_id2);
    try testing.expect(record1 != null);
    try testing.expect(record2 != null);
    var serialized1: [4096]u8 = undefined;
    var serialized2: [4096]u8 = undefined;
    const len1 = serialize_record(record1.?, &serialized1);
    const len2 = serialize_record(record2.?, &serialized2);
    try testing.expect(len1 > 0);
    try testing.expect(len2 > 0);
    const deserialized1 = try deserialize_record(testing.allocator, serialized1[0..len1]);
    defer deserialized1.deinit();
    const deserialized2 = try deserialize_record(testing.allocator, serialized2[0..len2]);
    defer deserialized2.deinit();
    try testing.expect(std.mem.eql(u8, deserialized1.key, "key1"));
    try testing.expect(std.mem.eql(u8, deserialized2.key, "key2"));
}

