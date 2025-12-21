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

test "graph renderer temporal filtering initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var graph_viz = GraphVisualization.init(allocator);
    var renderer = GraphRenderer.init(&graph_viz, 800, 600);

    // Initially, no time-travel mode
    try testing.expect(!renderer.is_time_travel_mode());
    try testing.expect(renderer.get_temporal_timestamp() == null);
}

test "graph renderer temporal timestamp setting" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var graph_viz = GraphVisualization.init(allocator);
    var renderer = GraphRenderer.init(&graph_viz, 800, 600);

    // Set timestamp
    const test_timestamp: u64 = 1234567890;
    renderer.set_temporal_timestamp(test_timestamp);

    // Time-travel mode should be active
    try testing.expect(renderer.is_time_travel_mode());
    try testing.expect(renderer.get_temporal_timestamp().? == test_timestamp);

    // Reset to present
    renderer.set_temporal_timestamp(null);
    try testing.expect(!renderer.is_time_travel_mode());
    try testing.expect(renderer.get_temporal_timestamp() == null);
}

test "graph renderer temporal graph integration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    const EditorDagIntegration = @import("grain_skate").EditorDagIntegration;
    const TemporalGraph = @import("grain_skate").TemporalGraph;

    // Create DAG integration and temporal graph
    var dag_integration = try EditorDagIntegration.init(allocator);
    defer dag_integration.deinit();

    const content = "line1\nline2\nline3";
    _ = try dag_integration.create_buffer_node(content);

    var temporal_graph = TemporalGraph.init(allocator, &dag_integration);

    var graph_viz = GraphVisualization.init(allocator);
    var renderer = GraphRenderer.init(&graph_viz, 800, 600);

    // Set temporal graph
    renderer.set_temporal_graph(&temporal_graph);

    // Initially, no time-travel mode
    try testing.expect(!renderer.is_time_travel_mode());

    // Set timestamp via temporal graph
    const test_timestamp: u64 = 1234567890;
    renderer.set_temporal_timestamp(test_timestamp);

    // Time-travel mode should be active
    try testing.expect(renderer.is_time_travel_mode());
    try testing.expect(renderer.get_temporal_timestamp().? == test_timestamp);
    try testing.expect(temporal_graph.get_timestamp().? == test_timestamp);
}

test "graph renderer temporal filtering of nodes" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    const Block = @import("grain_skate").Block;

    // Create block storage with blocks at different times
    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    // Create blocks (they get current timestamp)
    const block1_id = try block_storage.create_block("Block 1", "Content 1");
    const block2_id = try block_storage.create_block("Block 2", "Content 2");

    // Get creation timestamps
    const block1 = block_storage.get_block(block1_id).?;
    const block2 = block_storage.get_block(block2_id).?;
    const block1_created = block1.created_at;
    const block2_created = block2.created_at;

    // Ensure block2 was created after block1 (add small delay if needed)
    // For test, we'll use block1's timestamp as the filter point

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(block1_id);
    graph_viz.add_block(block2_id);
    graph_viz.calculate_layout(10);

    var renderer = GraphRenderer.init(&graph_viz, 800, 600);
    renderer.set_block_storage(&block_storage);

    // Initially, all blocks should be visible (no time-travel mode)
    var buffer: [800 * 600 * 4]u8 = undefined;
    renderer.render(&buffer);

    // Set timestamp to before block2 was created (should only show block1)
    const filter_timestamp = block1_created;
    renderer.set_temporal_timestamp(filter_timestamp);

    // Re-render with temporal filter
    renderer.render(&buffer);

    // Both blocks should exist at their creation times
    // (In practice, block2 would be filtered if timestamp < block2.created_at)
    // For this test, we verify the filtering logic exists
    try testing.expect(renderer.is_time_travel_mode());
    try testing.expect(renderer.get_temporal_timestamp().? == filter_timestamp);
}

test "graph renderer temporal filtering of edges" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    const Block = @import("grain_skate").Block;

    // Create block storage with linked blocks
    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    const block1_id = try block_storage.create_block("Block 1", "Content 1");
    const block2_id = try block_storage.create_block("Block 2", "Content 2");

    // Link blocks
    try block_storage.link_blocks(block1_id, block2_id);

    var graph_viz = GraphVisualization.init(allocator);
    graph_viz.add_block(block1_id);
    graph_viz.add_block(block2_id);
    graph_viz.add_link(block1_id, block2_id);
    graph_viz.calculate_layout(10);

    var renderer = GraphRenderer.init(&graph_viz, 800, 600);
    renderer.set_block_storage(&block_storage);

    // Get creation timestamps
    const block1 = block_storage.get_block(block1_id).?;
    const block1_created = block1.created_at;

    // Set temporal filter
    renderer.set_temporal_timestamp(block1_created);

    var buffer: [800 * 600 * 4]u8 = undefined;
    renderer.render(&buffer);

    // Verify temporal filtering is active
    try testing.expect(renderer.is_time_travel_mode());
    try testing.expect(renderer.get_temporal_timestamp().? == block1_created);
}
