//! Grain Database Graph: Graph data structure and traversal algorithms.
//!
//! Why: Enable graph queries and reverse lookups for relationships.
//! Architecture: Bounded nodes/edges, iterative traversal algorithms.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-03-165223-pst: Grain Database Agent

const std = @import("std");
const BTreeIndex = @import("index.zig").BTreeIndex;

// Bounded: Max nodes in graph.
pub const MAX_NODES: u32 = 10_000_000;

// Bounded: Max edges in graph.
pub const MAX_EDGES: u32 = 100_000_000;

// Bounded: Max edges per node.
pub const MAX_EDGES_PER_NODE: u32 = 1_000;

// Bounded: Max traversal depth.
pub const MAX_TRAVERSAL_DEPTH: u32 = 1_000;

// Graph node: Represents an entity (user, candidate, policy, etc.).
pub const GraphNode = struct {
    node_id: u64,
    node_type: []const u8,
    node_type_len: u32,
    properties: []const u8,
    properties_len: u32,
    created_at: u64,
    allocator: std.mem.Allocator,

    // Initialize graph node.
    pub fn init(
        allocator: std.mem.Allocator,
        node_id: u64,
        node_type: []const u8,
        properties: []const u8,
    ) !GraphNode {
        std.debug.assert(node_id > 0);
        std.debug.assert(node_type.len <= 256);
        _ = allocator;

        const type_copy = try allocator.dupe(u8, node_type);
        errdefer allocator.free(type_copy);

        const props_copy = try allocator.dupe(u8, properties);
        errdefer allocator.free(props_copy);

        const now = std.time.timestamp();

        return GraphNode{
            .node_id = node_id,
            .node_type = type_copy,
            .node_type_len = @as(u32, @intCast(type_copy.len)),
            .properties = props_copy,
            .properties_len = @as(u32, @intCast(props_copy.len)),
            .created_at = @as(u64, @intCast(now)),
            .allocator = allocator,
        };
    }

    // Deinitialize graph node and free memory.
    pub fn deinit(self: *GraphNode) void {
        _ = self.allocator;
        if (self.node_type_len > 0) {
            self.allocator.free(self.node_type);
        }
        if (self.properties_len > 0) {
            self.allocator.free(self.properties);
        }
        self.* = undefined;
    }
};

// Graph edge: Represents a relationship between nodes.
pub const GraphEdge = struct {
    edge_id: u64,
    from_node_id: u64,
    to_node_id: u64,
    relationship_type: []const u8,
    relationship_type_len: u32,
    properties: []const u8,
    properties_len: u32,
    created_at: u64,
    allocator: std.mem.Allocator,

    // Initialize graph edge.
    pub fn init(
        allocator: std.mem.Allocator,
        edge_id: u64,
        from_node_id: u64,
        to_node_id: u64,
        relationship_type: []const u8,
        properties: []const u8,
    ) !GraphEdge {
        std.debug.assert(edge_id > 0);
        std.debug.assert(from_node_id > 0);
        std.debug.assert(to_node_id > 0);
        std.debug.assert(relationship_type.len <= 256);
        _ = allocator;

        const rel_copy = try allocator.dupe(u8, relationship_type);
        errdefer allocator.free(rel_copy);

        const props_copy = try allocator.dupe(u8, properties);
        errdefer allocator.free(props_copy);

        const now = std.time.timestamp();

        return GraphEdge{
            .edge_id = edge_id,
            .from_node_id = from_node_id,
            .to_node_id = to_node_id,
            .relationship_type = rel_copy,
            .relationship_type_len = @as(u32, @intCast(rel_copy.len)),
            .properties = props_copy,
            .properties_len = @as(u32, @intCast(props_copy.len)),
            .created_at = @as(u64, @intCast(now)),
            .allocator = allocator,
        };
    }

    // Deinitialize graph edge and free memory.
    pub fn deinit(self: *GraphEdge) void {
        _ = self.allocator;
        if (self.relationship_type_len > 0) {
            self.allocator.free(self.relationship_type);
        }
        if (self.properties_len > 0) {
            self.allocator.free(self.properties);
        }
        self.* = undefined;
    }
};

