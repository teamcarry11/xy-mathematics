const std = @import("std");
const testing = std.testing;
const grain_silo = @import("grain_silo");
const Storage = grain_silo.Storage;

test "silo storage init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const hot_cache_size: u64 = 47_185_920_000; // 44GB
    var silo = try Storage.ObjectStorage.init(allocator, hot_cache_size);
    defer silo.deinit();

    try testing.expect(silo.objects_len == 0);
    try testing.expect(silo.hot_cache_size == hot_cache_size);
    try testing.expect(silo.hot_cache_used == 0);
}

test "silo store object" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const hot_cache_size: u64 = 1_073_741_824; // 1GB for testing
    var silo = try Storage.ObjectStorage.init(allocator, hot_cache_size);
    defer silo.deinit();

    try silo.store_object("test-key", "test-data", "test-metadata");

    try testing.expect(silo.objects_len == 1);

    const object = silo.get_object("test-key");
    try testing.expect(object != null);
    try testing.expect(std.mem.eql(u8, object.?.key, "test-key"));
    try testing.expect(std.mem.eql(u8, object.?.data, "test-data"));
    try testing.expect(std.mem.eql(u8, object.?.metadata, "test-metadata"));
}

test "silo hot cache promotion" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const hot_cache_size: u64 = 1_073_741_824; // 1GB for testing
    var silo = try Storage.ObjectStorage.init(allocator, hot_cache_size);
    defer silo.deinit();

    try silo.store_object("test-key", "test-data", "test-metadata");
    try silo.promote_to_hot("test-key", 0);

    const object = silo.get_object("test-key");
    try testing.expect(object != null);
    try testing.expect(object.?.is_hot == true);
    try testing.expect(object.?.hot_cache_offset == 0);
    try testing.expect(silo.hot_cache_used == object.?.data_len);
}

test "silo hot cache demotion" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const hot_cache_size: u64 = 1_073_741_824; // 1GB for testing
    var silo = try Storage.ObjectStorage.init(allocator, hot_cache_size);
    defer silo.deinit();

    try silo.store_object("test-key", "test-data", "test-metadata");
    try silo.promote_to_hot("test-key", 0);
    silo.demote_from_hot("test-key");

    const object = silo.get_object("test-key");
    try testing.expect(object != null);
    try testing.expect(object.?.is_hot == false);
    try testing.expect(object.?.hot_cache_offset == null);
    try testing.expect(silo.hot_cache_used == 0);
}

