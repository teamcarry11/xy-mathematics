//! Tests for Grain Text Editor application.
//!
//! Why: Verify text editing, file operations, search functionality.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-161231-pst: Phase 17 SLC v1.0 Text Editor
//! 2025-12-21-184709-pst: Phase 28 Find and Replace tests
//! 2025-12-21-234422-pst: Phase 29 Go to Line tests
//! 2025-12-23-194527-pst: Phase 30 Text Selection tests
//! 2025-12-23-210000-pst: Phase 31 Syntax Highlighting tests

const std = @import("std");
const testing = std.testing;
const TextEditor = @import("../src/grain_workspace/text_editor/app.zig").TextEditor;
const SyntaxToken = @import("../src/grain_workspace/text_editor/app.zig").SyntaxToken;
const SyntaxTokenType = @import("../src/grain_workspace/text_editor/app.zig").SyntaxTokenType;

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

test "undo insert" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello");
    try testing.expect(editor.lines[0].content_len == 5);

    const result = editor.undo();
    try testing.expect(result == true);
    try testing.expect(editor.lines[0].content_len == 0);
}

test "redo insert" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello");
    _ = editor.undo();
    try testing.expect(editor.lines[0].content_len == 0);

    const result = editor.redo();
    try testing.expect(result == true);
    try testing.expect(editor.lines[0].content_len == 5);
    try testing.expect(std.mem.eql(u8, editor.lines[0].content[0..5], "Hello"));
}

test "undo delete" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World!");
    _ = editor.move_cursor(0, 5);
    _ = editor.delete_text(7);
    try testing.expect(editor.lines[0].content_len == 6);

    const result = editor.undo();
    try testing.expect(result == true);
    try testing.expect(editor.lines[0].content_len == 13);
}

test "redo delete" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World!");
    _ = editor.move_cursor(0, 5);
    _ = editor.delete_text(7);
    _ = editor.undo();
    try testing.expect(editor.lines[0].content_len == 13);

    const result = editor.redo();
    try testing.expect(result == true);
    try testing.expect(editor.lines[0].content_len == 6);
}

test "undo history limit" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    // Insert many characters to test undo history
    var i: u32 = 0;
    while (i < 50) : (i += 1) {
        _ = editor.insert_text("a");
    }
    try testing.expect(editor.lines[0].content_len == 50);

    // Undo all
    i = 0;
    while (i < 50) : (i += 1) {
        _ = editor.undo();
    }
    try testing.expect(editor.lines[0].content_len == 0);
}

test "cannot undo when nothing to undo" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    const result = editor.undo();
    try testing.expect(result == false);
}

test "cannot redo when nothing to redo" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello");
    const result = editor.redo();
    try testing.expect(result == false);
}

test "get file content" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello");
    _ = editor.insert_text("\n");
    _ = editor.insert_text("World");

    var buffer: [1000]u8 = undefined;
    var buffer_len: u32 = 0;
    const result = editor.get_file_content(&buffer, &buffer_len);
    try testing.expect(result == true);
    try testing.expect(buffer_len > 0);
    try testing.expect(std.mem.eql(u8, buffer[0..5], "Hello"));
}

test "set file content" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    const content = "Hello\nWorld\nTest";
    const result = editor.set_file_content(content);
    try testing.expect(result == true);
    try testing.expect(editor.lines_len >= 1);
    try testing.expect(editor.file_state == .dirty);
}

test "set file content single line" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    const content = "Hello World";
    const result = editor.set_file_content(content);
    try testing.expect(result == true);
    try testing.expect(editor.lines_len == 1);
    try testing.expect(editor.lines[0].content_len == 11);
    try testing.expect(std.mem.eql(u8, editor.lines[0].content[0..11], "Hello World"));
}

test "set file content multiple lines" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    const content = "Line 1\nLine 2\nLine 3";
    const result = editor.set_file_content(content);
    try testing.expect(result == true);
    try testing.expect(editor.lines_len >= 2);
}

test "get file content empty" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    var buffer: [1000]u8 = undefined;
    var buffer_len: u32 = 0;
    const result = editor.get_file_content(&buffer, &buffer_len);
    try testing.expect(result == true);
    try testing.expect(buffer_len == 0);
}

