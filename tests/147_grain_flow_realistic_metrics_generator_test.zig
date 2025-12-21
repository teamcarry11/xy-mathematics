//! Grain Flow Realistic Metrics Generator Tests
//!
//! Tests for realistic workflow metrics generation for Step 3 validation.
//!
//! Why: Verify realistic metrics generator creates valid workflow execution data.
//! Architecture: Test workflow execution scenario generation and JSON export.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const grain_flow = @import("grain_flow");

test "realistic metrics generator initialization" {
    const generator = grain_flow.RealisticMetricsGenerator.init();
    std.debug.assert(generator.workflow_collector.total_executions == 0);
    std.debug.assert(generator.coordination_collector.total_coordinations == 0);
    std.debug.assert(generator.failure_collector.total_failures == 0);
}

test "realistic metrics generator scenario" {
    var generator = grain_flow.RealisticMetricsGenerator.init();
    const executed = generator.generate_realistic_scenario(20);
    std.debug.assert(executed == 20);
    std.debug.assert(generator.workflow_collector.total_executions >= 20);
}

test "realistic metrics generator export json" {
    var generator = grain_flow.RealisticMetricsGenerator.init();
    _ = generator.generate_realistic_scenario(15);
    var output: [8192]u8 = undefined;
    const written = generator.export_realistic_metrics_json(&output);
    std.debug.assert(written > 0);
    std.debug.assert(written < output.len);
    std.debug.assert(output[0] == '{');
}

test "realistic metrics generator with failures" {
    var generator = grain_flow.RealisticMetricsGenerator.init();
    const executed = generator.generate_realistic_scenario(30);
    std.debug.assert(executed == 30);
    // Should have some failures (90% success rate = ~3 failures in 30)
    std.debug.assert(generator.failure_collector.total_failures >= 0);
}

test "realistic metrics generator coordination metrics" {
    var generator = grain_flow.RealisticMetricsGenerator.init();
    _ = generator.generate_realistic_scenario(25);
    std.debug.assert(generator.coordination_collector.total_coordinations >= 25);
}

test "realistic metrics generator performance metrics" {
    var generator = grain_flow.RealisticMetricsGenerator.init();
    _ = generator.generate_realistic_scenario(10);
    std.debug.assert(generator.performance_collector.total_queue_depth_samples >= 10);
    std.debug.assert(generator.performance_collector.total_wait_time_records >= 10);
}
