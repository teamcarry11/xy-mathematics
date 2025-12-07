//! Tests for Aurora Editor.
//!
//! Why: Verify editor functionality (buffer operations, undo/redo, cursor movement).
//! Architecture: Comprehensive test coverage for editor operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! NOTE: These tests are currently blocked by Zig 0.15.2 comptime evaluation issue.
//! The Editor struct with AiProvider vtable requires comptime evaluation that fails
//! when importing through a module. Tests are written and ready, but cannot run until
//! Zig comptime evaluation is fixed or Editor initialization is refactored.
//!
//! See: src/aurora_editor.zig line 2164 for related comment.
//!
//! 2025-12-06-232932-pst: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const Editor = @import("aurora_editor").Editor;

test "editor initialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const initial_text = "hello world";
    var editor = try Editor.init(
        allocator,
        "file:///test.zig",
        initial_text,
    );
    defer editor.deinit();

    // Assert: Editor initialized correctly
    std.debug.assert(editor.cursor_line == 0);
    std.debug.assert(editor.cursor_char == 0);
    std.debug.assert(editor.undo_history.items.len == 0);
    std.debug.assert(editor.redo_history.items.len == 0);
    std.debug.assert(editor.pending_completion == null);
}

test "editor insert text" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var editor = try Editor.init(
        allocator,
        "file:///test.zig",
        "hello",
    );
    defer editor.deinit();

    // Insert text at cursor
    try editor.insert(" world");

    // Assert: Text inserted
    const text = editor.buffer.textSlice();
    try testing.expectEqualStrings("hello world", text);
    std.debug.assert(editor.cursor_char == 11); // "hello world".len
    std.debug.assert(editor.undo_history.items.len == 1);
}

test "editor delete text" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var editor = try Editor.init(
        allocator,
        "file:///test.zig",
        "hello world",
    );
    defer editor.deinit();

    // Move cursor to position 5 ("hello| world")
    editor.moveCursor(0, 5);

    // Delete 6 characters (" world")
    try editor.delete(6);

    // Assert: Text deleted
    const text = editor.buffer.textSlice();
    try testing.expectEqualStrings("hello", text);
    std.debug.assert(editor.cursor_char == 5);
    std.debug.assert(editor.undo_history.items.len == 1);
}

test "editor undo operation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var editor = try Editor.init(
        allocator,
        "file:///test.zig",
        "hello",
    );
    defer editor.deinit();

    // Insert text
    try editor.insert(" world");
    const text_after_insert = editor.buffer.textSlice();
    try testing.expectEqualStrings("hello world", text_after_insert);

    // Undo operation
    try editor.undo();

    // Assert: Text reverted
    const text_after_undo = editor.buffer.textSlice();
    try testing.expectEqualStrings("hello", text_after_undo);
    std.debug.assert(editor.undo_history.items.len == 0);
    std.debug.assert(editor.redo_history.items.len == 1);
}

test "editor redo operation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var editor = try Editor.init(
        allocator,
        "file:///test.zig",
        "hello",
    );
    defer editor.deinit();

    // Insert text
    try editor.insert(" world");
    const text_after_insert = editor.buffer.textSlice();
    try testing.expectEqualStrings("hello world", text_after_insert);

    // Undo operation
    try editor.undo();
    const text_after_undo = editor.buffer.textSlice();
    try testing.expectEqualStrings("hello", text_after_undo);

    // Redo operation
    try editor.redo();

    // Assert: Text restored
    const text_after_redo = editor.buffer.textSlice();
    try testing.expectEqualStrings("hello world", text_after_redo);
    std.debug.assert(editor.undo_history.items.len == 1);
    std.debug.assert(editor.redo_history.items.len == 0);
}

test "editor cursor movement" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var editor = try Editor.init(
        allocator,
        "file:///test.zig",
        "line1\nline2\nline3",
    );
    defer editor.deinit();

    // Move cursor to line 1, char 3
    editor.moveCursor(1, 3);

    // Assert: Cursor moved
    std.debug.assert(editor.cursor_line == 1);
    std.debug.assert(editor.cursor_char == 3);

    // Move cursor to line 2, char 0
    editor.moveCursor(2, 0);

    // Assert: Cursor moved
    std.debug.assert(editor.cursor_line == 2);
    std.debug.assert(editor.cursor_char == 0);
}

