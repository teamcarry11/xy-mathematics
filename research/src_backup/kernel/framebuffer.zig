//! framebuffer: simple framebuffer driver for Grain Basin Kernel
//!
//! Why: Provide basic pixel-level drawing for GUI display.
//! GrainStyle: Static allocation, explicit limits, comprehensive assertions.

const std = @import("std");

// Framebuffer constants
pub const FRAMEBUFFER_BASE: u64 = 0x90000000;
pub const FRAMEBUFFER_WIDTH: u32 = 1024;
pub const FRAMEBUFFER_HEIGHT: u32 = 768;
pub const FRAMEBUFFER_BPP: u32 = 4; // 32-bit RGBA
pub const FRAMEBUFFER_SIZE: u32 = FRAMEBUFFER_WIDTH * FRAMEBUFFER_HEIGHT * FRAMEBUFFER_BPP; // 3MB

// Color constants (32-bit RGBA)
pub const COLOR_BLACK: u32 = 0x00000000;
pub const COLOR_WHITE: u32 = 0xFFFFFFFF;
pub const COLOR_RED: u32 = 0xFF0000FF;
pub const COLOR_GREEN: u32 = 0x00FF00FF;
pub const COLOR_BLUE: u32 = 0x0000FFFF;
pub const COLOR_DARK_BG: u32 = 0x1E1E2EFF; // Dark background color

