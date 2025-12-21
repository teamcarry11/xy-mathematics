//! Grain Bubble DAG Integration: Design graph storage and version history.
//!
//! Why: Store design operations in DAG for undo/redo and collaboration.
//! Architecture: Integration with DAG Core for event ordering.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-054259-pst: Grain Bubble Agent

const std = @import("std");
const canvas = @import("canvas.zig");
const component = @import("component.zig");
const dag_core = @import("dag_core");

// Bounded: Max design history entries.
pub const MAX_DESIGN_HISTORY: u32 = 256;

// Bounded: Max event data length.
pub const MAX_EVENT_DATA_LEN: u32 = 1024;

// Design event: design operation in DAG.
pub const DesignEvent = struct {
    event_id: u64,
    event_type: EventType,
    canvas_id: u32,
    component_id: u32,
    event_data: [MAX_EVENT_DATA_LEN]u8,
    event_data_len: u32,
    timestamp: u64,
    parent_events: [8]u64,
    parent_events_len: u32,

    pub const EventType = enum(u8) {
        add_shape, // Add shape to canvas
        delete_shape, // Delete shape from canvas
        move_shape, // Move shape
        resize_shape, // Resize shape
        add_component, // Add component to canvas
        delete_component, // Delete component from canvas
        create_component, // Create new component
        update_component, // Update component definition
    };

    pub fn init() DesignEvent {
        var event = DesignEvent{
            .event_id = 0,
            .event_type = .add_shape,
            .canvas_id = 0,
            .component_id = 0,
            .event_data = undefined,
            .event_data_len = 0,
            .timestamp = 0,
            .parent_events = undefined,
            .parent_events_len = 0,
        };
        @memset(event.event_data[0..], 0);
        @memset(event.parent_events[0..], 0);
        std.debug.assert(event.event_data_len == 0);
        std.debug.assert(event.parent_events_len == 0);
        return event;
    }
};

// Design version: snapshot of design state.
pub const DesignVersion = struct {
    version_id: u32,
    canvas_id: u32,
    event_id: u64,
    timestamp: u64,
    description: [64]u8,
    description_len: u32,

    pub fn init() DesignVersion {
        var version = DesignVersion{
            .version_id = 0,
            .canvas_id = 0,
            .event_id = 0,
            .timestamp = 0,
            .description = undefined,
            .description_len = 0,
        };
        @memset(version.description[0..], 0);
        std.debug.assert(version.description_len == 0);
        return version;
    }
};

