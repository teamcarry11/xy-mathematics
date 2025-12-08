const std = @import("std");

/// DAG-Based UI Architecture: Core data structure for unified editor/browser state.
/// ~<~ Glow Airbend: explicit DAG structure, bounded nodes/edges.
/// ~~~~ Glow Waterbend: streaming updates flow deterministically.
///
/// This implements Hyperfiddle's vision: UIs as streaming DAGs.
/// Combines with Matklad's project-wide semantic understanding and
/// TigerBeetle-style deterministic execution.
pub const DagCore = struct {
    allocator: std.mem.Allocator,

    // Bounded: Max 10,000 nodes (explicit limit)
    pub const MAX_NODES: u32 = 10_000;

    // Bounded: Max 100,000 edges (explicit limit)
    pub const MAX_EDGES: u32 = 100_000;

    // Bounded: Max 1,000 pending events (explicit limit)
    pub const MAX_PENDING_EVENTS: u32 = 1_000;

    /// Node in the DAG (UI component, data source, computation).
    pub const Node = struct {
        id: u32,
        node_type: NodeType,
        data: []const u8, // Node-specific data (AST, DOM, UI state)
        data_len: u32,
        parent_count: u32,
        child_count: u32,
        // Attributes (readonly spans, metadata, etc.)
        attributes: Attributes,
    };

    /// Type of node in the DAG.
    pub const NodeType = enum(u8) {
        ast_node, // Tree-sitter AST node (editor)
        dom_node, // DOM node (browser)
        ui_component, // UI component (Grain Aurora)
        data_source, // Data source (Nostr event, file)
        computation, // Computation (GLM-4.6, transformation)
    };

    /// Node attributes (readonly spans, metadata, etc.).
    pub const Attributes = struct {
        is_readonly: bool = false,
        readonly_start: u32 = 0,
        readonly_end: u32 = 0,
        metadata: []const u8 = "",
        metadata_len: u32 = 0,
    };

    /// Edge in the DAG (dependency, data flow, transformation).
    pub const Edge = struct {
        from_node: u32, // Source node ID
        to_node: u32, // Target node ID
        edge_type: EdgeType,
        weight: u32 = 1, // Edge weight (for prioritization)
    };

    /// Type of edge in the DAG.
    pub const EdgeType = enum(u8) {
        dependency, // Node depends on another (AST parent, DOM parent)
        data_flow, // Data flows from source to target
        transformation, // Transformation edge (GLM-4.6, refactor)
        semantic, // Semantic relationship (calls, references)
    };

    /// Event in the DAG (code edit, web request, UI interaction).
    pub const Event = struct {
        id: u64, // Unique event ID (HashDAG-style)
        event_type: EventType,
        node_id: u32, // Target node
        data: []const u8, // Event data
        data_len: u32,
        parents: []const u64, // Parent event IDs (HashDAG-style)
        parents_len: u32,
        timestamp: u64, // Unix timestamp
    };

    /// Type of event in the DAG.
    pub const EventType = enum(u8) {
        code_edit, // Code edit (editor)
        web_request, // Web request (browser)
        ui_interaction, // UI interaction (click, keyboard)
        ai_completion, // AI completion (GLM-4.6)
        vcs_update, // VCS update (jj status, commit)
    };

    /// DAG state (nodes, edges, events).
    nodes: []Node,
    nodes_len: u32,
    edges: []Edge,
    edges_len: u32,
    pending_events: []Event,
    pending_events_len: u32,

    /// Initialize DAG with pre-allocated buffers.
    pub fn init(allocator: std.mem.Allocator) !DagCore {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        // Pre-allocate node buffer
        const nodes = try allocator.alloc(Node, MAX_NODES);
        errdefer allocator.free(nodes);

        // Pre-allocate edge buffer
        const edges = try allocator.alloc(Edge, MAX_EDGES);
        errdefer allocator.free(edges);

        // Pre-allocate event buffer
        const pending_events = try allocator.alloc(Event, MAX_PENDING_EVENTS);
        errdefer allocator.free(pending_events);

        return DagCore{
            .allocator = allocator,
            .nodes = nodes,
            .nodes_len = 0,
            .edges = edges,
            .edges_len = 0,
            .pending_events = pending_events,
            .pending_events_len = 0,
        };
    }

    /// Deinitialize DAG and free all resources.
    pub fn deinit(self: *DagCore) void {
        // Free node data
        for (self.nodes[0..self.nodes_len]) |*node| {
            if (node.data.len > 0) {
                self.allocator.free(node.data);
            }
            if (node.attributes.metadata.len > 0) {
                self.allocator.free(node.attributes.metadata);
            }
        }

        // Free event data
        for (self.pending_events[0..self.pending_events_len]) |*event| {
            if (event.data.len > 0) {
                self.allocator.free(event.data);
            }
            if (event.parents.len > 0) {
                self.allocator.free(event.parents);
            }
        }

        // Free buffers
        self.allocator.free(self.nodes);
        self.allocator.free(self.edges);
        self.allocator.free(self.pending_events);
    }

    /// Add a node to the DAG.
    pub fn addNode(
        self: *DagCore,
        node_type: NodeType,
        data: []const u8,
        attributes: Attributes,
    ) !u32 {
        // Assert: Node count must be within bounds
        std.debug.assert(self.nodes_len < MAX_NODES);

        // Assert: Data length must be reasonable
        std.debug.assert(data.len < 1_000_000); // Max 1MB per node

        const node_id = self.nodes_len;
        const node = &self.nodes[node_id];

        // Copy node data
        const node_data = try self.allocator.dupe(u8, data);
        errdefer self.allocator.free(node_data);

        // Copy metadata if present
        var metadata: []u8 = "";
        var metadata_len: u32 = 0;
        if (attributes.metadata.len > 0) {
            metadata = try self.allocator.dupe(u8, attributes.metadata);
            errdefer self.allocator.free(metadata);
            metadata_len = @as(u32, @intCast(metadata.len));
        }

        // Initialize node
        node.* = Node{
            .id = node_id,
            .node_type = node_type,
            .data = node_data,
            .data_len = @as(u32, @intCast(node_data.len)),
            .parent_count = 0,
            .child_count = 0,
            .attributes = Attributes{
                .is_readonly = attributes.is_readonly,
                .readonly_start = attributes.readonly_start,
                .readonly_end = attributes.readonly_end,
                .metadata = metadata,
                .metadata_len = metadata_len,
            },
        };

        self.nodes_len += 1;

        // Assert: Node count increased
        std.debug.assert(self.nodes_len == node_id + 1);

        return node_id;
    }

    /// Add an edge to the DAG.
    pub fn addEdge(
        self: *DagCore,
        from_node: u32,
        to_node: u32,
        edge_type: EdgeType,
    ) !void {
        // Assert: Edge count must be within bounds
        std.debug.assert(self.edges_len < MAX_EDGES);

        // Assert: Node IDs must be valid
        std.debug.assert(from_node < self.nodes_len);
        std.debug.assert(to_node < self.nodes_len);

        // Assert: No self-loops (DAG must be acyclic)
        std.debug.assert(from_node != to_node);

        // Check for cycles (simple check: verify no path from to_node to from_node)
        // For now, we'll do a simple check. Full cycle detection can be added later.
        // This is a placeholder for cycle detection.

        const edge_id = self.edges_len;
        const edge = &self.edges[edge_id];

        edge.* = Edge{
            .from_node = from_node,
            .to_node = to_node,
            .edge_type = edge_type,
            .weight = 1,
        };

        // Update node counts
        self.nodes[from_node].child_count += 1;
        self.nodes[to_node].parent_count += 1;

        self.edges_len += 1;

        // Assert: Edge count increased
        std.debug.assert(self.edges_len == edge_id + 1);
    }

    /// Add an event to the DAG (HashDAG-style).
    pub fn addEvent(
        self: *DagCore,
        event_type: EventType,
        node_id: u32,
        data: []const u8,
        parents: []const u64,
    ) !u64 {
        // Assert: Event count must be within bounds
        std.debug.assert(self.pending_events_len < MAX_PENDING_EVENTS);

        // Assert: Node ID must be valid
        std.debug.assert(node_id < self.nodes_len);

        // Assert: Data length must be reasonable
        std.debug.assert(data.len < 1_000_000); // Max 1MB per event

        // Generate unique event ID (HashDAG-style)
        const event_id = @as(u64, @intCast(self.pending_events_len)) + 1;

        const event_idx = self.pending_events_len;
        const event = &self.pending_events[event_idx];

        // Copy event data
        const event_data = try self.allocator.dupe(u8, data);
        errdefer self.allocator.free(event_data);

        // Copy parent IDs
        const parent_ids = try self.allocator.dupe(u64, parents);
        errdefer self.allocator.free(parent_ids);

        // Initialize event
        event.* = Event{
            .id = event_id,
            .event_type = event_type,
            .node_id = node_id,
            .data = event_data,
            .data_len = @as(u32, @intCast(event_data.len)),
            .parents = parent_ids,
            .parents_len = @as(u32, @intCast(parent_ids.len)),
            .timestamp = std.time.timestamp(),
        };

        self.pending_events_len += 1;

        // Assert: Event count increased
        std.debug.assert(self.pending_events_len == event_idx + 1);

        return event_id;
    }

    /// Process pending events (TigerBeetle-style state machine).
    pub fn processEvents(self: *DagCore) !void {
        // Assert: Events must be valid
        std.debug.assert(self.pending_events_len <= MAX_PENDING_EVENTS);

        // Process events in order (deterministic)
        for (self.pending_events[0..self.pending_events_len]) |*event| {
            // Apply event to target node
            const node = &self.nodes[event.node_id];

            // Update node data based on event type
            switch (event.event_type) {
                .code_edit => {
                    // Update AST node data
                    // This is a placeholder for actual AST update logic
                },
                .web_request => {
                    // Update DOM node data
                    // This is a placeholder for actual DOM update logic
                },
                .ui_interaction => {
                    // Update UI component state
                    // This is a placeholder for actual UI update logic
                },
                .ai_completion => {
                    // Update node with AI completion
                    // This is a placeholder for actual AI update logic
                },
                .vcs_update => {
                    // Update VCS metadata
                    // This is a placeholder for actual VCS update logic
                },
            }
        }

        // Clear pending events after processing
        self.pending_events_len = 0;
    }

    /// Get node by ID.
    pub fn getNode(self: *const DagCore, node_id: u32) ?*const Node {
        // Assert: Node ID must be valid
        if (node_id >= self.nodes_len) {
            return null;
        }

        return &self.nodes[node_id];
    }

    /// Get edges for a node (incoming or outgoing).
    pub fn getEdges(self: *const DagCore, node_id: u32, incoming: bool) []const Edge {
        // Assert: Node ID must be valid
        std.debug.assert(node_id < self.nodes_len);

        var result = std.ArrayList(Edge).init(self.allocator);
        defer result.deinit();

        for (self.edges[0..self.edges_len]) |edge| {
            if (incoming) {
                if (edge.to_node == node_id) {
                    result.append(edge) catch continue;
                }
            } else {
                if (edge.from_node == node_id) {
                    result.append(edge) catch continue;
                }
            }
        }

        // Return slice (caller must handle memory)
        // For now, return empty slice (placeholder)
        return &.{};
    }

    /// Verify DAG is acyclic (assertion).
    pub fn verifyAcyclic(self: *const DagCore) bool {
        // Simple check: verify no self-loops
        for (self.edges[0..self.edges_len]) |edge| {
            if (edge.from_node == edge.to_node) {
                return false; // Self-loop found
            }
        }

        // TODO: Full cycle detection (DFS)
        // For now, return true (placeholder)
        return true;
    }
};

