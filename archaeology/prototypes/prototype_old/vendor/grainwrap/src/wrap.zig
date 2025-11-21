//! wrap: line wrapping logic
//!
//! How do we wrap code to fit within constraints? This module
//! handles intelligent line breaking while preserving readability.

const std = @import("std");
const types = @import("types.zig");

// Wrap code to fit within maximum width.
//
// Takes source code and wraps lines that exceed max_width. Preserves
// indentation and tries to break at logical points (operators,
// commas, etc.).
//
// Why return owned memory? Wrapped code is a new string. We need to
// allocate space for it. The caller is responsible for freeing.
pub fn wrap(
    allocator: std.mem.Allocator,
    code: []const u8,
    config: types.WrapConfig,
) ![]u8 {
    var result = std.ArrayList(u8){};
    try result.ensureTotalCapacity(allocator, code.len);
    errdefer result.deinit(allocator);

    var line_iter = std.mem.splitScalar(u8, code, '\n');

    while (line_iter.next()) |line| {
        if (line.len <= config.max_width) {
            // Line fits - add as-is
            try result.appendSlice(allocator, line);
            try result.append(allocator, '\n');
        } else {
            // Line too long - wrap it
            try wrap_line(allocator, &result, line, config);
        }
    }

    return try result.toOwnedSlice(allocator);
}

// Wrap a single line that exceeds max width.
//
// This is where the actual wrapping logic lives. We try to break
// at logical points: operators, commas, spaces. We preserve
// indentation from the original line.
fn wrap_line(
    allocator: std.mem.Allocator,
    result: *std.ArrayList(u8),
    line: []const u8,
    config: types.WrapConfig,
) !void {
    const indent_info = calculate_indent(line);
    const max_content_width = config.max_width - indent_info.len;

    var start: usize = 0;

    while (start < indent_info.content.len) {
        const remaining = indent_info.content.len - start;

        if (remaining <= max_content_width) {
            // Rest fits on one line
            try write_wrapped_line(
                result,
                allocator,
                indent_info.str,
                indent_info.content[start..],
            );
            break;
        }

        // Find a break point
        const break_at = find_break_point(
            indent_info.content,
            start,
            max_content_width,
            config,
        );

        // Write this segment
        try write_wrapped_line(
            result,
            allocator,
            indent_info.str,
            indent_info.content[start..break_at],
        );

        // Skip whitespace at break point
        start = skip_whitespace(indent_info.content, break_at);
    }
}

// Indentation information extracted from a line.
const IndentInfo = struct {
    str: []const u8,
    content: []const u8,
    len: usize,
};

// Calculate indentation from leading whitespace.
//
// Why separate this? It makes the indentation logic explicit and
// testable. We can verify indentation calculation independently.
fn calculate_indent(line: []const u8) IndentInfo {
    var indent: usize = 0;
    while (indent < line.len and
        std.ascii.isWhitespace(line[indent]))
    {
        indent += 1;
    }

    return IndentInfo{
        .str = line[0..indent],
        .content = line[indent..],
        .len = indent,
    };
}

// Find a good break point in content.
//
// Why separate this? Break point logic is complex. Isolating it
// makes the code easier to test and understand.
fn find_break_point(
    content: []const u8,
    start: usize,
    max_width: usize,
    config: types.WrapConfig,
) usize {
    var break_at: usize = start + max_width;

    // Try to break at operator or comma if configured
    if (config.break_on_operators) {
        break_at = find_operator_break(content, start, max_width);
    }

    // Try to break at space if no operator found
    if (break_at == start + max_width) {
        break_at = find_space_break(content, start, max_width);
    }

    return break_at;
}

// Find break point at operator or comma.
fn find_operator_break(
    content: []const u8,
    start: usize,
    max_width: usize,
) usize {
    var break_at: usize = start + max_width;
    const search_start = @max(start + max_width - 20, start);

    while (break_at > search_start) : (break_at -= 1) {
        const char = content[break_at];
        if (char == ',' or char == ';' or char == '+' or
            char == '-' or char == '*' or char == '/' or
            char == '=' or char == '|' or char == '&')
        {
            return break_at + 1;
        }
    }

    return start + max_width;
}

// Find break point at whitespace.
fn find_space_break(
    content: []const u8,
    start: usize,
    max_width: usize,
) usize {
    var break_at: usize = start + max_width;
    const search_start = @max(start + max_width - 20, start);

    while (break_at > search_start) : (break_at -= 1) {
        if (std.ascii.isWhitespace(content[break_at])) {
            return break_at + 1;
        }
    }

    return start + max_width;
}

// Write a wrapped line with indentation.
fn write_wrapped_line(
    result: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    indent: []const u8,
    content: []const u8,
) !void {
    try result.appendSlice(allocator, indent);
    try result.appendSlice(allocator, content);
    try result.append(allocator, '\n');
}

// Skip whitespace starting at position.
fn skip_whitespace(content: []const u8, pos: usize) usize {
    var result = pos;
    while (result < content.len and
        std.ascii.isWhitespace(content[result]))
    {
        result += 1;
    }
    return result;
}

