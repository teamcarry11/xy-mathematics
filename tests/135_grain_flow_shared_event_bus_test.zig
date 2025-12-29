//! Tests for Grain Flow Shared Event Bus.
//!
//! Tests shared Event Bus instance initialization and access.

const std = @import("std");
const grain_flow = @import("grain_flow");

test "shared event bus initialization" {
    // Initialize shared Event Bus.
    grain_flow.init_shared_event_bus();
    // Get shared Event Bus instance.
    const bus = grain_flow.get_shared_event_bus();
    try std.testing.expect(bus != null);
    if (bus) |event_bus_instance| {
        try std.testing.expect(event_bus_instance.get_event_count() == 0);
        try std.testing.expect(event_bus_instance.get_subscriber_count() == 0);
    }
}

test "shared event bus publish and subscribe" {
    // Initialize shared Event Bus.
    grain_flow.init_shared_event_bus();
    const bus = grain_flow.get_shared_event_bus();
    try std.testing.expect(bus != null);
    if (bus) |event_bus_instance| {
        // Subscribe to test event.
        var received: bool = false;
        const test_callback = struct {
            fn callback(event: *const grain_flow.event_bus.Event, user_data: ?*anyopaque) void {
                _ = event;
                if (user_data) |data| {
                    const flag = @as(*bool, @ptrCast(@alignCast(data)));
                    flag.* = true;
                }
            }
        }.callback;
        _ = event_bus_instance.subscribe(
            grain_flow.event_bus.EventType.agent_started,
            1,
            0,
            test_callback,
            @as(?*anyopaque, @ptrCast(&received)),
        );
        // Publish test event.
        const result = event_bus_instance.publish_event(
            grain_flow.event_bus.EventType.agent_started,
            2,
            1,
            1000,
        );
        try std.testing.expect(result == true);
        // Process events.
        event_bus_instance.process_events();
        // Verify event was received.
        try std.testing.expect(received == true);
    }
}

test "shared event bus multiple agents access" {
    // Initialize shared Event Bus.
    grain_flow.init_shared_event_bus();
    const bus1 = grain_flow.get_shared_event_bus();
    const bus2 = grain_flow.get_shared_event_bus();
    try std.testing.expect(bus1 != null);
    try std.testing.expect(bus2 != null);
    // Verify both references point to same instance.
    if (bus1) |b1| {
        if (bus2) |b2| {
            try std.testing.expect(b1 == b2);
        }
    }
}
