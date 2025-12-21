//! Graincard Format Validation Test
//! Why: Ensure all graincards meet 103×80 character specification.
//! Grain Style: Explicit types (u32/u64), comprehensive assertions, bounded allocations.

const std = @import("std");
const testing = std.testing;

// Maximum graincard dimensions.
const MAX_GRAINCARD_WIDTH: u32 = 103;
const MAX_GRAINCARD_HEIGHT: u32 = 80;

// Validate graincard dimensions.
fn validate_graincard_dimensions(
    content: []const u8,
) !void {
    var lines: u32 = 0;
    var max_width: u32 = 0;
    var current_width: u32 = 0;
    
    for (content) |char| {
        if (char == '\n') {
            lines += 1;
            if (current_width > max_width) {
                max_width = current_width;
            }
            current_width = 0;
        } else {
            current_width += 1;
        }
    }
    
    // Handle last line if no trailing newline.
    if (current_width > 0) {
        lines += 1;
        if (current_width > max_width) {
            max_width = current_width;
        }
    }
    
    // Assert dimensions.
    try testing.expect(max_width <= MAX_GRAINCARD_WIDTH);
    try testing.expect(lines <= MAX_GRAINCARD_HEIGHT);
}

// Test: Valid graincard (exactly 103×80).
test "graincard_valid_exact_dimensions" {
    var content: [MAX_GRAINCARD_WIDTH * MAX_GRAINCARD_HEIGHT]u8 = undefined;
    var content_len: u32 = 0;
    
    // Fill with 103×80 content.
    var line: u32 = 0;
    while (line < MAX_GRAINCARD_HEIGHT) : (line += 1) {
        var col: u32 = 0;
        while (col < MAX_GRAINCARD_WIDTH) : (col += 1) {
            content[content_len] = 'x';
            content_len += 1;
        }
        if (line < MAX_GRAINCARD_HEIGHT - 1) {
            content[content_len] = '\n';
            content_len += 1;
        }
    }
    
    try validate_graincard_dimensions(content[0..content_len]);
}

// Test: Valid graincard (smaller than max).
test "graincard_valid_smaller_dimensions" {
    const content = "hello world\nthis is a test\n";
    try validate_graincard_dimensions(content);
}

// Test: Invalid graincard (too wide).
test "graincard_invalid_too_wide" {
    var content: [MAX_GRAINCARD_WIDTH + 10]u8 = undefined;
    var content_len: u32 = 0;
    
    // Create line wider than max.
    var col: u32 = 0;
    while (col < MAX_GRAINCARD_WIDTH + 1) : (col += 1) {
        content[content_len] = 'x';
        content_len += 1;
    }
    
    try testing.expectError(
        error.TestExpectedTrue,
        validate_graincard_dimensions(content[0..content_len]),
    );
}

// Test: Invalid graincard (too tall).
test "graincard_invalid_too_tall" {
    var content: [(MAX_GRAINCARD_WIDTH + 1) * (MAX_GRAINCARD_HEIGHT + 1)]u8 = undefined;
    var content_len: u32 = 0;
    
    // Create more lines than max.
    var line: u32 = 0;
    while (line < MAX_GRAINCARD_HEIGHT + 1) : (line += 1) {
        var col: u32 = 0;
        while (col < MAX_GRAINCARD_WIDTH) : (col += 1) {
            content[content_len] = 'x';
            content_len += 1;
        }
        if (line < MAX_GRAINCARD_HEIGHT) {
            content[content_len] = '\n';
            content_len += 1;
        }
    }
    
    try testing.expectError(
        error.TestExpectedTrue,
        validate_graincard_dimensions(content[0..content_len]),
    );
}

// Test: Empty graincard (valid).
test "graincard_valid_empty" {
    const content = "";
    try validate_graincard_dimensions(content);
}

// Test: Single line graincard (valid if <= 103 chars).
test "graincard_valid_single_line" {
    var content: [MAX_GRAINCARD_WIDTH]u8 = undefined;
    var content_len: u32 = 0;
    
    var col: u32 = 0;
    while (col < MAX_GRAINCARD_WIDTH) : (col += 1) {
        content[content_len] = 'x';
        content_len += 1;
    }
    
    try validate_graincard_dimensions(content[0..content_len]);
}
