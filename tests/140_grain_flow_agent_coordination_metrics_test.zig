//! Tests for Grain Flow Agent Coordination Metrics.
//!
//! Tests metric collection for agent coordination observability.

const std = @import("std");
const grain_flow = @import("grain_flow");
const agent_coordination_metrics = grain_flow.agent_coordination_metrics;
const event_bus = grain_flow.event_bus;
const agent_coordinator = grain_flow.agent_coordinator;

test "metrics collector initialization" {
    const collector = agent_coordination_metrics.AgentCoordinationMetricsCollector.init();
    try std.testing.expect(collector.coordinations_len == 0);
    try std.testing.expect(collector.total_coordinations == 0);
    try std.testing.expect(collector.successful_coordinations == 0);
    try std.testing.expect(collector.failed_coordinations == 0);
    try std.testing.expect(collector.timeout_coordinations == 0);
}

test "record coordination start" {
    var collector = agent_coordination_metrics.AgentCoordinationMetricsCollector.init();
    const result = collector.record_coordination_start(1, 2, 10, 100, 1000);
    try std.testing.expect(result == true);
    try std.testing.expect(collector.pending_coordinations_len == 1);
}

test "record successful coordination completion" {
    var collector = agent_coordination_metrics.AgentCoordinationMetricsCollector.init();
    const result = collector.record_coordination_completion(
        1,
        2,
        10,
        100,
        1000,
        2000,
        agent_coordination_metrics.AgentCoordinationStatus.success,
    );
    try std.testing.expect(result == true);
    try std.testing.expect(collector.coordinations_len == 1);
    try std.testing.expect(collector.total_coordinations == 1);
    try std.testing.expect(collector.successful_coordinations == 1);
    try std.testing.expect(collector.failed_coordinations == 0);
    try std.testing.expect(collector.coordinations[0].coordination_latency_ms == 1000);
    try std.testing.expect(collector.coordinations[0].status == .success);
}

test "record failed coordination completion" {
    var collector = agent_coordination_metrics.AgentCoordinationMetricsCollector.init();
    const result = collector.record_coordination_completion(
        1,
        2,
        10,
        100,
        1000,
        1500,
        agent_coordination_metrics.AgentCoordinationStatus.failure,
    );
    try std.testing.expect(result == true);
    try std.testing.expect(collector.total_coordinations == 1);
    try std.testing.expect(collector.successful_coordinations == 0);
    try std.testing.expect(collector.failed_coordinations == 1);
    try std.testing.expect(collector.coordinations[0].status == .failure);
}

test "calculate average coordination latency" {
    var collector = agent_coordination_metrics.AgentCoordinationMetricsCollector.init();
    _ = collector.record_coordination_completion(1, 2, 0, 1, 1000, 2000, .success);
    _ = collector.record_coordination_completion(2, 3, 0, 2, 1000, 4000, .success);
    _ = collector.record_coordination_completion(3, 4, 0, 3, 1000, 6000, .success);
    const avg_latency = collector.get_average_coordination_latency_ms();
    try std.testing.expect(avg_latency == 3000);
}

test "calculate coordination success rate" {
    var collector = agent_coordination_metrics.AgentCoordinationMetricsCollector.init();
    _ = collector.record_coordination_completion(1, 2, 0, 1, 1000, 2000, .success);
    _ = collector.record_coordination_completion(2, 3, 0, 2, 1000, 2000, .success);
    _ = collector.record_coordination_completion(3, 4, 0, 3, 1000, 2000, .failure);
    const success_rate = collector.get_coordination_success_rate_percent();
    try std.testing.expect(success_rate == 66);
}

test "track coordination patterns" {
    var collector = agent_coordination_metrics.AgentCoordinationMetricsCollector.init();
    _ = collector.record_coordination_completion(1, 2, 0, 1, 1000, 2000, .success);
    _ = collector.record_coordination_completion(1, 2, 0, 2, 1000, 2000, .success);
    _ = collector.record_coordination_completion(2, 3, 0, 3, 1000, 2000, .success);
    var patterns: [10]agent_coordination_metrics.AgentPairPattern = undefined;
    const pattern_count = collector.get_coordination_patterns(&patterns);
    try std.testing.expect(pattern_count == 2);
    var found_pair_1_2: bool = false;
    var found_pair_2_3: bool = false;
    var i: u32 = 0;
    while (i < pattern_count) : (i += 1) {
        if (patterns[i].source_agent_id == 1 and patterns[i].target_agent_id == 2) {
            try std.testing.expect(patterns[i].count == 2);
            found_pair_1_2 = true;
        }
        if (patterns[i].source_agent_id == 2 and patterns[i].target_agent_id == 3) {
            try std.testing.expect(patterns[i].count == 1);
            found_pair_2_3 = true;
        }
    }
    try std.testing.expect(found_pair_1_2);
    try std.testing.expect(found_pair_2_3);
}

test "export metrics to json" {
    var collector = agent_coordination_metrics.AgentCoordinationMetricsCollector.init();
    _ = collector.record_coordination_completion(1, 2, 10, 100, 1000, 2000, .success);
    var json_buf: [4096]u8 = undefined;
    const json_len = collector.export_json(&json_buf);
    try std.testing.expect(json_len > 0);
    const json_str = json_buf[0..json_len];
    try std.testing.expect(std.mem.indexOf(u8, json_str, "total_coordinations") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "success_rate_percent") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "avg_coordination_latency_ms") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "coordination_patterns") != null);
}

test "agent coordinator with metrics collector" {
    var bus = event_bus.EventBus.init();
    var coordinator = agent_coordinator.AgentCoordinator.init(&bus);
    var collector = agent_coordination_metrics.AgentCoordinationMetricsCollector.init();
    coordinator.set_coordination_metrics_collector(&collector);
    const agent1_id = coordinator.register_agent("agent1", 1000);
    try std.testing.expect(agent1_id != null);
    const agent2_id = coordinator.register_agent("agent2", 1000);
    try std.testing.expect(agent2_id != null);
    const request_id = coordinator.send_rpc_request(
        agent1_id.?,
        agent2_id.?,
        "test_method",
        "",
        1000,
    );
    try std.testing.expect(request_id != null);
    try std.testing.expect(collector.pending_coordinations_len == 1);
}

test "pending coordination removal on completion" {
    var collector = agent_coordination_metrics.AgentCoordinationMetricsCollector.init();
    _ = collector.record_coordination_start(1, 2, 10, 100, 1000);
    try std.testing.expect(collector.pending_coordinations_len == 1);
    _ = collector.record_coordination_completion(1, 2, 10, 100, 1000, 2000, .success);
    try std.testing.expect(collector.pending_coordinations_len == 0);
    try std.testing.expect(collector.total_coordinations == 1);
}

test "multiple coordination tracking" {
    var collector = agent_coordination_metrics.AgentCoordinationMetricsCollector.init();
    _ = collector.record_coordination_completion(1, 2, 0, 1, 1000, 2000, .success);
    _ = collector.record_coordination_completion(2, 3, 0, 2, 1000, 2500, .success);
    _ = collector.record_coordination_completion(1, 2, 0, 3, 1000, 3000, .failure);
    _ = collector.record_coordination_completion(3, 4, 0, 4, 1000, 3500, .timeout);
    try std.testing.expect(collector.coordinations_len == 4);
    try std.testing.expect(collector.total_coordinations == 4);
    try std.testing.expect(collector.successful_coordinations == 2);
    try std.testing.expect(collector.failed_coordinations == 1);
    try std.testing.expect(collector.timeout_coordinations == 1);
}
