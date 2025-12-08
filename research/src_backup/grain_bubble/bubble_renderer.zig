//! Grain Bubble Renderer: Render rounded shapes ("bubbles").
//!
//! Why: Render design elements with rounded corners.
//! Architecture: Vector graphics rendering via framebuffer.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-055154-pst: Grain Bubble Agent

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
        const renderer = BubbleRenderer{
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
        const radius_squared = clamped_radius_f * clamped_radius_f;
        const x_f = @as(f64, @floatFromInt(x));
        const y_f = @as(f64, @floatFromInt(y));
        const width_f = @as(f64, @floatFromInt(width));
        const height_f = @as(f64, @floatFromInt(height));
        // Corner centers.
        const top_left_cx = x_f + clamped_radius_f;
        const top_left_cy = y_f + clamped_radius_f;
        const top_right_cx = x_f + width_f - clamped_radius_f;
        const top_right_cy = y_f + clamped_radius_f;
        const bottom_left_cx = x_f + clamped_radius_f;
        const bottom_left_cy = y_f + height_f - clamped_radius_f;
        const bottom_right_cx = x_f + width_f - clamped_radius_f;
        const bottom_right_cy = y_f + height_f - clamped_radius_f;
        // Render main body (excluding corner areas).
        const start_y = if (y < 0) 0 else @as(u32, @intCast(y));
        const end_y = if (@as(u32, @intCast(y)) + height > self.framebuffer_height)
            self.framebuffer_height
        else
            @as(u32, @intCast(y)) + height;
        var py: u32 = start_y;
        while (py < end_y) : (py += 1) {
            const py_f = @as(f64, @floatFromInt(py));
            const start_x = if (x < 0) 0 else @as(u32, @intCast(x));
            const end_x = if (@as(u32, @intCast(x)) + width > self.framebuffer_width)
                self.framebuffer_width
            else
                @as(u32, @intCast(x)) + width;
            var px: u32 = start_x;
            while (px < end_x) : (px += 1) {
                const px_f = @as(f64, @floatFromInt(px));
                var should_draw = true;
                // Check if pixel is in corner exclusion zones.
                if (px_f < top_left_cx and py_f < top_left_cy) {
                    // Top-left corner.
                    const dx = px_f - top_left_cx;
                    const dy = py_f - top_left_cy;
                    if (dx * dx + dy * dy > radius_squared) {
                        should_draw = false;
                    }
                } else if (px_f >= top_right_cx and py_f < top_right_cy) {
                    // Top-right corner.
                    const dx = px_f - top_right_cx;
                    const dy = py_f - top_right_cy;
                    if (dx * dx + dy * dy > radius_squared) {
                        should_draw = false;
                    }
                } else if (px_f < bottom_left_cx and py_f >= bottom_left_cy) {
                    // Bottom-left corner.
                    const dx = px_f - bottom_left_cx;
                    const dy = py_f - bottom_left_cy;
                    if (dx * dx + dy * dy > radius_squared) {
                        should_draw = false;
                    }
                } else if (px_f >= bottom_right_cx and py_f >= bottom_right_cy) {
                    // Bottom-right corner.
                    const dx = px_f - bottom_right_cx;
                    const dy = py_f - bottom_right_cy;
                    if (dx * dx + dy * dy > radius_squared) {
                        should_draw = false;
                    }
                }
                if (should_draw) {
                    draw_fn(px, py, color);
                }
            }
        }
        // Render corner quarter-circles.
        self.render_quarter_circle(
            @as(i32, @intFromFloat(top_left_cx)),
            @as(i32, @intFromFloat(top_left_cy)),
            clamped_radius,
            color,
            .top_left,
            draw_fn,
        );
        self.render_quarter_circle(
            @as(i32, @intFromFloat(top_right_cx)),
            @as(i32, @intFromFloat(top_right_cy)),
            clamped_radius,
            color,
            .top_right,
            draw_fn,
        );
        self.render_quarter_circle(
            @as(i32, @intFromFloat(bottom_left_cx)),
            @as(i32, @intFromFloat(bottom_left_cy)),
            clamped_radius,
            color,
            .bottom_left,
            draw_fn,
        );
        self.render_quarter_circle(
            @as(i32, @intFromFloat(bottom_right_cx)),
            @as(i32, @intFromFloat(bottom_right_cy)),
            clamped_radius,
            color,
            .bottom_right,
            draw_fn,
        );
    }

    // Quarter circle corner type.
    const QuarterCorner = enum {
        top_left,
        top_right,
        bottom_left,
        bottom_right,
    };

    // Render quarter circle (for rounded rectangle corners).
    fn render_quarter_circle(
        self: *const BubbleRenderer,
        center_x: i32,
        center_y: i32,
        radius: u32,
        color: u32,
        corner: QuarterCorner,
        draw_fn: *const fn (u32, u32, u32) void,
    ) void {
        std.debug.assert(radius > 0);
        std.debug.assert(@intFromPtr(draw_fn) != 0);
        const center_x_f = @as(f64, @floatFromInt(center_x));
        const center_y_f = @as(f64, @floatFromInt(center_y));
        const radius_f = @as(f64, @floatFromInt(radius));
        const radius_squared = radius_f * radius_f;
        const radius_i = @as(i32, @intCast(radius));
        // Determine bounding box based on corner type.
        const start_x_i: i32 = switch (corner) {
            .top_left, .bottom_left => center_x - radius_i,
            .top_right, .bottom_right => center_x,
        };
        const end_x_i: i32 = switch (corner) {
            .top_left, .bottom_left => center_x,
            .top_right, .bottom_right => center_x + radius_i,
        };
        const start_y_i: i32 = switch (corner) {
            .top_left, .top_right => center_y - radius_i,
            .bottom_left, .bottom_right => center_y,
        };
        const end_y_i: i32 = switch (corner) {
            .top_left, .top_right => center_y,
            .bottom_left, .bottom_right => center_y + radius_i,
        };
        const start_x = @max(0, start_x_i);
        const end_x = @min(@as(i32, @intCast(self.framebuffer_width)), end_x_i);
        const start_y = @max(0, start_y_i);
        const end_y = @min(@as(i32, @intCast(self.framebuffer_height)), end_y_i);
        var py: i32 = start_y;
        while (py < end_y) : (py += 1) {
            var px: i32 = start_x;
            while (px < end_x) : (px += 1) {
                const px_f = @as(f64, @floatFromInt(px));
                const py_f = @as(f64, @floatFromInt(py));
                const dx = px_f - center_x_f;
                const dy = py_f - center_y_f;
                const distance_squared = dx * dx + dy * dy;
                if (distance_squared <= radius_squared) {
                    draw_fn(@as(u32, @intCast(px)), @as(u32, @intCast(py)), color);
                }
            }
        }
    }

    // Render rectangle (filled).
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

    // Render rectangle stroke (outline only).
    pub fn render_rect_stroke(
        self: *const BubbleRenderer,
        x: i32,
        y: i32,
        width: u32,
        height: u32,
        stroke_width: u32,
        stroke_color: u32,
        draw_fn: *const fn (u32, u32, u32) void,
    ) void {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        std.debug.assert(stroke_width > 0);
        std.debug.assert(@intFromPtr(draw_fn) != 0);
        const clamped_stroke = @min(stroke_width, width / 2);
        const clamped_stroke_h = @min(stroke_width, height / 2);
        // Top edge.
        var i: u32 = 0;
        while (i < clamped_stroke_h) : (i += 1) {
            const py = if (y + @as(i32, @intCast(i)) < 0) 0 else @as(u32, @intCast(y + @as(i32, @intCast(i))));
            if (py < self.framebuffer_height) {
                var px: u32 = if (x < 0) 0 else @as(u32, @intCast(x));
                const end_x = if (@as(u32, @intCast(x)) + width > self.framebuffer_width)
                    self.framebuffer_width
                else
                    @as(u32, @intCast(x)) + width;
                while (px < end_x) : (px += 1) {
                    draw_fn(px, py, stroke_color);
                }
            }
        }
        // Bottom edge.
        i = 0;
        while (i < clamped_stroke_h) : (i += 1) {
            const py = @as(u32, @intCast(y)) + height - clamped_stroke_h + i;
            if (py < self.framebuffer_height) {
                var px: u32 = if (x < 0) 0 else @as(u32, @intCast(x));
                const end_x = if (@as(u32, @intCast(x)) + width > self.framebuffer_width)
                    self.framebuffer_width
                else
                    @as(u32, @intCast(x)) + width;
                while (px < end_x) : (px += 1) {
                    draw_fn(px, py, stroke_color);
                }
            }
        }
        // Left edge.
        i = 0;
        while (i < clamped_stroke) : (i += 1) {
            const px = if (x + @as(i32, @intCast(i)) < 0) 0 else @as(u32, @intCast(x + @as(i32, @intCast(i))));
            if (px < self.framebuffer_width) {
                var py: u32 = if (y < 0) 0 else @as(u32, @intCast(y));
                const end_y = if (@as(u32, @intCast(y)) + height > self.framebuffer_height)
                    self.framebuffer_height
                else
                    @as(u32, @intCast(y)) + height;
                while (py < end_y) : (py += 1) {
                    draw_fn(px, py, stroke_color);
                }
            }
        }
        // Right edge.
        i = 0;
        while (i < clamped_stroke) : (i += 1) {
            const px = @as(u32, @intCast(x)) + width - clamped_stroke + i;
            if (px < self.framebuffer_width) {
                var py: u32 = if (y < 0) 0 else @as(u32, @intCast(y));
                const end_y = if (@as(u32, @intCast(y)) + height > self.framebuffer_height)
                    self.framebuffer_height
                else
                    @as(u32, @intCast(y)) + height;
                while (py < end_y) : (py += 1) {
                    draw_fn(px, py, stroke_color);
                }
            }
        }
    }

    // Render circle (filled).
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
        const radius_i = @as(i32, @intCast(radius));
        // Fill circle using bounding box scan.
        const start_y = @max(0, center_y - radius_i);
        const end_y = @min(@as(i32, @intCast(self.framebuffer_height)), center_y + radius_i);
        var py: i32 = start_y;
        while (py < end_y) : (py += 1) {
            const start_x = @max(0, center_x - radius_i);
            const end_x = @min(@as(i32, @intCast(self.framebuffer_width)), center_x + radius_i);
            var px: i32 = start_x;
            while (px < end_x) : (px += 1) {
                const dx = @as(f64, @floatFromInt(px)) - center_x_f;
                const dy = @as(f64, @floatFromInt(py)) - center_y_f;
                const distance_squared = dx * dx + dy * dy;
                const radius_squared = radius_f * radius_f;
                if (distance_squared <= radius_squared) {
                    draw_fn(@as(u32, @intCast(px)), @as(u32, @intCast(py)), color);
                }
            }
        }
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
