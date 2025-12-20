//! Tests for Grain Database Multi-Page Record Support
//! 2025-12-07-070701-pst: Grain Silo Agent

const std = @import("std");
const testing = std.testing;
const grain_core = @import("grain_core");
const file_storage = grain_core.file_storage;
const grain_database = @import("grain_database");
const PersistenceManager = grain_database.PersistenceManager;
const StorageEngine = grain_database.StorageEngine;

test "multi_page_record_manager_init" {
    var manager = grain_database.MultiPageRecordManager.init();
    std.debug.assert(manager.metadata_len == 0);
}

test "multi_page_record_manager_add_metadata" {
    var manager = grain_database.MultiPageRecordManager.init();
    const added = manager.add_metadata(123, 10, 3, 10000, 1000);
    std.debug.assert(added);
    std.debug.assert(manager.metadata_len == 1);
    std.debug.assert(manager.metadata[0].record_id == 123);
    std.debug.assert(manager.metadata[0].first_page_id == 10);
    std.debug.assert(manager.metadata[0].page_count == 3);
    std.debug.assert(manager.metadata[0].total_size == 10000);
}

test "multi_page_record_manager_find_metadata" {
    var manager = grain_database.MultiPageRecordManager.init();
    _ = manager.add_metadata(456, 20, 5, 20000, 2000);
    const found = manager.find_metadata(456);
    std.debug.assert(found != null);
    std.debug.assert(found.?.record_id == 456);
    std.debug.assert(found.?.first_page_id == 20);
    const not_found = manager.find_metadata(999);
    std.debug.assert(not_found == null);
}

test "needs_multiple_pages" {
    const small_size: u32 = 1000;
    const large_size: u32 = 5000;
    std.debug.assert(!grain_database.MultiPageRecordManager.needs_multiple_pages(small_size, file_storage.PAGE_SIZE));
    std.debug.assert(grain_database.MultiPageRecordManager.needs_multiple_pages(large_size, file_storage.PAGE_SIZE));
}

test "calculate_page_count" {
    const small_size: u32 = 1000;
    const medium_size: u32 = 4096;
    const large_size: u32 = 10000;
    std.debug.assert(grain_database.MultiPageRecordManager.calculate_page_count(small_size, file_storage.PAGE_SIZE) == 1);
    std.debug.assert(grain_database.MultiPageRecordManager.calculate_page_count(medium_size, file_storage.PAGE_SIZE) == 1);
    std.debug.assert(grain_database.MultiPageRecordManager.calculate_page_count(large_size, file_storage.PAGE_SIZE) == 3);
}

test "write_record_multi_page basic" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var manager = PersistenceManager.init("test_multi.db");
    std.debug.assert(manager.create_database_file());
    var engine = StorageEngine.init(allocator);
    const key = "large_key";
    var large_value: [5000]u8 = undefined;
    var i: u32 = 0;
    while (i < 5000) : (i += 1) {
        large_value[i] = @as(u8, @intCast(i % 256));
    }
    const record_id = engine.create_record(key, &large_value) catch return;
    const record = engine.get_record(record_id) orelse return;
    var pages: [3]file_storage.FilePage = undefined;
    var j: u32 = 0;
    while (j < 3) : (j += 1) {
        pages[j] = file_storage.FilePage.init(10 + j);
    }
    const result = manager.write_record_multi_page(&record, &pages, 10);
    std.debug.assert(result);
    std.debug.assert(pages[0].is_dirty);
    std.debug.assert(pages[1].is_dirty);
    std.debug.assert(pages[2].is_dirty);
}

test "read_record_multi_page basic" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var manager = PersistenceManager.init("test_multi2.db");
    std.debug.assert(manager.create_database_file());
    var engine = StorageEngine.init(allocator);
    const key = "large_key2";
    var large_value: [6000]u8 = undefined;
    var i: u32 = 0;
    while (i < 6000) : (i += 1) {
        large_value[i] = @as(u8, @intCast((i + 10) % 256));
    }
    const record_id = engine.create_record(key, &large_value) catch return;
    const record = engine.get_record(record_id) orelse return;
    var pages: [3]file_storage.FilePage = undefined;
    var j: u32 = 0;
    while (j < 3) : (j += 1) {
        pages[j] = file_storage.FilePage.init(20 + j);
    }
    const write_result = manager.write_record_multi_page(&record, &pages, 20);
    std.debug.assert(write_result);
    const read_record = manager.read_record_multi_page(allocator, &pages, record_id);
    std.debug.assert(read_record != null);
    std.debug.assert(read_record.?.record_id == record_id);
    std.debug.assert(read_record.?.key_len == key.len);
    std.debug.assert(read_record.?.value_len == 6000);
    i = 0;
    while (i < 6000) : (i += 1) {
        std.debug.assert(read_record.?.value[i] == @as(u8, @intCast((i + 10) % 256)));
    }
}

