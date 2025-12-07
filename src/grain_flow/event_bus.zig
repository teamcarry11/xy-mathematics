//! Grain Flow Event Bus: Centralized event routing for agent communication.
//!
//! Why: Provides centralized event routing for agent-to-agent communication.
//! Agents publish events and subscribe to event types. Event bus routes events
//! to subscribed agents using iterative matching (no recursion).
//!
//! Architecture: Event queue, subscription registry, iterative routing.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-054000-pst: Phase 1 Event Bus Foundation

const std = @import("std");

// Bounded: Max events in queue.
pub const MAX_EVENTS: u32 = 10000;

// Bounded: Max subscribers per event type.
pub const MAX_SUBSCRIBERS: u32 = 256;

// Bounded: Max event payload size (64KB).
pub const MAX_PAYLOAD_SIZE: u32 = 65536;

// Bounded: Max agent ID length.
pub const MAX_AGENT_ID_LEN: u32 = 64;

// Event type: enum-based event types for agent communication.
pub const EventType = enum(u16) {
    none = 0,
    agent_started = 1,
    agent_stopped = 2,
    agent_health_check = 3,
    workflow_started = 4,
    workflow_completed = 5,
    workflow_failed = 6,
    task_completed = 7,
    task_failed = 8,
    data_backup_started = 9,
    data_backup_completed = 10,
    data_backup_failed = 11,
    database_query_completed = 12,
    api_request_completed = 13,
    custom = 1000,
};

// Event: represents an event in the event bus.
pub const Event = struct {
    event_type: EventType,
    source_agent_id: u32,
    destination_agent_id: u32,
    timestamp: u64,
    payload: [MAX_PAYLOAD_SIZE]u8,
    payload_len: u32,
    processed: bool,

    pub fn init(
        event_type: EventType,
        source_agent_id: u32,
        destination_agent_id: u32,
        timestamp: u64,
    ) Event {
        std.debug.assert(source_agent_id > 0);
        std.debug.assert(timestamp > 0);
        var event = Event{
            .event_type = event_type,
            .source_agent_id = source_agent_id,
            .destination_agent_id = destination_agent_id,
            .timestamp = timestamp,
            .payload = undefined,
            .payload_len = 0,
            .processed = false,
        };
        var i: u32 = 0;
        while (i < MAX_PAYLOAD_SIZE) : (i += 1) {
            event.payload[i] = 0;
        }
        return event;
    }

    pub fn set_payload(self: *Event, data: []const u8) bool {
        std.debug.assert(data.len > 0);
        if (data.len > MAX_PAYLOAD_SIZE) {
            return false;
        }
        var i: u32 = 0;
        while (i < data.len) : (i += 1) {
            self.payload[i] = data[i];
        }
        self.payload_len = @intCast(data.len);
        return true;
    }
};

// Event subscriber callback function.
pub const EventSubscriberFn = *const fn (
    event: *const Event,
    user_data: ?*anyopaque,
) void;

// Event subscriber: callback for event types.
pub const EventSubscriber = struct {
    subscriber_fn: EventSubscriberFn,
    user_data: ?*anyopaque,
    agent_id: u32,
    active: bool,
};