test "toggle plain text mode" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    const initial = editor.plain_text_mode;
    editor.toggle_plain_text_mode();
    try testing.expect(editor.plain_text_mode == !initial);
    editor.toggle_plain_text_mode();
    try testing.expect(editor.plain_text_mode == initial);
}

test "plain text mode em dash conversion" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    editor.toggle_plain_text_mode();
    try testing.expect(editor.plain_text_mode == true);

    // Insert em dash (UTF-8: 0xE2 0x80 0x94)
    const em_dash = "\xE2\x80\x94";
    _ = editor.insert_text(em_dash);
    
    // Should be converted to double dash
    try testing.expect(editor.lines[0].content_len == 2);
    try testing.expect(editor.lines[0].content[0] == '-');
    try testing.expect(editor.lines[0].content[1] == '-');
}

test "plain text mode smart quotes conversion" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    editor.toggle_plain_text_mode();
    try testing.expect(editor.plain_text_mode == true);

    // Insert left double quote (UTF-8: 0xE2 0x80 0x9C)
    const left_quote = "\xE2\x80\x9C";
    _ = editor.insert_text(left_quote);
    
    // Should be converted to straight quote
    try testing.expect(editor.lines[0].content_len == 1);
    try testing.expect(editor.lines[0].content[0] == '"');

    // Insert right double quote (UTF-8: 0xE2 0x80 0x9D)
    const right_quote = "\xE2\x80\x9D";
    _ = editor.insert_text(right_quote);
    
    // Should be converted to straight quote
    try testing.expect(editor.lines[0].content_len == 2);
    try testing.expect(editor.lines[0].content[1] == '"');
}

test "plain text mode ellipsis conversion" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    editor.toggle_plain_text_mode();
    try testing.expect(editor.plain_text_mode == true);

    // Insert ellipsis (UTF-8: 0xE2 0x80 0xA6)
    const ellipsis = "\xE2\x80\xA6";
    _ = editor.insert_text(ellipsis);
    
    // Should be converted to triple periods
    try testing.expect(editor.lines[0].content_len == 3);
    try testing.expect(editor.lines[0].content[0] == '.');
    try testing.expect(editor.lines[0].content[1] == '.');
    try testing.expect(editor.lines[0].content[2] == '.');
}

test "plain text mode single quotes conversion" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    editor.toggle_plain_text_mode();
    try testing.expect(editor.plain_text_mode == true);

    // Insert left single quote (UTF-8: 0xE2 0x80 0x98)
    const left_single = "\xE2\x80\x98";
    _ = editor.insert_text(left_single);
    
    // Should be converted to straight quote
    try testing.expect(editor.lines[0].content_len == 1);
    try testing.expect(editor.lines[0].content[0] == '\'');

    // Insert right single quote (UTF-8: 0xE2 0x80 0x99)
    const right_single = "\xE2\x80\x99";
    _ = editor.insert_text(right_single);
    
    // Should be converted to straight quote
    try testing.expect(editor.lines[0].content_len == 2);
    try testing.expect(editor.lines[0].content[1] == '\'');
}

test "plain text mode disabled no conversion" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    try testing.expect(editor.plain_text_mode == false);

    // Insert regular text - should not be converted
    _ = editor.insert_text("Hello");
    try testing.expect(editor.lines[0].content_len == 5);
    try testing.expect(std.mem.eql(u8, editor.lines[0].content[0..5], "Hello"));
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

test "set replace query" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    const result = editor.set_replace_query("replacement");
    try testing.expect(result == true);
    try testing.expect(editor.replace_query_len == 11);
}

test "get replace query" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.set_replace_query("replacement");
    
    var query: [256]u8 = undefined;
    var query_len: u32 = 0;
    editor.get_replace_query(&query, &query_len);
    try testing.expect(query_len == 11);
    try testing.expect(std.mem.eql(u8, query[0..query_len], "replacement"));
}