// Framebuffer state
pub const Framebuffer = struct {
    base: u64,
    width: u32,
    height: u32,
    bpp: u32,
    memory: []u8,

    // Initialize framebuffer
    // Why: Set up framebuffer state and clear to background color.
    pub fn init(memory: []u8) Framebuffer {
        std.debug.assert(memory.len >= FRAMEBUFFER_SIZE);
        std.debug.assert(FRAMEBUFFER_WIDTH > 0);
        std.debug.assert(FRAMEBUFFER_HEIGHT > 0);
        std.debug.assert(FRAMEBUFFER_BPP == 4);

        const fb = Framebuffer{
            .base = FRAMEBUFFER_BASE,
            .width = FRAMEBUFFER_WIDTH,
            .height = FRAMEBUFFER_HEIGHT,
            .bpp = FRAMEBUFFER_BPP,
            .memory = memory[0..FRAMEBUFFER_SIZE],
        };

        // Assert: framebuffer must be initialized correctly.
        std.debug.assert(fb.width == FRAMEBUFFER_WIDTH);
        std.debug.assert(fb.height == FRAMEBUFFER_HEIGHT);
        std.debug.assert(fb.memory.len == FRAMEBUFFER_SIZE);

        return fb;
    }

    // Clear framebuffer to a color
    // Why: Fill entire framebuffer with a single color (e.g., background).
    pub fn clear(self: *const Framebuffer, color: u32) void {
        std.debug.assert(self.memory.len == FRAMEBUFFER_SIZE);

        // Convert 32-bit RGBA color to bytes
        const r: u8 = @as(u8, @truncate((color >> 24) & 0xFF));
        const g: u8 = @as(u8, @truncate((color >> 16) & 0xFF));
        const b: u8 = @as(u8, @truncate((color >> 8) & 0xFF));
        const a: u8 = @as(u8, @truncate(color & 0xFF));

        // Fill framebuffer with color (RGBA format)
        var i: u32 = 0;
        while (i < FRAMEBUFFER_SIZE) : (i += 4) {
            self.memory[i + 0] = r;
            self.memory[i + 1] = g;
            self.memory[i + 2] = b;
            self.memory[i + 3] = a;
        }

        // Assert: framebuffer must be filled (check first and last pixel).
        std.debug.assert(self.memory[0] == r);
        std.debug.assert(self.memory[FRAMEBUFFER_SIZE - 4] == r);
    }

    // Draw a single pixel
    // Why: Basic pixel-level drawing primitive.
    pub fn draw_pixel(self: *const Framebuffer, x: u32, y: u32, color: u32) void {
        std.debug.assert(x < self.width);
        std.debug.assert(y < self.height);
        std.debug.assert(self.memory.len == FRAMEBUFFER_SIZE);

        // Calculate pixel offset (RGBA format, row-major order)
        const offset: u32 = (y * self.width + x) * self.bpp;
        std.debug.assert(offset + 3 < FRAMEBUFFER_SIZE);

        // Convert 32-bit RGBA color to bytes
        const r: u8 = @as(u8, @truncate((color >> 24) & 0xFF));
        const g: u8 = @as(u8, @truncate((color >> 16) & 0xFF));
        const b: u8 = @as(u8, @truncate((color >> 8) & 0xFF));
        const a: u8 = @as(u8, @truncate(color & 0xFF));

        // Write pixel (RGBA format)
        self.memory[offset + 0] = r;
        self.memory[offset + 1] = g;
        self.memory[offset + 2] = b;
        self.memory[offset + 3] = a;

        // Assert: pixel must be written correctly.
        std.debug.assert(self.memory[offset + 0] == r);
    }

    // Draw a filled rectangle
    // Why: Common drawing primitive for UI elements.
    pub fn draw_rect(self: *const Framebuffer, x: u32, y: u32, w: u32, h: u32, color: u32) void {
        std.debug.assert(x < self.width);
        std.debug.assert(y < self.height);
        std.debug.assert(x + w <= self.width);
        std.debug.assert(y + h <= self.height);
        std.debug.assert(w > 0);
        std.debug.assert(h > 0);

        var py: u32 = y;
        while (py < y + h) : (py += 1) {
            var px: u32 = x;
            while (px < x + w) : (px += 1) {
                self.draw_pixel(px, py, color);
            }
        }

        // Assert: rectangle must be drawn (check corners).
        std.debug.assert(self.memory[(y * self.width + x) * self.bpp] == @as(u8, @truncate((color >> 24) & 0xFF)));
    }

    // Draw a test pattern
    // Why: Visual verification that framebuffer is working.
    pub fn draw_test_pattern(self: *const Framebuffer) void {
        std.debug.assert(self.memory.len == FRAMEBUFFER_SIZE);

        // Clear to dark background
        self.clear(COLOR_DARK_BG);

        // Draw colored rectangles
        const rect_size: u32 = 100;
        const spacing: u32 = 20;

        // Red rectangle (top-left)
        self.draw_rect(spacing, spacing, rect_size, rect_size, COLOR_RED);

        // Green rectangle (top-right)
        self.draw_rect(self.width - rect_size - spacing, spacing, rect_size, rect_size, COLOR_GREEN);

        // Blue rectangle (bottom-left)
        self.draw_rect(spacing, self.height - rect_size - spacing, rect_size, rect_size, COLOR_BLUE);

        // White rectangle (bottom-right)
        self.draw_rect(self.width - rect_size - spacing, self.height - rect_size - spacing, rect_size, rect_size, COLOR_WHITE);

        // Assert: test pattern must be drawn (check first red pixel).
        const red_offset: u32 = (spacing * self.width + spacing) * self.bpp;
        std.debug.assert(self.memory[red_offset] == 0xFF);
    }

    // Draw a single character using 8x8 bitmap font
    // Why: Basic text rendering primitive for kernel messages.
    // GrainStyle: Explicit bounds checking, deterministic rendering.
    pub fn draw_char(self: *const Framebuffer, ch: u8, x: u32, y: u32, fg_color: u32, bg_color: u32) void {
        // Assert: character position must be within bounds.
        std.debug.assert(x + 8 <= self.width);
        std.debug.assert(y + 8 <= self.height);
        
        // Get character pattern (8x8 bitmap, 64 bits).
        const pattern = get_char_pattern(ch);
        
        // Extract foreground and background colors.
        const fg_r: u8 = @truncate((fg_color >> 24) & 0xFF);
        const fg_g: u8 = @truncate((fg_color >> 16) & 0xFF);
        const fg_b: u8 = @truncate((fg_color >> 8) & 0xFF);
        const bg_r: u8 = @truncate((bg_color >> 24) & 0xFF);
        const bg_g: u8 = @truncate((bg_color >> 16) & 0xFF);
        const bg_b: u8 = @truncate((bg_color >> 8) & 0xFF);
        
        // Draw character (8x8 pixels).
        var py: u32 = 0;
        while (py < 8) : (py += 1) {
            var px: u32 = 0;
            while (px < 8) : (px += 1) {
                const bit_idx = py * 8 + px;
                const bit = (pattern >> @as(u6, @intCast(63 - bit_idx))) & 1;
                
                const pixel_x = x + px;
                const pixel_y = y + py;
                const offset: u32 = (pixel_y * self.width + pixel_x) * self.bpp;
                
                // Assert: offset must be within bounds.
                std.debug.assert(offset + 3 < FRAMEBUFFER_SIZE);
                
                if (bit == 1) {
                    // Foreground color
                    self.memory[offset + 0] = fg_r;
                    self.memory[offset + 1] = fg_g;
                    self.memory[offset + 2] = fg_b;
                } else {
                    // Background color
                    self.memory[offset + 0] = bg_r;
                    self.memory[offset + 1] = bg_g;
                    self.memory[offset + 2] = bg_b;
                }
                self.memory[offset + 3] = 0xFF; // Alpha
            }
        }
    }
    
    // Draw text string at position
    // Why: Render kernel boot messages and status text.
    // GrainStyle: Explicit bounds checking, deterministic rendering.
    pub fn draw_text(self: *const Framebuffer, text: []const u8, x: u32, y: u32, fg_color: u32, bg_color: u32) void {
        // Assert: text must not be empty.
        std.debug.assert(text.len > 0);
        
        // Assert: starting position must be within bounds.
        std.debug.assert(x < self.width);
        std.debug.assert(y < self.height);
        
        var char_x: u32 = x;
        var char_y: u32 = y;
        const char_width: u32 = 8;
        const char_height: u32 = 8;
        
        var i: u32 = 0;
        while (i < text.len) : (i += 1) {
            const ch = text[i];
            
            // Handle newline.
            if (ch == '\n') {
                char_x = x;
                char_y += char_height;
                continue;
            }
            
            // Assert: character position must be within bounds.
            if (char_x + char_width > self.width) {
                // Wrap to next line.
                char_x = x;
                char_y += char_height;
            }
            
            // Assert: character must fit vertically.
            if (char_y + char_height > self.height) {
                break; // Out of bounds, stop rendering.
            }
            
            // Draw character.
            self.draw_char(ch, char_x, char_y, fg_color, bg_color);
            char_x += char_width;
        }
    }
    
    // Get 8x8 bitmap pattern for character
    // Why: Simple bitmap font for kernel text rendering.
    // Pattern is row-major, MSB first (top-left to bottom-right).
    fn get_char_pattern(ch: u8) u64 {
        return switch (ch) {
            ' ' => 0x0000000000000000,
            '!' => 0x1818181818001800,
            '"' => 0x3636000000000000,
            '#' => 0x36367F36367F3636,
            '$' => 0x0C3E033E301F0C00,
            '%' => 0x006333180C666300,
            '&' => 0x1C361C6E3B331E00,
            '\'' => 0x0C0C180000000000,
            '(' => 0x0C18181818180C00,
            ')' => 0x180C0C0C0C0C1800,
            '*' => 0x00183C7E3C180000,
            '+' => 0x000018187E181800,
            ',' => 0x0000000000180C18,
            '-' => 0x000000007E000000,
            '.' => 0x0000000000181800,
            '/' => 0x303018180C0C0606,
            '0' => 0x3C666E7E76663C00,
            '1' => 0x1818381818187E00,
            '2' => 0x3C66060C18307E00,
            '3' => 0x3C66061C06663C00,
            '4' => 0x060E1E367F060600,
            '5' => 0x7E607C0606663C00,
            '6' => 0x1C30607C66663C00,
            '7' => 0x7E060C1818181800,
            '8' => 0x3C66663C66663C00,
            '9' => 0x3C66663E060C3800,
            ':' => 0x0000180000180000,
            ';' => 0x0000180000180C18,
            '<' => 0x000C1830180C0000,
            '=' => 0x00007E00007E0000,
            '>' => 0x00180C060C180000,
            '?' => 0x3C66060C18001800,
            '@' => 0x3C66766E60663C00,
            'A' => 0x183C66667E666600,
            'B' => 0x7C66667C66667C00,
            'C' => 0x3C66606060663C00,
            'D' => 0x786C6666666C7800,
            'E' => 0x7E60607C60607E00,
            'F' => 0x7E60607C60606000,
            'G' => 0x3C66606E66663C00,
            'H' => 0x6666667E66666600,
            'I' => 0x3C18181818183C00,
            'J' => 0x1E0C0C0C6C6C3800,
            'K' => 0x666C78786C666600,
            'L' => 0x6060606060607E00,
            'M' => 0x63777F6B63636300,
            'N' => 0x66767E7E6E666600,
            'O' => 0x3C66666666663C00,
            'P' => 0x7C66667C60606000,
            'Q' => 0x3C6666666E3C0600,
            'R' => 0x7C66667C6C666600,
            'S' => 0x3C603C06063C00,
            'T' => 0x7E18181818181800,
            'U' => 0x6666666666663C00,
            'V' => 0x66666666663C1800,
            'W' => 0x63636B7F77636300,
            'X' => 0x66663C183C666600,
            'Y' => 0x6666663C18181800,
            'Z' => 0x7E060C1830607E00,
            '[' => 0x3C30303030303C00,
            '\\' => 0x06060C0C18183030,
            ']' => 0x3C0C0C0C0C0C3C00,
            '^' => 0x183C660000000000,
            '_' => 0x0000000000007E00,
            '`' => 0x18180C0000000000,
            'a' => 0x00003C063E663E00,
            'b' => 0x60607C6666667C00,
            'c' => 0x00003C6660603C00,
            'd' => 0x06063E6666663E00,
            'e' => 0x00003C667E603C00,
            'f' => 0x1C30307C30303000,
            'g' => 0x00003E66663E063C,
            'h' => 0x60607C6666666600,
            'i' => 0x1800181818181800,
            'j' => 0x0C000C0C0C6C3800,
            'k' => 0x6060666C786C6600,
            'l' => 0x1818181818181800,
            'm' => 0x0000767F6B636300,
            'n' => 0x00007C6666666600,
            'o' => 0x00003C6666663C00,
            'p' => 0x00007C66667C6060,
            'q' => 0x00003E66663E0606,
            'r' => 0x00007C6660606000,
            's' => 0x00003E603C067C00,
            't' => 0x30307C3030301C00,
            'u' => 0x0000666666663E00,
            'v' => 0x00006666663C1800,
            'w' => 0x0000636B7F360000,
            'x' => 0x0000663C183C6600,
            'y' => 0x00006666663E063C,
            'z' => 0x00007E0C18307E00,
            '{' => 0x0C18187018180C00,
            '|' => 0x1818180018181800,
            '}' => 0x3018180E18183000,
            '~' => 0x0000003E6C000000,
            else => 0x7E8185B581817E00, // fallback: box
        };
    }
};

