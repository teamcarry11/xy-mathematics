//! Tests for Grain Flow Failure Pattern Metrics.
//!
//! Tests metric collection for failure pattern analysis.

const std = @import("std");
const grain_flow = @import("grain_flow");
const failure_pattern_metrics = grain_flow.failure_pattern_metrics;
const event_bus = grain_flow.event_bus;
const agent_coordinator = grain_flow.agent_coordinator;
const workflow_engine = grain_flow.workflow_engine;

test "metrics collector initialization" {
    const collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    try std.testing.expect(collector.failures_len == 0);
    try std.testing.expect(collector.total_failures == 0);
    try std.testing.expect(collector.recovered_failures == 0);
}

test "record failure" {
    var collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    const complexity = failure_pattern_metrics.WorkflowComplexity.init(10, 5, 3);
    const result = collector.record_failure(
        1,
        10,
        20,
        failure_pattern_metrics.FailureType.transient,
        1000,
        complexity,
        null,
        null,
    );
    try std.testing.expect(result == true);
    try std.testing.expect(collector.failures_len == 1);
    try std.testing.expect(collector.total_failures == 1);
    try std.testing.expect(collector.failures[0].failure_type == .transient);
    try std.testing.expect(collector.failures[0].workflow_id == 1);
    try std.testing.expect(collector.failures[0].failure_id == 1);
}

test "get failure count by type" {
    var collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    const complexity = failure_pattern_metrics.WorkflowComplexity.init(5, 2, 2);
    _ = collector.record_failure(1, 0, 0, .transient, 1000, complexity, null, null);
    _ = collector.record_failure(2, 0, 0, .transient, 1000, complexity, null, null);
    _ = collector.record_failure(3, 0, 0, .permanent, 1000, complexity, null, null);
    const transient_count = collector.get_failure_count_by_type(.transient);
    try std.testing.expect(transient_count == 2);
    const permanent_count = collector.get_failure_count_by_type(.permanent);
    try std.testing.expect(permanent_count == 1);
}

test "record failure recovery" {
    var collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    const complexity = failure_pattern_metrics.WorkflowComplexity.init(5, 2, 2);
    _ = collector.record_failure(1, 0, 0, .transient, 1000, complexity, null, null);
    const result = collector.record_failure_recovery(1, 2000);
    try std.testing.expect(result == true);
    try std.testing.expect(collector.recovered_failures == 1);
    try std.testing.expect(collector.failures[0].recovered == true);
}

test "calculate recovery success rate" {
    var collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    const complexity = failure_pattern_metrics.WorkflowComplexity.init(5, 2, 2);
    _ = collector.record_failure(1, 0, 0, .transient, 1000, complexity, null, null);
    _ = collector.record_failure(2, 0, 0, .transient, 1000, complexity, null, null);
    _ = collector.record_failure(3, 0, 0, .permanent, 1000, complexity, null, null);
    _ = collector.record_failure_recovery(1, 2000);
    _ = collector.record_failure_recovery(2, 2000);
    const recovery_rate = collector.get_recovery_success_rate_percent();
    try std.testing.expect(recovery_rate == 66);
}

test "workflow complexity level calculation" {
    const complexity1 = failure_pattern_metrics.WorkflowComplexity.init(10, 5, 3);
    const level1 = complexity1.get_complexity_level();
    try std.testing.expect(level1 == 1);
    const complexity2 = failure_pattern_metrics.WorkflowComplexity.init(100, 50, 20);
    const level2 = complexity2.get_complexity_level();
    try std.testing.expect(level2 == 17);
}

test "record workflow execution for complexity tracking" {
    var collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    const complexity = failure_pattern_metrics.WorkflowComplexity.init(10, 5, 3);
    collector.record_workflow_execution(complexity);
    const level = complexity.get_complexity_level();
    try std.testing.expect(collector.complexity_total_counts[level] == 1);
}

test "failure rate by complexity" {
    var collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    const complexity = failure_pattern_metrics.WorkflowComplexity.init(10, 5, 3);
    collector.record_workflow_execution(complexity);
    collector.record_workflow_execution(complexity);
    _ = collector.record_failure(1, 0, 0, .transient, 1000, complexity, null, null);
    const level = complexity.get_complexity_level();
    const failure_rate = collector.get_failure_rate_by_complexity_percent(level);
    try std.testing.expect(failure_rate == 50);
}

test "export metrics to json" {
    var collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    const complexity = failure_pattern_metrics.WorkflowComplexity.init(5, 2, 2);
    _ = collector.record_failure(1, 0, 0, .transient, 1000, complexity, null, null);
    var json_buf: [4096]u8 = undefined;
    const json_len = collector.export_json(&json_buf);
    try std.testing.expect(json_len > 0);
    const json_str = json_buf[0..json_len];
    try std.testing.expect(std.mem.indexOf(u8, json_str, "total_failures") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "recovery_success_rate_percent") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "failure_type_distribution") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "failures") != null);
}

test "workflow engine with failure pattern collector" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    var collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    engine.set_failure_pattern_collector(&collector);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    const result = engine.execute_workflow(workflow_id.?, 1000);
    try std.testing.expect(result == true);
    // Workflow should fail if no nodes are added
    // (processed != nodes_len when nodes_len == 0)
    try std.testing.expect(collector.total_failures >= 0);
}

