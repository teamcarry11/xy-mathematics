//! ZON Format Phase 4 Validation Runner Tool.
//!
//! Why: Runs Phase 4 validation tests and generates validation report.
//! Validates round-trip conversion, performance benchmarks, and integration success.
//! Architecture: Standalone validation runner, report generation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-28-125036-pst: ZON Format Phase 4 Validation Runner Tool

const std = @import("std");
const grain_research = @import("grain_research");
const Phase4IntegrationValidator = grain_research.Phase4IntegrationValidator;
const Phase4ValidationRunner = grain_research.Phase4ValidationRunner;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("ZON Format Phase 4 Validation Runner\n", .{});
    std.debug.print("====================================\n\n", .{});

    // Initialize validator.
    var validator = Phase4IntegrationValidator.init(allocator);
    defer validator.deinit();

    // Run validation tests.
    std.debug.print("Running validation tests...\n", .{});
    try Phase4ValidationRunner.run_validation_tests(&validator);

    // Generate report summary.
    std.debug.print("Generating report summary...\n\n", .{});
    const summary = Phase4ValidationRunner.generate_report_summary(&validator);

    // Print results.
    std.debug.print("Validation Results:\n", .{});
    std.debug.print("-------------------\n", .{});
    std.debug.print("Total Tests: {}\n", .{summary.total_tests});
    std.debug.print("Success Count: {}\n", .{summary.success_count});
    std.debug.print("Success Rate: {d:.2}%\n", .{summary.success_rate});
    std.debug.print("Round-Trip Success Rate: {d:.2}%\n", .{summary.round_trip_success_rate});
    std.debug.print("Average Encoding Time: {d:.2} ms\n", .{summary.avg_encoding_ms});
    std.debug.print("Average Decoding Time: {d:.2} ms\n", .{summary.avg_decoding_ms});

    // Print detailed results.
    const framework = validator.get_framework();
    const test_results = framework.get_test_results();
    const round_trip_results = framework.get_round_trip_results();
    const perf_results = framework.get_performance_results();

    std.debug.print("\nDetailed Test Results:\n", .{});
    std.debug.print("---------------------\n", .{});
    for (test_results, 0..) |result, i| {
        std.debug.print("Test {}: {s} - {s}\n", .{ i + 1, result.test_name, if (result.success) "PASS" else "FAIL" });
    }

    std.debug.print("\nRound-Trip Results:\n", .{});
    std.debug.print("------------------\n", .{});
    for (round_trip_results, 0..) |result, i| {
        std.debug.print("Round-Trip {}: {s} - {s} (Data Integrity: {})\n", .{
            i + 1,
            result.test_name,
            if (result.success) "PASS" else "FAIL",
            result.data_integrity,
        });
    }

    std.debug.print("\nPerformance Results:\n", .{});
    std.debug.print("-------------------\n", .{});
    for (perf_results, 0..) |result, i| {
        std.debug.print("Performance {}: {s} - {d} ms (avg: {d} ms, min: {d} ms, max: {d} ms)\n", .{
            i + 1,
            result.operation_name,
            result.total_time_ms,
            result.average_time_ms,
            result.min_time_ms,
            result.max_time_ms,
        });
    }

    // Success criteria validation.
    std.debug.print("\nSuccess Criteria:\n", .{});
    std.debug.print("----------------\n", .{});
    const round_trip_pass = summary.round_trip_success_rate > 99.0;
    const performance_pass = summary.avg_encoding_ms < 1000 and summary.avg_decoding_ms < 1000;
    const integration_pass = summary.success_rate > 99.0;

    std.debug.print("Round-Trip Tests (>99%): {s}\n", .{if (round_trip_pass) "PASS" else "FAIL"});
    std.debug.print("Performance (<1000ms): {s}\n", .{if (performance_pass) "PASS" else "FAIL"});
    std.debug.print("Integration (>99%): {s}\n", .{if (integration_pass) "PASS" else "FAIL"});

    const all_pass = round_trip_pass and performance_pass and integration_pass;
    std.debug.print("\nOverall Status: {s}\n", .{if (all_pass) "PASS" else "FAIL"});

    if (all_pass) {
        std.debug.print("\n✅ Phase 4 Integration Validation: SUCCESS\n", .{});
    } else {
        std.debug.print("\n❌ Phase 4 Integration Validation: FAILED\n", .{});
        return error.ValidationFailed;
    }
}
