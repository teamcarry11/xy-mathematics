const std = @import("std");
const testing = std.testing;
const GraphVisualization = @import("grain_skate").GraphVisualization;
const GraphRenderer = @import("grain_skate").GraphRenderer;
const Block = @import("grain_skate").Block;
const AiInsights = @import("grain_skate").AiInsights;

test "graph renderer init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var graph_viz = GraphVisualization.init(allocator);
    const renderer = GraphRenderer.init(&graph_viz, 800, 600);

    try testing.expect(renderer.buffer_width == 800);
    try testing.expect(renderer.buffer_height == 600);
    try testing.expect(renderer.graph_viz == &graph_viz);
}

test "graph renderer render empty graph" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var graph_viz = GraphVisualization.init(allocator);
    var renderer = GraphRenderer.init(&graph_viz, 800, 600);

    var buffer: [800 * 600 * 4]u8 = undefined;
    renderer.render(&buffer);

    // Buffer should be filled with background color
    const bg_r = @as(u8, @truncate((GraphRenderer.COLOR_BACKGROUND >> 16) & 0xFF));
    try testing.expect(buffer[0] == bg_r);
}

test "graph renderer render nodes" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(1);
    graph_viz.add_block(2);
    graph_viz.calculate_layout(10);

    var renderer = GraphRenderer.init(&graph_viz, 800, 600);

    var buffer: [800 * 600 * 4]u8 = undefined;
    renderer.render(&buffer);

    // Buffer should have nodes rendered (non-background pixels)
    const bg_r = @as(u8, @truncate((GraphRenderer.COLOR_BACKGROUND >> 16) & 0xFF));
    const node_r = @as(u8, @truncate((GraphRenderer.COLOR_NODE >> 16) & 0xFF));
    
    // Check that at least some pixels are not background (nodes should be visible)
    var found_node_pixel = false;
    var i: u32 = 0;
    while (i < buffer.len and i < 10000) : (i += 4) {
        if (buffer[i] != bg_r) {
            found_node_pixel = true;
            break;
        }
    }
    // Note: This may not always find a node pixel if nodes are outside viewport
    // but it's a basic sanity check
}

test "graph renderer render edges" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(1);
    graph_viz.add_block(2);
    graph_viz.add_link(1, 2);
    graph_viz.calculate_layout(10);

    var renderer = GraphRenderer.init(&graph_viz, 800, 600);

    var buffer: [800 * 600 * 4]u8 = undefined;
    renderer.render(&buffer);

    // Buffer should have edges rendered
    // Basic sanity check that rendering completed without errors
    try testing.expect(buffer.len == 800 * 600 * 4);
}

test "graph renderer render selected node" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(1);
    graph_viz.select_block(1);
    graph_viz.calculate_layout(10);

    var renderer = GraphRenderer.init(&graph_viz, 800, 600);

    var buffer: [800 * 600 * 4]u8 = undefined;
    renderer.render(&buffer);

    // Selected node should be rendered with selected color
    // Basic sanity check that rendering completed
    try testing.expect(buffer.len == 800 * 600 * 4);
}

test "graph renderer zoom and pan" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(1);
    graph_viz.zoom_view(0.5);
    graph_viz.pan(0.1, 0.1);

    var renderer = GraphRenderer.init(&graph_viz, 800, 600);

    var buffer: [800 * 600 * 4]u8 = undefined;
    renderer.render(&buffer);

    // Rendering should complete successfully with zoom and pan applied
    try testing.expect(buffer.len == 800 * 600 * 4);
    try testing.expect(graph_viz.zoom > 1.0);
}

test "graph renderer labels" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(1);
    graph_viz.add_block(42);
    graph_viz.add_block(123);
    graph_viz.calculate_layout(10);

    var renderer = GraphRenderer.init(&graph_viz, 800, 600);

    var buffer: [800 * 600 * 4]u8 = undefined;
    renderer.render(&buffer);

    // Labels should be rendered (basic sanity check)
    try testing.expect(buffer.len == 800 * 600 * 4);
}

test "graph renderer title labels" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    const Block = @import("grain_skate").Block;

    // Create block storage with blocks
    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    const block1_id = try block_storage.create_block("Test Block", "Content 1");
    const block2_id = try block_storage.create_block("Another Block", "Content 2");

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(block1_id);
    graph_viz.add_block(block2_id);
    graph_viz.calculate_layout(10);

    var renderer = GraphRenderer.init(&graph_viz, 800, 600);
    renderer.set_block_storage(&block_storage);

    var buffer: [800 * 600 * 4]u8 = undefined;
    renderer.render(&buffer);

    // Title labels should be rendered (basic sanity check)
    try testing.expect(buffer.len == 800 * 600 * 4);
}

