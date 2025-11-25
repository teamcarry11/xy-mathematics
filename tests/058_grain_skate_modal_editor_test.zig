const std = @import("std");
const testing = std.testing;
const grain_skate = @import("grain_skate");
const Editor = grain_skate.Editor;
const ModalEditor = grain_skate.ModalEditor;
const events = @import("events");

test "modal editor command parse w" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "Test content";
    var editor = try Editor.EditorState.init(allocator, content);
    defer editor.deinit();

    var modal_editor = try ModalEditor.init(allocator, &editor);
    defer modal_editor.deinit();

    // Enter command mode
    editor.mode = .command;

    // Type 'w' command
    const w_event = events.KeyboardEvent{ .key_code = 'w' };
    try modal_editor.handle_key_event(w_event);

    // Press Enter to execute
    const enter_event = events.KeyboardEvent{ .key_code = 13 };
    try modal_editor.handle_key_event(enter_event);

    // Check mode returned to normal
    try testing.expect(editor.mode == .normal);
    try testing.expect(modal_editor.command_buffer_len == 0);
}

test "modal editor command parse q" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "Test content";
    var editor = try Editor.EditorState.init(allocator, content);
    defer editor.deinit();

    var modal_editor = try ModalEditor.init(allocator, &editor);
    defer modal_editor.deinit();

    // Enter command mode
    editor.mode = .command;

    // Type 'q' command
    const q_event = events.KeyboardEvent{ .key_code = 'q' };
    try modal_editor.handle_key_event(q_event);

    // Press Enter to execute
    const enter_event = events.KeyboardEvent{ .key_code = 13 };
    try modal_editor.handle_key_event(enter_event);

    // Check mode returned to normal
    try testing.expect(editor.mode == .normal);
    try testing.expect(modal_editor.command_buffer_len == 0);
}

test "modal editor command parse wq" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "Test content";
    var editor = try Editor.EditorState.init(allocator, content);
    defer editor.deinit();

    var modal_editor = try ModalEditor.init(allocator, &editor);
    defer modal_editor.deinit();

    // Enter command mode
    editor.mode = .command;

    // Type 'wq' command
    const w_event = events.KeyboardEvent{ .key_code = 'w' };
    try modal_editor.handle_key_event(w_event);
    const q_event = events.KeyboardEvent{ .key_code = 'q' };
    try modal_editor.handle_key_event(q_event);

    // Press Enter to execute
    const enter_event = events.KeyboardEvent{ .key_code = 13 };
    try modal_editor.handle_key_event(enter_event);

    // Check mode returned to normal
    try testing.expect(editor.mode == .normal);
    try testing.expect(modal_editor.command_buffer_len == 0);
}

test "modal editor command parse q!" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "Test content";
    var editor = try Editor.EditorState.init(allocator, content);
    defer editor.deinit();

    var modal_editor = try ModalEditor.init(allocator, &editor);
    defer modal_editor.deinit();

    // Enter command mode
    editor.mode = .command;

    // Type 'q!' command
    const q_event = events.KeyboardEvent{ .key_code = 'q' };
    try modal_editor.handle_key_event(q_event);
    const bang_event = events.KeyboardEvent{ .key_code = '!' };
    try modal_editor.handle_key_event(bang_event);

    // Press Enter to execute
    const enter_event = events.KeyboardEvent{ .key_code = 13 };
    try modal_editor.handle_key_event(enter_event);

    // Check mode returned to normal
    try testing.expect(editor.mode == .normal);
    try testing.expect(modal_editor.command_buffer_len == 0);
}

test "modal editor command cancel escape" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "Test content";
    var editor = try Editor.EditorState.init(allocator, content);
    defer editor.deinit();

    var modal_editor = try ModalEditor.init(allocator, &editor);
    defer modal_editor.deinit();

    // Enter command mode
    editor.mode = .command;

    // Type some characters
    const w_event = events.KeyboardEvent{ .key_code = 'w' };
    try modal_editor.handle_key_event(w_event);
    try testing.expect(modal_editor.command_buffer_len == 1);

    // Press Escape to cancel
    const escape_event = events.KeyboardEvent{ .key_code = 27 };
    try modal_editor.handle_key_event(escape_event);

    // Check mode returned to normal and buffer cleared
    try testing.expect(editor.mode == .normal);
    try testing.expect(modal_editor.command_buffer_len == 0);
}

test "modal editor command backspace" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "Test content";
    var editor = try Editor.EditorState.init(allocator, content);
    defer editor.deinit();

    var modal_editor = try ModalEditor.init(allocator, &editor);
    defer modal_editor.deinit();

    // Enter command mode
    editor.mode = .command;

    // Type 'w'
    const w_event = events.KeyboardEvent{ .key_code = 'w' };
    try modal_editor.handle_key_event(w_event);
    try testing.expect(modal_editor.command_buffer_len == 1);

    // Press Backspace
    const backspace_event = events.KeyboardEvent{ .key_code = 8 };
    try modal_editor.handle_key_event(backspace_event);

    // Check buffer is cleared
    try testing.expect(modal_editor.command_buffer_len == 0);
}

test "modal editor get command string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "Test content";
    var editor = try Editor.EditorState.init(allocator, content);
    defer editor.deinit();

    var modal_editor = try ModalEditor.init(allocator, &editor);
    defer modal_editor.deinit();

    // Enter command mode
    editor.mode = .command;

    // Type 'wq'
    const w_event = events.KeyboardEvent{ .key_code = 'w' };
    try modal_editor.handle_key_event(w_event);
    const q_event = events.KeyboardEvent{ .key_code = 'q' };
    try modal_editor.handle_key_event(q_event);

    // Check command string
    const cmd_str = modal_editor.get_command_string();
    try testing.expect(cmd_str.len == 2);
    try testing.expect(std.mem.eql(u8, cmd_str, "wq"));
}

