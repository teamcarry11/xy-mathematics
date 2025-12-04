//! Tests for Grain Database Relational Layer.
//!
//! Why: Verify table definitions, schema management, and foreign keys.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-164442-pst: Grain Database Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const Schema = grain_database.Schema;
const Table = grain_database.Table;
const ColumnType = grain_database.ColumnType;

test "schema initialization" {
    const allocator = testing.allocator;
    var schema = try Schema.init(allocator);
    defer schema.deinit();

    try testing.expect(schema.tables_len == 0);
}

test "create table" {
    const allocator = testing.allocator;
    var schema = try Schema.init(allocator);
    defer schema.deinit();

    const table = try schema.create_table("users");
    try testing.expect(schema.tables_len == 1);
    try testing.expect(std.mem.eql(u8, table.name, "users"));
    try testing.expect(table.columns_len == 0);
}

test "add column to table" {
    const allocator = testing.allocator;
    var schema = try Schema.init(allocator);
    defer schema.deinit();

    const table = try schema.create_table("users");
    try table.add_column("id", ColumnType.integer, true, false);
    try table.add_column("name", ColumnType.text, false, false);
    try testing.expect(table.columns_len == 2);
}

test "add foreign key to table" {
    const allocator = testing.allocator;
    var schema = try Schema.init(allocator);
    defer schema.deinit();

    _ = try schema.create_table("users");
    const posts_table = try schema.create_table("posts");
    try posts_table.add_column("user_id", ColumnType.integer, false, false);
    try posts_table.add_foreign_key("user_id", "users", "id");
    try testing.expect(posts_table.foreign_keys_len == 1);
}

test "find table" {
    const allocator = testing.allocator;
    var schema = try Schema.init(allocator);
    defer schema.deinit();

    _ = try schema.create_table("users");
    const found = schema.find_table("users");
    try testing.expect(found != null);
    try testing.expect(std.mem.eql(u8, found.?.name, "users"));
}

test "find column in table" {
    const allocator = testing.allocator;
    var schema = try Schema.init(allocator);
    defer schema.deinit();

    const table = try schema.create_table("users");
    try table.add_column("id", ColumnType.integer, true, false);
    const column = table.find_column("id");
    try testing.expect(column != null);
    try testing.expect(std.mem.eql(u8, column.?.name, "id"));
    try testing.expect(column.?.column_type == ColumnType.integer);
    try testing.expect(column.?.is_primary_key == true);
}

test "drop table" {
    const allocator = testing.allocator;
    var schema = try Schema.init(allocator);
    defer schema.deinit();

    _ = try schema.create_table("users");
    try testing.expect(schema.tables_len == 1);
    try schema.drop_table("users");
    try testing.expect(schema.tables_len == 0);
    const found = schema.find_table("users");
    try testing.expect(found == null);
}

test "duplicate table error" {
    const allocator = testing.allocator;
    var schema = try Schema.init(allocator);
    defer schema.deinit();

    _ = try schema.create_table("users");
    const result = schema.create_table("users");
    try testing.expectError(error.TableExists, result);
}

test "multiple tables" {
    const allocator = testing.allocator;
    var schema = try Schema.init(allocator);
    defer schema.deinit();

    _ = try schema.create_table("users");
    _ = try schema.create_table("posts");
    _ = try schema.create_table("comments");
    try testing.expect(schema.tables_len == 3);

    const users = schema.find_table("users");
    try testing.expect(users != null);

    const posts = schema.find_table("posts");
    try testing.expect(posts != null);

    const comments = schema.find_table("comments");
    try testing.expect(comments != null);
}

test "table with multiple columns" {
    const allocator = testing.allocator;
    var schema = try Schema.init(allocator);
    defer schema.deinit();

    const table = try schema.create_table("users");
    try table.add_column("id", ColumnType.integer, true, false);
    try table.add_column("name", ColumnType.text, false, false);
    try table.add_column("email", ColumnType.text, false, false);
    try table.add_column("age", ColumnType.integer, false, true);
    try table.add_column("active", ColumnType.boolean, false, false);
    try testing.expect(table.columns_len == 5);
}

test "table with multiple foreign keys" {
    const allocator = testing.allocator;
    var schema = try Schema.init(allocator);
    defer schema.deinit();

    _ = try schema.create_table("users");
    _ = try schema.create_table("categories");
    const posts_table = try schema.create_table("posts");
    try posts_table.add_column("user_id", ColumnType.integer, false, false);
    try posts_table.add_column("category_id", ColumnType.integer, false, true);
    try posts_table.add_foreign_key("user_id", "users", "id");
    try posts_table.add_foreign_key("category_id", "categories", "id");
    try testing.expect(posts_table.foreign_keys_len == 2);
}