// Graph: Collection of nodes and edges with traversal support.
pub const Graph = struct {
    nodes: []GraphNode,
    nodes_len: u32,
    edges: []GraphEdge,
    edges_len: u32,
    next_node_id: u64,
    next_edge_id: u64,
    forward_index: BTreeIndex,
    reverse_index: BTreeIndex,
    allocator: std.mem.Allocator,

    // Initialize graph.
    pub fn init(allocator: std.mem.Allocator) !Graph {
        _ = allocator;
        const nodes = try allocator.alloc(GraphNode, MAX_NODES);
        errdefer allocator.free(nodes);

        const edges = try allocator.alloc(GraphEdge, MAX_EDGES);
        errdefer allocator.free(edges);

        const forward_idx = try BTreeIndex.init(allocator);
        errdefer forward_idx.deinit();

        const reverse_idx = try BTreeIndex.init(allocator);
        errdefer reverse_idx.deinit();

        return Graph{
            .nodes = nodes,
            .nodes_len = 0,
            .edges = edges,
            .edges_len = 0,
            .next_node_id = 1,
            .next_edge_id = 1,
            .forward_index = forward_idx,
            .reverse_index = reverse_idx,
            .allocator = allocator,
        };
    }

    // Deinitialize graph and free memory.
    pub fn deinit(self: *Graph) void {
        _ = self.allocator;
        var i: u32 = 0;
        while (i < self.nodes_len) : (i += 1) {
            self.nodes[i].deinit();
        }
        i = 0;
        while (i < self.edges_len) : (i += 1) {
            self.edges[i].deinit();
        }
        self.allocator.free(self.nodes);
        self.allocator.free(self.edges);
        self.forward_index.deinit();
        self.reverse_index.deinit();
        self.* = undefined;
    }

    // Add node to graph.
    pub fn add_node(
        self: *Graph,
        node_type: []const u8,
        properties: []const u8,
    ) !u64 {
        std.debug.assert(self.nodes_len < MAX_NODES);

        if (self.nodes_len >= MAX_NODES) {
            return error.GraphFull;
        }

        const node_id = self.next_node_id;
        self.next_node_id += 1;

        var node = try GraphNode.init(
            self.allocator,
            node_id,
            node_type,
            properties,
        );
        errdefer node.deinit();

        self.nodes[self.nodes_len] = node;
        self.nodes_len += 1;

        std.debug.assert(self.nodes_len <= MAX_NODES);
        return node_id;
    }

    // Add edge to graph.
    pub fn add_edge(
        self: *Graph,
        from_node_id: u64,
        to_node_id: u64,
        relationship_type: []const u8,
        properties: []const u8,
    ) !u64 {
        std.debug.assert(self.edges_len < MAX_EDGES);
        std.debug.assert(from_node_id > 0);
        std.debug.assert(to_node_id > 0);

        if (self.edges_len >= MAX_EDGES) {
            return error.GraphFull;
        }

        const edge_id = self.next_edge_id;
        self.next_edge_id += 1;

        var edge = try GraphEdge.init(
            self.allocator,
            edge_id,
            from_node_id,
            to_node_id,
            relationship_type,
            properties,
        );
        errdefer edge.deinit();

        self.edges[self.edges_len] = edge;
        self.edges_len += 1;

        // Update forward index: from_node_id -> edge_id
        _ = try self.forward_index.insert(from_node_id, edge_id);

        // Update reverse index: to_node_id -> edge_id
        _ = try self.reverse_index.insert(to_node_id, edge_id);

        std.debug.assert(self.edges_len <= MAX_EDGES);
        return edge_id;
    }

    // Get node by ID.
    pub fn get_node(self: *Graph, node_id: u64) ?*GraphNode {
        std.debug.assert(node_id > 0);
        var i: u32 = 0;
        while (i < self.nodes_len) : (i += 1) {
            if (self.nodes[i].node_id == node_id) {
                return &self.nodes[i];
            }
        }
        return null;
    }

    // Get edges from node (forward traversal).
    pub fn get_edges_from(
        self: *Graph,
        node_id: u64,
        output: []u64,
    ) !u32 {
        std.debug.assert(node_id > 0);
        std.debug.assert(output.len >= MAX_EDGES_PER_NODE);
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.edges_len) : (i += 1) {
            if (self.edges[i].from_node_id == node_id) {
                if (count >= output.len) {
                    return error.TooManyEdges;
                }
                output[count] = self.edges[i].edge_id;
                count += 1;
            }
        }
        return count;
    }

    // Get edges to node (reverse traversal).
    pub fn get_edges_to(
        self: *Graph,
        node_id: u64,
        output: []u64,
    ) !u32 {
        std.debug.assert(node_id > 0);
        std.debug.assert(output.len >= MAX_EDGES_PER_NODE);
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.edges_len) : (i += 1) {
            if (self.edges[i].to_node_id == node_id) {
                if (count >= output.len) {
                    return error.TooManyEdges;
                }
                output[count] = self.edges[i].edge_id;
                count += 1;
            }
        }
        return count;
    }

    // Breadth-first search (iterative, queue-based).
    pub fn traverse_bfs(
        self: *Graph,
        start_node_id: u64,
        visitor: *const fn (node_id: u64) void,
        visited: []bool,
    ) !void {
        std.debug.assert(start_node_id > 0);
        std.debug.assert(visited.len >= MAX_NODES);

        var queue: [MAX_NODES]u64 = undefined;
        var queue_front: u32 = 0;
        var queue_back: u32 = 0;
        var depth: u32 = 0;

        @memset(visited, false);
        queue[queue_back] = start_node_id;
        queue_back += 1;
        visited[@as(usize, @intCast(start_node_id % MAX_NODES))] = true;

        while (queue_front < queue_back) {
            if (depth >= MAX_TRAVERSAL_DEPTH) {
                return error.MaxDepthExceeded;
            }

            const current_id = queue[queue_front];
            queue_front += 1;
            visitor(current_id);

            var edges: [MAX_EDGES_PER_NODE]u64 = undefined;
            const edge_count = try self.get_edges_from(current_id, &edges);
            var i: u32 = 0;
            while (i < edge_count) : (i += 1) {
                const edge = self.find_edge(edges[i]);
                if (edge) |e| {
                    const next_id = e.to_node_id;
                    const visited_idx = @as(usize, @intCast(next_id % MAX_NODES));
                    if (!visited[visited_idx]) {
                        visited[visited_idx] = true;
                        if (queue_back >= MAX_NODES) {
                            return error.QueueFull;
                        }
                        queue[queue_back] = next_id;
                        queue_back += 1;
                    }
                }
            }
            depth += 1;
        }
    }

    // Depth-first search (iterative, stack-based).
    pub fn traverse_dfs(
        self: *Graph,
        start_node_id: u64,
        visitor: *const fn (node_id: u64) void,
        visited: []bool,
    ) !void {
        std.debug.assert(start_node_id > 0);
        std.debug.assert(visited.len >= MAX_NODES);

        var stack: [MAX_NODES]u64 = undefined;
        var stack_len: u32 = 0;
        var depth: u32 = 0;

        @memset(visited, false);
        stack[stack_len] = start_node_id;
        stack_len += 1;

        while (stack_len > 0) {
            if (depth >= MAX_TRAVERSAL_DEPTH) {
                return error.MaxDepthExceeded;
            }

            stack_len -= 1;
            const current_id = stack[stack_len];
            const visited_idx = @as(usize, @intCast(current_id % MAX_NODES));

            if (visited[visited_idx]) {
                continue;
            }
            visited[visited_idx] = true;
            visitor(current_id);

            var edges: [MAX_EDGES_PER_NODE]u64 = undefined;
            const edge_count = try self.get_edges_from(current_id, &edges);
            var i: u32 = 0;
            while (i < edge_count) : (i += 1) {
                const edge = self.find_edge(edges[i]);
                if (edge) |e| {
                    const next_id = e.to_node_id;
                    const next_visited_idx = @as(usize, @intCast(next_id % MAX_NODES));
                    if (!visited[next_visited_idx]) {
                        if (stack_len >= MAX_NODES) {
                            return error.StackFull;
                        }
                        stack[stack_len] = next_id;
                        stack_len += 1;
                    }
                }
            }
            depth += 1;
        }
    }

    // Reverse lookup: Find all nodes that have edges to target node.
    pub fn reverse_lookup(
        self: *Graph,
        target_node_id: u64,
        output: []u64,
    ) !u32 {
        std.debug.assert(target_node_id > 0);
        std.debug.assert(output.len >= MAX_NODES);
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.edges_len) : (i += 1) {
            if (self.edges[i].to_node_id == target_node_id) {
                if (count >= output.len) {
                    return error.TooManyNodes;
                }
                output[count] = self.edges[i].from_node_id;
                count += 1;
            }
        }
        return count;
    }

    // Find edge by ID (internal helper).
    fn find_edge(self: *Graph, edge_id: u64) ?*GraphEdge {
        std.debug.assert(edge_id > 0);
        var i: u32 = 0;
        while (i < self.edges_len) : (i += 1) {
            if (self.edges[i].edge_id == edge_id) {
                return &self.edges[i];
            }
        }
        return null;
    }
};

