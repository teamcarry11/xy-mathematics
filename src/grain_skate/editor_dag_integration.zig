const std = @import("std");
const DagCore = @import("../dag_core.zig").DagCore;

/// Editor-DAG Integration: Maps Grain Skate editor operations to DAG events.
/// ~<~ Glow Airbend: explicit editor-to-DAG mapping, bounded conversions.
/// ~~~~ Glow Waterbend: editor operations stream through DAG deterministically.
///
/// This implements HashDAG-style event ordering for deterministic undo/redo:
/// - Editor buffer becomes DAG node
/// - Editor operations (insert, delete, replace) become DAG events
/// - Parent event IDs maintain ordering (HashDAG-style)
/// - Foundation for collaborative editing
pub const EditorDagIntegration = struct {
    allocator: std.mem.Allocator,
    dag: DagCore,
    buffer_node_id: ?u32, // DAG node ID for editor buffer
    last_event_id: u64, // Last event ID (for parent references)
    
    // Bounded: Max 1,000 events per editor session
    pub const MAX_EVENTS_PER_SESSION: u32 = 1_000;
    
    // Bounded: Max 100 operations per second
    pub const MAX_OPERATIONS_PER_SECOND: u32 = 100;
    
    /// Initialize editor-DAG integration.
    pub fn init(allocator: std.mem.Allocator) !EditorDagIntegration {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);
        
        const dag = try DagCore.init(allocator);
        errdefer dag.deinit();
        
        return EditorDagIntegration{
            .allocator = allocator,
            .dag = dag,
            .buffer_node_id = null,
            .last_event_id = 0,
        };
    }
    
    /// Deinitialize editor-DAG integration.
    pub fn deinit(self: *EditorDagIntegration) void {
        self.dag.deinit();
    }
    
    /// Create DAG node for editor buffer.
    /// Returns node ID for the buffer.
    pub fn create_buffer_node(
        self: *EditorDagIntegration,
        initial_content: []const u8,
    ) !u32 {
        // Assert: Buffer node not already created
        std.debug.assert(self.buffer_node_id == null);
        
        // Create node data (buffer content)
        const node_data = try self.allocator.dupe(u8, initial_content);
        errdefer self.allocator.free(node_data);
        
        // Create DAG node (ui_component type for editor buffer)
        const node_id = try self.dag.addNode(
            .ui_component,
            node_data,
            .{
                .is_readonly = false,
                .readonly_start = 0,
                .readonly_end = @as(u32, @intCast(initial_content.len)),
                .metadata = "",
                .metadata_len = 0,
            },
        );
        
        self.buffer_node_id = node_id;
        
        // Assert: Node was created
        std.debug.assert(self.buffer_node_id.? == node_id);
        
        return node_id;
    }
    
    /// Map editor operation to DAG event (HashDAG-style).
    /// Returns event ID for the operation.
    pub fn map_operation_to_event(
        self: *EditorDagIntegration,
        op_type: OperationType,
        line_num: u32,
        column: u32,
        old_text: []const u8,
        new_text: []const u8,
    ) !u64 {
        // Assert: Buffer node must be created
        std.debug.assert(self.buffer_node_id != null);
        
        // Assert: Event count must be within bounds
        std.debug.assert(self.dag.pending_events_len < MAX_EVENTS_PER_SESSION);
        
        // Create event data (operation type + line/column + old/new text)
        var event_data = std.ArrayList(u8).init(self.allocator);
        defer event_data.deinit();
        
        const writer = event_data.writer();
        try writer.print("{s}:", .{@tagName(op_type)});
        try writer.print("line:{d}:", .{line_num});
        try writer.print("col:{d}:", .{column});
        try writer.print("old:{d}:", .{old_text.len});
        try writer.print("new:{d}:", .{new_text.len});
        try writer.writeAll(old_text);
        try writer.writeAll(new_text);
        
        // Create parent event IDs (HashDAG-style: reference last event)
        var parent_events: []const u64 = &.{};
        if (self.last_event_id > 0) {
            parent_events = &.{self.last_event_id};
        }
        
        // Add event to DAG (code_edit type)
        const event_id = try self.dag.addEvent(
            .code_edit,
            self.buffer_node_id.?,
            try event_data.toOwnedSlice(),
            parent_events,
        );
        
        // Update last event ID
        self.last_event_id = event_id;
        
        // Assert: Event was added
        std.debug.assert(event_id > 0);
        
        return event_id;
    }
    
    /// Type of editor operation.
    pub const OperationType = enum(u8) {
        insert, // Insert text
        delete, // Delete text
        replace, // Replace text
    };
    
    /// Process pending events (deterministic ordering).
    pub fn process_events(self: *EditorDagIntegration) !void {
        // Process events in DAG (TigerBeetle-style state machine)
        try self.dag.processEvents();
        
        // Assert: Events were processed
        std.debug.assert(self.dag.pending_events_len == 0);
    }
    
    /// Get last event ID (for undo/redo navigation).
    pub fn get_last_event_id(self: *const EditorDagIntegration) u64 {
        return self.last_event_id;
    }
    
    /// Get buffer node ID.
    pub fn get_buffer_node_id(self: *const EditorDagIntegration) ?u32 {
        return self.buffer_node_id;
    }
    
    /// Get pending events count.
    pub fn get_pending_events_count(self: *const EditorDagIntegration) u32 {
        return self.dag.pending_events_len;
    }
};

