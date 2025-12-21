//! Tests for Grain Flow Performance Metrics.
//!
//! Tests metric collection for performance characteristics.

const std = @import("std");
const grain_flow = @import("grain_flow");
const performance_metrics = grain_flow.performance_metrics;
const event_bus = grain_flow.event_bus;
const agent_coordinator = grain_flow.agent_coordinator;
const workflow_engine = grain_flow.workflow_engine;

test "metrics collector initialization" {
    const collector = performance_metrics.PerformanceMetricsCollector.init();
    try std.testing.expect(collector.resource_samples_len == 0);
    try std.testing.expect(collector.queue_depth_samples_len == 0);
    try std.testing.expect(collector.wait_time_records_len == 0);
}

test "record resource usage" {
    var collector = performance_metrics.PerformanceMetricsCollector.init();
    const result = collector.record_resource_usage(1, 1000, 50, 1024 * 1024, 512 * 1024);
    try std.testing.expect(result == true);
    try std.testing.expect(collector.resource_samples_len == 1);
    try std.testing.expect(collector.resource_samples[0].cpu_percent == 50);
    try std.testing.expect(collector.resource_samples[0].memory_bytes == 1024 * 1024);
}

test "record queue depth" {
    var collector = performance_metrics.PerformanceMetricsCollector.init();
    const result = collector.record_queue_depth(1000, 5);
    try std.testing.expect(result == true);
    try std.testing.expect(collector.queue_depth_samples_len == 1);
    try std.testing.expect(collector.queue_depth_samples[0].queue_depth == 5);
}

test "record wait time" {
    var collector = performance_metrics.PerformanceMetricsCollector.init();
    const result = collector.record_wait_time(1, 1000, 2500);
    try std.testing.expect(result == true);
    try std.testing.expect(collector.wait_time_records_len == 1);
    try std.testing.expect(collector.wait_time_records[0].wait_time_ms == 1500);
}

test "calculate average queue depth" {
    var collector = performance_metrics.PerformanceMetricsCollector.init();
    _ = collector.record_queue_depth(1000, 5);
    _ = collector.record_queue_depth(2000, 10);
    _ = collector.record_queue_depth(3000, 15);
    const avg_depth = collector.get_average_queue_depth();
    try std.testing.expect(avg_depth == 10);
}

test "calculate average wait time" {
    var collector = performance_metrics.PerformanceMetricsCollector.init();
    _ = collector.record_wait_time(1, 1000, 2000);
    _ = collector.record_wait_time(2, 1000, 3000);
    _ = collector.record_wait_time(3, 1000, 4000);
    const avg_wait = collector.get_average_wait_time_ms();
    try std.testing.expect(avg_wait == 2000);
}

test "calculate average CPU usage" {
    var collector = performance_metrics.PerformanceMetricsCollector.init();
    _ = collector.record_resource_usage(1, 1000, 50, 0, 0);
    _ = collector.record_resource_usage(2, 2000, 75, 0, 0);
    _ = collector.record_resource_usage(3, 3000, 25, 0, 0);
    const avg_cpu = collector.get_average_cpu_percent();
    try std.testing.expect(avg_cpu == 50);
}

test "calculate average memory usage" {
    var collector = performance_metrics.PerformanceMetricsCollector.init();
    _ = collector.record_resource_usage(1, 1000, 0, 1024 * 1024, 0);
    _ = collector.record_resource_usage(2, 2000, 0, 2 * 1024 * 1024, 0);
    _ = collector.record_resource_usage(3, 3000, 0, 3 * 1024 * 1024, 0);
    const avg_mem = collector.get_average_memory_bytes();
    try std.testing.expect(avg_mem == 2 * 1024 * 1024);
}

test "export metrics to json" {
    var collector = performance_metrics.PerformanceMetricsCollector.init();
    _ = collector.record_queue_depth(1000, 5);
    _ = collector.record_wait_time(1, 1000, 2000);
    var json_buf: [4096]u8 = undefined;
    const json_len = collector.export_json(&json_buf);
    try std.testing.expect(json_len > 0);
    const json_str = json_buf[0..json_len];
    try std.testing.expect(std.mem.indexOf(u8, json_str, "avg_queue_depth") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "avg_wait_time_ms") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "avg_cpu_percent") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "avg_memory_bytes") != null);
}

test "workflow engine with performance collector" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var engine = workflow_engine.WorkflowEngine.init(&bus, &coordinator);
    var collector = performance_metrics.PerformanceMetricsCollector.init();
    engine.set_performance_collector(&collector);
    const workflow_id = engine.create_workflow("test_workflow", 1000);
    try std.testing.expect(workflow_id != null);
    const queue_depth_before = engine.get_queue_depth();
    try std.testing.expect(queue_depth_before == 1);
    const result = engine.execute_workflow(workflow_id.?, 2000);
    try std.testing.expect(result == true);
    try std.testing.expect(collector.wait_time_records_len == 1);
    try std.testing.expect(collector.queue_depth_samples_len == 1);
}

test "multiple performance samples tracking" {
    var collector = performance_metrics.PerformanceMetricsCollector.init();
    _ = collector.record_resource_usage(1, 1000, 50, 1024, 512);
    _ = collector.record_resource_usage(2, 2000, 60, 2048, 1024);
    _ = collector.record_queue_depth(1000, 5);
    _ = collector.record_queue_depth(2000, 10);
    _ = collector.record_wait_time(1, 1000, 2000);
    _ = collector.record_wait_time(2, 1000, 3000);
    try std.testing.expect(collector.resource_samples_len == 2);
    try std.testing.expect(collector.queue_depth_samples_len == 2);
    try std.testing.expect(collector.wait_time_records_len == 2);
}
