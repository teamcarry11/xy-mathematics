//! Grain Flow Step 3 Real Metrics Export Test
//!
//! Test for exporting real workflow metrics for Research Agent Step 3 validation.
//!
//! Why: Verify real workflow metrics can be generated and exported for Step 3 validation.
//! Architecture: Generate realistic scenario, export JSON, validate format.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const grain_flow = @import("grain_flow");

test "step3 real metrics export for research agent" {
    // Initialize generator.
    var generator = grain_flow.RealisticMetricsGenerator.init();

    // Generate realistic scenario (30 workflows for Step 3 validation).
    const executed = generator.generate_realistic_scenario(30);
    std.debug.assert(executed == 30);
    std.debug.assert(generator.workflow_collector.total_executions >= 30);

    // Export metrics JSON (10MB buffer for full export).
    var json_buffer: [10_485_760]u8 = undefined;
    const written = generator.export_realistic_metrics_json(&json_buffer);
    std.debug.assert(written > 0);
    std.debug.assert(written < json_buffer.len);

    // Validate JSON format (starts with '{', ends with '}').
    std.debug.assert(json_buffer[0] == '{');
    var i: u32 = written - 1;
    while (i > 0) : (i -= 1) {
        if (json_buffer[i] != ' ' and json_buffer[i] != '\n' and json_buffer[i] != '\r' and json_buffer[i] != '\t') {
            std.debug.assert(json_buffer[i] == '}');
            break;
        }
    }

    // Validate nested structure (contains "workflow", "coordination", "failure", "performance").
    const json_str = json_buffer[0..written];
    const has_workflow = std.mem.indexOf(u8, json_str, "\"workflow\"") != null;
    const has_coordination = std.mem.indexOf(u8, json_str, "\"coordination\"") != null;
    const has_failure = std.mem.indexOf(u8, json_str, "\"failure\"") != null;
    const has_performance = std.mem.indexOf(u8, json_str, "\"performance\"") != null;
    std.debug.assert(has_workflow);
    std.debug.assert(has_coordination);
    std.debug.assert(has_failure);
    std.debug.assert(has_performance);
}

test "step3 real metrics export with 50 workflows" {
    // Initialize generator.
    var generator = grain_flow.RealisticMetricsGenerator.init();

    // Generate realistic scenario (50 workflows - maximum).
    const executed = generator.generate_realistic_scenario(50);
    std.debug.assert(executed == 50);

    // Export metrics JSON.
    var json_buffer: [10_485_760]u8 = undefined;
    const written = generator.export_realistic_metrics_json(&json_buffer);
    std.debug.assert(written > 0);
    std.debug.assert(written < json_buffer.len);
    std.debug.assert(json_buffer[0] == '{');
}

test "step3 real metrics export metrics counts" {
    // Initialize generator.
    var generator = grain_flow.RealisticMetricsGenerator.init();

    // Generate realistic scenario (25 workflows).
    const executed = generator.generate_realistic_scenario(25);
    std.debug.assert(executed == 25);

    // Verify metrics collected.
    std.debug.assert(generator.workflow_collector.total_executions >= 25);
    std.debug.assert(generator.coordination_collector.total_coordinations >= 25);
    std.debug.assert(generator.performance_collector.total_queue_depth_samples >= 25);
    std.debug.assert(generator.performance_collector.total_wait_time_records >= 25);

    // Export metrics JSON.
    var json_buffer: [10_485_760]u8 = undefined;
    const written = generator.export_realistic_metrics_json(&json_buffer);
    std.debug.assert(written > 0);
}
