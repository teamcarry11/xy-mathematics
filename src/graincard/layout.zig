const std = @import("std");
const types = @import("types.zig");

// Graincard Layout Engine
// Handles 75x100 graincard assembly with 1-char borders

pub fn create_border(
    allocator: std.mem.Allocator,
    width: usize,
    height: usize,
) ![]u8 {
    var buffer: std.ArrayList(u8) = .{ .items = &.{}, .capacity = 0 };
    defer buffer.deinit(allocator);

    // Top border
    try buffer.append(allocator, '+');
    var i: usize = 0;
    while (i < width - 2) : (i += 1) {
        try buffer.append(allocator, '-');
    }
    try buffer.append(allocator, '+');
    try buffer.append(allocator, '\n');

    // Middle rows
    var row: usize = 0;
    while (row < height - 2) : (row += 1) {
        try buffer.append(allocator, '|');
        var col: usize = 0;
        while (col < width - 2) : (col += 1) {
            try buffer.append(allocator, ' ');
        }
        try buffer.append(allocator, '|');
        try buffer.append(allocator, '\n');
    }

    // Bottom border
    try buffer.append(allocator, '+');
    i = 0;
    while (i < width - 2) : (i += 1) {
        try buffer.append(allocator, '-');
    }
    try buffer.append(allocator, '+');
    try buffer.append(allocator, '\n');

    return buffer.toOwnedSlice(allocator);
}

pub fn wrap_content(
    allocator: std.mem.Allocator,
    content: []const u8,
    max_width: usize,
) ![][]u8 {
    var lines: std.ArrayList([]u8) = .{ .items = &.{}, .capacity = 0 };
    errdefer {
        for (lines.items) |line| allocator.free(line);
        lines.deinit(allocator);
    }

    var line_start: usize = 0;
    var i: usize = 0;

    while (i < content.len) {
        if (content[i] == '\n' or i - line_start >= max_width) {
            const line = try allocator.dupe(
                u8,
                content[line_start..i],
            );
            try lines.append(allocator, line);
            line_start = i + 1;
        }
        i += 1;
    }

    // Add remaining content
    if (line_start < content.len) {
        const line = try allocator.dupe(
            u8,
            content[line_start..],
        );
        try lines.append(allocator, line);
    }

    return lines.toOwnedSlice(allocator);
}

pub fn layout_graincard(
    allocator: std.mem.Allocator,
    config: types.GraincardConfig,
    content: types.GraincardContent,
) ![]u8 {
    var buffer: std.ArrayList(u8) = .{ .items = &.{}, .capacity = 0 };
    errdefer buffer.deinit(allocator);

    // Top border
    try buffer.append(allocator, '+');
    var i: usize = 0;
    while (i < config.content_width) : (i += 1) {
        try buffer.append(allocator, '-');
    }
    try buffer.append(allocator, '+');
    try buffer.append(allocator, '\n');

    // Simplified: just append all content sections directly
    // Each section should already be formatted correctly
    try buffer.appendSlice(allocator, content.header);
    try buffer.appendSlice(allocator, content.stalk_visual);
    try buffer.appendSlice(allocator, content.metrics_box);
    try buffer.appendSlice(allocator, content.footer);

    // Bottom border
    try buffer.append(allocator, '+');
    i = 0;
    while (i < config.content_width) : (i += 1) {
        try buffer.append(allocator, '-');
    }
    try buffer.append(allocator, '+');
    try buffer.append(allocator, '\n');

    return buffer.toOwnedSlice(allocator);
}
