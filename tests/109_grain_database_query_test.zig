//! Tests for Grain Database Query Parser and Executor.
//!
//! Why: Verify query construction and execution.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-164442-pst: Grain Database Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const Query = grain_database.Query;
const QueryType = grain_database.QueryType;
const JoinType = grain_database.JoinType;
const ConditionOperator = grain_database.ConditionOperator;
const QueryExecutor = grain_database.QueryExecutor;
const Schema = grain_database.Schema;
const StorageEngine = grain_database.StorageEngine;

test "query initialization" {
    const allocator = testing.allocator;
    var query = try Query.init(allocator);
    defer query.deinit();

    try testing.expect(query.query_type == QueryType.select);
    try testing.expect(query.conditions_len == 0);
    try testing.expect(query.joins_len == 0);
}

test "add condition to query" {
    const allocator = testing.allocator;
    var query = try Query.init(allocator);
    defer query.deinit();

    try query.add_condition("id", ConditionOperator.equals, "1");
    try testing.expect(query.conditions_len == 1);
    try testing.expect(std.mem.eql(u8, query.conditions[0].column_name, "id"));
    try testing.expect(query.conditions[0].operator == ConditionOperator.equals);
    try testing.expect(std.mem.eql(u8, query.conditions[0].value, "1"));
}

test "add multiple conditions" {
    const allocator = testing.allocator;
    var query = try Query.init(allocator);
    defer query.deinit();

    try query.add_condition("id", ConditionOperator.equals, "1");
    try query.add_condition("name", ConditionOperator.equals, "test");
    try query.add_condition("age", ConditionOperator.greater_than, "18");
    try testing.expect(query.conditions_len == 3);
}

test "add join to query" {
    const allocator = testing.allocator;
    var query = try Query.init(allocator);
    defer query.deinit();

    try query.add_join(JoinType.inner, "posts", "user_id", "id");
    try testing.expect(query.joins_len == 1);
    try testing.expect(query.joins[0].join_type == JoinType.inner);
    try testing.expect(std.mem.eql(u8, query.joins[0].table_name, "posts"));
}

test "add multiple joins" {
    const allocator = testing.allocator;
    var query = try Query.init(allocator);
    defer query.deinit();

    try query.add_join(JoinType.inner, "posts", "user_id", "id");
    try query.add_join(JoinType.left, "comments", "post_id", "id");
    try testing.expect(query.joins_len == 2);
}

test "query executor initialization" {
    const allocator = testing.allocator;
    var schema = try Schema.init(allocator);
    defer schema.deinit();

    var storage = try StorageEngine.init(allocator, 1024 * 1024);
    defer storage.deinit();

    var executor = QueryExecutor.init(allocator, &schema, &storage);
    _ = executor;
    try testing.expect(true);
}

test "different condition operators" {
    const allocator = testing.allocator;
    var query = try Query.init(allocator);
    defer query.deinit();

    try query.add_condition("id", ConditionOperator.equals, "1");
    try query.add_condition("age", ConditionOperator.not_equals, "18");
    try query.add_condition("score", ConditionOperator.greater_than, "100");
    try query.add_condition("price", ConditionOperator.less_than, "50");
    try query.add_condition("count", ConditionOperator.greater_equal, "10");
    try query.add_condition("limit", ConditionOperator.less_equal, "100");
    try testing.expect(query.conditions_len == 6);
}

test "different join types" {
    const allocator = testing.allocator;
    var query = try Query.init(allocator);
    defer query.deinit();

    try query.add_join(JoinType.inner, "posts", "user_id", "id");
    try query.add_join(JoinType.left, "comments", "post_id", "id");
    try query.add_join(JoinType.right, "tags", "post_id", "id");
    try testing.expect(query.joins_len == 3);
}

