//! Tests for Grain Bubble async integration module.
//!
//! Why: Verify async pattern integration with Flow Agent Event Bus.
//! Architecture: Unit tests for async integration functions.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const testing = std.testing;
const grain_bubble = @import("grain_bubble");
const grain_flow = @import("grain_flow");

test "async integration init" {
    var integration = grain_bubble.async_integration.AsyncIntegration.init();
    try testing.expect(integration.event_bus == null);
    try testing.expect(integration.subscribed == false);
    try testing.expect(integration.operation_contexts_len == 0);
}

test "async integration set event bus" {
    var integration = grain_bubble.async_integration.AsyncIntegration.init();
    var event_bus = grain_flow.event_bus.EventBus.init();
    integration.set_event_bus(&event_bus);
    try testing.expect(integration.event_bus != null);
    try testing.expect(integration.event_bus.? == &event_bus);
}

test "async integration subscribe to events" {
    var integration = grain_bubble.async_integration.AsyncIntegration.init();
    var event_bus = grain_flow.event_bus.EventBus.init();
    integration.set_event_bus(&event_bus);
    const result = integration.subscribe_to_events();
    try testing.expect(result == true);
    try testing.expect(integration.subscribed == true);
}

test "async integration subscribe without event bus" {
    var integration = grain_bubble.async_integration.AsyncIntegration.init();
    const result = integration.subscribe_to_events();
    try testing.expect(result == false);
    try testing.expect(integration.subscribed == false);
}

test "async integration publish component created" {
    var integration = grain_bubble.async_integration.AsyncIntegration.init();
    var event_bus = grain_flow.event_bus.EventBus.init();
    integration.set_event_bus(&event_bus);
    const operation_id = "test-op-1";
    const component_id: u32 = 42;
    const result = integration.publish_component_created(component_id, operation_id);
    try testing.expect(result == true);
}

test "async integration publish component created without event bus" {
    var integration = grain_bubble.async_integration.AsyncIntegration.init();
    const operation_id = "test-op-1";
    const component_id: u32 = 42;
    const result = integration.publish_component_created(component_id, operation_id);
    try testing.expect(result == false);
}

test "async integration publish component creation failed" {
    var integration = grain_bubble.async_integration.AsyncIntegration.init();
    var event_bus = grain_flow.event_bus.EventBus.init();
    integration.set_event_bus(&event_bus);
    const operation_id = "test-op-1";
    const error_msg = "Component creation failed";
    const result = integration.publish_component_creation_failed(error_msg, operation_id);
    try testing.expect(result == true);
}

test "async integration publish pattern applied" {
    var integration = grain_bubble.async_integration.AsyncIntegration.init();
    var event_bus = grain_flow.event_bus.EventBus.init();
    integration.set_event_bus(&event_bus);
    const operation_id = "test-op-1";
    const pattern_id: u32 = 10;
    const component_id: u32 = 42;
    const result = integration.publish_pattern_applied(pattern_id, component_id, operation_id);
    try testing.expect(result == true);
}

test "async integration publish pattern application failed" {
    var integration = grain_bubble.async_integration.AsyncIntegration.init();
    var event_bus = grain_flow.event_bus.EventBus.init();
    integration.set_event_bus(&event_bus);
    const operation_id = "test-op-1";
    const error_msg = "Pattern application failed";
    const result = integration.publish_pattern_application_failed(error_msg, operation_id);
    try testing.expect(result == true);
}

test "async integration operation context init" {
    var ctx = grain_bubble.async_integration.OperationContext.init();
    try testing.expect(ctx.operation_id_len == 0);
    try testing.expect(ctx.operation_type == .component_create);
    try testing.expect(ctx.timestamp == 0);
    try testing.expect(ctx.user_data == null);
}

test "async integration bubble event type values" {
    try testing.expect(@intFromEnum(grain_bubble.async_integration.BubbleEventType.component_created) == 1001);
    try testing.expect(@intFromEnum(grain_bubble.async_integration.BubbleEventType.component_creation_failed) == 1002);
    try testing.expect(@intFromEnum(grain_bubble.async_integration.BubbleEventType.pattern_applied) == 1003);
    try testing.expect(@intFromEnum(grain_bubble.async_integration.BubbleEventType.pattern_application_failed) == 1004);
}
