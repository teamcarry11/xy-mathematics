//! graincard: 75x100 monospace teaching cards
//!
//! pure zig, beautiful typography, ascii only
//!
//! "what if knowledge came in perfectly-sized cards?"

const std = @import("std");

// Constants
pub const CARD_WIDTH: u32 = 75;
pub const CARD_HEIGHT: u32 = 100;
pub const CONTENT_WIDTH: u32 = 73; // 75 - 2 (borders)
pub const MAX_CONTENT_LINES: u32 = 98; // 100 - 2 (top/bottom borders)

// ASCII box-drawing characters only
pub const BOX_TOP_LEFT: u8 = '+';
pub const BOX_TOP_RIGHT: u8 = '+';
pub const BOX_BOTTOM_LEFT: u8 = '+';
pub const BOX_BOTTOM_RIGHT: u8 = '+';
pub const BOX_HORIZONTAL: u8 = '-';
pub const BOX_VERTICAL: u8 = '|';
pub const BOX_TEE_LEFT: u8 = '+';
pub const BOX_TEE_RIGHT: u8 = '+';

// GrainCard metadata structure
pub const GrainCard = struct {
    grainorder: []const u8, // 6-char unique ID
    title: []const u8,
    content: []const u8,
    file_path: []const u8,
    live_url: []const u8,
    card_num: u32,
    total_cards: u32,
    author: []const u8,
    grainbook_name: []const u8,

    // Validate that all strings contain only ASCII characters
    pub fn validate_ascii(self: *const GrainCard) !void {
        try validate_ascii_string(self.grainorder, "grainorder");
        try validate_ascii_string(self.title, "title");
        try validate_ascii_string(self.content, "content");
        try validate_ascii_string(self.file_path, "file_path");
        try validate_ascii_string(self.live_url, "live_url");
        try validate_ascii_string(self.author, "author");
        try validate_ascii_string(self.grainbook_name, "grainbook_name");
    }
};

// Validate that a string contains only ASCII characters (0-127)
fn validate_ascii_string(s: []const u8, field_name: []const u8) !void {
    std.debug.assert(s.len > 0);
    std.debug.assert(field_name.len > 0);
    
    for (s, 0..) |byte, i| {
        if (byte > 127) {
            std.debug.panic(
                "non-ascii character at index {} in field '{}': 0x{x}",
                .{ i, field_name, byte },
            );
        }
    }
}

// Wrap a single line of text to max_width, preserving word boundaries
pub fn wrap_line(allocator: std.mem.Allocator, text: []const u8, max_width: u32) ![]const []const u8 {
    std.debug.assert(text.len > 0);
    std.debug.assert(max_width > 0);
    std.debug.assert(max_width <= CARD_WIDTH);
    
    // If text fits, return as single line
    if (text.len <= max_width) {
        const line = try allocator.dupe(u8, text);
        const lines = try allocator.alloc([]const u8, 1);
        lines[0] = line;
        return lines;
    }
    
    // Split into words and wrap
    var words = std.ArrayList([]const u8).init(allocator);
    defer words.deinit();
    
    var start: u32 = 0;
    while (start < text.len) {
        // Find next space or end
        var end = start;
        while (end < text.len and text[end] != ' ') {
            end += 1;
        }
        
        const word = text[start..end];
        if (word.len > 0) {
            try words.append(word);
        }
        
        start = if (end < text.len) end + 1 else text.len;
    }
    
    std.debug.assert(words.items.len > 0);
    
    // Build wrapped lines
    var lines = std.ArrayList([]const u8).init(allocator);
    var current_line = std.ArrayList(u8).init(allocator);
    defer current_line.deinit();
    
    for (words.items) |word| {
        std.debug.assert(word.len <= max_width);
        
        const test_len = if (current_line.items.len == 0)
            word.len
        else
            current_line.items.len + 1 + word.len;
        
        if (test_len <= max_width) {
            // Word fits, add to current line
            if (current_line.items.len > 0) {
                try current_line.append(' ');
            }
            try current_line.appendSlice(word);
        } else {
            // Word doesn't fit, start new line
            if (current_line.items.len > 0) {
                const line = try allocator.dupe(u8, current_line.items);
                try lines.append(line);
                current_line.clearRetainingCapacity();
            }
            try current_line.appendSlice(word);
        }
    }
    
    // Add final line
    if (current_line.items.len > 0) {
        const line = try allocator.dupe(u8, current_line.items);
        try lines.append(line);
    }
    
    std.debug.assert(lines.items.len > 0);
    return lines.toOwnedSlice();
}

