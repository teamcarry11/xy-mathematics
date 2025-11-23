const std = @import("std");
const testing = std.testing;
const grain_skate = @import("grain_skate");
const Block = grain_skate.Block;
const Editor = grain_skate.Editor;

test "block create" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var storage = try Block.BlockStorage.init(allocator);
    defer storage.deinit();

    const block_id = try storage.create_block("Test Block", "This is test content");
    try testing.expect(block_id > 0);

    const block = storage.get_block(block_id);
    try testing.expect(block != null);
    try testing.expect(std.mem.eql(u8, block.?.title, "Test Block"));
    try testing.expect(std.mem.eql(u8, block.?.content, "This is test content"));
}

test "block link" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var storage = try Block.BlockStorage.init(allocator);
    defer storage.deinit();

    const block1_id = try storage.create_block("Block 1", "Content 1");
    const block2_id = try storage.create_block("Block 2", "Content 2");

    try storage.link_blocks(block1_id, block2_id);

    const block1 = storage.get_block(block1_id);
    try testing.expect(block1 != null);
    try testing.expect(block1.?.links_len == 1);
    try testing.expect(block1.?.links[0] == block2_id);

    const block2 = storage.get_block(block2_id);
    try testing.expect(block2 != null);
    try testing.expect(block2.?.backlinks_len == 1);
    try testing.expect(block2.?.backlinks[0] == block1_id);
}

test "block unlink" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var storage = try Block.BlockStorage.init(allocator);
    defer storage.deinit();

    const block1_id = try storage.create_block("Block 1", "Content 1");
    const block2_id = try storage.create_block("Block 2", "Content 2");

    try storage.link_blocks(block1_id, block2_id);
    storage.unlink_blocks(block1_id, block2_id);

    const block1 = storage.get_block(block1_id);
    try testing.expect(block1 != null);
    try testing.expect(block1.?.links_len == 0);

    const block2 = storage.get_block(block2_id);
    try testing.expect(block2 != null);
    try testing.expect(block2.?.backlinks_len == 0);
}

test "block update content" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var storage = try Block.BlockStorage.init(allocator);
    defer storage.deinit();

    const block_id = try storage.create_block("Test Block", "Old content");
    var block = storage.get_block(block_id);
    try testing.expect(block != null);

    try block.?.update_content("New content");
    try testing.expect(std.mem.eql(u8, block.?.content, "New content"));
}

test "editor init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "Line 1\nLine 2\nLine 3";
    var editor = try Editor.EditorState.init(allocator, content);
    defer editor.deinit();

    try testing.expect(editor.mode == .normal);
    try testing.expect(editor.cursor_line == 0);
    try testing.expect(editor.cursor_column == 0);
    try testing.expect(editor.buffer.lines_len == 3);
}

test "editor cursor movement" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "Line 1\nLine 2\nLine 3";
    var editor = try Editor.EditorState.init(allocator, content);
    defer editor.deinit();

    editor.move_right();
    try testing.expect(editor.cursor_column == 1);

    editor.move_down();
    try testing.expect(editor.cursor_line == 1);

    editor.move_up();
    try testing.expect(editor.cursor_line == 0);

    editor.move_left();
    try testing.expect(editor.cursor_column == 0);
}

test "editor mode switching" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "Line 1\nLine 2";
    var editor = try Editor.EditorState.init(allocator, content);
    defer editor.deinit();

    try testing.expect(editor.mode == .normal);

    editor.enter_insert_mode();
    try testing.expect(editor.mode == .insert);

    editor.exit_insert_mode();
    try testing.expect(editor.mode == .normal);
}