// Event bus: manages events and subscriptions.
pub const EventBus = struct {
    events: [MAX_EVENTS]Event,
    events_head: u32,
    events_tail: u32,
    events_count: u32,
    subscribers: [MAX_SUBSCRIBERS]EventSubscriber,
    subscribers_len: u32,
    subscribers_by_type: [256][MAX_SUBSCRIBERS]u32,
    subscribers_count_by_type: [256]u32,

    pub fn init() EventBus {
        var bus = EventBus{
            .events = undefined,
            .events_head = 0,
            .events_tail = 0,
            .events_count = 0,
            .subscribers = undefined,
            .subscribers_len = 0,
            .subscribers_by_type = undefined,
            .subscribers_count_by_type = undefined,
        };
        var i: u32 = 0;
        while (i < MAX_EVENTS) : (i += 1) {
            bus.events[i] = Event.init(
                EventType.none,
                0,
                0,
                0,
            );
        }
        i = 0;
        while (i < MAX_SUBSCRIBERS) : (i += 1) {
            bus.subscribers[i] = EventSubscriber{
                .subscriber_fn = undefined,
                .user_data = null,
                .agent_id = 0,
                .active = false,
            };
        }
        i = 0;
        while (i < 256) : (i += 1) {
            bus.subscribers_count_by_type[i] = 0;
            var j: u32 = 0;
            while (j < MAX_SUBSCRIBERS) : (j += 1) {
                bus.subscribers_by_type[i][j] = 0;
            }
        }
        return bus;
    }

    // Publish event to event bus.
    pub fn publish_event(
        self: *EventBus,
        event_type: EventType,
        source_agent_id: u32,
        destination_agent_id: u32,
        timestamp: u64,
    ) bool {
        std.debug.assert(source_agent_id > 0);
        std.debug.assert(timestamp > 0);
        // destination_agent_id can be 0 (broadcast to all subscribers)
        if (self.events_count >= MAX_EVENTS) {
            // Queue full, drop oldest event.
            self.events_head = (self.events_head + 1) % MAX_EVENTS;
            self.events_count -= 1;
        }
        const idx = self.events_tail;
        self.events[idx] = Event.init(
            event_type,
            source_agent_id,
            destination_agent_id,
            timestamp,
        );
        self.events_tail = (self.events_tail + 1) % MAX_EVENTS;
        self.events_count += 1;
        // Route event to subscribers.
        self.route_event(&self.events[idx]);
        return true;
    }

    // Publish event with payload.
    pub fn publish_event_with_payload(
        self: *EventBus,
        event_type: EventType,
        source_agent_id: u32,
        destination_agent_id: u32,
        timestamp: u64,
        payload: []const u8,
    ) bool {
        std.debug.assert(source_agent_id > 0);
        std.debug.assert(timestamp > 0);
        if (self.events_count >= MAX_EVENTS) {
            self.events_head = (self.events_head + 1) % MAX_EVENTS;
            self.events_count -= 1;
        }
        const idx = self.events_tail;
        self.events[idx] = Event.init(
            event_type,
            source_agent_id,
            destination_agent_id,
            timestamp,
        );
        if (!self.events[idx].set_payload(payload)) {
            return false;
        }
        self.events_tail = (self.events_tail + 1) % MAX_EVENTS;
        self.events_count += 1;
        self.route_event(&self.events[idx]);
        return true;
    }

    // Subscribe to event type.
    pub fn subscribe(
        self: *EventBus,
        event_type: EventType,
        agent_id: u32,
        subscriber_fn: EventSubscriberFn,
        user_data: ?*anyopaque,
    ) bool {
        std.debug.assert(agent_id > 0);
        if (self.subscribers_len >= MAX_SUBSCRIBERS) {
            return false;
        }
        const type_idx = @intFromEnum(event_type);
        if (type_idx >= 256) {
            return false;
        }
        if (self.subscribers_count_by_type[type_idx] >= MAX_SUBSCRIBERS) {
            return false;
        }
        const sub_idx = self.subscribers_len;
        self.subscribers[sub_idx] = EventSubscriber{
            .subscriber_fn = subscriber_fn,
            .user_data = user_data,
            .agent_id = agent_id,
            .active = true,
        };
        self.subscribers_len += 1;
        const type_sub_idx = self.subscribers_count_by_type[type_idx];
        self.subscribers_by_type[type_idx][type_sub_idx] = sub_idx;
        self.subscribers_count_by_type[type_idx] += 1;
        return true;
    }

    // Unsubscribe from event type.
    pub fn unsubscribe(
        self: *EventBus,
        event_type: EventType,
        agent_id: u32,
    ) bool {
        std.debug.assert(agent_id > 0);
        const type_idx = @intFromEnum(event_type);
        if (type_idx >= 256) {
            return false;
        }
        var found: bool = false;
        var sub_idx: u32 = 0;
        var type_sub_idx: u32 = 0;
        var i: u32 = 0;
        while (i < self.subscribers_count_by_type[type_idx]) : (i += 1) {
            const idx = self.subscribers_by_type[type_idx][i];
            if (self.subscribers[idx].agent_id == agent_id) {
                found = true;
                sub_idx = idx;
                type_sub_idx = i;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Mark subscriber as inactive.
        self.subscribers[sub_idx].active = false;
        // Remove from type-specific list.
        i = type_sub_idx;
        while (i < self.subscribers_count_by_type[type_idx] - 1) : (i += 1) {
            self.subscribers_by_type[type_idx][i] =
                self.subscribers_by_type[type_idx][i + 1];
        }
        self.subscribers_count_by_type[type_idx] -= 1;
        return true;
    }

    // Route event to subscribers (iterative, no recursion).
    fn route_event(self: *EventBus, event: *Event) void {
        std.debug.assert(event.processed == false);
        const type_idx = @intFromEnum(event.event_type);
        if (type_idx >= 256) {
            return;
        }
        var i: u32 = 0;
        while (i < self.subscribers_count_by_type[type_idx]) : (i += 1) {
            const sub_idx = self.subscribers_by_type[type_idx][i];
            const subscriber = &self.subscribers[sub_idx];
            if (!subscriber.active) {
                continue;
            }
            // Filter by destination if specified.
            if (event.destination_agent_id > 0) {
                if (subscriber.agent_id != event.destination_agent_id) {
                    continue;
                }
            }
            // Filter by source if needed (future enhancement).
            subscriber.subscriber_fn(event, subscriber.user_data);
        }
        event.processed = true;
    }

    // Process all pending events (iterative).
    pub fn process_events(self: *EventBus) void {
        var processed: u32 = 0;
        const max_iterations: u32 = self.events_count;
        var iterations: u32 = 0;
        while (iterations < max_iterations and processed < self.events_count) : (iterations += 1) {
            const idx = (self.events_head + processed) % MAX_EVENTS;
            const event = &self.events[idx];
            if (event.processed) {
                processed += 1;
                continue;
            }
            if (event.event_type == EventType.none) {
                processed += 1;
                continue;
            }
            self.route_event(event);
            processed += 1;
        }
    }

    // Get event count.
    pub fn get_event_count(self: *const EventBus) u32 {
        return self.events_count;
    }

    // Get subscriber count.
    pub fn get_subscriber_count(self: *const EventBus) u32 {
        return self.subscribers_len;
    }

    // Get subscriber count for event type.
    pub fn get_subscriber_count_for_type(
        self: *const EventBus,
        event_type: EventType,
    ) u32 {
        const type_idx = @intFromEnum(event_type);
        if (type_idx >= 256) {
            return 0;
        }
        return self.subscribers_count_by_type[type_idx];
    }

    // Clear all events.
    pub fn clear_events(self: *EventBus) void {
        self.events_head = 0;
        self.events_tail = 0;
        self.events_count = 0;
    }
};
