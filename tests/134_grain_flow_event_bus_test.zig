//! Grain Flow Event Bus Tests: Comprehensive tests for event bus functionality.
//!
//! Why: Verify event bus publishes, subscribes, and routes events correctly.
//! Architecture: Tests event publishing, subscription, routing, and filtering.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-054000-pst: Phase 1 Event Bus Foundation

const std = @import("std");
const grain_flow = @import("grain_flow");
const event_bus = grain_flow.event_bus;

test "event bus initialization" {
    var bus = event_bus.EventBus.init();
    try std.testing.expect(bus.get_event_count() == 0);
    try std.testing.expect(bus.get_subscriber_count() == 0);
}

test "publish event without payload" {
    var bus = event_bus.EventBus.init();
    const result = bus.publish_event(
        event_bus.EventType.agent_started,
        1,
        0,
        1000,
    );
    try std.testing.expect(result == true);
    try std.testing.expect(bus.get_event_count() == 1);
}

test "publish event with payload" {
    var bus = event_bus.EventBus.init();
    const payload = "test payload";
    const result = bus.publish_event_with_payload(
        event_bus.EventType.workflow_started,
        1,
        0,
        1000,
        payload,
    );
    try std.testing.expect(result == true);
    try std.testing.expect(bus.get_event_count() == 1);
}

test "subscribe to event type" {
    var bus = event_bus.EventBus.init();
    var received: bool = false;
        const callback = struct {
        fn handler(event: *const event_bus.Event, user_data: ?*anyopaque) void {
            _ = event;
            const received_ptr = @as(*bool, @ptrCast(@alignCast(user_data.?)));
            received_ptr.* = true;
        }
    }.handler;
    const result = bus.subscribe(
        event_bus.EventType.agent_started,
        1,
        callback,
        @as(?*anyopaque, @ptrCast(&received)),
    );
    try std.testing.expect(result == true);
    try std.testing.expect(bus.get_subscriber_count() == 1);
    try std.testing.expect(
        bus.get_subscriber_count_for_type(event_bus.EventType.agent_started) == 1,
    );
}

test "event routing to subscriber" {
    var bus = event_bus.EventBus.init();
    var received: bool = false;
    const callback = struct {
        fn handler(event: *const event_bus.Event, user_data: ?*anyopaque) void {
            _ = event;
            const received_ptr = @as(*bool, @ptrCast(@alignCast(user_data.?)));
            received_ptr.* = true;
        }
    }.handler;
    _ = bus.subscribe(
        event_bus.EventType.agent_started,
        1,
        callback,
        @as(?*anyopaque, @ptrCast(&received)),
    );
    _ = bus.publish_event(
        event_bus.EventType.agent_started,
        2,
        0,
        1000,
    );
    bus.process_events();
    try std.testing.expect(received == true);
}

test "unsubscribe from event type" {
    var bus = event_bus.EventBus.init();
    const callback = struct {
        fn handler(event: *const event_bus.Event, user_data: ?*anyopaque) void {
            _ = event;
            _ = user_data;
        }
    }.handler;
    _ = bus.subscribe(
        event_bus.EventType.agent_started,
        1,
        callback,
        null,
    );
    try std.testing.expect(bus.get_subscriber_count() == 1);
    const result = bus.unsubscribe(event_bus.EventType.agent_started, 1);
    try std.testing.expect(result == true);
    try std.testing.expect(
        bus.get_subscriber_count_for_type(event_bus.EventType.agent_started) == 0,
    );
}

test "event filtering by destination" {
    var bus = event_bus.EventBus.init();
    var agent1_received: bool = false;
    var agent2_received: bool = false;
    const callback1 = struct {
        fn handler(event: *const event_bus.Event, user_data: ?*anyopaque) void {
            _ = event;
            const received_ptr = @as(*bool, @ptrCast(@alignCast(user_data.?)));
            received_ptr.* = true;
        }
    }.handler;
    const callback2 = struct {
        fn handler(event: *const event_bus.Event, user_data: ?*anyopaque) void {
            _ = event;
            const received_ptr = @as(*bool, @ptrCast(@alignCast(user_data.?)));
            received_ptr.* = true;
        }
    }.handler;
    _ = bus.subscribe(
        event_bus.EventType.task_completed,
        1,
        callback1,
        @as(?*anyopaque, @ptrCast(&agent1_received)),
    );
    _ = bus.subscribe(
        event_bus.EventType.task_completed,
        2,
        callback2,
        @as(?*anyopaque, @ptrCast(&agent2_received)),
    );
    _ = bus.publish_event(
        event_bus.EventType.task_completed,
        3,
        1,
        1000,
    );
    bus.process_events();
    try std.testing.expect(agent1_received == true);
    try std.testing.expect(agent2_received == false);
}

test "bounded event queue" {
    var bus = event_bus.EventBus.init();
    var i: u32 = 0;
    while (i < event_bus.MAX_EVENTS + 10) : (i += 1) {
        _ = bus.publish_event(
            event_bus.EventType.agent_started,
            1,
            0,
            1000 + i,
        );
    }
    try std.testing.expect(bus.get_event_count() == event_bus.MAX_EVENTS);
}

test "bounded subscribers per type" {
    var bus = event_bus.EventBus.init();
    const callback = struct {
        fn handler(event: *const event_bus.Event, user_data: ?*anyopaque) void {
            _ = event;
            _ = user_data;
        }
    }.handler;
    var i: u32 = 0;
    while (i < event_bus.MAX_SUBSCRIBERS + 10) : (i += 1) {
        _ = bus.subscribe(
            event_bus.EventType.agent_started,
            i + 1,
            callback,
            null,
        );
    }
    try std.testing.expect(
        bus.get_subscriber_count_for_type(event_bus.EventType.agent_started) ==
            event_bus.MAX_SUBSCRIBERS,
    );
}

test "clear events" {
    var bus = event_bus.EventBus.init();
    _ = bus.publish_event(
        event_bus.EventType.agent_started,
        1,
        0,
        1000,
    );
    try std.testing.expect(bus.get_event_count() == 1);
    bus.clear_events();
    try std.testing.expect(bus.get_event_count() == 0);
}

test "event payload setting" {
    var event = event_bus.Event.init(
        event_bus.EventType.custom,
        1,
        0,
        1000,
    );
    const payload = "test data";
    const result = event.set_payload(payload);
    try std.testing.expect(result == true);
    try std.testing.expect(event.payload_len == payload.len);
}

test "event payload too large" {
    var event = event_bus.Event.init(
        event_bus.EventType.custom,
        1,
        0,
        1000,
    );
    var large_payload: [event_bus.MAX_PAYLOAD_SIZE + 1]u8 = undefined;
    var i: u32 = 0;
    while (i < event_bus.MAX_PAYLOAD_SIZE + 1) : (i += 1) {
        large_payload[i] = 0;
    }
    const result = event.set_payload(&large_payload);
    try std.testing.expect(result == false);
}
