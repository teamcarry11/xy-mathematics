//! Grain Database Index Entry Serialization: Serialize/deserialize index entries.
//!
//! Why: Convert index entries to/from binary format for file page storage.
//! Architecture: Binary format with fixed header and variable data.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-07-053910-pst: Grain Silo Agent

const std = @import("std");
const grain_core = @import("grain_core");
const index_manager = grain_core.index_manager;

// Index entry header size (record_id + key_len + value_len + timestamp).
pub const INDEX_ENTRY_HEADER_SIZE: u32 = 8 + 4 + 4 + 8;

// Serialize index entry to binary format.
pub fn serialize_index_entry(
    entry: *const index_manager.IndexEntry,
    output: []u8,
) u32 {
    std.debug.assert(entry != null);
    std.debug.assert(output.len >= INDEX_ENTRY_HEADER_SIZE + entry.key_len + entry.value_len);
    var offset: u32 = 0;
    const record_id_bytes = std.mem.toBytes(entry.record_id);
    var i: u32 = 0;
    while (i < 8) : (i += 1) {
        output[offset] = record_id_bytes[i];
        offset += 1;
    }
    const key_len_bytes = std.mem.toBytes(entry.key_len);
    i = 0;
    while (i < 4) : (i += 1) {
        output[offset] = key_len_bytes[i];
        offset += 1;
    }
    const value_len_bytes = std.mem.toBytes(entry.value_len);
    i = 0;
    while (i < 4) : (i += 1) {
        output[offset] = value_len_bytes[i];
        offset += 1;
    }
    const timestamp_bytes = std.mem.toBytes(entry.timestamp);
    i = 0;
    while (i < 8) : (i += 1) {
        output[offset] = timestamp_bytes[i];
        offset += 1;
    }
    std.mem.copyForwards(u8, output[offset..], entry.key[0..entry.key_len]);
    offset += entry.key_len;
    std.mem.copyForwards(u8, output[offset..], entry.value[0..entry.value_len]);
    offset += entry.value_len;
    std.debug.assert(offset == INDEX_ENTRY_HEADER_SIZE + entry.key_len + entry.value_len);
    return offset;
}

// Deserialize index entry from binary format.
pub fn deserialize_index_entry(
    data: []const u8,
) ?index_manager.IndexEntry {
    std.debug.assert(data.len >= INDEX_ENTRY_HEADER_SIZE);
    var offset: u32 = 0;
    const record_id = std.mem.readInt(u64, data[offset..][0..8], .little);
    offset += 8;
    const key_len = std.mem.readInt(u32, data[offset..][0..4], .little);
    offset += 4;
    const value_len = std.mem.readInt(u32, data[offset..][0..4], .little);
    offset += 4;
    const timestamp = std.mem.readInt(u64, data[offset..][0..8], .little);
    offset += 8;
    if (key_len > index_manager.MAX_INDEX_KEY_SIZE) {
        return null;
    }
    if (value_len > index_manager.MAX_INDEX_VALUE_SIZE) {
        return null;
    }
    if (offset + key_len + value_len > data.len) {
        return null;
    }
    var entry = index_manager.IndexEntry.init();
    entry.record_id = record_id;
    entry.key_len = key_len;
    entry.value_len = value_len;
    entry.timestamp = timestamp;
    var i: u32 = 0;
    while (i < key_len) : (i += 1) {
        entry.key[i] = data[offset + i];
    }
    offset += key_len;
    i = 0;
    while (i < value_len) : (i += 1) {
        entry.value[i] = data[offset + i];
    }
    std.debug.assert(entry.key_len <= index_manager.MAX_INDEX_KEY_SIZE);
    std.debug.assert(entry.value_len <= index_manager.MAX_INDEX_VALUE_SIZE);
    return entry;
}

// Calculate serialized index entry size.
pub fn calculate_serialized_size(
    key_len: u32,
    value_len: u32,
) u32 {
    std.debug.assert(key_len <= index_manager.MAX_INDEX_KEY_SIZE);
    std.debug.assert(value_len <= index_manager.MAX_INDEX_VALUE_SIZE);
    return INDEX_ENTRY_HEADER_SIZE + key_len + value_len;
}

