//! Grain Database Record Serialization: Serialize/deserialize records for file pages.
//!
//! Why: Convert records to/from binary format for file page storage.
//! Architecture: Binary format with fixed header and variable data.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-07-024322-pst: Grain Silo Agent

const std = @import("std");
const storage_engine = @import("storage_engine.zig");
const grain_core = @import("grain_core");
const file_storage = grain_core.file_storage;

// Record header size (record_id + key_len + value_len + created_at + updated_at).
pub const RECORD_HEADER_SIZE: u32 = 8 + 4 + 8 + 8 + 8;

// Serialize record to binary format.
pub fn serialize_record(
    record: *const storage_engine.Record,
    output: []u8,
) u32 {
    std.debug.assert(record != null);
    std.debug.assert(output.len >= RECORD_HEADER_SIZE + record.key_len + @as(u32, @intCast(record.value_len)));
    var offset: u32 = 0;
    const record_id_bytes = std.mem.toBytes(record.record_id);
    var i: u32 = 0;
    while (i < 8) : (i += 1) {
        output[offset] = record_id_bytes[i];
        offset += 1;
    }
    const key_len_bytes = std.mem.toBytes(record.key_len);
    i = 0;
    while (i < 4) : (i += 1) {
        output[offset] = key_len_bytes[i];
        offset += 1;
    }
    const value_len_bytes = std.mem.toBytes(record.value_len);
    i = 0;
    while (i < 8) : (i += 1) {
        output[offset] = value_len_bytes[i];
        offset += 1;
    }
    const created_at_bytes = std.mem.toBytes(record.created_at);
    i = 0;
    while (i < 8) : (i += 1) {
        output[offset] = created_at_bytes[i];
        offset += 1;
    }
    const updated_at_bytes = std.mem.toBytes(record.updated_at);
    i = 0;
    while (i < 8) : (i += 1) {
        output[offset] = updated_at_bytes[i];
        offset += 1;
    }
    std.mem.copyForwards(u8, output[offset..], record.key);
    offset += record.key_len;
    const value_len_u32 = @as(u32, @intCast(record.value_len));
    std.mem.copyForwards(u8, output[offset..], record.value[0..value_len_u32]);
    offset += value_len_u32;
    std.debug.assert(offset == RECORD_HEADER_SIZE + record.key_len + value_len_u32);
    return offset;
}

// Deserialize record from binary format.
pub fn deserialize_record(
    allocator: std.mem.Allocator,
    data: []const u8,
) !storage_engine.Record {
    std.debug.assert(data.len >= RECORD_HEADER_SIZE);
    var offset: u32 = 0;
    const record_id = std.mem.readInt(u64, data[offset..][0..8], .little);
    offset += 8;
    const key_len = std.mem.readInt(u32, data[offset..][0..4], .little);
    offset += 4;
    const value_len = std.mem.readInt(u64, data[offset..][0..8], .little);
    offset += 8;
    const created_at = std.mem.readInt(u64, data[offset..][0..8], .little);
    offset += 8;
    const updated_at = std.mem.readInt(u64, data[offset..][0..8], .little);
    offset += 8;
    std.debug.assert(key_len <= storage_engine.MAX_KEY_LEN);
    std.debug.assert(value_len <= storage_engine.MAX_VALUE_LEN);
    const key = try allocator.dupe(u8, data[offset..][0..key_len]);
    errdefer allocator.free(key);
    offset += key_len;
    const value_len_u32 = @as(u32, @intCast(value_len));
    const value = try allocator.dupe(u8, data[offset..][0..value_len_u32]);
    errdefer allocator.free(value);
    return storage_engine.Record{
        .key = key,
        .key_len = key_len,
        .value = value,
        .value_len = value_len,
        .record_id = record_id,
        .created_at = created_at,
        .updated_at = updated_at,
        .allocator = allocator,
    };
}

// Calculate serialized record size.
pub fn calculate_serialized_size(
    key_len: u32,
    value_len: u64,
) u32 {
    std.debug.assert(key_len <= storage_engine.MAX_KEY_LEN);
    std.debug.assert(value_len <= storage_engine.MAX_VALUE_LEN);
    const value_len_u32 = @as(u32, @intCast(value_len));
    return RECORD_HEADER_SIZE + key_len + value_len_u32;
}

