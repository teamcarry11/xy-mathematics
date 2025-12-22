//! Integration Test Harness Tests.
//!
//! Why: Validates integration test harness functionality for multi-agent testing.
//! Tests harness initialization, event bus setup, mock dependencies, test data generation.
//! Architecture: Test harness, mocks, test data generation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-184500-pst: Integration Testing Patterns Framework (Priority 2)

const std = @import("std");
const testing = std.testing;
const grain_research = @import("grain_research");
const IntegrationTestHarness = grain_research.IntegrationTestHarness;
const MockLLMProvider = grain_research.MockLLMProvider;
const MockDatabase = grain_research.MockDatabase;
const TestDataGenerator = grain_research.TestDataGenerator;

test "initialize test harness" {
    const allocator = testing.allocator;
    var harness = IntegrationTestHarness.init(allocator);
    defer harness.deinit();

    // Verify initialization.
    try testing.expect(harness.event_bus == null);
    try testing.expect(harness.agent_ids.items.len == 0);
    try testing.expect(harness.start_time == 0);
}

test "setup and teardown event bus" {
    const allocator = testing.allocator;
    var harness = IntegrationTestHarness.init(allocator);
    defer harness.deinit();

    // Setup event bus.
    try harness.setup_event_bus();
    try testing.expect(harness.event_bus != null);

    // Teardown event bus.
    harness.teardown_event_bus();
    try testing.expect(harness.event_bus == null);
}

test "register agent IDs" {
    const allocator = testing.allocator;
    var harness = IntegrationTestHarness.init(allocator);
    defer harness.deinit();

    // Register agent IDs.
    try harness.register_agent_id(1);
    try harness.register_agent_id(2);
    try harness.register_agent_id(3);

    // Verify agent IDs.
    const agent_ids = harness.get_agent_ids();
    try testing.expect(agent_ids.len == 3);
    try testing.expect(agent_ids[0] == 1);
    try testing.expect(agent_ids[1] == 2);
    try testing.expect(agent_ids[2] == 3);
}

test "test timer functionality" {
    const allocator = testing.allocator;
    var harness = IntegrationTestHarness.init(allocator);
    defer harness.deinit();

    // Start timer.
    harness.start_timer();
    try testing.expect(harness.start_time > 0);

    // Check timeout (should not timeout immediately).
    try testing.expect(!harness.is_test_timeout());
}

test "mock LLM provider" {
    const allocator = testing.allocator;
    var mock = MockLLMProvider.init(allocator);
    defer mock.deinit();

    // Add mock responses.
    try mock.add_response("Response 1");
    try mock.add_response("Response 2");
    try mock.add_response("Response 3");

    // Get responses.
    const response1 = mock.get_response();
    try testing.expect(response1 != null);
    try testing.expect(std.mem.eql(u8, response1.?, "Response 1"));

    const response2 = mock.get_response();
    try testing.expect(response2 != null);
    try testing.expect(std.mem.eql(u8, response2.?, "Response 2"));

    // Reset and get first response again.
    mock.reset();
    const response1_again = mock.get_response();
    try testing.expect(response1_again != null);
    try testing.expect(std.mem.eql(u8, response1_again.?, "Response 1"));
}

test "mock database" {
    const allocator = testing.allocator;
    var mock_db = MockDatabase.init(allocator);
    defer mock_db.deinit();

    // Store data.
    try mock_db.store("key1", "value1");
    try mock_db.store("key2", "value2");

    // Retrieve data.
    const value1 = mock_db.retrieve("key1");
    try testing.expect(value1 != null);
    try testing.expect(std.mem.eql(u8, value1.?, "value1"));

    const value2 = mock_db.retrieve("key2");
    try testing.expect(value2 != null);
    try testing.expect(std.mem.eql(u8, value2.?, "value2"));

    // Retrieve non-existent key.
    const value3 = mock_db.retrieve("key3");
    try testing.expect(value3 == null);
}

test "test data generator workflow metrics" {
    const allocator = testing.allocator;
    var generator = TestDataGenerator.init(allocator, 12345);
    defer _ = generator;

    // Generate workflow metrics.
    const metrics = try generator.generate_workflow_metrics(5);
    defer allocator.free(metrics);

    // Verify JSON structure.
    try testing.expect(std.mem.indexOf(u8, metrics, "\"total_executions\":5") != null);
    try testing.expect(std.mem.indexOf(u8, metrics, "\"executions\":[") != null);
    try testing.expect(std.mem.indexOf(u8, metrics, "\"workflow_id\":1") != null);
}

test "test data generator coordination data" {
    const allocator = testing.allocator;
    var generator = TestDataGenerator.init(allocator, 12345);
    defer _ = generator;

    // Generate coordination data.
    const coord_data = try generator.generate_coordination_data(1, 2);
    defer allocator.free(coord_data);

    // Verify JSON structure.
    try testing.expect(std.mem.indexOf(u8, coord_data, "\"source_agent_id\":1") != null);
    try testing.expect(std.mem.indexOf(u8, coord_data, "\"target_agent_id\":2") != null);
    try testing.expect(std.mem.indexOf(u8, coord_data, "\"latency_ms\":") != null);
}
