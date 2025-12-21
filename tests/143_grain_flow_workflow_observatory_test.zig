//! Grain Flow Workflow Observatory Tests
//!
//! Tests for metrics aggregation and dashboard API functionality.

const std = @import("std");
const grain_flow = @import("grain_flow");

test "workflow observatory initialization" {
    const observatory = grain_flow.WorkflowObservatory.init();
    std.debug.assert(observatory.workflow_collector == null);
    std.debug.assert(observatory.coordination_collector == null);
    std.debug.assert(observatory.failure_collector == null);
    std.debug.assert(observatory.performance_collector == null);
}

test "workflow observatory set collectors" {
    var observatory = grain_flow.WorkflowObservatory.init();
    var workflow_collector = grain_flow.WorkflowMetricsCollector.init();
    var coordination_collector = grain_flow.AgentCoordinationMetricsCollector.init();
    var failure_collector = grain_flow.FailurePatternMetricsCollector.init();
    var performance_collector = grain_flow.PerformanceMetricsCollector.init();

    observatory.set_workflow_collector(&workflow_collector);
    observatory.set_coordination_collector(&coordination_collector);
    observatory.set_failure_collector(&failure_collector);
    observatory.set_performance_collector(&performance_collector);

    std.debug.assert(observatory.workflow_collector != null);
    std.debug.assert(observatory.coordination_collector != null);
    std.debug.assert(observatory.failure_collector != null);
    std.debug.assert(observatory.performance_collector != null);
}

test "workflow observatory aggregated summary" {
    var observatory = grain_flow.WorkflowObservatory.init();
    var workflow_collector = grain_flow.WorkflowMetricsCollector.init();
    var coordination_collector = grain_flow.AgentCoordinationMetricsCollector.init();
    var failure_collector = grain_flow.FailurePatternMetricsCollector.init();
    var performance_collector = grain_flow.PerformanceMetricsCollector.init();

    observatory.set_workflow_collector(&workflow_collector);
    observatory.set_coordination_collector(&coordination_collector);
    observatory.set_failure_collector(&failure_collector);
    observatory.set_performance_collector(&performance_collector);

    // Record some test data.
    _ = workflow_collector.record_execution(
        1,
        "test_workflow",
        1000,
        2000,
        grain_flow.WorkflowExecutionStatus.success,
    );
    _ = coordination_collector.record_coordination_start(1, 2, 0, 1, 1000);
    _ = coordination_collector.record_coordination_completion(1, 0, 2000, grain_flow.AgentCoordinationStatus.success);
    _ = failure_collector.record_failure(
        1,
        1,
        1,
        grain_flow.FailureType.transient,
        1000,
        grain_flow.WorkflowComplexity.init(5, 4, 2),
    );
    _ = performance_collector.record_queue_depth(1000, 5);
    _ = performance_collector.record_wait_time(1, 500, 1000);

    // Get aggregated summary.
    var output: [4096]u8 = undefined;
    const written = observatory.get_aggregated_summary(&output);
    std.debug.assert(written > 0);
    std.debug.assert(written < output.len);
}

test "workflow observatory export all metrics" {
    var observatory = grain_flow.WorkflowObservatory.init();
    var workflow_collector = grain_flow.WorkflowMetricsCollector.init();
    var coordination_collector = grain_flow.AgentCoordinationMetricsCollector.init();
    var failure_collector = grain_flow.FailurePatternMetricsCollector.init();
    var performance_collector = grain_flow.PerformanceMetricsCollector.init();

    observatory.set_workflow_collector(&workflow_collector);
    observatory.set_coordination_collector(&coordination_collector);
    observatory.set_failure_collector(&failure_collector);
    observatory.set_performance_collector(&performance_collector);

    // Record test data.
    _ = workflow_collector.record_execution(
        1,
        "test_workflow",
        1000,
        2000,
        grain_flow.WorkflowExecutionStatus.success,
    );

    // Export all metrics.
    var output: [8192]u8 = undefined;
    const written = observatory.export_all_metrics_json(&output);
    std.debug.assert(written > 0);
    std.debug.assert(written < output.len);
}

test "workflow observatory empty collectors" {
    const observatory = grain_flow.WorkflowObservatory.init();
    var output: [1024]u8 = undefined;

    // Should handle empty collectors gracefully.
    const written = observatory.get_aggregated_summary(&output);
    std.debug.assert(written > 0);
    std.debug.assert(output[0] == '{');
}

test "workflow observatory partial collectors" {
    var observatory = grain_flow.WorkflowObservatory.init();
    var workflow_collector = grain_flow.WorkflowMetricsCollector.init();
    observatory.set_workflow_collector(&workflow_collector);

    // Should handle partial collectors.
    var output: [2048]u8 = undefined;
    const written = observatory.get_aggregated_summary(&output);
    std.debug.assert(written > 0);
}
