//! Tests for Grain Flow Workflow Metrics.
//!
//! Tests metric collection for workflow observability.

const std = @import("std");
const grain_flow = @import("grain_flow");
const workflow_metrics = grain_flow.workflow_metrics;
const event_bus = grain_flow.event_bus;
const agent_coordinator = grain_flow.agent_coordinator;
const workflow_engine = grain_flow.workflow_engine;

test "metrics collector initialization" {
    const collector = workflow_metrics.WorkflowMetricsCollector.init();
    try std.testing.expect(collector.executions_len == 0);
    try std.testing.expect(collector.total_executions == 0);
    try std.testing.expect(collector.successful_executions == 0);
    try std.testing.expect(collector.failed_executions == 0);
}

test "record successful execution" {
    var collector = workflow_metrics.WorkflowMetricsCollector.init();
    const result = collector.record_execution(
        1,
        "test_workflow",
        1000,
        2000,
        workflow_metrics.WorkflowExecutionStatus.success,
    );
    try std.testing.expect(result == true);
    try std.testing.expect(collector.executions_len == 1);
    try std.testing.expect(collector.total_executions == 1);
    try std.testing.expect(collector.successful_executions == 1);
    try std.testing.expect(collector.failed_executions == 0);
    try std.testing.expect(collector.executions[0].workflow_id == 1);
    try std.testing.expect(collector.executions[0].execution_time_ms == 1000);
    try std.testing.expect(collector.executions[0].status == .success);
}

test "record failed execution" {
    var collector = workflow_metrics.WorkflowMetricsCollector.init();
    const result = collector.record_execution(
        2,
        "failed_workflow",
        1000,
        1500,
        workflow_metrics.WorkflowExecutionStatus.failure,
    );
    try std.testing.expect(result == true);
    try std.testing.expect(collector.executions_len == 1);
    try std.testing.expect(collector.total_executions == 1);
    try std.testing.expect(collector.successful_executions == 0);
    try std.testing.expect(collector.failed_executions == 1);
    try std.testing.expect(collector.executions[0].workflow_id == 2);
    try std.testing.expect(collector.executions[0].execution_time_ms == 500);
    try std.testing.expect(collector.executions[0].status == .failure);
}

test "calculate success rate" {
    var collector = workflow_metrics.WorkflowMetricsCollector.init();
    _ = collector.record_execution(1, "wf1", 1000, 2000, .success);
    _ = collector.record_execution(2, "wf2", 1000, 2000, .success);
    _ = collector.record_execution(3, "wf3", 1000, 2000, .failure);
    const success_rate = collector.get_success_rate_percent();
    try std.testing.expect(success_rate == 66);
}

test "calculate failure rate" {
    var collector = workflow_metrics.WorkflowMetricsCollector.init();
    _ = collector.record_execution(1, "wf1", 1000, 2000, .success);
    _ = collector.record_execution(2, "wf2", 1000, 2000, .failure);
    _ = collector.record_execution(3, "wf3", 1000, 2000, .failure);
    const failure_rate = collector.get_failure_rate_percent();
    try std.testing.expect(failure_rate == 66);
}

test "calculate average execution time" {
    var collector = workflow_metrics.WorkflowMetricsCollector.init();
    _ = collector.record_execution(1, "wf1", 1000, 2000, .success);
    _ = collector.record_execution(2, "wf2", 1000, 3000, .success);
    _ = collector.record_execution(3, "wf3", 1000, 4000, .success);
    const avg_time = collector.get_average_execution_time_ms();
    try std.testing.expect(avg_time == 2000);
}

test "export metrics to json" {
    var collector = workflow_metrics.WorkflowMetricsCollector.init();
    _ = collector.record_execution(1, "test_workflow", 1000, 2000, .success);
    var json_buf: [4096]u8 = undefined;
    const json_len = collector.export_json(&json_buf);
    try std.testing.expect(json_len > 0);
    const json_str = json_buf[0..json_len];
    try std.testing.expect(std.mem.indexOf(u8, json_str, "total_executions") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "success_rate_percent") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "failure_rate_percent") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "avg_execution_time_ms") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "executions") != null);
}

test "workflow engine with metrics collector" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    var collector = workflow_metrics.WorkflowMetricsCollector.init();
    engine.set_metrics_collector(&collector);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    const result = engine.execute_workflow(workflow_id.?, 1000);
    try std.testing.expect(result == true);
    try std.testing.expect(collector.total_executions == 1);
}

test "multiple workflow executions tracked" {
    var collector = workflow_metrics.WorkflowMetricsCollector.init();
    _ = collector.record_execution(1, "wf1", 1000, 2000, .success);
    _ = collector.record_execution(2, "wf2", 1000, 2500, .success);
    _ = collector.record_execution(3, "wf3", 1000, 3000, .failure);
    _ = collector.record_execution(4, "wf4", 1000, 3500, .success);
    try std.testing.expect(collector.executions_len == 4);
    try std.testing.expect(collector.total_executions == 4);
    try std.testing.expect(collector.successful_executions == 3);
    try std.testing.expect(collector.failed_executions == 1);
    const success_rate = collector.get_success_rate_percent();
    try std.testing.expect(success_rate == 75);
    const failure_rate = collector.get_failure_rate_percent();
    try std.testing.expect(failure_rate == 25);
}
