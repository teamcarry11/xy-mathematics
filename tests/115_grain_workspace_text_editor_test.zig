//! Tests for Grain Text Editor application.
//!
//! Why: Verify text editing, file operations, search functionality.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-161231-pst: Phase 17 SLC v1.0 Text Editor

const std = @import("std");
const testing = std.testing;
const TextEditor = @import("../src/grain_workspace/text_editor/app.zig").TextEditor;

test "text editor initialization" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    try testing.expect(editor.lines_len == 0);
    try testing.expect(editor.file_state == .closed);
    try testing.expect(editor.cursor.line == 0);
    try testing.expect(editor.cursor.column == 0);
    try testing.expect(editor.undo_history_len == 0);
    try testing.expect(editor.search_results_len == 0);
    try testing.expect(editor.show_line_numbers == true);
}

test "open file" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    const result = editor.open_file("/test/file.txt");
    try testing.expect(result == true);
    try testing.expect(editor.file_state == .clean);
    try testing.expect(editor.file_path_len > 0);
    try testing.expect(std.mem.eql(u8, editor.file_path[0..editor.file_path_len], "/test/file.txt"));
}

test "close file" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    const result = editor.close_file();
    try testing.expect(result == true);
    try testing.expect(editor.file_state == .closed);
    try testing.expect(editor.file_path_len == 0);
}

test "insert text" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    const result = editor.insert_text("Hello, World!");
    try testing.expect(result == true);
    try testing.expect(editor.lines_len == 1);
    try testing.expect(editor.file_state == .dirty);
    try testing.expect(editor.lines[0].content_len == 13);
    try testing.expect(std.mem.eql(u8, editor.lines[0].content[0..13], "Hello, World!"));
}

test "delete text" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World!");
    _ = editor.move_cursor(0, 5);
    const result = editor.delete_text(7);
    try testing.expect(result == true);
    try testing.expect(editor.lines[0].content_len == 6);
    try testing.expect(std.mem.eql(u8, editor.lines[0].content[0..6], "Hello!"));
}

test "move cursor" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World!");
    const result = editor.move_cursor(0, 7);
    try testing.expect(result == true);
    try testing.expect(editor.cursor.line == 0);
    try testing.expect(editor.cursor.column == 7);
}

test "get current line number" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Line 1");
    _ = editor.insert_text("\n");
    _ = editor.insert_text("Line 2");
    const line_num = editor.get_current_line_number();
    try testing.expect(line_num >= 1);
}

test "get total line count" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    const count1 = editor.get_total_line_count();
    try testing.expect(count1 == 1);

    _ = editor.insert_text("Line 1");
    _ = editor.insert_text("\n");
    _ = editor.insert_text("Line 2");
    const count2 = editor.get_total_line_count();
    try testing.expect(count2 >= 1);
}

test "search text" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World! Hello again!");
    const result_count = editor.search_text("Hello");
    try testing.expect(result_count == 2);
    try testing.expect(editor.search_results_len == 2);
    try testing.expect(editor.search_results[0].line == 0);
    try testing.expect(editor.search_results[0].column == 0);
    try testing.expect(editor.search_results[1].line == 0);
    try testing.expect(editor.search_results[1].column == 14);
}

test "get search results" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World! Hello again!");
    _ = editor.search_text("Hello");

    var results: [10]TextEditor.SearchResult = undefined;
    var results_len: u32 = 0;
    editor.get_search_results(&results, &results_len);
    try testing.expect(results_len == 2);
    try testing.expect(results[0].line == 0);
    try testing.expect(results[0].column == 0);
}

test "toggle line numbers" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    const initial = editor.show_line_numbers;
    editor.toggle_line_numbers();
    try testing.expect(editor.show_line_numbers == !initial);
    editor.toggle_line_numbers();
    try testing.expect(editor.show_line_numbers == initial);
}

test "save file" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World!");
    try testing.expect(editor.file_state == .dirty);

    const result = editor.save_file();
    try testing.expect(result == true);
    try testing.expect(editor.file_state == .clean);
}

test "cannot close file with unsaved changes" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World!");
    try testing.expect(editor.file_state == .dirty);

    const result = editor.close_file();
    try testing.expect(result == false);
    try testing.expect(editor.file_state == .dirty);
}

test "cannot open file when file has unsaved changes" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file1.txt");
    _ = editor.insert_text("Hello, World!");
    try testing.expect(editor.file_state == .dirty);

    const result = editor.open_file("/test/file2.txt");
    try testing.expect(result == false);
    try testing.expect(editor.file_state == .dirty);
}