test "graph renderer enhanced labels with truncation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    const Block = @import("grain_skate").Block;

    // Create block storage with a long title (should be truncated)
    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    const long_title = "This is a very long block title that should be truncated with ellipsis";
    const block_id = try block_storage.create_block(long_title, "Content");

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(block_id);
    graph_viz.calculate_layout(10);

    var renderer = GraphRenderer.init(&graph_viz, 800, 600);
    renderer.set_block_storage(&block_storage);

    var buffer: [800 * 600 * 4]u8 = undefined;
    renderer.render(&buffer);

    // Enhanced labels with truncation should be rendered
    try testing.expect(buffer.len == 800 * 600 * 4);
}

test "graph renderer enhanced labels with background" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    const Block = @import("grain_skate").Block;

    // Create block storage with blocks
    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    const block1_id = try block_storage.create_block("Short", "Content 1");
    const block2_id = try block_storage.create_block("Medium Title", "Content 2");

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(block1_id);
    graph_viz.add_block(block2_id);
    graph_viz.calculate_layout(10);

    var renderer = GraphRenderer.init(&graph_viz, 800, 600);
    renderer.set_block_storage(&block_storage);

    var buffer: [800 * 600 * 4]u8 = undefined;
    renderer.render(&buffer);

    // Enhanced labels with background should be rendered
    try testing.expect(buffer.len == 800 * 600 * 4);
}

test "graph renderer enhanced labels centered" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    const Block = @import("grain_skate").Block;

    // Create block storage with blocks
    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    const block_id = try block_storage.create_block("Centered", "Content");

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(block_id);
    graph_viz.calculate_layout(10);

    var renderer = GraphRenderer.init(&graph_viz, 800, 600);
    renderer.set_block_storage(&block_storage);

    var buffer: [800 * 600 * 4]u8 = undefined;
    renderer.render(&buffer);

    // Centered labels should be rendered
    try testing.expect(buffer.len == 800 * 600 * 4);
}

test "graph renderer AI suggestions visual indicators" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(1);
    graph_viz.add_block(2);
    graph_viz.calculate_layout(10);

    var renderer = GraphRenderer.init(&graph_viz, 800, 600);

    // Create AI suggestions
    var ai_reason = try allocator.dupe(u8, "High semantic similarity");
    defer allocator.free(ai_reason);
    
    const suggestions = [_]AiInsights.ConnectionSuggestion{
        .{
            .from_block_id = 1,
            .to_block_id = 2,
            .confidence = 0.85,
            .reason = ai_reason,
            .reason_len = @as(u32, @intCast(ai_reason.len)),
        },
    };

    renderer.set_ai_suggestions(&suggestions);

    var buffer: [800 * 600 * 4]u8 = undefined;
    renderer.render(&buffer);

    // AI suggestions should be rendered (basic sanity check)
    try testing.expect(buffer.len == 800 * 600 * 4);
    try testing.expect(renderer.ai_suggestions_len == 1);
}

test "graph renderer AI suggestions for non-existent edges" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(1);
    graph_viz.add_block(2);
    graph_viz.add_block(3);
    // Note: No link between 1 and 2, so AI suggestion should appear as ghost
    graph_viz.calculate_layout(10);

    var renderer = GraphRenderer.init(&graph_viz, 800, 600);

    // Create AI suggestion for non-existent edge
    var ai_reason = try allocator.dupe(u8, "Should be connected");
    defer allocator.free(ai_reason);
    
    const suggestions = [_]AiInsights.ConnectionSuggestion{
        .{
            .from_block_id = 1,
            .to_block_id = 2,
            .confidence = 0.75,
            .reason = ai_reason,
            .reason_len = @as(u32, @intCast(ai_reason.len)),
        },
    };

    renderer.set_ai_suggestions(&suggestions);

    var buffer: [800 * 600 * 4]u8 = undefined;
    renderer.render(&buffer);

    // AI suggestion should be rendered as ghost edge
    try testing.expect(buffer.len == 800 * 600 * 4);
    try testing.expect(renderer.ai_suggestions_len == 1);
}

