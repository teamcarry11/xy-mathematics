//! Tests for Grain Database Index Entry Serialization
//! 2025-12-07-053910-pst: Grain Silo Agent

const std = @import("std");
const testing = std.testing;
const grain_core = @import("grain_core");
const index_manager = grain_core.index_manager;
const index_entry_serialization = @import("../src/grain_database/index_entry_serialization.zig");

test "serialize_index_entry basic" {
    var entry = index_manager.IndexEntry.init();
    entry.record_id = 123;
    entry.key_len = 3;
    entry.value_len = 5;
    entry.timestamp = 1000;
    var i: u32 = 0;
    while (i < 3) : (i += 1) {
        entry.key[i] = @as(u8, @intCast(65 + i));
    }
    i = 0;
    while (i < 5) : (i += 1) {
        entry.value[i] = @as(u8, @intCast(97 + i));
    }
    var buffer: [256]u8 = undefined;
    const written = index_entry_serialization.serialize_index_entry(&entry, &buffer);
    std.debug.assert(written > 0);
    std.debug.assert(written == index_entry_serialization.INDEX_ENTRY_HEADER_SIZE + 3 + 5);
    const deserialized = index_entry_serialization.deserialize_index_entry(buffer[0..written]);
    std.debug.assert(deserialized != null);
    std.debug.assert(deserialized.?.record_id == 123);
    std.debug.assert(deserialized.?.key_len == 3);
    std.debug.assert(deserialized.?.value_len == 5);
    std.debug.assert(deserialized.?.timestamp == 1000);
    i = 0;
    while (i < 3) : (i += 1) {
        std.debug.assert(deserialized.?.key[i] == @as(u8, @intCast(65 + i)));
    }
    i = 0;
    while (i < 5) : (i += 1) {
        std.debug.assert(deserialized.?.value[i] == @as(u8, @intCast(97 + i)));
    }
}

test "serialize_index_entry large key" {
    var entry = index_manager.IndexEntry.init();
    entry.record_id = 456;
    entry.key_len = 200;
    entry.value_len = 50;
    entry.timestamp = 2000;
    var i: u32 = 0;
    while (i < 200) : (i += 1) {
        entry.key[i] = @as(u8, @intCast(i % 256));
    }
    i = 0;
    while (i < 50) : (i += 1) {
        entry.value[i] = @as(u8, @intCast(100 + i));
    }
    var buffer: [512]u8 = undefined;
    const written = index_entry_serialization.serialize_index_entry(&entry, &buffer);
    std.debug.assert(written > 0);
    const deserialized = index_entry_serialization.deserialize_index_entry(buffer[0..written]);
    std.debug.assert(deserialized != null);
    std.debug.assert(deserialized.?.record_id == 456);
    std.debug.assert(deserialized.?.key_len == 200);
    std.debug.assert(deserialized.?.value_len == 50);
    std.debug.assert(deserialized.?.timestamp == 2000);
}

test "calculate_serialized_size" {
    const size1 = index_entry_serialization.calculate_serialized_size(10, 20);
    std.debug.assert(size1 == index_entry_serialization.INDEX_ENTRY_HEADER_SIZE + 10 + 20);
    const size2 = index_entry_serialization.calculate_serialized_size(100, 200);
    std.debug.assert(size2 == index_entry_serialization.INDEX_ENTRY_HEADER_SIZE + 100 + 200);
}

test "deserialize_index_entry invalid data" {
    var buffer: [16]u8 = undefined;
    const deserialized = index_entry_serialization.deserialize_index_entry(&buffer);
    std.debug.assert(deserialized == null);
}