test "editor dag integration initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = try EditorDagIntegration.init(arena.allocator());
    defer integration.deinit();
    
    // Assert: Integration initialized
    try std.testing.expect(integration.dag.nodes_len == 0);
    try std.testing.expect(integration.dag.edges_len == 0);
    try std.testing.expect(integration.buffer_node_id == null);
    try std.testing.expect(integration.last_event_id == 0);
}

test "editor dag create buffer node" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = try EditorDagIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const content = "line1\nline2\nline3";
    const node_id = try integration.create_buffer_node(content);
    
    // Assert: Buffer node created
    try std.testing.expect(node_id < DagCore.MAX_NODES);
    try std.testing.expect(integration.buffer_node_id == node_id);
    try std.testing.expect(integration.dag.nodes_len == 1);
}

test "editor dag map operation to event" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = try EditorDagIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try integration.create_buffer_node(content);
    
    // Map insert operation to event
    const event_id = try integration.map_operation_to_event(
        .insert,
        1,
        5,
        "",
        "new",
    );
    
    // Assert: Event was created
    try std.testing.expect(event_id > 0);
    try std.testing.expect(integration.dag.pending_events_len == 1);
    try std.testing.expect(integration.last_event_id == event_id);
}

test "editor dag event parent references" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = try EditorDagIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try integration.create_buffer_node(content);
    
    // Create first event
    const event1_id = try integration.map_operation_to_event(
        .insert,
        1,
        5,
        "",
        "new1",
    );
    
    // Create second event (should reference first as parent)
    const event2_id = try integration.map_operation_to_event(
        .insert,
        1,
        9,
        "",
        "new2",
    );
    
    // Assert: Events created with parent references
    try std.testing.expect(event1_id > 0);
    try std.testing.expect(event2_id > event1_id);
    try std.testing.expect(integration.dag.pending_events_len == 2);
    try std.testing.expect(integration.last_event_id == event2_id);
}

test "editor dag process events" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = try EditorDagIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const content = "line1\nline2\nline3";
    _ = try integration.create_buffer_node(content);
    
    // Create events
    _ = try integration.map_operation_to_event(.insert, 1, 5, "", "new1");
    _ = try integration.map_operation_to_event(.insert, 1, 9, "", "new2");
    
    // Process events
    try integration.process_events();
    
    // Assert: Events were processed
    try std.testing.expect(integration.dag.pending_events_len == 0);
}

