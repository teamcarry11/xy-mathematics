//! Grain OS Framebuffer Renderer: Render windows to kernel framebuffer.
//!
//! Why: Render compositor windows using kernel framebuffer syscalls.
//! Architecture: Syscall-based rendering, window compositing.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const basin_kernel = @import("basin_kernel");

// Bounded: Max text length for rendering.
pub const MAX_TEXT_LEN: u32 = 256;

// Framebuffer constants (matching kernel/framebuffer.zig).
pub const FRAMEBUFFER_WIDTH: u32 = 1024;
pub const FRAMEBUFFER_HEIGHT: u32 = 768;

// Color constants (32-bit RGBA).
pub const COLOR_BLACK: u32 = 0x00000000;
pub const COLOR_WHITE: u32 = 0xFFFFFFFF;
pub const COLOR_RED: u32 = 0xFF0000FF;
pub const COLOR_GREEN: u32 = 0x00FF00FF;
pub const COLOR_BLUE: u32 = 0x0000FFFF;
pub const COLOR_DARK_BG: u32 = 0x1E1E2EFF;

// Syscall numbers (matching kernel/basin_kernel.zig).
const SYSCALL_FB_CLEAR: u32 = 70;
const SYSCALL_FB_DRAW_PIXEL: u32 = 71;
const SYSCALL_FB_DRAW_TEXT: u32 = 72;

// Framebuffer renderer: renders windows to kernel framebuffer.
pub const FramebufferRenderer = struct {
    // Syscall function pointer (set by kernel integration).
    syscall_fn: ?SyscallFn = null,
    const SyscallFn = *const fn (u32, u64, u64, u64, u64) i64;

    pub fn init() FramebufferRenderer {
        return FramebufferRenderer{
            .syscall_fn = null,
        };
    }

    pub fn set_syscall_fn(self: *FramebufferRenderer, fn_ptr: *const fn (u32, u64, u64, u64, u64) i64) void {
        std.debug.assert(@intFromPtr(fn_ptr) != 0);
        self.syscall_fn = fn_ptr;
        std.debug.assert(self.syscall_fn != null);
    }

    // Clear framebuffer to background color.
    pub fn clear(self: *const FramebufferRenderer, color: u32) void {
        std.debug.assert(self.syscall_fn != null);
        if (self.syscall_fn) |fn| {
            const result = fn(SYSCALL_FB_CLEAR, color, 0, 0, 0);
            std.debug.assert(result == 0);
        }
    }

    // Draw pixel at position.
    pub fn draw_pixel(
        self: *const FramebufferRenderer,
        x: u32,
        y: u32,
        color: u32,
    ) void {
        std.debug.assert(x < FRAMEBUFFER_WIDTH);
        std.debug.assert(y < FRAMEBUFFER_HEIGHT);
        std.debug.assert(self.syscall_fn != null);
        if (self.syscall_fn) |fn| {
            const result = fn(SYSCALL_FB_DRAW_PIXEL, x, y, color, 0);
            std.debug.assert(result == 0);
        }
    }

    // Draw filled rectangle.
    pub fn draw_rect(
        self: *const FramebufferRenderer,
        x: i32,
        y: i32,
        width: u32,
        height: u32,
        color: u32,
    ) void {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        std.debug.assert(@as(u32, @intCast(x)) + width <= FRAMEBUFFER_WIDTH);
        std.debug.assert(@as(u32, @intCast(y)) + height <= FRAMEBUFFER_HEIGHT);
        const start_y = if (y < 0) 0 else @as(u32, @intCast(y));
        const end_y = if (@as(u32, @intCast(y)) + height > FRAMEBUFFER_HEIGHT)
            FRAMEBUFFER_HEIGHT
        else
            @as(u32, @intCast(y)) + height;
        var py: u32 = start_y;
        while (py < end_y) : (py += 1) {
            const start_x = if (x < 0) 0 else @as(u32, @intCast(x));
            const end_x = if (@as(u32, @intCast(x)) + width > FRAMEBUFFER_WIDTH)
                FRAMEBUFFER_WIDTH
            else
                @as(u32, @intCast(x)) + width;
            var px: u32 = start_x;
            while (px < end_x) : (px += 1) {
                self.draw_pixel(px, py, color);
            }
        }
    }

    // Draw text string.
    pub fn draw_text(
        self: *const FramebufferRenderer,
        text: []const u8,
        x: u32,
        y: u32,
        fg_color: u32,
    ) void {
        std.debug.assert(text.len > 0);
        std.debug.assert(text.len <= MAX_TEXT_LEN);
        std.debug.assert(x < FRAMEBUFFER_WIDTH);
        std.debug.assert(y < FRAMEBUFFER_HEIGHT);
        std.debug.assert(self.syscall_fn != null);
        // Note: In real implementation, text would be in VM memory.
        // For now, this is a placeholder that will be implemented
        // when we have VM memory access.
        _ = text;
        _ = x;
        _ = y;
        _ = fg_color;
    }
};