test "editor insert at cursor position" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var editor = try Editor.init(
        allocator,
        "file:///test.zig",
        "hello",
    );
    defer editor.deinit();

    // Move cursor to position 3 ("hel|lo")
    editor.moveCursor(0, 3);

    // Insert text
    try editor.insert("X");

    // Assert: Text inserted at cursor
    const text = editor.buffer.textSlice();
    try testing.expectEqualStrings("helXlo", text);
    std.debug.assert(editor.cursor_char == 4); // After inserted 'X'
}

test "editor multiple undo operations" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var editor = try Editor.init(
        allocator,
        "file:///test.zig",
        "hello",
    );
    defer editor.deinit();

    // Insert text multiple times
    try editor.insert(" ");
    try editor.insert("world");
    try editor.insert("!");

    // Assert: All operations recorded
    std.debug.assert(editor.undo_history.items.len == 3);
    const text_after_inserts = editor.buffer.textSlice();
    try testing.expectEqualStrings("hello world!", text_after_inserts);

    // Undo all operations
    try editor.undo();
    try editor.undo();
    try editor.undo();

    // Assert: All operations undone
    const text_after_undos = editor.buffer.textSlice();
    try testing.expectEqualStrings("hello", text_after_undos);
    std.debug.assert(editor.undo_history.items.len == 0);
    std.debug.assert(editor.redo_history.items.len == 3);
}

test "editor delete and undo" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var editor = try Editor.init(
        allocator,
        "file:///test.zig",
        "hello world",
    );
    defer editor.deinit();

    // Move cursor to position 5
    editor.moveCursor(0, 5);

    // Delete 6 characters
    try editor.delete(6);

    // Assert: Text deleted
    const text_after_delete = editor.buffer.textSlice();
    try testing.expectEqualStrings("hello", text_after_delete);

    // Undo delete
    try editor.undo();

    // Assert: Text restored
    const text_after_undo = editor.buffer.textSlice();
    try testing.expectEqualStrings("hello world", text_after_undo);
}

test "editor empty buffer operations" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var editor = try Editor.init(
        allocator,
        "file:///test.zig",
        "",
    );
    defer editor.deinit();

    // Insert text into empty buffer
    try editor.insert("hello");

    // Assert: Text inserted
    const text = editor.buffer.textSlice();
    try testing.expectEqualStrings("hello", text);
    std.debug.assert(editor.cursor_char == 5);
}

test "editor reject completion" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var editor = try Editor.init(
        allocator,
        "file:///test.zig",
        "hello",
    );
    defer editor.deinit();

    // Set pending completion (simulate)
    const completion_text = try allocator.dupe(u8, " world");
    editor.pending_completion = completion_text;

    // Reject completion
    editor.reject_completion();

    // Assert: Completion cleared
    std.debug.assert(editor.pending_completion == null);
}

test "editor get diagnostics empty" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var editor = try Editor.init(
        allocator,
        "file:///test.zig",
        "hello",
    );
    defer editor.deinit();

    // Get diagnostics (should be empty without LSP)
    const diagnostics = editor.get_diagnostics();

    // Assert: Diagnostics array returned (may be empty)
    _ = diagnostics; // Just verify it doesn't crash
}

test "editor folding operations" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var editor = try Editor.init(
        allocator,
        "file:///test.zig",
        "fn test() void {\n    return;\n}",
    );
    defer editor.deinit();

    // Toggle fold at line 0
    editor.toggleFold(0);

    // Assert: Fold toggled
    const is_folded = editor.isFolded(0);
    std.debug.assert(is_folded == true);

    // Toggle fold again
    editor.toggleFold(0);

    // Assert: Fold untoggled
    const is_folded_again = editor.isFolded(0);
    std.debug.assert(is_folded_again == false);
}

