//! Tests for Grain Database User Storage Helper
//! 2025-12-21-185000-pst: Grain Silo Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const StorageEngine = grain_database.StorageEngine;
const UserStorage = grain_database.UserStorage;

test "user_storage_init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var user_storage = UserStorage.init(&storage);
    std.debug.assert(user_storage.storage_engine != null);
}

test "user_storage_store_and_retrieve" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var user_storage = UserStorage.init(&storage);
    const user_id = "abc123def456";
    const user_data = "{\"user_id\":\"abc123def456\",\"email\":\"user@example.com\",\"username\":\"user\"}";
    const record_id = try user_storage.store_user(user_id, user_data);
    std.debug.assert(record_id > 0);
    const retrieved = user_storage.get_user(user_id);
    std.debug.assert(retrieved != null);
    std.debug.assert(retrieved.?.record_id == record_id);
}

test "user_storage_update" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var user_storage = UserStorage.init(&storage);
    const user_id = "update123";
    const user_data1 = "{\"email\":\"old@example.com\"}";
    const user_data2 = "{\"email\":\"new@example.com\"}";
    _ = try user_storage.store_user(user_id, user_data1);
    try user_storage.update_user(user_id, user_data2);
    const retrieved = user_storage.get_user(user_id);
    std.debug.assert(retrieved != null);
}

test "user_storage_delete" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var user_storage = UserStorage.init(&storage);
    const user_id = "delete123";
    const user_data = "{\"email\":\"user@example.com\"}";
    _ = try user_storage.store_user(user_id, user_data);
    try user_storage.delete_user(user_id);
    const retrieved = user_storage.get_user(user_id);
    std.debug.assert(retrieved == null);
}

test "user_storage_validation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var user_storage = UserStorage.init(&storage);
    const valid_user_id = "abc123def456";
    const invalid_user_id = "invalid!@#";
    const user_data = "{\"email\":\"user@example.com\"}";
    _ = try user_storage.store_user(valid_user_id, user_data);
    const invalid_result = user_storage.store_user(invalid_user_id, user_data);
    std.debug.assert(invalid_result == error.InvalidUserId);
}

test "user_storage_search_by_email" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var user_storage = UserStorage.init(&storage);
    _ = try user_storage.store_user("user1", "{\"email\":\"alice@example.com\",\"name\":\"Alice\"}");
    _ = try user_storage.store_user("user2", "{\"email\":\"bob@example.com\",\"name\":\"Bob\"}");
    _ = try user_storage.store_user("user3", "{\"email\":\"alice@test.com\",\"name\":\"Alice2\"}");
    var output: [10]u64 = undefined;
    const count = user_storage.search_by_email("alice", &output);
    std.debug.assert(count >= 2);
}

test "user_storage_list_users" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var user_storage = UserStorage.init(&storage);
    const user_data = "{\"email\":\"user@example.com\"}";
    _ = try user_storage.store_user("list1", user_data);
    _ = try user_storage.store_user("list2", user_data);
    var output: [10]u64 = undefined;
    const count = user_storage.list_users(&output);
    std.debug.assert(count >= 2);
}

test "user_storage_list_users_paginated" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var user_storage = UserStorage.init(&storage);
    const user_data = "{\"email\":\"user@example.com\"}";
    _ = try user_storage.store_user("page1", user_data);
    _ = try user_storage.store_user("page2", user_data);
    _ = try user_storage.store_user("page3", user_data);
    var output: [2]u64 = undefined;
    const count1 = user_storage.list_users_paginated(&output, 0, 2);
    std.debug.assert(count1 == 2);
    const count2 = user_storage.list_users_paginated(&output, 2, 2);
    std.debug.assert(count2 >= 1);
}

test "user_storage_count_users" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var user_storage = UserStorage.init(&storage);
    const user_data = "{\"email\":\"user@example.com\"}";
    _ = try user_storage.store_user("count1", user_data);
    _ = try user_storage.store_user("count2", user_data);
    const count = user_storage.count_users();
    std.debug.assert(count >= 2);
}

test "validate_user_id" {
    const valid_id = "abc123def456";
    const invalid_id1 = "invalid!@#";
    const invalid_id2 = "";
    std.debug.assert(grain_database.validate_user_id(valid_id));
    std.debug.assert(!grain_database.validate_user_id(invalid_id1));
    std.debug.assert(!grain_database.validate_user_id(invalid_id2));
}

test "validate_email" {
    const valid_email = "user@example.com";
    const invalid_email1 = "notanemail";
    const invalid_email2 = "missing@dot";
    std.debug.assert(grain_database.validate_email(valid_email));
    std.debug.assert(!grain_database.validate_email(invalid_email1));
    std.debug.assert(!grain_database.validate_email(invalid_email2));
}
