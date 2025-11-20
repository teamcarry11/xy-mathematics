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

    // 1. Top Border
    try buffer.append(allocator, config.border_top_bottom);
    var i: usize = 0;
    while (i < config.content_width) : (i += 1) {
        try buffer.append(allocator, config.border_horizontal);
    }
    try buffer.append(allocator, config.border_top_bottom);
    try buffer.append(allocator, '\n');

    // 2. Content Sections
    // Helper to process and pad each section
    try append_padded_section(allocator, &buffer, content.header, config, false);
    try append_padded_section(allocator, &buffer, content.stalk_visual, config, true); // Center the stalk
    try append_padded_section(allocator, &buffer, content.metrics_box, config, false);
    
    // Footer needs special handling to be bottom-aligned if we were doing full height,
    // but for now we just append it.
    try append_padded_section(allocator, &buffer, content.footer, config, true); // Center footer

    // 3. Bottom Border
    try buffer.append(allocator, config.border_top_bottom);
    i = 0;
    while (i < config.content_width) : (i += 1) {
        try buffer.append(allocator, config.border_horizontal);
    }
    try buffer.append(allocator, config.border_top_bottom);
    try buffer.append(allocator, '\n');

    return buffer.toOwnedSlice(allocator);
}

fn append_padded_section(
    allocator: std.mem.Allocator,
    buffer: *std.ArrayList(u8),
    content: []const u8,
    config: types.GraincardConfig,
    center: bool,
) !void {
    var it = std.mem.splitScalar(u8, content, '\n');
    while (it.next()) |line| {
        // Skip empty lines at start/end if they are just artifacts of string literals
        if (line.len == 0) continue;

        try buffer.append(allocator, config.border_char);
        
        // Calculate padding
        var visible_len: usize = 0;
        // TODO: Handle UTF-8 length properly if we use fancy chars
        visible_len = line.len;

        if (visible_len > config.content_width) {
            // Truncate if too long (shouldn't happen with good generation)
            try buffer.appendSlice(allocator, line[0..config.content_width]);
        } else {
            const padding = config.content_width - visible_len;
            if (center) {
                const left_pad = padding / 2;
                const right_pad = padding - left_pad;
                try append_spaces(allocator, buffer, left_pad);
                try buffer.appendSlice(allocator, line);
                try append_spaces(allocator, buffer, right_pad);
            } else {
                // Left align
                try buffer.appendSlice(allocator, line);
                try append_spaces(allocator, buffer, padding);
            }
        }

        try buffer.append(allocator, config.border_char);
        try buffer.append(allocator, '\n');
    }
}

fn append_spaces(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8), count: usize) !void {
    var i: usize = 0;
    while (i < count) : (i += 1) {
        try buffer.append(allocator, ' ');
    }
}
