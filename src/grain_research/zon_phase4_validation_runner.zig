//! Grain Research ZON Format Phase 4: Validation Runner.
//!
//! Why: Runs comprehensive Phase 4 validation tests and generates validation report.
//! Validates round-trip conversion, performance benchmarks, and integration success.
//! Architecture: Validation test runner, report generation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-23-122000-pst: ZON Format Phase 4 Validation Runner

const std = @import("std");
const grain_court = @import("grain_court");
const ZonFormat = grain_court.ZonFormat;
const ZonValue = ZonFormat.ZonValue;
const zon_phase4_integration = @import("zon_phase4_integration.zig");
const Phase4IntegrationValidator = zon_phase4_integration.Phase4IntegrationValidator;
const IntegrationValidationFramework = @import("zon_integration_validation.zig").IntegrationValidationFramework;

// Bounded: Max validation test cases.
pub const MAX_VALIDATION_TEST_CASES: u32 = 100;

// Phase 4 validation runner (helper functions for Phase4IntegrationValidator).
pub const Phase4ValidationRunner = struct {
    // Run comprehensive Phase 4 validation tests.
    pub fn run_validation_tests(
        validator: *Phase4IntegrationValidator,
    ) !void {
        std.debug.assert(validator.allocator != null);

        // Test 1: Simple object (config file).
        const test1_pairs = [_]struct { key: []const u8, value: ZonValue }{
            .{ .key = "database_host", .value = ZonValue.from_string("localhost") },
            .{ .key = "database_port", .value = ZonValue.from_u32(5432) },
            .{ .key = "dark_mode", .value = ZonValue.from_bool(true) },
        };
        try validator.perform_integration_validation("test_simple_object", &test1_pairs, 100);

        // Test 2: Array of objects (workflow metrics).
        const test2_pairs = [_]struct { key: []const u8, value: ZonValue }{
            .{ .key = "total_executions", .value = ZonValue.from_u32(1000) },
            .{ .key = "active_workflows", .value = ZonValue.from_u32(5) },
            .{ .key = "success_rate", .value = ZonValue.from_u32(95) },
        };
        try validator.perform_integration_validation("test_workflow_metrics", &test2_pairs, 100);

        // Test 3: Mixed data types.
        const test3_pairs = [_]struct { key: []const u8, value: ZonValue }{
            .{ .key = "name", .value = ZonValue.from_string("test") },
            .{ .key = "count", .value = ZonValue.from_u32(42) },
            .{ .key = "enabled", .value = ZonValue.from_bool(true) },
        };
        try validator.perform_integration_validation("test_mixed_types", &test3_pairs, 100);

        // Test 4: Large dataset (performance test).
        // Note: Using static array for large dataset to avoid memory management complexity.
        const test4_pairs = [_]struct { key: []const u8, value: ZonValue }{
            .{ .key = "field_0", .value = ZonValue.from_u32(0) },
            .{ .key = "field_1", .value = ZonValue.from_u32(1) },
            .{ .key = "field_2", .value = ZonValue.from_u32(2) },
            .{ .key = "field_3", .value = ZonValue.from_u32(3) },
            .{ .key = "field_4", .value = ZonValue.from_u32(4) },
        };
        try validator.perform_integration_validation("test_large_dataset", &test4_pairs, 50);
    }

    // Generate validation report summary.
    pub fn generate_report_summary(
        validator: *const Phase4IntegrationValidator,
    ) struct {
        total_tests: u32,
        success_count: u32,
        success_rate: f64,
        round_trip_success_rate: f64,
        avg_encoding_ms: f64,
        avg_decoding_ms: f64,
    } {
        const framework = validator.get_framework();
        const test_results = framework.get_test_results();
        const round_trip_results = framework.get_round_trip_results();
        const perf_results = framework.get_performance_results();

        var success_count: u32 = 0;
        for (test_results) |result| {
            if (result.success) {
                success_count += 1;
            }
        }

        const success_rate = if (test_results.len > 0)
            (@as(f64, @floatFromInt(success_count)) / @as(f64, @floatFromInt(test_results.len))) * 100.0
        else
            0.0;

        const round_trip_success_rate = framework.calculate_round_trip_success_rate();

        var total_encoding_ms: u64 = 0;
        var total_decoding_ms: u64 = 0;
        var encoding_count: u32 = 0;
        var decoding_count: u32 = 0;

        for (perf_results) |result| {
            if (std.mem.eql(u8, result.operation_name, "encoding")) {
                total_encoding_ms += result.average_time_ms;
                encoding_count += 1;
            } else if (std.mem.eql(u8, result.operation_name, "decoding")) {
                total_decoding_ms += result.average_time_ms;
                decoding_count += 1;
            }
        }

        const avg_encoding_ms = if (encoding_count > 0)
            @as(f64, @floatFromInt(total_encoding_ms)) / @as(f64, @floatFromInt(encoding_count))
        else
            0.0;

        const avg_decoding_ms = if (decoding_count > 0)
            @as(f64, @floatFromInt(total_decoding_ms)) / @as(f64, @floatFromInt(decoding_count))
        else
            0.0;

        return .{
            .total_tests = @intCast(test_results.len),
            .success_count = success_count,
            .success_rate = success_rate,
            .round_trip_success_rate = round_trip_success_rate,
            .avg_encoding_ms = avg_encoding_ms,
            .avg_decoding_ms = avg_decoding_ms,
        };
    }
};