test "replace at result" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello World");
    
    // Search for "World"
    const count = editor.search_text("World");
    try testing.expect(count == 1);
    
    // Set replace query
    _ = editor.set_replace_query("Universe");
    
    // Replace at first result
    const result = editor.replace_at_result(0);
    try testing.expect(result == true);
    
    // Verify replacement
    try testing.expect(editor.lines[0].content_len == 13);
    try testing.expect(std.mem.eql(u8, editor.lines[0].content[0..13], "Hello Universe"));
}

test "replace all" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("foo bar foo");
    
    // Search for "foo"
    const count = editor.search_text("foo");
    try testing.expect(count == 2);
    
    // Set replace query
    _ = editor.set_replace_query("baz");
    
    // Replace all
    const replace_count = editor.replace_all();
    try testing.expect(replace_count == 2);
    
    // Verify replacement
    try testing.expect(editor.lines[0].content_len == 11);
    try testing.expect(std.mem.eql(u8, editor.lines[0].content[0..11], "baz bar baz"));
    
    // Search results should be cleared
    try testing.expect(editor.search_results_len == 0);
}

test "replace all with no results" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello World");
    
    // Set replace query
    _ = editor.set_replace_query("replacement");
    
    // Replace all with no search results
    const replace_count = editor.replace_all();
    try testing.expect(replace_count == 0);
}

test "replace all with no replace query" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello World");
    
    // Search for "World"
    _ = editor.search_text("World");
    
    // Replace all with no replace query set
    const replace_count = editor.replace_all();
    try testing.expect(replace_count == 0);
}

test "go to line" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Line 1");
    _ = editor.insert_text("\n");
    _ = editor.insert_text("Line 2");
    _ = editor.insert_text("\n");
    _ = editor.insert_text("Line 3");
    
    // Go to line 2 (1-indexed)
    const result = editor.go_to_line(2);
    try testing.expect(result == true);
    try testing.expect(editor.cursor.line == 1); // 0-indexed
    try testing.expect(editor.cursor.column == 0);
}

test "go to line first line" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Line 1");
    _ = editor.insert_text("\n");
    _ = editor.insert_text("Line 2");
    
    // Go to line 1 (1-indexed)
    const result = editor.go_to_line(1);
    try testing.expect(result == true);
    try testing.expect(editor.cursor.line == 0); // 0-indexed
    try testing.expect(editor.cursor.column == 0);
}

test "go to line beyond end" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Line 1");
    _ = editor.insert_text("\n");
    _ = editor.insert_text("Line 2");
    
    // Go to line 10 (beyond end, should clamp to last line)
    const result = editor.go_to_line(10);
    try testing.expect(result == true);
    try testing.expect(editor.cursor.line == 1); // Clamped to last line (0-indexed)
    try testing.expect(editor.cursor.column == 0);
}

test "go to line invalid" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Line 1");
    
    // Go to line 0 (invalid, 1-indexed)
    const result = editor.go_to_line(0);
    try testing.expect(result == false);
}

test "go to line column" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Line 1");
    _ = editor.insert_text("\n");
    _ = editor.insert_text("Line 2");
    
    // Go to line 2, column 3 (1-indexed line, 0-indexed column)
    const result = editor.go_to_line_column(2, 3);
    try testing.expect(result == true);
    try testing.expect(editor.cursor.line == 1); // 0-indexed
    try testing.expect(editor.cursor.column == 3);
}

test "go to line column beyond end" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Line 1");
    _ = editor.insert_text("\n");
    _ = editor.insert_text("Line 2");
    
    // Go to line 2, column 100 (beyond line length, should clamp)
    const result = editor.go_to_line_column(2, 100);
    try testing.expect(result == true);
    try testing.expect(editor.cursor.line == 1); // 0-indexed
    try testing.expect(editor.cursor.column == 6); // Clamped to line length
}

test "start selection" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World!");
    _ = editor.move_cursor(0, 5);
    
    editor.start_selection();
    try testing.expect(editor.has_selection() == true);
    try testing.expect(editor.selection.start.column == 5);
    try testing.expect(editor.selection.end.column == 5);
}

test "extend selection" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World!");
    _ = editor.move_cursor(0, 5);
    editor.start_selection();
    
    _ = editor.move_cursor(0, 10);
    editor.extend_selection();
    try testing.expect(editor.has_selection() == true);
    try testing.expect(editor.selection.end.column == 10);
}

