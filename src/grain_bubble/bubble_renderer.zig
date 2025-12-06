//! Grain Bubble Renderer: Render rounded shapes ("bubbles").
//!
//! Why: Render design elements with rounded corners.
//! Architecture: Vector graphics rendering via framebuffer.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-05-143400-pst: Grain Bubble Agent

const std = @import("std");
const canvas = @import("canvas.zig");

// Bounded: Max corner radius (pixels).
pub const MAX_CORNER_RADIUS: u32 = 100;

// Bounded: Circle approximation segments.
pub const CIRCLE_SEGMENTS: u32 = 32;

// Bubble renderer: renders shapes to framebuffer.
pub const BubbleRenderer = struct {
    framebuffer_width: u32,
    framebuffer_height: u32,

    pub fn init(width: u32, height: u32) BubbleRenderer {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        var renderer = BubbleRenderer{
            .framebuffer_width = width,
            .framebuffer_height = height,
        };
        std.debug.assert(renderer.framebuffer_width > 0);
        std.debug.assert(renderer.framebuffer_height > 0);
        return renderer;
    }

    // Render rounded rectangle ("bubble").
    pub fn render_rounded_rect(
        self: *const BubbleRenderer,
        x: i32,
        y: i32,
        width: u32,
        height: u32,
        color: u32,
        corner_radius: f64,
        draw_fn: *const fn (u32, u32, u32) void,
    ) void {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        std.debug.assert(corner_radius >= 0.0);
        std.debug.assert(@intFromPtr(draw_fn) != 0);
        const radius = @as(u32, @intFromFloat(corner_radius));
        if (radius == 0) {
            // Simple rectangle.
            self.render_rect(x, y, width, height, color, draw_fn);
            return;
        }
        const clamped_radius = @min(radius, MAX_CORNER_RADIUS);
        const clamped_radius_f = @as(f64, @floatFromInt(clamped_radius));
        // Render rounded rectangle (simplified: draw main rect + corners).
        // For Phase 1, we'll use a simplified approach.
        self.render_rect(x, y, width, height, color, draw_fn);
        // TODO: Add proper rounded corner rendering in future iteration.
    }

    // Render rectangle.
    pub fn render_rect(
        self: *const BubbleRenderer,
        x: i32,
        y: i32,
        width: u32,
        height: u32,
        color: u32,
        draw_fn: *const fn (u32, u32, u32) void,
    ) void {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        std.debug.assert(@intFromPtr(draw_fn) != 0);
        const start_y = if (y < 0) 0 else @as(u32, @intCast(y));
        const end_y = if (@as(u32, @intCast(y)) + height > self.framebuffer_height)
            self.framebuffer_height
        else
            @as(u32, @intCast(y)) + height;
        var py: u32 = start_y;
        while (py < end_y) : (py += 1) {
            const start_x = if (x < 0) 0 else @as(u32, @intCast(x));
            const end_x = if (@as(u32, @intCast(x)) + width > self.framebuffer_width)
                self.framebuffer_width
            else
                @as(u32, @intCast(x)) + width;
            var px: u32 = start_x;
            while (px < end_x) : (px += 1) {
                draw_fn(px, py, color);
            }
        }
    }

    // Render circle.
    pub fn render_circle(
        self: *const BubbleRenderer,
        center_x: i32,
        center_y: i32,
        radius: u32,
        color: u32,
        draw_fn: *const fn (u32, u32, u32) void,
    ) void {
        std.debug.assert(radius > 0);
        std.debug.assert(@intFromPtr(draw_fn) != 0);
        const center_x_f = @as(f64, @floatFromInt(center_x));
        const center_y_f = @as(f64, @floatFromInt(center_y));
        const radius_f = @as(f64, @floatFromInt(radius));
        // Render circle using midpoint algorithm (simplified).
        var angle: f64 = 0.0;
        const angle_step = (2.0 * std.math.pi) / @as(f64, @floatFromInt(CIRCLE_SEGMENTS));
        var i: u32 = 0;
        while (i < CIRCLE_SEGMENTS) : (i += 1) {
            const px = @as(i32, @intFromFloat(center_x_f + radius_f * std.math.cos(angle)));
            const py = @as(i32, @intFromFloat(center_y_f + radius_f * std.math.sin(angle)));
            if (px >= 0 and @as(u32, @intCast(px)) < self.framebuffer_width and
                py >= 0 and @as(u32, @intCast(py)) < self.framebuffer_height)
            {
                draw_fn(@as(u32, @intCast(px)), @as(u32, @intCast(py)), color);
            }
            angle += angle_step;
        }
        // Fill circle (simplified: draw lines from center to edge).
        // TODO: Add proper circle fill in future iteration.
    }

    // Render shape from canvas.
    pub fn render_shape(
        self: *const BubbleRenderer,
        shape: *const canvas.Shape,
        viewport: *const canvas.Viewport,
        draw_fn: *const fn (u32, u32, u32) void,
    ) void {
        std.debug.assert(@intFromPtr(shape) != 0);
        std.debug.assert(@intFromPtr(viewport) != 0);
        std.debug.assert(@intFromPtr(draw_fn) != 0);
        const screen_x = @as(i32, @intFromFloat(
            (shape.x + viewport.pan_x) * viewport.zoom,
        ));
        const screen_y = @as(i32, @intFromFloat(
            (shape.y + viewport.pan_y) * viewport.zoom,
        ));
        const screen_width = @as(u32, @intFromFloat(shape.width * viewport.zoom));
        const screen_height = @as(u32, @intFromFloat(shape.height * viewport.zoom));
        switch (shape.shape_type) {
            .rectangle => {
                self.render_rect(screen_x, screen_y, screen_width, screen_height, shape.color, draw_fn);
            },
            .circle => {
                const radius = @min(screen_width, screen_height) / 2;
                const center_x = screen_x + @as(i32, @intCast(screen_width / 2));
                const center_y = screen_y + @as(i32, @intCast(screen_height / 2));
                self.render_circle(center_x, center_y, radius, shape.color, draw_fn);
            },
            .rounded_rectangle => {
                const corner_radius = shape.corner_radius * viewport.zoom;
                self.render_rounded_rect(
                    screen_x,
                    screen_y,
                    screen_width,
                    screen_height,
                    shape.color,
                    corner_radius,
                    draw_fn,
                );
            },
        }
    }
};
