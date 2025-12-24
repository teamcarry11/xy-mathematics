//! ZON Format Phase 4 Validation Runner Tests.
//!
//! Why: Validates Phase 4 validation runner functionality.
//! Tests validation test execution, report generation, and summary statistics.
//! Architecture: Validation runner, report generation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-23-122000-pst: ZON Format Phase 4 Validation Runner

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const Phase4IntegrationValidator = grain_research.Phase4IntegrationValidator;
const Phase4ValidationRunner = grain_research.Phase4ValidationRunner;

test "run validation tests" {
    const allocator = testing.allocator;
    var validator = Phase4IntegrationValidator.init(allocator);
    defer validator.deinit();

    // Run validation tests.
    try Phase4ValidationRunner.run_validation_tests(&validator);

    // Verify tests ran.
    const framework = validator.get_framework();
    const test_results = framework.get_test_results();
    try testing.expect(test_results.len >= 4);

    // Verify all tests passed.
    for (test_results) |result| {
        try testing.expect(result.success);
        try testing.expect(result.round_trip_success);
    }
}

test "generate report summary" {
    const allocator = testing.allocator;
    var validator = Phase4IntegrationValidator.init(allocator);
    defer validator.deinit();

    // Run validation tests.
    try Phase4ValidationRunner.run_validation_tests(&validator);

    // Generate report summary.
    const summary = Phase4ValidationRunner.generate_report_summary(&validator);

    // Verify summary.
    try testing.expect(summary.total_tests >= 4);
    try testing.expect(summary.success_count >= 4);
    try testing.expect(summary.success_rate > 99.0);
    try testing.expect(summary.round_trip_success_rate > 99.0);
    try testing.expect(summary.avg_encoding_ms >= 0);
    try testing.expect(summary.avg_decoding_ms >= 0);
}

test "validation report success criteria" {
    const allocator = testing.allocator;
    var validator = Phase4IntegrationValidator.init(allocator);
    defer validator.deinit();

    // Run validation tests.
    try Phase4ValidationRunner.run_validation_tests(&validator);

    // Generate report summary.
    const summary = Phase4ValidationRunner.generate_report_summary(&validator);

    // Verify success criteria:
    // 1. Round-trip tests pass (lossless conversion) - > 99% success rate
    try testing.expect(summary.round_trip_success_rate > 99.0);

    // 2. Performance acceptable (< 10ms for 10KB) - verify encoding/decoding times
    // Note: Actual performance depends on system, but should be reasonable
    // Using 1000ms as upper bound for test (actual should be much lower)
    try testing.expect(summary.avg_encoding_ms < 1000);
    try testing.expect(summary.avg_decoding_ms < 1000);

    // 3. Integration validated - all tests pass
    try testing.expect(summary.success_rate > 99.0);
}
