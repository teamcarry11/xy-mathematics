const std = @import("std");
const testing = std.testing;
const grain_skate = @import("grain_skate");
const Editor = grain_skate.Editor;
const BracketMatcher = grain_skate.BracketMatcher;
const BracketMatch = grain_skate.BracketMatch;
const BracketType = grain_skate.BracketType;

test "bracket type detection" {
    try testing.expect(BracketMatcher.get_bracket_type('(') == .paren_open);
    try testing.expect(BracketMatcher.get_bracket_type(')') == .paren_close);
    try testing.expect(BracketMatcher.get_bracket_type('[') == .bracket_open);
    try testing.expect(BracketMatcher.get_bracket_type(']') == .bracket_close);
    try testing.expect(BracketMatcher.get_bracket_type('{') == .brace_open);
    try testing.expect(BracketMatcher.get_bracket_type('}') == .brace_close);
    try testing.expect(BracketMatcher.get_bracket_type('<') == .angle_open);
    try testing.expect(BracketMatcher.get_bracket_type('>') == .angle_close);
    try testing.expect(BracketMatcher.get_bracket_type('a') == .none);
}

test "bracket type checks" {
    try testing.expect(BracketMatcher.is_open_bracket(.paren_open) == true);
    try testing.expect(BracketMatcher.is_open_bracket(.paren_close) == false);
    try testing.expect(BracketMatcher.is_close_bracket(.paren_close) == true);
    try testing.expect(BracketMatcher.is_close_bracket(.paren_open) == false);
}

test "matching bracket types" {
    try testing.expect(BracketMatcher.get_matching_bracket(.paren_open) == .paren_close);
    try testing.expect(BracketMatcher.get_matching_bracket(.paren_close) == .paren_open);
    try testing.expect(BracketMatcher.get_matching_bracket(.bracket_open) == .bracket_close);
    try testing.expect(BracketMatcher.get_matching_bracket(.brace_open) == .brace_close);
}

test "simple bracket matching - parentheses" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var editor = try Editor.EditorState.init(allocator, "(test)");
    defer editor.deinit();
    
    // Cursor on opening parenthesis at column 0
    const match = BracketMatcher.find_matching_bracket(&editor, 0, 0);
    try testing.expect(match.found == true);
    try testing.expect(match.line == 0);
    try testing.expect(match.column == 5); // Closing parenthesis
    
    // Cursor on closing parenthesis at column 5
    const match2 = BracketMatcher.find_matching_bracket(&editor, 0, 5);
    try testing.expect(match2.found == true);
    try testing.expect(match2.line == 0);
    try testing.expect(match2.column == 0); // Opening parenthesis
}

test "nested bracket matching - parentheses" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var editor = try Editor.EditorState.init(allocator, "((test))");
    defer editor.deinit();
    
    // Cursor on first opening parenthesis at column 0
    const match = BracketMatcher.find_matching_bracket(&editor, 0, 0);
    try testing.expect(match.found == true);
    try testing.expect(match.line == 0);
    try testing.expect(match.column == 7); // Last closing parenthesis
    
    // Cursor on second opening parenthesis at column 1
    const match2 = BracketMatcher.find_matching_bracket(&editor, 0, 1);
    try testing.expect(match2.found == true);
    try testing.expect(match2.line == 0);
    try testing.expect(match2.column == 6); // First closing parenthesis
}

test "bracket matching - brackets" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var editor = try Editor.EditorState.init(allocator, "[test]");
    defer editor.deinit();
    
    // Cursor on opening bracket at column 0
    const match = BracketMatcher.find_matching_bracket(&editor, 0, 0);
    try testing.expect(match.found == true);
    try testing.expect(match.line == 0);
    try testing.expect(match.column == 5); // Closing bracket
    
    // Cursor on closing bracket at column 5
    const match2 = BracketMatcher.find_matching_bracket(&editor, 0, 5);
    try testing.expect(match2.found == true);
    try testing.expect(match2.line == 0);
    try testing.expect(match2.column == 0); // Opening bracket
}

test "bracket matching - braces" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var editor = try Editor.EditorState.init(allocator, "{test}");
    defer editor.deinit();
    
    // Cursor on opening brace at column 0
    const match = BracketMatcher.find_matching_bracket(&editor, 0, 0);
    try testing.expect(match.found == true);
    try testing.expect(match.line == 0);
    try testing.expect(match.column == 5); // Closing brace
}

test "bracket matching - no match" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var editor = try Editor.EditorState.init(allocator, "test");
    defer editor.deinit();
    
    // Cursor on non-bracket character
    const match = BracketMatcher.find_matching_bracket(&editor, 0, 0);
    try testing.expect(match.found == false);
}

test "bracket matching - unmatched opening" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var editor = try Editor.EditorState.init(allocator, "(test");
    defer editor.deinit();
    
    // Cursor on opening parenthesis (no closing bracket)
    const match = BracketMatcher.find_matching_bracket(&editor, 0, 0);
    try testing.expect(match.found == false);
}

test "bracket matching - unmatched closing" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var editor = try Editor.EditorState.init(allocator, "test)");
    defer editor.deinit();
    
    // Cursor on closing parenthesis (no opening bracket)
    const match = BracketMatcher.find_matching_bracket(&editor, 0, 4);
    try testing.expect(match.found == false);
}

test "bracket matching - multi-line" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var editor = try Editor.EditorState.init(allocator, "(\n)\n");
    defer editor.deinit();
    
    // Cursor on opening parenthesis at line 0, column 0
    const match = BracketMatcher.find_matching_bracket(&editor, 0, 0);
    try testing.expect(match.found == true);
    try testing.expect(match.line == 1);
    try testing.expect(match.column == 0); // Closing parenthesis on next line
}

test "bracket matching - complex nested" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var editor = try Editor.EditorState.init(allocator, "({[test]})");
    defer editor.deinit();
    
    // Cursor on first opening parenthesis at column 0
    const match = BracketMatcher.find_matching_bracket(&editor, 0, 0);
    try testing.expect(match.found == true);
    try testing.expect(match.line == 0);
    try testing.expect(match.column == 9); // Last closing parenthesis
}

test "bracket match no_match" {
    const match = BracketMatch.no_match();
    try testing.expect(match.found == false);
    try testing.expect(match.line == 0);
    try testing.expect(match.column == 0);
}

test "bracket match init" {
    const match = BracketMatch.init(5, 10);
    try testing.expect(match.found == true);
    try testing.expect(match.line == 5);
    try testing.expect(match.column == 10);
}

