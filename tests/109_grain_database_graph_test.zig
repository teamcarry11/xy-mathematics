//! Tests for Grain Database Graph Layer.
//!
//! Why: Verify graph operations, traversal algorithms, and reverse lookups.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-165223-pst: Grain Database Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const Graph = grain_database.Graph;

test "graph initialization" {
    const allocator = testing.allocator;
    var graph = try Graph.init(allocator);
    defer graph.deinit();

    try testing.expect(graph.nodes_len == 0);
    try testing.expect(graph.edges_len == 0);
    try testing.expect(graph.next_node_id == 1);
    try testing.expect(graph.next_edge_id == 1);
}

test "add node to graph" {
    const allocator = testing.allocator;
    var graph = try Graph.init(allocator);
    defer graph.deinit();

    const node_id = try graph.add_node("user", "{\"name\":\"test\"}");
    try testing.expect(node_id == 1);
    try testing.expect(graph.nodes_len == 1);
    try testing.expect(graph.next_node_id == 2);
}

test "add edge to graph" {
    const allocator = testing.allocator;
    var graph = try Graph.init(allocator);
    defer graph.deinit();

    const node1_id = try graph.add_node("user", "{\"name\":\"user1\"}");
    const node2_id = try graph.add_node("user", "{\"name\":\"user2\"}");
    const edge_id = try graph.add_edge(
        node1_id,
        node2_id,
        "follows",
        "{}",
    );
    try testing.expect(edge_id == 1);
    try testing.expect(graph.edges_len == 1);
}

test "get node by id" {
    const allocator = testing.allocator;
    var graph = try Graph.init(allocator);
    defer graph.deinit();

    const node_id = try graph.add_node("user", "{\"name\":\"test\"}");
    const node = graph.get_node(node_id);
    try testing.expect(node != null);
    try testing.expect(node.?.node_id == node_id);
    try testing.expect(std.mem.eql(u8, node.?.node_type, "user"));
}

test "get edges from node" {
    const allocator = testing.allocator;
    var graph = try Graph.init(allocator);
    defer graph.deinit();

    const node1_id = try graph.add_node("user", "{}");
    const node2_id = try graph.add_node("user", "{}");
    const node3_id = try graph.add_node("user", "{}");
    _ = try graph.add_edge(node1_id, node2_id, "follows", "{}");
    _ = try graph.add_edge(node1_id, node3_id, "follows", "{}");

    var edges: [1000]u64 = undefined;
    const count = try graph.get_edges_from(node1_id, &edges);
    try testing.expect(count == 2);
}

test "get edges to node" {
    const allocator = testing.allocator;
    var graph = try Graph.init(allocator);
    defer graph.deinit();

    const node1_id = try graph.add_node("user", "{}");
    const node2_id = try graph.add_node("user", "{}");
    const node3_id = try graph.add_node("user", "{}");
    _ = try graph.add_edge(node1_id, node2_id, "follows", "{}");
    _ = try graph.add_edge(node3_id, node2_id, "follows", "{}");

    var edges: [1000]u64 = undefined;
    const count = try graph.get_edges_to(node2_id, &edges);
    try testing.expect(count == 2);
}

test "reverse lookup" {
    const allocator = testing.allocator;
    var graph = try Graph.init(allocator);
    defer graph.deinit();

    const node1_id = try graph.add_node("user", "{}");
    const node2_id = try graph.add_node("user", "{}");
    const node3_id = try graph.add_node("user", "{}");
    _ = try graph.add_edge(node1_id, node2_id, "follows", "{}");
    _ = try graph.add_edge(node3_id, node2_id, "follows", "{}");

    var nodes: [1000]u64 = undefined;
    const count = try graph.reverse_lookup(node2_id, &nodes);
    try testing.expect(count == 2);
}

test "breadth-first search traversal" {
    const allocator = testing.allocator;
    var graph = try Graph.init(allocator);
    defer graph.deinit();

    const node1_id = try graph.add_node("user", "{}");
    const node2_id = try graph.add_node("user", "{}");
    const node3_id = try graph.add_node("user", "{}");
    _ = try graph.add_edge(node1_id, node2_id, "follows", "{}");
    _ = try graph.add_edge(node2_id, node3_id, "follows", "{}");

    var visited: [10000]bool = undefined;
    var visit_count: u32 = 0;

    const Visitor = struct {
        count: *u32,
        fn visit(node_id: u64) void {
            _ = node_id;
            count.* += 1;
        }
    };

    var visitor_state = Visitor{ .count = &visit_count };
    const visitor_fn = struct {
        fn call(node_id: u64) void {
            visitor_state.visit(node_id);
        }
    }.call;

    try graph.traverse_bfs(node1_id, visitor_fn, &visited);
    try testing.expect(visit_count >= 1);
}

test "depth-first search traversal" {
    const allocator = testing.allocator;
    var graph = try Graph.init(allocator);
    defer graph.deinit();

    const node1_id = try graph.add_node("user", "{}");
    const node2_id = try graph.add_node("user", "{}");
    const node3_id = try graph.add_node("user", "{}");
    _ = try graph.add_edge(node1_id, node2_id, "follows", "{}");
    _ = try graph.add_edge(node2_id, node3_id, "follows", "{}");

    var visited: [10000]bool = undefined;
    var visit_count: u32 = 0;

    const Visitor = struct {
        count: *u32,
        fn visit(node_id: u64) void {
            _ = node_id;
            count.* += 1;
        }
    };

    var visitor_state = Visitor{ .count = &visit_count };
    const visitor_fn = struct {
        fn call(node_id: u64) void {
            visitor_state.visit(node_id);
        }
    }.call;

    try graph.traverse_dfs(node1_id, visitor_fn, &visited);
    try testing.expect(visit_count >= 1);
}

test "multiple nodes and edges" {
    const allocator = testing.allocator;
    var graph = try Graph.init(allocator);
    defer graph.deinit();

    const node1_id = try graph.add_node("user", "{}");
    const node2_id = try graph.add_node("user", "{}");
    const node3_id = try graph.add_node("user", "{}");
    const node4_id = try graph.add_node("user", "{}");

    _ = try graph.add_edge(node1_id, node2_id, "follows", "{}");
    _ = try graph.add_edge(node1_id, node3_id, "follows", "{}");
    _ = try graph.add_edge(node2_id, node4_id, "follows", "{}");
    _ = try graph.add_edge(node3_id, node4_id, "follows", "{}");

    try testing.expect(graph.nodes_len == 4);
    try testing.expect(graph.edges_len == 4);
}

test "graph with different relationship types" {
    const allocator = testing.allocator;
    var graph = try Graph.init(allocator);
    defer graph.deinit();

    const user_id = try graph.add_node("user", "{}");
    const policy_id = try graph.add_node("policy", "{}");
    const candidate_id = try graph.add_node("candidate", "{}");

    _ = try graph.add_edge(user_id, candidate_id, "follows", "{}");
    _ = try graph.add_edge(candidate_id, policy_id, "supports", "{}");

    try testing.expect(graph.edges_len == 2);
}

