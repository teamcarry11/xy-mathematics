const std = @import("std");
const testing = std.testing;
const grain_skate = @import("grain_skate");
const GraphVisualization = grain_skate.GraphVisualization;

test "graph visualization init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var viz = GraphVisualization.init(allocator);
    try testing.expect(viz.nodes_len == 0);
    try testing.expect(viz.edges_len == 0);
    try testing.expect(viz.center_x == 0.5);
    try testing.expect(viz.center_y == 0.5);
    try testing.expect(viz.zoom == 1.0);
    try testing.expect(viz.selected_block_id == null);
}

test "graph visualization add block" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var viz = GraphVisualization.init(allocator);
    viz.add_block(1);
    try testing.expect(viz.nodes_len == 1);
    try testing.expect(viz.nodes[0].block_id == 1);
    try testing.expect(viz.nodes[0].visible == true);
    try testing.expect(viz.nodes[0].selected == false);
}

test "graph visualization add link" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var viz = GraphVisualization.init(allocator);
    viz.add_block(1);
    viz.add_block(2);
    viz.add_link(1, 2);
    try testing.expect(viz.edges_len == 1);
    try testing.expect(viz.edges[0].from_block_id == 1);
    try testing.expect(viz.edges[0].to_block_id == 2);
    try testing.expect(viz.edges[0].visible == true);
}

test "graph visualization select block" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var viz = GraphVisualization.init(allocator);
    viz.add_block(1);
    viz.add_block(2);
    viz.select_block(1);
    try testing.expect(viz.selected_block_id.? == 1);
    try testing.expect(viz.nodes[0].selected == true);
    try testing.expect(viz.nodes[1].selected == false);
}

test "graph visualization pan" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var viz = GraphVisualization.init(allocator);
    viz.pan(0.1, 0.2);
    try testing.expect(viz.center_x == 0.6);
    try testing.expect(viz.center_y == 0.7);
    viz.pan(-1.0, -1.0); // Should clamp
    try testing.expect(viz.center_x == 0.0);
    try testing.expect(viz.center_y == 0.0);
}

test "graph visualization zoom" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var viz = GraphVisualization.init(allocator);
    viz.zoom_view(0.5);
    try testing.expect(viz.zoom == 1.5);
    viz.zoom_view(-2.0); // Should clamp to 0.1
    try testing.expect(viz.zoom == 0.1);
    viz.zoom_view(20.0); // Should clamp to 10.0
    try testing.expect(viz.zoom == 10.0);
}

test "graph visualization layout calculation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var viz = GraphVisualization.init(allocator);
    viz.add_block(1);
    viz.add_block(2);
    viz.add_block(3);
    viz.add_link(1, 2);
    viz.add_link(2, 3);
    viz.calculate_layout(10);
    // After layout, positions should be within bounds
    var i: u32 = 0;
    while (i < viz.nodes_len) : (i += 1) {
        try testing.expect(viz.nodes[i].position.x >= 0.0);
        try testing.expect(viz.nodes[i].position.x <= 1.0);
        try testing.expect(viz.nodes[i].position.y >= 0.0);
        try testing.expect(viz.nodes[i].position.y <= 1.0);
    }
}

test "graph visualization multiple blocks and links" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var viz = GraphVisualization.init(allocator);
    // Add 5 blocks
    viz.add_block(1);
    viz.add_block(2);
    viz.add_block(3);
    viz.add_block(4);
    viz.add_block(5);
    // Create a chain: 1 -> 2 -> 3 -> 4 -> 5
    viz.add_link(1, 2);
    viz.add_link(2, 3);
    viz.add_link(3, 4);
    viz.add_link(4, 5);
    // Calculate layout
    viz.calculate_layout(20);
    // Verify all nodes are within bounds
    var i: u32 = 0;
    while (i < viz.nodes_len) : (i += 1) {
        try testing.expect(viz.nodes[i].position.x >= 0.0);
        try testing.expect(viz.nodes[i].position.x <= 1.0);
        try testing.expect(viz.nodes[i].position.y >= 0.0);
        try testing.expect(viz.nodes[i].position.y <= 1.0);
    }
    // Verify all edges are valid
    var e: u32 = 0;
    while (e < viz.edges_len) : (e += 1) {
        try testing.expect(viz.edges[e].from_block_id > 0);
        try testing.expect(viz.edges[e].to_block_id > 0);
    }
}

test "graph visualization find node at pixel" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var viz = GraphVisualization.init(allocator);
    viz.add_block(1);
    viz.add_block(2);
    viz.calculate_layout(10);

    // Test hit testing at center of buffer (may or may not find node)
    const buffer_width: u32 = 800;
    const buffer_height: u32 = 600;
    const clicked_block_id = viz.find_node_at_pixel(400, 300, buffer_width, buffer_height);
    // May or may not find node depending on layout, but should not crash
    _ = clicked_block_id;

    // Test hit testing at edge (should not find node)
    const edge_click = viz.find_node_at_pixel(0, 0, buffer_width, buffer_height);
    // Should return null for edge clicks
    _ = edge_click;
}

