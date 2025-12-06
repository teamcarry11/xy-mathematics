//! Test: Grain Skate Line Buffer Adapter
//!
//! Tests the line buffer adapter that wraps GrainBuffer with line-based API.

const std = @import("std");
const LineBufferAdapter = @import("grain_skate").LineBufferAdapter;

test "line buffer adapter init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "line1\nline2\nline3";
    var adapter = try LineBufferAdapter.init(allocator, content);
    defer adapter.deinit();

    try std.testing.expectEqual(@as(u32, 3), adapter.lines_len);
    try std.testing.expectEqualStrings("line1", adapter.lines[0]);
    try std.testing.expectEqualStrings("line2", adapter.lines[1]);
    try std.testing.expectEqualStrings("line3", adapter.lines[2]);
}

test "line buffer adapter get_content" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "line1\nline2\nline3";
    var adapter = try LineBufferAdapter.init(allocator, content);
    defer adapter.deinit();

    const retrieved = try adapter.get_content();
    defer allocator.free(retrieved);
    try std.testing.expectEqualStrings(content, retrieved);
}

test "line buffer adapter replace_line" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "line1\nline2\nline3";
    var adapter = try LineBufferAdapter.init(allocator, content);
    defer adapter.deinit();

    try adapter.replace_line(1, "newline2");
    try std.testing.expectEqualStrings("newline2", adapter.lines[1]);

    const retrieved = try adapter.get_content();
    defer allocator.free(retrieved);
    try std.testing.expectEqualStrings("line1\nnewline2\nline3", retrieved);
}

test "line buffer adapter remove_line" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "line1\nline2\nline3";
    var adapter = try LineBufferAdapter.init(allocator, content);
    defer adapter.deinit();

    try adapter.remove_line(1);
    try std.testing.expectEqual(@as(u32, 2), adapter.lines_len);
    try std.testing.expectEqualStrings("line1", adapter.lines[0]);
    try std.testing.expectEqualStrings("line3", adapter.lines[1]);

    const retrieved = try adapter.get_content();
    defer allocator.free(retrieved);
    try std.testing.expectEqualStrings("line1\nline3", retrieved);
}

test "line buffer adapter empty lines" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "line1\n\nline3";
    var adapter = try LineBufferAdapter.init(allocator, content);
    defer adapter.deinit();

    try std.testing.expectEqual(@as(u32, 3), adapter.lines_len);
    try std.testing.expectEqualStrings("line1", adapter.lines[0]);
    try std.testing.expectEqualStrings("", adapter.lines[1]);
    try std.testing.expectEqualStrings("line3", adapter.lines[2]);
}

test "line buffer adapter trailing newline" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const content = "line1\nline2\n";
    var adapter = try LineBufferAdapter.init(allocator, content);
    defer adapter.deinit();

    try std.testing.expectEqual(@as(u32, 3), adapter.lines_len);
    try std.testing.expectEqualStrings("line1", adapter.lines[0]);
    try std.testing.expectEqualStrings("line2", adapter.lines[1]);
    try std.testing.expectEqualStrings("", adapter.lines[2]);
}

