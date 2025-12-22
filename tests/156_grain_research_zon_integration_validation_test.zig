//! ZON Format Phase 4 Integration Validation Framework Tests.
//!
//! Why: Validates Phase 4 integration validation framework structure.
//! Tests framework initialization, result tracking, success rate calculation.
//! Architecture: Integration validation framework, round-trip tests, performance benchmarks.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-210000-pst: ZON Format Phase 4 Framework Preparation

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const IntegrationValidationFramework = grain_research.IntegrationValidationFramework;
const IntegrationValidationResult = grain_research.IntegrationValidationResult;
const RoundTripResult = grain_research.RoundTripResult;
const PerformanceBenchmarkResult = grain_research.PerformanceBenchmarkResult;

test "initialize integration validation framework" {
    const allocator = testing.allocator;
    var framework = IntegrationValidationFramework.init(allocator);
    defer framework.deinit();

    // Verify initialization.
    try testing.expect(framework.test_results.items.len == 0);
    try testing.expect(framework.round_trip_results.items.len == 0);
    try testing.expect(framework.performance_results.items.len == 0);
}

test "add integration validation result" {
    const allocator = testing.allocator;
    var framework = IntegrationValidationFramework.init(allocator);
    defer framework.deinit();

    // Add test result.
    const result = IntegrationValidationResult.init(
        "Test 1",
        true,
        true,
        10,
        5,
        "",
    );
    try framework.add_test_result(result);

    // Verify result added.
    const results = framework.get_test_results();
    try testing.expect(results.len == 1);
    try testing.expect(results[0].success);
    try testing.expect(results[0].round_trip_success);
    try testing.expect(results[0].performance_encoding_ms == 10);
    try testing.expect(results[0].performance_decoding_ms == 5);
}

test "add round-trip test result" {
    const allocator = testing.allocator;
    var framework = IntegrationValidationFramework.init(allocator);
    defer framework.deinit();

    // Add round-trip result.
    const result = RoundTripResult.init(
        "original",
        "encoded",
        "decoded",
        true,
        true,
        "",
    );
    try framework.add_round_trip_result(result);

    // Verify result added.
    const results = framework.get_round_trip_results();
    try testing.expect(results.len == 1);
    try testing.expect(results[0].success);
    try testing.expect(results[0].data_integrity);
    try testing.expect(std.mem.eql(u8, results[0].original_data, "original"));
    try testing.expect(std.mem.eql(u8, results[0].encoded_data, "encoded"));
    try testing.expect(std.mem.eql(u8, results[0].decoded_data, "decoded"));
}

test "add performance benchmark result" {
    const allocator = testing.allocator;
    var framework = IntegrationValidationFramework.init(allocator);
    defer framework.deinit();

    // Add performance result.
    const result = PerformanceBenchmarkResult.init(
        "encoding",
        100,
        1000,
        10,
        5,
        20,
    );
    try framework.add_performance_result(result);

    // Verify result added.
    const results = framework.get_performance_results();
    try testing.expect(results.len == 1);
    try testing.expect(results[0].iterations == 100);
    try testing.expect(results[0].total_time_ms == 1000);
    try testing.expect(results[0].average_time_ms == 10);
    try testing.expect(results[0].min_time_ms == 5);
    try testing.expect(results[0].max_time_ms == 20);
}

test "calculate validation success rate" {
    const allocator = testing.allocator;
    var framework = IntegrationValidationFramework.init(allocator);
    defer framework.deinit();

    // Add test results.
    try framework.add_test_result(IntegrationValidationResult.init("Test 1", true, true, 10, 5, ""));
    try framework.add_test_result(IntegrationValidationResult.init("Test 2", true, true, 15, 8, ""));
    try framework.add_test_result(IntegrationValidationResult.init("Test 3", false, false, 20, 10, "Error"));

    // Calculate success rate.
    const success_rate = framework.calculate_success_rate();
    try testing.expect(success_rate > 66.0);
    try testing.expect(success_rate < 67.0);
}

test "calculate round-trip success rate" {
    const allocator = testing.allocator;
    var framework = IntegrationValidationFramework.init(allocator);
    defer framework.deinit();

    // Add round-trip results.
    try framework.add_round_trip_result(RoundTripResult.init("data1", "enc1", "dec1", true, true, ""));
    try framework.add_round_trip_result(RoundTripResult.init("data2", "enc2", "dec2", true, true, ""));
    try framework.add_round_trip_result(RoundTripResult.init("data3", "enc3", "dec3", false, false, "Error"));

    // Calculate round-trip success rate.
    const success_rate = framework.calculate_round_trip_success_rate();
    try testing.expect(success_rate > 66.0);
    try testing.expect(success_rate < 67.0);
}

test "calculate success rate with empty results" {
    const allocator = testing.allocator;
    var framework = IntegrationValidationFramework.init(allocator);
    defer framework.deinit();

    // Calculate success rate with no results.
    const success_rate = framework.calculate_success_rate();
    try testing.expect(success_rate == 0.0);
}
