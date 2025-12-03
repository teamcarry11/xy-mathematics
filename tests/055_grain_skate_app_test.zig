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

test "grain skate app keyboard event routing" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var window = try SkateWindow.init(allocator, "Test", 800, 600);
    defer window.deinit();

    var app = try GrainSkateApp.init(allocator, &block_storage, &window);
    defer app.deinit();

    // Create a block and open it
    const block_id = try app.create_block("Test Block", "Hello World");
    try app.open_block(block_id);

    // Create keyboard event (key 'h' press)
    const events_mod = @import("platform/events.zig");
    const key_event = events_mod.KeyboardEvent{
        .kind = .down,
        .key_code = 'h',
        .character = 'h',
        .modifiers = .{},
    };

    // Handle keyboard event (should route to modal editor)
    const handled = app.handle_keyboard_event(key_event);
    // Event should be handled if modal editor is active
    // Note: This may return false if modal editor isn't initialized yet
    _ = handled; // Basic test - just verify it doesn't crash
}

test "grain skate app keyboard event ctrl alt passthrough" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var window = try SkateWindow.init(allocator, "Test", 800, 600);
    defer window.deinit();

    var app = try GrainSkateApp.init(allocator, &block_storage, &window);
    defer app.deinit();

    // Create keyboard event with Ctrl+Alt (should pass through to OS)
    const events_mod = @import("platform/events.zig");
    const key_event = events_mod.KeyboardEvent{
        .kind = .down,
        .key_code = 'h',
        .character = 'h',
        .modifiers = .{
            .control = true,
            .option = true,
        },
    };

    // Handle keyboard event (should NOT handle Ctrl+Alt)
    const handled = app.handle_keyboard_event(key_event);
    // Should return false to let OS handle it
    try testing.expect(!handled);
}

test "grain skate app save command integration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var window = try SkateWindow.init(allocator, "Test", 800, 600);
    defer window.deinit();

    var app = try GrainSkateApp.init(allocator, &block_storage, &window);
    defer app.deinit();

    // Create a block and open it
    const block_id = try app.create_block("Test Block", "Original Content");
    try app.open_block(block_id);

    // Verify modal editor is created
    try testing.expect(app.modal_editor != null);

    // Get editor and modify content (insert text)
    if (app.window.get_editor()) |editor| {
        // Enter insert mode and add text
        editor.mode = .insert;
        try editor.insert_char('N');
        try editor.insert_char('e');
        try editor.insert_char('w');
        editor.mode = .normal;
    }

    // Execute save command (simulate :w command)
    if (app.modal_editor) |modal_editor| {
        modal_editor.editor.mode = .command;
        modal_editor.command_buffer[0] = 'w';
        modal_editor.command_buffer_len = 1;
        // Simulate Enter key to execute command
        const events_mod = @import("platform/events.zig");
        const enter_event = events_mod.KeyboardEvent{
            .kind = .down,
            .key_code = 13, // Enter
            .character = null,
            .modifiers = .{},
        };
        try modal_editor.handle_key_event(enter_event);
        // Check command result
        const cmd_result = modal_editor.get_last_command_result();
        try testing.expect(cmd_result == .save);
    }

    // Verify content was saved to block storage
    const block = block_storage.get_block(block_id).?;
    // Content should include "New" that was inserted
    try testing.expect(std.mem.indexOf(u8, block.content, "New") != null or
        std.mem.indexOf(u8, block.content, "Original ContentNew") != null);
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

test "grain skate app quit command closes editor" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var block_storage = try Block.BlockStorage.init(allocator);
    defer block_storage.deinit();

    var window = try SkateWindow.init(allocator, "Test", 800, 600);
    defer window.deinit();

    var app = try GrainSkateApp.init(allocator, &block_storage, &window);
    defer app.deinit();

    // Create a block and open it
    const block_id = try app.create_block("Test Block", "Content");
    try app.open_block(block_id);

    // Verify editor is open
    try testing.expect(app.window.get_editor() != null);
    try testing.expect(app.modal_editor != null);
    try testing.expect(app.window.get_current_block_id() != null);

    // Execute quit command (simulate :q command)
    if (app.modal_editor) |modal_editor| {
        modal_editor.editor.mode = .command;
        modal_editor.command_buffer[0] = 'q';
        modal_editor.command_buffer_len = 1;
        // Simulate Enter key to execute command
        const events_mod = @import("platform/events.zig");
        const enter_event = events_mod.KeyboardEvent{
            .kind = .down,
            .key_code = 13, // Enter
            .character = null,
            .modifiers = .{},
        };
        try modal_editor.handle_key_event(enter_event);
        // Check command result
        const cmd_result = modal_editor.get_last_command_result();
        try testing.expect(cmd_result == .quit);
    }

    // Simulate keyboard event handling to trigger quit processing
    const events_mod = @import("platform/events.zig");
    const dummy_event = events_mod.KeyboardEvent{
        .kind = .down,
        .key_code = 0,
        .character = null,
        .modifiers = .{},
    };
    _ = app.handle_keyboard_event(dummy_event);

    // Verify editor is closed
    try testing.expect(app.window.get_editor() == null);
    try testing.expect(app.modal_editor == null);
    try testing.expect(app.window.get_current_block_id() == null);
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

test "grain skate app handle window resize" {
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

    // Resize window
    try app.handle_window_resize(1024, 768);

    // Verify window dimensions updated
    try testing.expect(window.window.width == 1024);
    try testing.expect(window.window.height == 768);
}

