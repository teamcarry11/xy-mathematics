const std = @import("std");
const shared = @import("shared");
const FontRenderer = shared.FontRenderer;

test "font renderer initialization" {
    const renderer_5x7 = FontRenderer.init(.font_5x7, .ascii_alphanumeric);
    try std.testing.expect(renderer_5x7.font_size == .font_5x7);
    try std.testing.expect(renderer_5x7.char_set == .ascii_alphanumeric);
    try std.testing.expect(renderer_5x7.get_font_width() == 5);
    try std.testing.expect(renderer_5x7.get_font_height() == 7);
    try std.testing.expect(renderer_5x7.get_char_width() == 6);
    try std.testing.expect(renderer_5x7.get_char_height() == 8);
    const renderer_8x8 = FontRenderer.init(.font_8x8, .ascii_basic);
    try std.testing.expect(renderer_8x8.font_size == .font_8x8);
    try std.testing.expect(renderer_8x8.char_set == .ascii_basic);
    try std.testing.expect(renderer_8x8.get_font_width() == 8);
    try std.testing.expect(renderer_8x8.get_font_height() == 8);
    try std.testing.expect(renderer_8x8.get_char_width() == 9);
    try std.testing.expect(renderer_8x8.get_char_height() == 9);
}

// Note: get_char_pattern is internal, tested via render_char_to_pixels

test "font renderer render char to pixels 5x7" {
    const renderer = FontRenderer.init(.font_5x7, .ascii_alphanumeric);
    var pixel_buffer: [6 * 8 * 4]u8 = undefined;
    const success = renderer.render_char_to_pixels('A', 255, 255, 255, 255, 0, 0, 0, 255, &pixel_buffer);
    try std.testing.expect(success == true);
    // Check that at least some pixels are set (foreground color)
    var has_foreground = false;
    var i: u32 = 0;
    while (i < pixel_buffer.len) : (i += 4) {
        if (pixel_buffer[i] == 255 and pixel_buffer[i + 1] == 255 and pixel_buffer[i + 2] == 255) {
            has_foreground = true;
            break;
        }
    }
    try std.testing.expect(has_foreground == true);
}

test "font renderer render char to pixels 8x8" {
    const renderer = FontRenderer.init(.font_8x8, .ascii_basic);
    var pixel_buffer: [9 * 9 * 4]u8 = undefined;
    const success = renderer.render_char_to_pixels('A', 255, 255, 255, 255, 0, 0, 0, 255, &pixel_buffer);
    try std.testing.expect(success == true);
    // Check that at least some pixels are set (foreground color)
    var has_foreground = false;
    var i: u32 = 0;
    while (i < pixel_buffer.len) : (i += 4) {
        if (pixel_buffer[i] == 255 and pixel_buffer[i + 1] == 255 and pixel_buffer[i + 2] == 255) {
            has_foreground = true;
            break;
        }
    }
    try std.testing.expect(has_foreground == true);
}

test "font renderer render invalid char" {
    const renderer = FontRenderer.init(.font_5x7, .ascii_alphanumeric);
    var pixel_buffer: [6 * 8 * 4]u8 = undefined;
    const success = renderer.render_char_to_pixels(0, 255, 255, 255, 255, 0, 0, 0, 255, &pixel_buffer);
    try std.testing.expect(success == false);
}