// DAG integration: manages design graph and version history.
pub const DagIntegration = struct {
    dag: ?*dag_core.DagCore,
    design_history: [MAX_DESIGN_HISTORY]DesignVersion,
    design_history_len: u32,
    next_version_id: u32,
    next_event_id: u64,

    pub fn init() DagIntegration {
        var integration = DagIntegration{
            .dag = null,
            .design_history = undefined,
            .design_history_len = 0,
            .next_version_id = 1,
            .next_event_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_DESIGN_HISTORY) : (i += 1) {
            integration.design_history[i] = DesignVersion.init();
        }
        std.debug.assert(integration.design_history_len == 0);
        std.debug.assert(integration.next_version_id == 1);
        std.debug.assert(integration.next_event_id == 1);
        return integration;
    }

    // Set DAG instance.
    pub fn set_dag(self: *DagIntegration, dag: *dag_core.DagCore) void {
        std.debug.assert(@intFromPtr(dag) != 0);
        self.dag = dag;
        std.debug.assert(self.dag != null);
    }

    // Record design event in DAG.
    pub fn record_event(
        self: *DagIntegration,
        event: *const DesignEvent,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(event) != 0);
        if (self.dag == null) {
            return false;
        }
        const dag = self.dag.?;
        std.debug.assert(event.event_id > 0);
        std.debug.assert(event.event_data_len <= MAX_EVENT_DATA_LEN);
        std.debug.assert(event.parent_events_len <= 8);
        // Create canvas node if it doesn't exist (simplified - use canvas_id as node_id).
        const canvas_node_id: u32 = event.canvas_id;
        // Convert DesignEvent to DAG Event.
        const event_data = event.event_data[0..event.event_data_len];
        const parent_ids = event.parent_events[0..event.parent_events_len];
        // Map DesignEvent.EventType to DAG EventType.
        const dag_event_type: dag_core.DagCore.EventType = switch (event.event_type) {
            .add_shape, .delete_shape, .move_shape, .resize_shape => .ui_interaction,
            .add_component, .delete_component, .create_component, .update_component => .ui_interaction,
        };
        // Add event to DAG using addEvent.
        const event_id = dag.addEvent(
            dag_event_type,
            canvas_node_id,
            event_data,
            parent_ids,
        ) catch return false;
        std.debug.assert(event_id > 0);
        return true;
    }

    // Get event history for canvas.
    pub fn get_event_history(
        self: *const DagIntegration,
        canvas_id: u32,
        events: []DesignEvent,
    ) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(canvas_id > 0);
        std.debug.assert(events.len <= MAX_DESIGN_HISTORY);
        if (self.dag == null) {
            return 0;
        }
        const dag = self.dag.?;
        // Query DAG for events related to canvas_id (node_id).
        const canvas_node_id: u32 = canvas_id;
        var event_count: u32 = 0;
        var i: u32 = 0;
        // Iterate through pending events to find matching canvas_id.
        while (i < dag.pending_events_len and event_count < events.len) : (i += 1) {
            const dag_event = &dag.pending_events[i];
            if (dag_event.node_id == canvas_node_id) {
                // Convert DAG Event to DesignEvent.
                var design_event = DesignEvent.init();
                design_event.event_id = dag_event.id;
                // Map DAG EventType to DesignEvent EventType.
                design_event.event_type = switch (dag_event.event_type) {
                    .ui_interaction => .add_shape, // Simplified mapping.
                    else => .add_shape,
                };
                design_event.canvas_id = canvas_node_id;
                design_event.component_id = 0; // Not available in DAG event.
                // Copy event data.
                const data_len = @min(dag_event.data_len, MAX_EVENT_DATA_LEN);
                if (data_len > 0) {
                    @memcpy(design_event.event_data[0..data_len], dag_event.data[0..data_len]);
                    design_event.event_data_len = data_len;
                }
                design_event.timestamp = dag_event.timestamp;
                // Copy parent events.
                const parent_len = @min(dag_event.parents_len, 8);
                if (parent_len > 0) {
                    @memcpy(design_event.parent_events[0..parent_len], dag_event.parents[0..parent_len]);
                    design_event.parent_events_len = parent_len;
                }
                events[event_count] = design_event;
                event_count += 1;
            }
        }
        std.debug.assert(event_count <= MAX_DESIGN_HISTORY);
        return event_count;
    }

    // Create design version snapshot.
    pub fn create_version(
        self: *DagIntegration,
        canvas_id: u32,
        description: []const u8,
    ) ?u32 {
        std.debug.assert(canvas_id > 0);
        std.debug.assert(description.len > 0);
        std.debug.assert(description.len <= 64);
        if (self.design_history_len >= MAX_DESIGN_HISTORY) {
            return null;
        }
        const version_id = self.next_version_id;
        self.next_version_id += 1;
        var version = DesignVersion.init();
        version.version_id = version_id;
        version.canvas_id = canvas_id;
        version.event_id = self.next_event_id;
        self.next_event_id += 1;
        const desc_len = @min(description.len, 64);
        @memset(version.description[0..desc_len], 0);
        @memcpy(version.description[0..desc_len], description[0..desc_len]);
        version.description_len = @as(u32, @intCast(desc_len));
        self.design_history[self.design_history_len] = version;
        self.design_history_len += 1;
        std.debug.assert(self.design_history_len <= MAX_DESIGN_HISTORY);
        return version_id;
    }

    // Get design version by ID.
    pub fn get_version(
        self: *const DagIntegration,
        version_id: u32,
    ) ?*const DesignVersion {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(version_id > 0);
        var i: u32 = 0;
        while (i < self.design_history_len) : (i += 1) {
            if (self.design_history[i].version_id == version_id) {
                return &self.design_history[i];
            }
        }
        return null;
    }

    // Create version snapshot from event ID.
    pub fn create_version_snapshot(
        self: *DagIntegration,
        canvas_id: u32,
        event_id: u64,
        description: []const u8,
    ) ?u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(canvas_id > 0);
        std.debug.assert(event_id > 0);
        std.debug.assert(description.len > 0);
        std.debug.assert(description.len <= 64);
        if (self.design_history_len >= MAX_DESIGN_HISTORY) {
            return null;
        }
        const version_id = self.next_version_id;
        self.next_version_id += 1;
        var version = DesignVersion.init();
        version.version_id = version_id;
        version.canvas_id = canvas_id;
        version.event_id = event_id;
        const desc_len = @min(description.len, 64);
        @memset(version.description[0..desc_len], 0);
        @memcpy(version.description[0..desc_len], description[0..desc_len]);
        version.description_len = @as(u32, @intCast(desc_len));
        self.design_history[self.design_history_len] = version;
        self.design_history_len += 1;
        std.debug.assert(self.design_history_len <= MAX_DESIGN_HISTORY);
        return version_id;
    }

    // Load version snapshot (returns event ID to replay to).
    pub fn load_version_snapshot(
        self: *const DagIntegration,
        version_id: u32,
    ) ?u64 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(version_id > 0);
        if (self.get_version(version_id)) |version| {
            return version.event_id;
        }
        return null;
    }

    // Serialize design event to buffer for storage.
    pub fn serialize_event(
        event: *const DesignEvent,
        buffer: []u8,
    ) u32 {
        std.debug.assert(@intFromPtr(event) != 0);
        std.debug.assert(buffer.len >= MAX_EVENT_DATA_LEN + 64);
        var offset: u32 = 0;
        // Write event ID (8 bytes).
        @memcpy(buffer[offset..offset + 8], std.mem.asBytes(&event.event_id));
        offset += 8;
        // Write event type (1 byte).
        const event_type_val: u8 = @intFromEnum(event.event_type);
        buffer[offset] = event_type_val;
        offset += 1;
        // Write canvas ID (4 bytes).
        @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&event.canvas_id));
        offset += 4;
        // Write component ID (4 bytes).
        @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&event.component_id));
        offset += 4;
        // Write event data length (4 bytes).
        @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&event.event_data_len));
        offset += 4;
        // Write event data.
        if (event.event_data_len > 0) {
            const data_len = @min(event.event_data_len, MAX_EVENT_DATA_LEN);
            if (offset + data_len <= buffer.len) {
                @memcpy(buffer[offset..offset + data_len], event.event_data[0..data_len]);
                offset += data_len;
            }
        }
        // Write timestamp (8 bytes).
        @memcpy(buffer[offset..offset + 8], std.mem.asBytes(&event.timestamp));
        offset += 8;
        // Write parent events length (4 bytes).
        @memcpy(buffer[offset..offset + 4], std.mem.asBytes(&event.parent_events_len));
        offset += 4;
        // Write parent events (up to 8 * 8 = 64 bytes).
        var i: u32 = 0;
        while (i < event.parent_events_len and i < 8) : (i += 1) {
            @memcpy(buffer[offset..offset + 8], std.mem.asBytes(&event.parent_events[i]));
            offset += 8;
        }
        std.debug.assert(offset <= buffer.len);
        return offset;
    }

    // Deserialize design event from buffer.
    pub fn deserialize_event(
        buffer: []const u8,
        event: *DesignEvent,
    ) bool {
        std.debug.assert(@intFromPtr(event) != 0);
        std.debug.assert(buffer.len >= 33); // Minimum size
        var offset: u32 = 0;
        // Read event ID.
        event.event_id = std.mem.readInt(u64, buffer[offset..offset + 8], .little);
        offset += 8;
        // Read event type.
        const event_type_val = buffer[offset];
        offset += 1;
        if (event_type_val > 7) {
            return false;
        }
        event.event_type = @enumFromInt(event_type_val);
        // Read canvas ID.
        event.canvas_id = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
        offset += 4;
        // Read component ID.
        event.component_id = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
        offset += 4;
        // Read event data length.
        event.event_data_len = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
        offset += 4;
        if (event.event_data_len > MAX_EVENT_DATA_LEN) {
            return false;
        }
        // Read event data.
        if (event.event_data_len > 0) {
            const data_len = @min(event.event_data_len, MAX_EVENT_DATA_LEN);
            if (offset + data_len > buffer.len) {
                return false;
            }
            @memset(event.event_data[0..data_len], 0);
            @memcpy(event.event_data[0..data_len], buffer[offset..offset + data_len]);
            offset += data_len;
        }
        // Read timestamp.
        event.timestamp = std.mem.readInt(u64, buffer[offset..offset + 8], .little);
        offset += 8;
        // Read parent events length.
        event.parent_events_len = std.mem.readInt(u32, buffer[offset..offset + 4], .little);
        offset += 4;
        if (event.parent_events_len > 8) {
            return false;
        }
        // Read parent events.
        var i: u32 = 0;
        while (i < event.parent_events_len and i < 8) : (i += 1) {
            if (offset + 8 > buffer.len) {
                return false;
            }
            event.parent_events[i] = std.mem.readInt(u64, buffer[offset..offset + 8], .little);
            offset += 8;
        }
        std.debug.assert(offset <= buffer.len);
        return true;
    }
};