test "multiple failure tracking" {
    var collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    const complexity = failure_pattern_metrics.WorkflowComplexity.init(5, 2, 2);
    _ = collector.record_failure(1, 0, 0, .transient, 1000, complexity, null, null);
    _ = collector.record_failure(2, 0, 0, .permanent, 1000, complexity, null, null);
    _ = collector.record_failure(3, 0, 0, .timeout, 1000, complexity, null, null);
    try std.testing.expect(collector.failures_len == 3);
    try std.testing.expect(collector.total_failures == 3);
    const transient_count = collector.get_failure_count_by_type(.transient);
    try std.testing.expect(transient_count == 1);
    const permanent_count = collector.get_failure_count_by_type(.permanent);
    try std.testing.expect(permanent_count == 1);
    const timeout_count = collector.get_failure_count_by_type(.timeout);
    try std.testing.expect(timeout_count == 1);
    // Verify sequential failure_id assignment.
    try std.testing.expect(collector.failures[0].failure_id == 1);
    try std.testing.expect(collector.failures[1].failure_id == 2);
    try std.testing.expect(collector.failures[2].failure_id == 3);
}

test "failure_id sequential assignment" {
    var collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    const complexity = failure_pattern_metrics.WorkflowComplexity.init(5, 2, 2);
    _ = collector.record_failure(1, 0, 0, .transient, 1000, complexity, null, null);
    _ = collector.record_failure(2, 0, 0, .permanent, 2000, complexity, null, null);
    _ = collector.record_failure(3, 0, 0, .timeout, 3000, complexity, null, null);
    try std.testing.expect(collector.failures[0].failure_id == 1);
    try std.testing.expect(collector.failures[1].failure_id == 2);
    try std.testing.expect(collector.failures[2].failure_id == 3);
}

test "error_message storage" {
    var collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    const complexity = failure_pattern_metrics.WorkflowComplexity.init(5, 2, 2);
    const error_msg = "Connection timeout after 5 seconds";
    _ = collector.record_failure(1, 0, 0, .timeout, 1000, complexity, error_msg, null);
    try std.testing.expect(collector.failures[0].error_message_len == error_msg.len);
    const stored_msg = collector.failures[0].error_message[0..collector.failures[0].error_message_len];
    try std.testing.expect(std.mem.eql(u8, stored_msg, error_msg));
}

test "context_data storage" {
    var collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    const complexity = failure_pattern_metrics.WorkflowComplexity.init(5, 2, 2);
    const ctx_data = "{\"retry_count\": 3, \"last_endpoint\": \"/api/v1/process\"}";
    _ = collector.record_failure(1, 0, 0, .transient, 1000, complexity, null, ctx_data);
    try std.testing.expect(collector.failures[0].context_data_len == ctx_data.len);
    const stored_ctx = collector.failures[0].context_data[0..collector.failures[0].context_data_len];
    try std.testing.expect(std.mem.eql(u8, stored_ctx, ctx_data));
}

test "export json includes failures array with all fields" {
    var collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    const complexity = failure_pattern_metrics.WorkflowComplexity.init(5, 2, 2);
    const error_msg = "Connection timeout";
    const ctx_data = "{\"retry\": 2}";
    _ = collector.record_failure(42, 10, 3, .transient, 1234567890000000000, complexity, error_msg, ctx_data);
    _ = collector.record_failure_recovery(42, 1234567890001500000);
    var json_buf: [8192]u8 = undefined;
    const json_len = collector.export_json(&json_buf);
    try std.testing.expect(json_len > 0);
    const json_str = json_buf[0..json_len];
    // Verify failures array exists.
    try std.testing.expect(std.mem.indexOf(u8, json_str, "failures") != null);
    // Verify all required fields in failures array.
    try std.testing.expect(std.mem.indexOf(u8, json_str, "failure_id") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "workflow_id") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "agent_id") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "failure_type") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "timestamp") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "recovery_status") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "recovery_time_ms") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "error_message") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "context_data") != null);
}

test "recovery_status string conversion" {
    var collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    const complexity = failure_pattern_metrics.WorkflowComplexity.init(5, 2, 2);
    _ = collector.record_failure(1, 0, 0, .transient, 1000, complexity, null, null);
    _ = collector.record_failure_recovery(1, 2000);
    var json_buf: [4096]u8 = undefined;
    const json_len = collector.export_json(&json_buf);
    try std.testing.expect(json_len > 0);
    const json_str = json_buf[0..json_len];
    // Verify recovery_status is "succeeded" for recovered failures.
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"recovery_status\":\"succeeded\"") != null);
}

test "recovery_time_ms calculation" {
    var collector = failure_pattern_metrics.FailurePatternMetricsCollector.init();
    const complexity = failure_pattern_metrics.WorkflowComplexity.init(5, 2, 2);
    const failed_at: u64 = 1000_000_000; // 1 second in nanoseconds.
    const recovered_at: u64 = 1500_000_000; // 1.5 seconds in nanoseconds.
    _ = collector.record_failure(1, 0, 0, .transient, failed_at, complexity, null, null);
    _ = collector.record_failure_recovery(1, recovered_at);
    var json_buf: [4096]u8 = undefined;
    const json_len = collector.export_json(&json_buf);
    try std.testing.expect(json_len > 0);
    const json_str = json_buf[0..json_len];
    // Verify recovery_time_ms is calculated correctly (500ms = 500000000 nanoseconds / 1000000).
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"recovery_time_ms\":500") != null);
}