// Wrap multiple lines (paragraphs) to max_width
pub fn wrap_text(allocator: std.mem.Allocator, text: []const u8, max_width: u32) ![]const []const u8 {
    std.debug.assert(text.len > 0);
    std.debug.assert(max_width > 0);
    
    var all_lines = std.ArrayList([]const u8).init(allocator);
    
    var start: u32 = 0;
    while (start < text.len) {
        // Find next newline or end
        var end = start;
        while (end < text.len and text[end] != '\n') {
            end += 1;
        }
        
        const line = text[start..end];
        if (line.len > 0) {
            const wrapped = try wrap_line(allocator, line, max_width);
            for (wrapped) |w| {
                try all_lines.append(w);
            }
            allocator.free(wrapped);
        } else {
            // Empty line (paragraph break)
            const empty = try allocator.dupe(u8, "");
            try all_lines.append(empty);
        }
        
        start = if (end < text.len) end + 1 else text.len;
    }
    
    return all_lines.toOwnedSlice();
}

// Pad a string to exactly n characters with spaces
fn pad_string(allocator: std.mem.Allocator, s: []const u8, n: u32) ![]const u8 {
    std.debug.assert(n > 0);
    std.debug.assert(n <= CARD_WIDTH);
    
    if (s.len >= n) {
        // Truncate if too long
        return try allocator.dupe(u8, s[0..n]);
    }
    
    // Pad with spaces
    var result = try allocator.alloc(u8, n);
    @memcpy(result[0..s.len], s);
    @memset(result[s.len..], ' ');
    return result;
}

// Create a box line with content (| content |)
fn box_line(allocator: std.mem.Allocator, content: []const u8) ![]const u8 {
    std.debug.assert(content.len <= CONTENT_WIDTH);
    
    const padded = try pad_string(allocator, content, CONTENT_WIDTH);
    defer allocator.free(padded);
    
    const line = try std.fmt.allocPrint(
        allocator,
        "{c} {s} {c}",
        .{ BOX_VERTICAL, padded, BOX_VERTICAL },
    );
    
    std.debug.assert(line.len == CARD_WIDTH);
    return line;
}

// Create a horizontal border line (+---...---+)
fn border_line(allocator: std.mem.Allocator, left: u8, right: u8) ![]const u8 {
    std.debug.assert(left == BOX_TOP_LEFT or left == BOX_BOTTOM_LEFT or left == BOX_TEE_LEFT);
    std.debug.assert(right == BOX_TOP_RIGHT or right == BOX_BOTTOM_RIGHT or right == BOX_TEE_RIGHT);
    
    var dashes: [CONTENT_WIDTH]u8 = undefined;
    @memset(&dashes, BOX_HORIZONTAL);
    
    const line = try std.fmt.allocPrint(
        allocator,
        "{c}{s}{c}",
        .{ left, &dashes, right },
    );
    
    std.debug.assert(line.len == CARD_WIDTH);
    return line;
}

// Generate the complete graincard document
pub fn generate_graincard(allocator: std.mem.Allocator, card: *const GrainCard) ![]const u8 {
    std.debug.assert(card.grainorder.len == 6);
    std.debug.assert(card.title.len > 0);
    std.debug.assert(card.content.len > 0);
    
    // Validate ASCII-only
    try card.validate_ascii();
    
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();
    
    // Header section (outside the box)
    const header = try std.fmt.allocPrint(
        allocator,
        "# graincard {s} - {s}\n\n**file**: {s}\n**live**: {s}\n\n```\n",
        .{ card.grainorder, card.title, card.file_path, card.live_url },
    );
    defer allocator.free(header);
    try output.appendSlice(header);
    
    // Top border
    const top_border = try border_line(allocator, BOX_TOP_LEFT, BOX_TOP_RIGHT);
    defer allocator.free(top_border);
    try output.appendSlice(top_border);
    try output.append('\n');
    
    // Box header line
    const header_line_text = try std.fmt.allocPrint(
        allocator,
        "GRAINCARD {s}                          Card {} of {}",
        .{ card.grainorder, card.card_num, card.total_cards },
    );
    defer allocator.free(header_line_text);
    const header_line = try box_line(allocator, header_line_text);
    defer allocator.free(header_line);
    try output.appendSlice(header_line);
    try output.append('\n');
    
    // Wrap content to CONTENT_WIDTH
    const wrapped_content = try wrap_text(allocator, card.content, CONTENT_WIDTH);
    defer {
        for (wrapped_content) |line| {
            allocator.free(line);
        }
        allocator.free(wrapped_content);
    }
    
    // Content lines
    var content_line_count: u32 = 0;
    for (wrapped_content) |line| {
        const boxed = try box_line(allocator, line);
        defer allocator.free(boxed);
        try output.appendSlice(boxed);
        try output.append('\n');
        content_line_count += 1;
    }
    
    // Calculate padding to reach MAX_CONTENT_LINES
    const current_lines = 2 + content_line_count; // header + content
    const padding_needed = if (current_lines < MAX_CONTENT_LINES)
        MAX_CONTENT_LINES - current_lines
    else
        0;
    
    std.debug.assert(current_lines + padding_needed <= MAX_CONTENT_LINES);
    
    // Add padding lines
    const empty_line = try box_line(allocator, "");
    defer allocator.free(empty_line);
    var i: u32 = 0;
    while (i < padding_needed) : (i += 1) {
        try output.appendSlice(empty_line);
        try output.append('\n');
    }
    
    // Divider
    const divider = try border_line(allocator, BOX_TEE_LEFT, BOX_TEE_RIGHT);
    defer allocator.free(divider);
    try output.appendSlice(divider);
    try output.append('\n');
    
    // Footer lines
    const footer1_text = try std.fmt.allocPrint(allocator, "grainbook: {s}", .{card.grainbook_name});
    defer allocator.free(footer1_text);
    const footer1 = try box_line(allocator, footer1_text);
    defer allocator.free(footer1);
    try output.appendSlice(footer1);
    try output.append('\n');
    
    const footer2_text = try std.fmt.allocPrint(
        allocator,
        "card: {s} ({} of {})",
        .{ card.grainorder, card.card_num, card.total_cards },
    );
    defer allocator.free(footer2_text);
    const footer2 = try box_line(allocator, footer2_text);
    defer allocator.free(footer2);
    try output.appendSlice(footer2);
    try output.append('\n');
    
    const footer3_text = "now == next + 1";
    const footer3 = try box_line(allocator, footer3_text);
    defer allocator.free(footer3);
    try output.appendSlice(footer3);
    try output.append('\n');
    
    // Bottom border
    const bottom_border = try border_line(allocator, BOX_BOTTOM_LEFT, BOX_BOTTOM_RIGHT);
    defer allocator.free(bottom_border);
    try output.appendSlice(bottom_border);
    try output.append('\n');
    
    // Closing code fence
    try output.appendSlice("```\n");
    
    return output.toOwnedSlice();
}

