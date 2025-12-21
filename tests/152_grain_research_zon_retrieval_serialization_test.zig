//! ZON Format Retrieval Serialization Tests.
//!
//! Why: Validates JSON and ZON serialization of test datasets for retrieval
//! accuracy testing. Tests serialization correctness and format compliance.
//! Architecture: JSON and ZON serialization, format validation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-144000-pst: ZON Format Token Efficiency Validation Phase 2

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const TestDataset = grain_research.TestDataset;
const Fact = grain_research.Fact;
const Query = grain_research.Query;
const QueryType = grain_research.QueryType;
const Serializer = grain_research.Serializer;
const SerializationFormat = grain_research.SerializationFormat;

test "serialize dataset to JSON" {
    const allocator = testing.allocator;
    var dataset = TestDataset.init(allocator);
    defer dataset.deinit();

    // Add facts.
    const fact1 = Fact.init(1, "Workflow backup executed in 500ms", "workflow");
    const fact2 = Fact.init(2, "Database host is localhost", "config");
    try dataset.add_fact(fact1);
    try dataset.add_fact(fact2);

    // Add queries.
    const expected_fact_ids = [_]u32{ 1 };
    const query1 = Query.init(1, "How long did backup take?", &expected_fact_ids, .simple_fact);
    try dataset.add_query(query1);

    // Serialize to JSON.
    var serializer = Serializer.init(allocator);
    defer serializer.deinit();

    const json_result = try serializer.serialize_to_json(&dataset);
    defer allocator.free(json_result.data);

    // Verify JSON format.
    try testing.expect(json_result.format == .json);
    try testing.expect(json_result.len > 0);
    try testing.expect(std.mem.indexOf(u8, json_result.data, "\"facts\":") != null);
    try testing.expect(std.mem.indexOf(u8, json_result.data, "\"queries\":") != null);
    try testing.expect(std.mem.indexOf(u8, json_result.data, "Workflow backup") != null);
}

test "serialize dataset to ZON" {
    const allocator = testing.allocator;
    var dataset = TestDataset.init(allocator);
    defer dataset.deinit();

    // Add facts.
    const fact1 = Fact.init(1, "Workflow backup executed in 500ms", "workflow");
    const fact2 = Fact.init(2, "Database host is localhost", "config");
    try dataset.add_fact(fact1);
    try dataset.add_fact(fact2);

    // Add queries.
    const expected_fact_ids = [_]u32{ 1 };
    const query1 = Query.init(1, "How long did backup take?", &expected_fact_ids, .simple_fact);
    try dataset.add_query(query1);

    // Serialize to ZON.
    var serializer = Serializer.init(allocator);
    defer serializer.deinit();

    const zon_result = try serializer.serialize_to_zon(&dataset);
    defer allocator.free(zon_result.data);

    // Verify ZON format.
    try testing.expect(zon_result.format == .zon);
    try testing.expect(zon_result.len > 0);
    try testing.expect(std.mem.indexOf(u8, zon_result.data, "id|text|category") != null);
    try testing.expect(std.mem.indexOf(u8, zon_result.data, "Workflow backup") != null);
}

test "serialize facts with special characters" {
    const allocator = testing.allocator;
    var dataset = TestDataset.init(allocator);
    defer dataset.deinit();

    // Add fact with special characters.
    const fact1 = Fact.init(1, "Value contains \"quotes\" and |pipes|", "test");
    try dataset.add_fact(fact1);

    // Serialize to JSON.
    var serializer = Serializer.init(allocator);
    defer serializer.deinit();

    const json_result = try serializer.serialize_to_json(&dataset);
    defer allocator.free(json_result.data);

    // Verify JSON escaping.
    try testing.expect(std.mem.indexOf(u8, json_result.data, "\\\"quotes\\\"") != null);

    // Serialize to ZON.
    const zon_result = try serializer.serialize_to_zon(&dataset);
    defer allocator.free(zon_result.data);

    // Verify ZON escaping.
    try testing.expect(std.mem.indexOf(u8, zon_result.data, "\\|pipes\\|") != null);
}

test "serialize queries with multiple expected facts" {
    const allocator = testing.allocator;
    var dataset = TestDataset.init(allocator);
    defer dataset.deinit();

    // Add facts.
    const fact1 = Fact.init(1, "Total executions: 1000", "metric");
    const fact2 = Fact.init(2, "Success rate: 90%", "metric");
    const fact3 = Fact.init(3, "Average time: 1250ms", "metric");
    try dataset.add_fact(fact1);
    try dataset.add_fact(fact2);
    try dataset.add_fact(fact3);

    // Add query with multiple expected facts.
    const expected_fact_ids = [_]u32{ 1, 2, 3 };
    const query1 = Query.init(1, "What are all the metrics?", &expected_fact_ids, .complex_query);
    try dataset.add_query(query1);

    // Serialize to JSON.
    var serializer = Serializer.init(allocator);
    defer serializer.deinit();

    const json_result = try serializer.serialize_to_json(&dataset);
    defer allocator.free(json_result.data);

    // Verify JSON contains all fact IDs.
    try testing.expect(std.mem.indexOf(u8, json_result.data, "\"expected_fact_ids\":[1,2,3]") != null);

    // Serialize to ZON.
    const zon_result = try serializer.serialize_to_zon(&dataset);
    defer allocator.free(zon_result.data);

    // Verify ZON contains all fact IDs.
    try testing.expect(std.mem.indexOf(u8, zon_result.data, "1,2,3") != null);
}

test "serialize empty dataset" {
    const allocator = testing.allocator;
    var dataset = TestDataset.init(allocator);
    defer dataset.deinit();

    // Serialize empty dataset to JSON.
    var serializer = Serializer.init(allocator);
    defer serializer.deinit();

    const json_result = try serializer.serialize_to_json(&dataset);
    defer allocator.free(json_result.data);

    // Verify JSON structure (empty arrays).
    try testing.expect(std.mem.indexOf(u8, json_result.data, "\"facts\":[]") != null);
    try testing.expect(std.mem.indexOf(u8, json_result.data, "\"queries\":[]") != null);
}
