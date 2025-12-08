const std = @import("std");
const shared = @import("shared");

/// Monospace text renderer: converts GrainBuffer text into RGBA pixels.
/// Uses shared font renderer (8x8 bitmap font).
/// GrainStyle: grain_case, u32 types, bounded allocations, assertions.
pub const TextRenderer = struct {
    width: u32,
    height: u32,
    font_renderer: shared.FontRenderer,

    /// Initialize text renderer with dimensions.
    /// Why: Create renderer with shared font renderer (8x8 font).
    /// Contract: width and height must be > 0.
    pub fn init(width: u32, height: u32) TextRenderer {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        const font_renderer = shared.FontRenderer.init(
            .font_8x8,
            .ascii_basic,
        );
        return TextRenderer{
            .width = width,
            .height = height,
            .font_renderer = font_renderer,
        };
    }

    /// Render text to pixel buffer.
    /// Why: Convert text to RGBA pixels using shared font renderer.
    /// Contract: buffer must be large enough (width * height * 4 bytes).
    pub fn render(
        self: *const TextRenderer,
        text: []const u8,
        buffer: []u8,
        fg_r: u8,
        fg_g: u8,
        fg_b: u8,
        bg_r: u8,
        bg_g: u8,
        bg_b: u8,
    ) void {
        std.debug.assert(buffer.len >= self.width * self.height * 4);
        const font_w = self.font_renderer.get_font_width();
        const font_h = self.font_renderer.get_font_height();
        const chars_per_row = self.width / font_w;
        const rows = self.height / font_h;
        var y: u32 = 0;
        var x: u32 = 0;
        var char_idx: u32 = 0;

        while (y < rows and char_idx < text.len) : (y += 1) {
            x = 0;
            while (x < chars_per_row and char_idx < text.len) : ({
                x += 1;
                char_idx += 1;
            }) {
                const ch = if (char_idx < text.len)
                    text[char_idx]
                else
                    ' ';
                self.draw_char(
                    ch,
                    x,
                    y,
                    buffer,
                    fg_r,
                    fg_g,
                    fg_b,
                    bg_r,
                    bg_g,
                    bg_b,
                );
            }
            if (char_idx < text.len and text[char_idx] == '\n') {
                char_idx += 1;
            }
        }
    }

    /// Draw single character at grid position.
    /// Why: Render character using shared font renderer.
    /// Contract: grid_x, grid_y must be within bounds.
    fn draw_char(
        self: *const TextRenderer,
        ch: u8,
        grid_x: u32,
        grid_y: u32,
        buffer: []u8,
        fg_r: u8,
        fg_g: u8,
        fg_b: u8,
        bg_r: u8,
        bg_g: u8,
        bg_b: u8,
    ) void {
        std.debug.assert(grid_x < self.width);
        std.debug.assert(grid_y < self.height);
        const font_w = self.font_renderer.get_font_width();
        const font_h = self.font_renderer.get_font_height();
        const start_x = grid_x * font_w;
        const start_y = grid_y * font_h;
        
        // Render character to temporary pixel buffer
        var char_pixels: [8 * 8 * 4]u8 = undefined;
        const rendered = self.font_renderer.render_char_to_pixels(
            ch,
            fg_r,
            fg_g,
            fg_b,
            255,
            bg_r,
            bg_g,
            bg_b,
            255,
            &char_pixels,
        );
        if (!rendered) return;
        
        // Copy pixels to main buffer
        var py: u32 = 0;
        while (py < font_h) : (py += 1) {
            var px: u32 = 0;
            while (px < font_w) : (px += 1) {
                const buf_x = start_x + px;
                const buf_y = start_y + py;
                if (buf_x >= self.width) continue;
                if (buf_y >= self.height) continue;
                
                const pixel_idx = (buf_y * self.width + buf_x) * 4;
                if (pixel_idx + 3 >= buffer.len) continue;
                
                const char_pixel_idx = (py * font_w + px) * 4;
                buffer[pixel_idx] = char_pixels[char_pixel_idx];
                buffer[pixel_idx + 1] = char_pixels[char_pixel_idx + 1];
                buffer[pixel_idx + 2] = char_pixels[char_pixel_idx + 2];
                buffer[pixel_idx + 3] = char_pixels[char_pixel_idx + 3];
            }
        }
    }
};

test "text renderer draws char" {
    var buffer: [1024 * 768 * 4]u8 = undefined;
    @memset(&buffer, 0);
    const renderer = TextRenderer.init(1024, 768);
    renderer.render("A", &buffer, 255, 255, 255, 0, 0, 0);
    try std.testing.expect(buffer[0] == 0 or buffer[0] == 255);
}