// Validate that a graincard string meets the 75x100 spec
pub fn validate_graincard(allocator: std.mem.Allocator, card_str: []const u8) !ValidationResult {
    std.debug.assert(card_str.len > 0);
    
    var errors = std.ArrayList([]const u8).init(allocator);
    defer {
        for (errors.items) |err| {
            allocator.free(err);
        }
        errors.deinit();
    }
    
    // Split into lines
    var lines = std.ArrayList([]const u8).init(allocator);
    defer {
        for (lines.items) |line| {
            allocator.free(line);
        }
        lines.deinit();
    }
    
    var start: u32 = 0;
    while (start < card_str.len) {
        var end = start;
        while (end < card_str.len and card_str[end] != '\n') {
            end += 1;
        }
        
        const line = try allocator.dupe(u8, card_str[start..end]);
        try lines.append(line);
        
        start = if (end < card_str.len) end + 1 else card_str.len;
    }
    
    // Check total line count (should be 102: header + box + fences)
    const expected_lines: u32 = 102;
    if (lines.items.len != expected_lines) {
        const err = try std.fmt.allocPrint(
            allocator,
            "total lines: {} (expected {})",
            .{ lines.items.len, expected_lines },
        );
        try errors.append(err);
    }
    
    // Check box content width (should be CARD_WIDTH)
    for (lines.items, 0..) |line, i| {
        // Skip header and fence lines
        if (i < 5 or i >= lines.items.len - 1) continue;
        
        // Validate ASCII-only
        for (line) |byte| {
            if (byte > 127) {
                const err = try std.fmt.allocPrint(
                    allocator,
                    "line {}: non-ascii character 0x{x}",
                    .{ i + 1, byte },
                );
                try errors.append(err);
                break;
            }
        }
        
        // Check width for box lines
        if (line.len > 0 and (line[0] == BOX_VERTICAL or line[0] == BOX_TOP_LEFT or line[0] == BOX_BOTTOM_LEFT)) {
            if (line.len != CARD_WIDTH) {
                const err = try std.fmt.allocPrint(
                    allocator,
                    "line {}: width {} chars (expected {})",
                    .{ i + 1, line.len, CARD_WIDTH },
                );
                try errors.append(err);
            }
        }
    }
    
    if (errors.items.len == 0) {
        return ValidationResult{ .ok = "valid graincard!" };
    } else {
        const err_msgs = try errors.toOwnedSlice();
        return ValidationResult{ .err = err_msgs };
    }
}

pub const ValidationResult = union(enum) {
    ok: []const u8,
    err: []const []const u8,
};

// Save graincard to file
pub fn save_graincard(allocator: std.mem.Allocator, card: *const GrainCard, filename: []const u8) !bool {
    std.debug.assert(filename.len > 0);
    
    const card_str = try generate_graincard(allocator, card);
    defer allocator.free(card_str);
    
    const validation = try validate_graincard(allocator, card_str);
    defer {
        switch (validation) {
            .ok => {},
            .err => |errs| {
                for (errs) |err| {
                    allocator.free(err);
                }
                allocator.free(errs);
            },
        }
    }
    
    switch (validation) {
        .ok => {
            // Write to file
            try std.fs.cwd().writeFile(filename, card_str);
            return true;
        },
        .err => |errs| {
            std.debug.print("validation failed:\n", .{});
            for (errs) |err| {
                std.debug.print("  {s}\n", .{err});
            }
            return false;
        },
    }
}

