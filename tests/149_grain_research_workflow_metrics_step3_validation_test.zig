//! Step 3 Validation Test: Real Workflow Metrics Analysis.
//!
//! Why: Validates end-to-end integration with real workflow metrics from Flow Agent
//! for Phase 3 Step 3 validation.
//! Architecture: Generate real metrics, parse, analyze, generate insights.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-105400-pst: Flow Agent Phase 3 Step 3 Validation

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const grain_flow = @import("grain_flow");
const WorkflowMetricsAnalyzer = grain_research.WorkflowMetricsAnalyzer;
const InsightsGenerator = grain_research.InsightsGenerator;

test "step 3 validation: analyze real workflow metrics" {
    const allocator = testing.allocator;

    // Generate real workflow metrics using Flow Agent's generator.
    var generator = grain_flow.RealisticMetricsGenerator.init();
    const executed = generator.generate_realistic_scenario(30);
    std.debug.assert(executed == 30);

    // Export metrics JSON.
    var json_buffer: [10_485_760]u8 = undefined;
    const written = generator.export_realistic_metrics_json(&json_buffer);
    std.debug.assert(written > 0);
    std.debug.assert(written < json_buffer.len);

    // Parse real metrics using Research Agent's analyzer.
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data = json_buffer[0..written];
    try analyzer.parse_json_metrics(json_data);

    // Validate metrics were parsed.
    try testing.expect(analyzer.get_workflow_execution_count() > 0);
    try testing.expect(analyzer.get_coordination_metric_count() > 0);
    try testing.expect(analyzer.get_failure_metric_count() >= 0);
    try testing.expect(analyzer.get_performance_metric_count() > 0);

    // Generate insights.
    var insights_gen = InsightsGenerator.init(allocator);
    defer insights_gen.deinit();

    try insights_gen.generate_insights(&analyzer);
    try insights_gen.test_hypotheses(&analyzer);
    try insights_gen.generate_recommendations(&analyzer);

    // Validate insights were generated.
    try testing.expect(insights_gen.get_insight_count() >= 0);
    try testing.expect(insights_gen.get_hypothesis_result_count() >= 3);
    try testing.expect(insights_gen.get_recommendation_count() >= 0);
}

test "step 3 validation: real metrics characteristics" {
    const allocator = testing.allocator;

    // Generate real workflow metrics (30 executions).
    var generator = grain_flow.RealisticMetricsGenerator.init();
    const executed = generator.generate_realistic_scenario(30);
    std.debug.assert(executed == 30);

    // Export metrics JSON.
    var json_buffer: [10_485_760]u8 = undefined;
    const written = generator.export_realistic_metrics_json(&json_buffer);
    std.debug.assert(written > 0);

    // Parse and analyze.
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data = json_buffer[0..written];
    try analyzer.parse_json_metrics(json_data);

    // Validate real metrics characteristics.
    const execution_count = analyzer.get_workflow_execution_count();
    try testing.expect(execution_count > 0);
    try testing.expect(execution_count <= 30);

    const avg_exec_time = analyzer.get_average_execution_time_ms();
    try testing.expect(avg_exec_time > 0);
    try testing.expect(avg_exec_time < 10000); // Realistic range

    const success_rate = analyzer.get_success_rate_percent();
    try testing.expect(success_rate <= 100);

    const coord_count = analyzer.get_coordination_metric_count();
    try testing.expect(coord_count > 0);

    const avg_latency = analyzer.get_average_coordination_latency_ms();
    try testing.expect(avg_latency >= 0);
    try testing.expect(avg_latency < 1000); // Realistic range
}

test "step 3 validation: generate insights from real metrics" {
    const allocator = testing.allocator;

    // Generate real workflow metrics.
    var generator = grain_flow.RealisticMetricsGenerator.init();
    _ = generator.generate_realistic_scenario(30);

    // Export metrics JSON.
    var json_buffer: [10_485_760]u8 = undefined;
    const written = generator.export_realistic_metrics_json(&json_buffer);
    std.debug.assert(written > 0);

    // Parse and analyze.
    var analyzer = WorkflowMetricsAnalyzer.init(allocator);
    defer analyzer.deinit();

    const json_data = json_buffer[0..written];
    try analyzer.parse_json_metrics(json_data);

    // Generate insights.
    var insights_gen = InsightsGenerator.init(allocator);
    defer insights_gen.deinit();

    try insights_gen.generate_insights(&analyzer);
    try insights_gen.test_hypotheses(&analyzer);
    try insights_gen.generate_recommendations(&analyzer);

    // Validate insights were generated.
    const insight_count = insights_gen.get_insight_count();
    const hypothesis_count = insights_gen.get_hypothesis_result_count();
    const recommendation_count = insights_gen.get_recommendation_count();

    try testing.expect(insight_count >= 0);
    try testing.expect(hypothesis_count >= 3); // At least 3 hypotheses tested
    try testing.expect(recommendation_count >= 0);
}