test "clear selection" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World!");
    _ = editor.move_cursor(0, 5);
    editor.start_selection();
    
    editor.clear_selection();
    try testing.expect(editor.has_selection() == false);
}

test "select all" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Line 1");
    _ = editor.insert_text("\n");
    _ = editor.insert_text("Line 2");
    
    editor.select_all();
    try testing.expect(editor.has_selection() == true);
    try testing.expect(editor.selection.start.line == 0);
    try testing.expect(editor.selection.start.column == 0);
    try testing.expect(editor.selection.end.line == 1);
}

test "get selected text single line" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World!");
    _ = editor.move_cursor(0, 0);
    editor.start_selection();
    _ = editor.move_cursor(0, 5);
    editor.extend_selection();
    
    var buffer: [256]u8 = undefined;
    var buffer_len: u32 = 0;
    const result = editor.get_selected_text(&buffer, &buffer_len);
    try testing.expect(result == true);
    try testing.expect(buffer_len == 5);
    try testing.expect(std.mem.eql(u8, buffer[0..5], "Hello"));
}

test "get selected text multi line" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Line 1");
    _ = editor.insert_text("\n");
    _ = editor.insert_text("Line 2");
    
    _ = editor.move_cursor(0, 0);
    editor.start_selection();
    _ = editor.move_cursor(1, 3);
    editor.extend_selection();
    
    var buffer: [256]u8 = undefined;
    var buffer_len: u32 = 0;
    const result = editor.get_selected_text(&buffer, &buffer_len);
    try testing.expect(result == true);
    try testing.expect(buffer_len > 0);
}

test "copy selection" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World!");
    _ = editor.move_cursor(0, 0);
    editor.start_selection();
    _ = editor.move_cursor(0, 5);
    editor.extend_selection();
    
    const result = editor.copy_selection();
    try testing.expect(result == true);
    try testing.expect(editor.clipboard_len == 5);
    try testing.expect(std.mem.eql(u8, editor.clipboard[0..5], "Hello"));
}

test "cut selection" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World!");
    _ = editor.move_cursor(0, 0);
    editor.start_selection();
    _ = editor.move_cursor(0, 5);
    editor.extend_selection();
    
    const result = editor.cut_selection();
    try testing.expect(result == true);
    try testing.expect(editor.clipboard_len == 5);
    try testing.expect(editor.lines[0].content_len == 8); // ", World!"
    try testing.expect(editor.has_selection() == false);
}

test "delete selection" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World!");
    _ = editor.move_cursor(0, 0);
    editor.start_selection();
    _ = editor.move_cursor(0, 5);
    editor.extend_selection();
    
    const result = editor.delete_selection();
    try testing.expect(result == true);
    try testing.expect(editor.lines[0].content_len == 8); // ", World!"
    try testing.expect(editor.has_selection() == false);
}

test "paste" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World!");
    _ = editor.move_cursor(0, 0);
    editor.start_selection();
    _ = editor.move_cursor(0, 5);
    editor.extend_selection();
    _ = editor.copy_selection();
    
    _ = editor.move_cursor(0, 13);
    const result = editor.paste();
    try testing.expect(result == true);
    try testing.expect(editor.lines[0].content_len == 18); // "Hello, World!Hello"
}

test "paste replaces selection" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    _ = editor.insert_text("Hello, World!");
    _ = editor.move_cursor(0, 0);
    editor.start_selection();
    _ = editor.move_cursor(0, 5);
    editor.extend_selection();
    _ = editor.copy_selection();
    
    // Select different text
    _ = editor.move_cursor(0, 7);
    editor.start_selection();
    _ = editor.move_cursor(0, 12);
    editor.extend_selection();
    
    const result = editor.paste();
    try testing.expect(result == true);
    try testing.expect(editor.has_selection() == false);
}

test "is zig file" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.zig");
    const result = editor.is_zig_file();
    try testing.expect(result == true);
}

test "is not zig file" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.txt");
    const result = editor.is_zig_file();
    try testing.expect(result == false);
}

