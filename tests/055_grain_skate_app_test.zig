const std = @import("std");
const testing = std.testing;
const grain_skate = @import("grain_skate");
const GrainSkateApp = grain_skate.GrainSkateApp;
const Block = grain_skate.Block;
const SkateWindow = grain_skate.SkateWindow;

test "grain skate app init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var window = try SkateWindow.init(allocator, "Test", 800, 600);
    defer window.deinit();

    var app = try GrainSkateApp.init(allocator, &block_storage, &window);
    defer app.deinit();

    try testing.expect(app.block_storage == &block_storage);
    try testing.expect(app.window == &window);
    try testing.expect(app.modal_editor == null);
    try testing.expect(app.storage_integration == null);
}

test "grain skate app load blocks to graph" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var window = try SkateWindow.init(allocator, "Test", 800, 600);
    defer window.deinit();

    var app = try GrainSkateApp.init(allocator, &block_storage, &window);
    defer app.deinit();

    // Create blocks
    const block1_id = try app.create_block("Block 1", "Content 1");
    const block2_id = try app.create_block("Block 2", "Content 2");

    // Link blocks
    try app.link_blocks(block1_id, block2_id);

    // Load to graph
    app.load_blocks_to_graph();

    // Verify graph has nodes and edges
    try testing.expect(app.graph_viz.nodes_len >= 2);
    try testing.expect(app.graph_viz.edges_len >= 1);
}

test "grain skate app open block" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var window = try SkateWindow.init(allocator, "Test", 800, 600);
    defer window.deinit();

    var app = try GrainSkateApp.init(allocator, &block_storage, &window);
    defer app.deinit();

    // Create block
    const block_id = try app.create_block("Test Block", "Test Content");

    // Open block
    try app.open_block(block_id);

    // Verify block is set in window
    try testing.expect(app.window.get_current_block_id().? == block_id);
    try testing.expect(app.window.get_editor() != null);

    // Verify block is selected in graph
    try testing.expect(app.graph_viz.selected_block_id.? == block_id);
}

test "grain skate app create and link blocks" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var window = try SkateWindow.init(allocator, "Test", 800, 600);
    defer window.deinit();

    var app = try GrainSkateApp.init(allocator, &block_storage, &window);
    defer app.deinit();

    // Create blocks
    const block1_id = try app.create_block("Block 1", "Content 1");
    const block2_id = try app.create_block("Block 2", "Content 2");
    const block3_id = try app.create_block("Block 3", "Content 3");

    // Link blocks (chain: 1 -> 2 -> 3)
    try app.link_blocks(block1_id, block2_id);
    try app.link_blocks(block2_id, block3_id);

    // Verify links in block storage
    const block1 = block_storage.get_block(block1_id).?;
    try testing.expect(block1.links_len == 1);
    try testing.expect(block1.links[0] == block2_id);

    // Verify graph has edges
    try testing.expect(app.graph_viz.edges_len >= 2);
}

test "grain skate app update current block" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var window = try SkateWindow.init(allocator, "Test", 800, 600);
    defer window.deinit();

    var app = try GrainSkateApp.init(allocator, &block_storage, &window);
    defer app.deinit();

    // Create and open block
    const block_id = try app.create_block("Test", "Original");
    try app.open_block(block_id);

    // Update content
    try app.update_current_block("Updated");

    // Verify update
    const block = block_storage.get_block(block_id).?;
    try testing.expect(std.mem.eql(u8, block.content, "Updated"));
}

test "grain skate app handle graph click" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var window = try SkateWindow.init(allocator, "Test", 800, 600);
    defer window.deinit();

    var app = try GrainSkateApp.init(allocator, &block_storage, &window);
    defer app.deinit();

    const block_id = try app.create_block("Test Block", "Content");
    app.load_blocks_to_graph();

    // Click on graph (may or may not find node depending on layout)
    app.handle_graph_click(400.0, 400.0);
    // Should not crash
}