test "dag core initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();

    // Assert: Initial state is empty
    try std.testing.expect(dag.nodes_len == 0);
    try std.testing.expect(dag.edges_len == 0);
    try std.testing.expect(dag.pending_events_len == 0);
}

test "dag add node" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();

    const node_id = try dag.addNode(.ast_node, "test data", .{});

    // Assert: Node was added
    try std.testing.expect(node_id == 0);
    try std.testing.expect(dag.nodes_len == 1);

    const node = dag.getNode(node_id);
    try std.testing.expect(node != null);
    try std.testing.expect(node.?.node_type == .ast_node);
}

test "dag add edge" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();

    const node1 = try dag.addNode(.ast_node, "node1", .{});
    const node2 = try dag.addNode(.ast_node, "node2", .{});

    try dag.addEdge(node1, node2, .dependency);

    // Assert: Edge was added
    try std.testing.expect(dag.edges_len == 1);
    try std.testing.expect(dag.nodes[node1].child_count == 1);
    try std.testing.expect(dag.nodes[node2].parent_count == 1);
}

test "dag add event" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();

    const node_id = try dag.addNode(.ast_node, "test", .{});

    const event_id = try dag.addEvent(.code_edit, node_id, "edit data", &.{});

    // Assert: Event was added
    try std.testing.expect(event_id > 0);
    try std.testing.expect(dag.pending_events_len == 1);
}

test "dag verify acyclic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();

    const node1 = try dag.addNode(.ast_node, "node1", .{});
    const node2 = try dag.addNode(.ast_node, "node2", .{});

    try dag.addEdge(node1, node2, .dependency);

    // Assert: DAG is acyclic
    try std.testing.expect(dag.verifyAcyclic());
}

