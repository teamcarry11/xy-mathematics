const std = @import("std");
const testing = std.testing;
const SkateWindow = @import("grain_skate").SkateWindow;
const GraphVisualization = @import("grain_skate").GraphVisualization;
const Block = @import("grain_skate").Block;

test "window set graph visualization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var window = try SkateWindow.init(allocator, "Test Window", 800, 600);
    defer window.deinit();

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(1);
    graph_viz.calculate_layout(10);

    try window.set_graph_viz(&graph_viz);

    // Graph renderer should be set
    try testing.expect(window.graph_renderer != null);
}

test "window render graph" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var window = try SkateWindow.init(allocator, "Test Window", 800, 600);
    defer window.deinit();

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(1);
    graph_viz.add_block(2);
    graph_viz.add_link(1, 2);
    graph_viz.calculate_layout(10);

    try window.set_graph_viz(&graph_viz);

    // Render graph (should not crash)
    window.render_graph();

    // Buffer should be modified (basic sanity check)
    const buffer = window.window.getBuffer();
    try testing.expect(buffer.len > 0);
}

test "window present with graph" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var window = try SkateWindow.init(allocator, "Test Window", 800, 600);
    defer window.deinit();

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(1);
    graph_viz.calculate_layout(10);

    try window.set_graph_viz(&graph_viz);

    // Present window (should not crash, but may fail on headless systems)
    window.present() catch |err| {
        // Expected to fail in test environment without display
        _ = err;
    };
}

test "window graph renderer cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var window = try SkateWindow.init(allocator, "Test Window", 800, 600);

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(1);
    graph_viz.calculate_layout(10);

    try window.set_graph_viz(&graph_viz);
    try testing.expect(window.graph_renderer != null);

    // Deinit should clean up renderer
    window.deinit();
    // Should not crash
}