test "toggle syntax highlighting" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    try testing.expect(editor.syntax_highlighting_enabled == true);
    editor.toggle_syntax_highlighting();
    try testing.expect(editor.syntax_highlighting_enabled == false);
    editor.toggle_syntax_highlighting();
    try testing.expect(editor.syntax_highlighting_enabled == true);
}

test "highlight zig line keywords" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.zig");
    const line = "const x = 42;";
    var tokens: [256]SyntaxToken = undefined;
    var tokens_len: u32 = 0;

    const result = editor.highlight_zig_line(line, &tokens, &tokens_len);
    try testing.expect(result == true);
    try testing.expect(tokens_len >= 1);
    try testing.expect(tokens[0].token_type == .keyword);
    try testing.expect(tokens[0].start == 0);
    try testing.expect(tokens[0].end == 5); // "const"
}

test "highlight zig line string literal" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.zig");
    const line = "const s = \"hello\";";
    var tokens: [256]SyntaxToken = undefined;
    var tokens_len: u32 = 0;

    const result = editor.highlight_zig_line(line, &tokens, &tokens_len);
    try testing.expect(result == true);
    try testing.expect(tokens_len >= 2);
    
    // Find string literal token
    var found_string = false;
    var i: u32 = 0;
    while (i < tokens_len) : (i += 1) {
        if (tokens[i].token_type == .string_literal) {
            found_string = true;
            try testing.expect(tokens[i].start == 10); // "\"hello\""
            try testing.expect(tokens[i].end == 17);
            break;
        }
    }
    try testing.expect(found_string == true);
}

test "highlight zig line comment" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.zig");
    const line = "const x = 42; // This is a comment";
    var tokens: [256]SyntaxToken = undefined;
    var tokens_len: u32 = 0;

    const result = editor.highlight_zig_line(line, &tokens, &tokens_len);
    try testing.expect(result == true);
    try testing.expect(tokens_len >= 1);
    
    // Last token should be comment
    const last_token = tokens[tokens_len - 1];
    try testing.expect(last_token.token_type == .comment);
    try testing.expect(last_token.start == 13); // "// This is a comment"
}

test "highlight zig line number literal" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.zig");
    const line = "const x = 42;";
    var tokens: [256]SyntaxToken = undefined;
    var tokens_len: u32 = 0;

    const result = editor.highlight_zig_line(line, &tokens, &tokens_len);
    try testing.expect(result == true);
    
    // Find number literal token
    var found_number = false;
    var i: u32 = 0;
    while (i < tokens_len) : (i += 1) {
        if (tokens[i].token_type == .number_literal) {
            found_number = true;
            try testing.expect(tokens[i].start == 10); // "42"
            try testing.expect(tokens[i].end == 12);
            break;
        }
    }
    try testing.expect(found_number == true);
}

test "highlight zig line empty" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.zig");
    const line = "";
    var tokens: [256]SyntaxToken = undefined;
    var tokens_len: u32 = 0;

    const result = editor.highlight_zig_line(line, &tokens, &tokens_len);
    try testing.expect(result == true);
    try testing.expect(tokens_len == 0);
}

test "highlight zig line multiple keywords" {
    const allocator = testing.allocator;
    var editor = TextEditor.init(allocator);

    _ = editor.open_file("/test/file.zig");
    const line = "pub fn main() void {";
    var tokens: [256]SyntaxToken = undefined;
    var tokens_len: u32 = 0;

    const result = editor.highlight_zig_line(line, &tokens, &tokens_len);
    try testing.expect(result == true);
    try testing.expect(tokens_len >= 2);
    
    // Check for "pub" and "fn" keywords
    var found_pub = false;
    var found_fn = false;
    var i: u32 = 0;
    while (i < tokens_len) : (i += 1) {
        if (tokens[i].token_type == .keyword) {
            if (tokens[i].start == 0 and tokens[i].end == 3) {
                found_pub = true;
            } else if (tokens[i].start == 4 and tokens[i].end == 6) {
                found_fn = true;
            }
        }
    }
    try testing.expect(found_pub == true);
    try testing.expect(found_fn == true);
}
