//! Integration Test Scenarios Tests.
//!
//! Why: Validates integration test scenarios for common integration patterns.
//! Tests agent registration, event-driven coordination, data export/import,
//! error handling, and workflow execution scenarios.
//! Architecture: Test scenario implementations, pattern-based testing.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-184500-pst: Integration Testing Patterns Framework (Priority 2)

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const IntegrationTestHarness = grain_research.IntegrationTestHarness;
const TestDataGenerator = grain_research.TestDataGenerator;
const scenario_agent_registration = grain_research.scenario_agent_registration;
const scenario_event_driven_coordination = grain_research.scenario_event_driven_coordination;
const scenario_data_export_import = grain_research.scenario_data_export_import;
const scenario_error_handling = grain_research.scenario_error_handling;
const scenario_workflow_execution = grain_research.scenario_workflow_execution;
const grain_flow = @import("grain_flow");
const EventBus = grain_flow.EventBus;
const AgentCoordinator = grain_flow.AgentCoordinator;

test "scenario agent registration" {
    const allocator = testing.allocator;
    var harness = IntegrationTestHarness.init(allocator);
    defer harness.deinit();

    // Setup event bus.
    try harness.setup_event_bus();
    defer harness.teardown_event_bus();

    const event_bus_instance = harness.get_event_bus().?;
    var coordinator = AgentCoordinator.init(event_bus_instance);

    // Run agent registration scenario.
    const result = try scenario_agent_registration(&harness, &coordinator, "TestAgent");

    // Verify result.
    try testing.expect(result.success);
    try testing.expect(result.latency_ms >= 0);
    try testing.expect(std.mem.eql(u8, result.scenario_name, "Agent Registration"));
}

test "scenario event-driven coordination" {
    const allocator = testing.allocator;
    var harness = IntegrationTestHarness.init(allocator);
    defer harness.deinit();

    // Setup event bus.
    try harness.setup_event_bus();
    defer harness.teardown_event_bus();

    // Register agent IDs.
    try harness.register_agent_id(1);
    try harness.register_agent_id(2);

    // Run event-driven coordination scenario.
    const result = try scenario_event_driven_coordination(&harness, 1, 2);

    // Verify result.
    try testing.expect(result.success);
    try testing.expect(result.latency_ms >= 0);
    try testing.expect(std.mem.eql(u8, result.scenario_name, "Event-Driven Coordination"));
}

test "scenario data export import" {
    const allocator = testing.allocator;
    var harness = IntegrationTestHarness.init(allocator);
    defer harness.deinit();

    // Generate test data.
    var generator = TestDataGenerator.init(allocator, 12345);
    const test_data = try generator.generate_workflow_metrics(10);
    defer allocator.free(test_data);

    // Run data export/import scenario.
    const result = try scenario_data_export_import(&harness, test_data);

    // Verify result.
    try testing.expect(result.success);
    try testing.expect(result.latency_ms >= 0);
    try testing.expect(std.mem.eql(u8, result.scenario_name, "Data Export/Import"));
}

test "scenario error handling success" {
    const allocator = testing.allocator;
    var harness = IntegrationTestHarness.init(allocator);
    defer harness.deinit();

    // Run error handling scenario (should succeed).
    const result = try scenario_error_handling(&harness, false);

    // Verify result.
    try testing.expect(result.success);
    try testing.expect(result.latency_ms >= 0);
    try testing.expect(std.mem.eql(u8, result.scenario_name, "Error Handling"));
}

test "scenario error handling failure" {
    const allocator = testing.allocator;
    var harness = IntegrationTestHarness.init(allocator);
    defer harness.deinit();

    // Run error handling scenario (should fail).
    const result = try scenario_error_handling(&harness, true);

    // Verify result.
    try testing.expect(!result.success);
    try testing.expect(result.latency_ms >= 0);
    try testing.expect(result.error_message.len > 0);
    try testing.expect(std.mem.eql(u8, result.scenario_name, "Error Handling"));
}

test "scenario workflow execution" {
    const allocator = testing.allocator;
    var harness = IntegrationTestHarness.init(allocator);
    defer harness.deinit();

    // Generate workflow data.
    var generator = TestDataGenerator.init(allocator, 12345);
    const workflow_data = try generator.generate_workflow_metrics(5);
    defer allocator.free(workflow_data);

    // Run workflow execution scenario.
    const result = try scenario_workflow_execution(&harness, workflow_data);

    // Verify result.
    try testing.expect(result.success);
    try testing.expect(result.latency_ms >= 0);
    try testing.expect(std.mem.eql(u8, result.scenario_name, "Workflow Execution"));
}
