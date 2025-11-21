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
        const r: u8 = @truncate((color >> 24) & 0xFF);
        const g: u8 = @truncate((color >> 16) & 0xFF);
        const b: u8 = @truncate((color >> 8) & 0xFF);
        const a: u8 = @truncate(color & 0xFF);

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
        const r: u8 = @truncate((color >> 24) & 0xFF);
        const g: u8 = @truncate((color >> 16) & 0xFF);
        const b: u8 = @truncate((color >> 8) & 0xFF);
        const a: u8 = @truncate(color & 0xFF);

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
        std.debug.assert(self.memory[(y * self.width + x) * self.bpp] == @truncate((color >> 24) & 0xFF));
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
};

