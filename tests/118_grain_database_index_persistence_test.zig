//! Tests for Grain Database Index File Persistence
//! 2025-12-07-053910-pst: Grain Silo Agent

const std = @import("std");
const testing = std.testing;
const grain_core = @import("grain_core");
const file_storage = grain_core.file_storage;
const index_manager = grain_core.index_manager;
const grain_database = @import("../src/grain_database/root.zig");
const PersistenceManager = grain_database.PersistenceManager;
const index_entry_serialization = @import("../src/grain_database/index_entry_serialization.zig");

test "write_index_entry_to_page basic" {
    var manager = PersistenceManager.init("test_index.db");
    std.debug.assert(manager.create_database_file());
    var entry = index_manager.IndexEntry.init();
    entry.record_id = 789;
    entry.key_len = 4;
    entry.value_len = 6;
    entry.timestamp = 3000;
    var i: u32 = 0;
    while (i < 4) : (i += 1) {
        entry.key[i] = @as(u8, @intCast(48 + i));
    }
    i = 0;
    while (i < 6) : (i += 1) {
        entry.value[i] = @as(u8, @intCast(120 + i));
    }
    var page = file_storage.FilePage.init();
    const offset: u32 = 100;
    const result = manager.write_index_entry_to_page(&entry, &page, offset);
    std.debug.assert(result);
    std.debug.assert(page.is_dirty);
}

test "read_index_entry_from_page basic" {
    var manager = PersistenceManager.init("test_index2.db");
    std.debug.assert(manager.create_database_file());
    var entry = index_manager.IndexEntry.init();
    entry.record_id = 999;
    entry.key_len = 5;
    entry.value_len = 7;
    entry.timestamp = 4000;
    var i: u32 = 0;
    while (i < 5) : (i += 1) {
        entry.key[i] = @as(u8, @intCast(70 + i));
    }
    i = 0;
    while (i < 7) : (i += 1) {
        entry.value[i] = @as(u8, @intCast(80 + i));
    }
    var page = file_storage.FilePage.init();
    const offset: u32 = 200;
    const write_result = manager.write_index_entry_to_page(&entry, &page, offset);
    std.debug.assert(write_result);
    const read_entry = manager.read_index_entry_from_page(&page, offset);
    std.debug.assert(read_entry != null);
    std.debug.assert(read_entry.?.record_id == 999);
    std.debug.assert(read_entry.?.key_len == 5);
    std.debug.assert(read_entry.?.value_len == 7);
    std.debug.assert(read_entry.?.timestamp == 4000);
    i = 0;
    while (i < 5) : (i += 1) {
        std.debug.assert(read_entry.?.key[i] == @as(u8, @intCast(70 + i)));
    }
    i = 0;
    while (i < 7) : (i += 1) {
        std.debug.assert(read_entry.?.value[i] == @as(u8, @intCast(80 + i)));
    }
}

test "find_index_entry_offset_in_page" {
    var manager = PersistenceManager.init("test_index3.db");
    std.debug.assert(manager.create_database_file());
    var entry1 = index_manager.IndexEntry.init();
    entry1.record_id = 111;
    entry1.key_len = 3;
    entry1.value_len = 4;
    entry1.timestamp = 5000;
    var entry2 = index_manager.IndexEntry.init();
    entry2.record_id = 222;
    entry2.key_len = 3;
    entry2.value_len = 4;
    entry2.timestamp = 6000;
    var page = file_storage.FilePage.init();
    const offset1: u32 = 50;
    const offset2: u32 = offset1 + index_entry_serialization.calculate_serialized_size(3, 4);
    const write1 = manager.write_index_entry_to_page(&entry1, &page, offset1);
    std.debug.assert(write1);
    const write2 = manager.write_index_entry_to_page(&entry2, &page, offset2);
    std.debug.assert(write2);
    const found_offset1 = manager.find_index_entry_offset_in_page(&page, 111);
    std.debug.assert(found_offset1 != null);
    std.debug.assert(found_offset1.? == offset1);
    const found_offset2 = manager.find_index_entry_offset_in_page(&page, 222);
    std.debug.assert(found_offset2 != null);
    std.debug.assert(found_offset2.? == offset2);
    const not_found = manager.find_index_entry_offset_in_page(&page, 999);
    std.debug.assert(not_found == null);
}

test "write_index_entry_to_page overflow" {
    var manager = PersistenceManager.init("test_index4.db");
    std.debug.assert(manager.create_database_file());
    var entry = index_manager.IndexEntry.init();
    entry.record_id = 333;
    entry.key_len = 2000;
    entry.value_len = 2000;
    entry.timestamp = 7000;
    var page = file_storage.FilePage.init();
    const offset: u32 = file_storage.PAGE_SIZE - 100;
    const result = manager.write_index_entry_to_page(&entry, &page, offset);
    std.debug.assert(!result);
}

