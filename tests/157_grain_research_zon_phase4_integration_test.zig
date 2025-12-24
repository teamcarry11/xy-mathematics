//! ZON Format Phase 4 Integration Validation Tests.
//!
//! Why: Validates Phase 4 integration validation using Court Agent's ZON module.
//! Tests round-trip validation, performance benchmarking, and integration with
//! Research Agent's Phase 4 framework.
//! Architecture: Integration with Court Agent ZON module, Research Agent framework.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-23-121000-pst: ZON Format Phase 4 Integration Validation

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const Phase4IntegrationValidator = grain_research.Phase4IntegrationValidator;
const grain_court = @import("grain_court");
const ZonFormat = grain_court.ZonFormat;
const ZonValue = ZonFormat.ZonValue;

test "initialize phase 4 integration validator" {
    const allocator = testing.allocator;
    var validator = Phase4IntegrationValidator.init(allocator);
    defer validator.deinit();

    // Verify initialization.
    const framework = validator.get_framework();
    try testing.expect(framework.test_results.items.len == 0);
    try testing.expect(framework.round_trip_results.items.len == 0);
    try testing.expect(framework.performance_results.items.len == 0);
}

test "perform round-trip test" {
    const allocator = testing.allocator;
    var validator = Phase4IntegrationValidator.init(allocator);
    defer validator.deinit();

    // Prepare test data.
    const pairs = [_]struct { key: []const u8, value: ZonValue }{
        .{ .key = "total_executions", .value = ZonValue.from_u32(1000) },
        .{ .key = "active", .value = ZonValue.from_bool(true) },
        .{ .key = "name", .value = ZonValue.from_string("test") },
    };

    // Perform round-trip test.
    try validator.perform_round_trip_test("test_round_trip", &pairs);

    // Verify results.
    const framework = validator.get_framework();
    const round_trip_results = framework.get_round_trip_results();
    try testing.expect(round_trip_results.len == 1);
    try testing.expect(round_trip_results[0].success);
    try testing.expect(round_trip_results[0].data_integrity);
}

test "perform performance benchmark" {
    const allocator = testing.allocator;
    var validator = Phase4IntegrationValidator.init(allocator);
    defer validator.deinit();

    // Prepare test data.
    const pairs = [_]struct { key: []const u8, value: ZonValue }{
        .{ .key = "total_executions", .value = ZonValue.from_u32(1000) },
        .{ .key = "active", .value = ZonValue.from_bool(true) },
    };

    // Perform performance benchmark.
    try validator.perform_performance_benchmark("test_benchmark", &pairs, 100);

    // Verify results.
    const framework = validator.get_framework();
    const perf_results = framework.get_performance_results();
    try testing.expect(perf_results.len == 2);
    try testing.expect(std.mem.eql(u8, perf_results[0].operation_name, "encoding"));
    try testing.expect(std.mem.eql(u8, perf_results[1].operation_name, "decoding"));
    try testing.expect(perf_results[0].iterations == 100);
    try testing.expect(perf_results[1].iterations == 100);
}

test "perform complete integration validation" {
    const allocator = testing.allocator;
    var validator = Phase4IntegrationValidator.init(allocator);
    defer validator.deinit();

    // Prepare test data.
    const pairs = [_]struct { key: []const u8, value: ZonValue }{
        .{ .key = "total_executions", .value = ZonValue.from_u32(1000) },
        .{ .key = "active", .value = ZonValue.from_bool(true) },
        .{ .key = "name", .value = ZonValue.from_string("test") },
    };

    // Perform complete integration validation.
    try validator.perform_integration_validation("test_integration", &pairs, 100);

    // Verify results.
    const framework = validator.get_framework();
    const test_results = framework.get_test_results();
    try testing.expect(test_results.len == 1);
    try testing.expect(test_results[0].success);
    try testing.expect(test_results[0].round_trip_success);

    const round_trip_results = framework.get_round_trip_results();
    try testing.expect(round_trip_results.len == 1);

    const perf_results = framework.get_performance_results();
    try testing.expect(perf_results.len == 2);
}

test "calculate success rates" {
    const allocator = testing.allocator;
    var validator = Phase4IntegrationValidator.init(allocator);
    defer validator.deinit();

    // Prepare test data.
    const pairs1 = [_]struct { key: []const u8, value: ZonValue }{
        .{ .key = "test1", .value = ZonValue.from_u32(1) },
    };
    const pairs2 = [_]struct { key: []const u8, value: ZonValue }{
        .{ .key = "test2", .value = ZonValue.from_u32(2) },
    };

    // Perform multiple validations.
    try validator.perform_integration_validation("test1", &pairs1, 10);
    try validator.perform_integration_validation("test2", &pairs2, 10);

    // Calculate success rates.
    const framework = validator.get_framework();
    const success_rate = framework.calculate_success_rate();
    try testing.expect(success_rate > 99.0);

    const round_trip_success_rate = framework.calculate_round_trip_success_rate();
    try testing.expect(round_trip_success_rate > 99.0);
}

test "validate with different data types" {
    const allocator = testing.allocator;
    var validator = Phase4IntegrationValidator.init(allocator);
    defer validator.deinit();

    // Test with bool.
    const pairs_bool = [_]struct { key: []const u8, value: ZonValue }{
        .{ .key = "active", .value = ZonValue.from_bool(true) },
    };
    try validator.perform_round_trip_test("test_bool", &pairs_bool);

    // Test with u32.
    const pairs_u32 = [_]struct { key: []const u8, value: ZonValue }{
        .{ .key = "count", .value = ZonValue.from_u32(42) },
    };
    try validator.perform_round_trip_test("test_u32", &pairs_u32);

    // Test with string.
    const pairs_string = [_]struct { key: []const u8, value: ZonValue }{
        .{ .key = "name", .value = ZonValue.from_string("test_value") },
    };
    try validator.perform_round_trip_test("test_string", &pairs_string);

    // Verify all tests passed.
    const framework = validator.get_framework();
    const round_trip_results = framework.get_round_trip_results();
    try testing.expect(round_trip_results.len == 3);
    try testing.expect(round_trip_results[0].success);
    try testing.expect(round_trip_results[1].success);
    try testing.expect(round_trip_results[2].success);
}
