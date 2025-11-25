//! Tests for Grain OS window events system.
//!
//! Why: Verify window event emission and listener functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const EventManager = grain_os.window_events.EventManager;
const EventType = grain_os.window_events.EventType;

var test_event_received: bool = false;
var test_event_window_id: u32 = 0;

fn test_listener(event: *const grain_os.window_events.WindowEvent, _user_data: ?*anyopaque) void {
    _ = _user_data;
    test_event_received = true;
    test_event_window_id = event.window_id;
}

test "event manager initialization" {
    const manager = EventManager.init();
    std.debug.assert(manager.events_count == 0);
    std.debug.assert(manager.listeners_len == 0);
}

test "emit event" {
    var manager = EventManager.init();
    manager.emit_event(EventType.window_created, 1, 0);
    std.debug.assert(manager.get_event_count() == 1);
}

test "emit event with position" {
    var manager = EventManager.init();
    manager.emit_event_with_position(EventType.window_moved, 1, 0, 100, 200);
    std.debug.assert(manager.get_event_count() == 1);
}

test "emit event with size" {
    var manager = EventManager.init();
    manager.emit_event_with_size(EventType.window_resized, 1, 0, 800, 600);
    std.debug.assert(manager.get_event_count() == 1);
}

test "add event listener" {
    var manager = EventManager.init();
    const result = manager.add_listener(test_listener, null);
    std.debug.assert(result);
    std.debug.assert(manager.get_listener_count() == 1);
}

test "remove event listener" {
    var manager = EventManager.init();
    _ = manager.add_listener(test_listener, null);
    const result = manager.remove_listener(test_listener);
    std.debug.assert(result);
    std.debug.assert(manager.get_listener_count() == 0);
}

test "event listener notification" {
    var manager = EventManager.init();
    test_event_received = false;
    test_event_window_id = 0;
    _ = manager.add_listener(test_listener, null);
    manager.emit_event(EventType.window_created, 42, 0);
    std.debug.assert(test_event_received);
    std.debug.assert(test_event_window_id == 42);
}

test "clear events" {
    var manager = EventManager.init();
    manager.emit_event(EventType.window_created, 1, 0);
    manager.emit_event(EventType.window_destroyed, 2, 0);
    manager.clear_events();
    std.debug.assert(manager.get_event_count() == 0);
}

test "compositor add event listener" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const result = comp.add_event_listener(test_listener, null);
    std.debug.assert(result);
}

test "compositor remove event listener" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.add_event_listener(test_listener, null);
    const result = comp.remove_event_listener(test_listener);
    std.debug.assert(result);
}

test "compositor window events" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    test_event_received = false;
    test_event_window_id = 0;
    _ = comp.add_event_listener(test_listener, null);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);
    // Window created event should have been emitted.
    std.debug.assert(comp.get_event_count() > 0);
}

test "window events constants" {
    std.debug.assert(grain_os.window_events.MAX_EVENTS == 128);
    std.debug.assert(grain_os.window_events.MAX_LISTENERS == 16);
}

