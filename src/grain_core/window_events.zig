//! Grain OS Window Events: Event system for window lifecycle notifications.
//!
//! Why: Allow systems to be notified about window events (create, destroy, focus, etc.).
//! Architecture: Event queue and callback system.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");

// Bounded: Max event queue size.
pub const MAX_EVENTS: u32 = 128;

// Bounded: Max event listeners.
pub const MAX_LISTENERS: u32 = 16;

// Event type.
pub const EventType = enum(u8) {
    none,
    window_created,
    window_destroyed,
    window_focused,
    window_unfocused,
    window_minimized,
    window_maximized,
    window_moved,
    window_resized,
    window_title_changed,
};

// Window event: represents a window event.
pub const WindowEvent = struct {
    event_type: EventType,
    window_id: u32,
    timestamp: u64,
    data_x: i32,
    data_y: i32,
    data_width: u32,
    data_height: u32,
};

// Event listener callback function.
pub const EventListenerFn = *const fn (
    event: *const WindowEvent,
    user_data: ?*anyopaque,
) void;

// Event listener: callback for window events.
pub const EventListener = struct {
    listener_fn: EventListenerFn,
    user_data: ?*anyopaque,
    active: bool,
};

// Event manager: manages window events and listeners.
pub const EventManager = struct {
    events: [MAX_EVENTS]WindowEvent,
    events_head: u32,
    events_tail: u32,
    events_count: u32,
    listeners: [MAX_LISTENERS]EventListener,
    listeners_len: u32,

    pub fn init() EventManager {
        var manager = EventManager{
            .events = undefined,
            .events_head = 0,
            .events_tail = 0,
            .events_count = 0,
            .listeners = undefined,
            .listeners_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_EVENTS) : (i += 1) {
            manager.events[i] = WindowEvent{
                .event_type = EventType.none,
                .window_id = 0,
                .timestamp = 0,
                .data_x = 0,
                .data_y = 0,
                .data_width = 0,
                .data_height = 0,
            };
        }
        i = 0;
        while (i < MAX_LISTENERS) : (i += 1) {
            manager.listeners[i] = EventListener{
                .listener_fn = undefined,
                .user_data = null,
                .active = false,
            };
        }
        return manager;
    }

    // Emit window event.
    pub fn emit_event(
        self: *EventManager,
        event_type: EventType,
        window_id: u32,
        timestamp: u64,
    ) void {
        std.debug.assert(window_id > 0);
        if (self.events_count >= MAX_EVENTS) {
            // Queue full, drop oldest event.
            self.events_head = (self.events_head + 1) % MAX_EVENTS;
            self.events_count -= 1;
        }
        const idx = self.events_tail;
        self.events[idx] = WindowEvent{
            .event_type = event_type,
            .window_id = window_id,
            .timestamp = timestamp,
            .data_x = 0,
            .data_y = 0,
            .data_width = 0,
            .data_height = 0,
        };
        self.events_tail = (self.events_tail + 1) % MAX_EVENTS;
        self.events_count += 1;
        // Notify listeners.
        self.notify_listeners(&self.events[idx]);
    }

    // Emit window event with position data.
    pub fn emit_event_with_position(
        self: *EventManager,
        event_type: EventType,
        window_id: u32,
        timestamp: u64,
        x: i32,
        y: i32,
    ) void {
        std.debug.assert(window_id > 0);
        if (self.events_count >= MAX_EVENTS) {
            self.events_head = (self.events_head + 1) % MAX_EVENTS;
            self.events_count -= 1;
        }
        const idx = self.events_tail;
        self.events[idx] = WindowEvent{
            .event_type = event_type,
            .window_id = window_id,
            .timestamp = timestamp,
            .data_x = x,
            .data_y = y,
            .data_width = 0,
            .data_height = 0,
        };
        self.events_tail = (self.events_tail + 1) % MAX_EVENTS;
        self.events_count += 1;
        self.notify_listeners(&self.events[idx]);
    }

    // Emit window event with size data.
    pub fn emit_event_with_size(
        self: *EventManager,
        event_type: EventType,
        window_id: u32,
        timestamp: u64,
        width: u32,
        height: u32,
    ) void {
        std.debug.assert(window_id > 0);
        if (self.events_count >= MAX_EVENTS) {
            self.events_head = (self.events_head + 1) % MAX_EVENTS;
            self.events_count -= 1;
        }
        const idx = self.events_tail;
        self.events[idx] = WindowEvent{
            .event_type = event_type,
            .window_id = window_id,
            .timestamp = timestamp,
            .data_x = 0,
            .data_y = 0,
            .data_width = width,
            .data_height = height,
        };
        self.events_tail = (self.events_tail + 1) % MAX_EVENTS;
        self.events_count += 1;
        self.notify_listeners(&self.events[idx]);
    }

    // Add event listener.
    pub fn add_listener(
        self: *EventManager,
        listener_fn: EventListenerFn,
        user_data: ?*anyopaque,
    ) bool {
        if (self.listeners_len >= MAX_LISTENERS) {
            return false;
        }
        self.listeners[self.listeners_len] = EventListener{
            .listener_fn = listener_fn,
            .user_data = user_data,
            .active = true,
        };
        self.listeners_len += 1;
        return true;
    }

    // Remove event listener.
    pub fn remove_listener(self: *EventManager, listener_fn: EventListenerFn) bool {
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.listeners_len) : (i += 1) {
            if (self.listeners[i].listener_fn == listener_fn) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining listeners left.
        while (i < self.listeners_len - 1) : (i += 1) {
            self.listeners[i] = self.listeners[i + 1];
        }
        self.listeners_len -= 1;
        return true;
    }

    // Notify all listeners of event.
    fn notify_listeners(self: *EventManager, event: *const WindowEvent) void {
        var i: u32 = 0;
        while (i < self.listeners_len) : (i += 1) {
            if (self.listeners[i].active) {
                self.listeners[i].listener_fn(event, self.listeners[i].user_data);
            }
        }
    }

    // Get event count.
    pub fn get_event_count(self: *const EventManager) u32 {
        return self.events_count;
    }

    // Get listener count.
    pub fn get_listener_count(self: *const EventManager) u32 {
        return self.listeners_len;
    }

    // Clear all events.
    pub fn clear_events(self: *EventManager) void {
        self.events_head = 0;
        self.events_tail = 0;
        self.events_count = 0;
    }
};

