const std = @import("std");
const zigimg = @import("zigimg");
const font8x8 = @import("font8x8.zig");
const types = @import("types.zig");

pub const PngOptions = struct {
    scale: u8 = 1,
    background: u8 = 255, // White
    foreground: u8 = 0,   // Black
    include_borders: bool = true,
    stalk_only: bool = false,
};

pub fn ascii_to_png(
    allocator: std.mem.Allocator,
    ascii_art: []const u8,
    output_path: []const u8,
    options: PngOptions,
) !void {
    // 1. Parse ASCII art into lines to determine dimensions
    var lines: std.ArrayList([]const u8) = .{ .items = &.{}, .capacity = 0 };
    defer lines.deinit(allocator);

    var max_width: usize = 0;
    var it = std.mem.splitScalar(u8, ascii_art, '\n');
    while (it.next()) |line| {
        try lines.append(allocator, line);
        if (line.len > max_width) max_width = line.len;
    }

    // 2. Calculate image dimensions
    const char_w = font8x8.CHAR_WIDTH * options.scale;
    const char_h = font8x8.CHAR_HEIGHT * options.scale;
    const img_width = max_width * char_w;
    const img_height = lines.items.len * char_h;

    // 3. Create grayscale image
    var image = try zigimg.Image.create(allocator, img_width, img_height, .grayscale8);
    defer image.deinit(allocator);

    // Fill background
    const bg_color = zigimg.color.Grayscale8{ .value = options.background };
    const fg_color = zigimg.color.Grayscale8{ .value = options.foreground };

    for (image.pixels.grayscale8) |*pixel| {
        pixel.* = bg_color;
    }

    // 4. Render characters
    for (lines.items, 0..) |line, row| {
        for (line, 0..) |char, col| {
            const bitmap = font8x8.get_char_bitmap(char);
            
            // Render 8x8 bitmap with scaling
            var by: usize = 0;
            while (by < 8) : (by += 1) {
                var bx: usize = 0;
                while (bx < 8) : (bx += 1) {
                    // Check if bit is set (bits are stored MSB first)
                    const bit_set = (bitmap[by] & (@as(u8, 1) << @intCast(7 - bx))) != 0;
                    
                    if (bit_set) {
                        // Draw scaled pixel(s)
                        var sy: usize = 0;
                        while (sy < options.scale) : (sy += 1) {
                            var sx: usize = 0;
                            while (sx < options.scale) : (sx += 1) {
                                const px = (col * char_w) + (bx * options.scale) + sx;
                                const py = (row * char_h) + (by * options.scale) + sy;
                                
                                if (px < img_width and py < img_height) {
                                    const pixel_idx = py * img_width + px;
                                    image.pixels.grayscale8[pixel_idx] = fg_color;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 5. Write PNG file
    const write_buffer = try allocator.alloc(u8, 4096);
    defer allocator.free(write_buffer);
    try image.writeToFilePath(allocator, output_path, write_buffer, .{ .png = .{} });
}

pub fn graincard_to_png(
    allocator: std.mem.Allocator,
    content: types.GraincardContent,
    output_path: []const u8,
    options: PngOptions,
) !void {
    // Combine content based on options
    var full_content: std.ArrayList(u8) = .{ .items = &.{}, .capacity = 0 };
    defer full_content.deinit(allocator);

    if (options.stalk_only) {
        try full_content.appendSlice(allocator, content.stalk_visual);
    } else {
        // Full card assembly (simplified for now, similar to layout.zig but just text)
        // Note: layout.zig adds borders, here we assume content parts are raw text
        // If we want exact match, we should use the output of layout_graincard
        // But layout_graincard returns []u8, so we can just pass that in!
        
        // For now, let's assume the caller passes the fully laid out text if they want the full card.
        // If they pass raw content structs, we might need to layout it first.
        // Let's change the signature to take []const u8 (the final text)
        return error.UseAsciiToPngDirectly; 
    }

    try ascii_to_png(allocator, full_content.items, output_path, options);
}
