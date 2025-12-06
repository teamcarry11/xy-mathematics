//! Grain Bubble Canvas Renderer: Render canvas to framebuffer.
//!
//! Why: Bridge canvas engine with framebuffer renderer for display.
//! Architecture: Canvas → Bubble Renderer → Framebuffer Renderer.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-011503-pst: Grain Bubble Agent

const std = @import("std");
const canvas = @import("canvas.zig");
const bubble_renderer = @import("bubble_renderer.zig");
const grain_core = @import("grain_core");

// Thread-local renderer context for draw callbacks.
var current_renderer: ?*const CanvasRenderer = null;

// Canvas renderer: renders canvas to framebuffer.
pub const CanvasRenderer = struct {
    canvas: *canvas.Canvas,
    bubble_renderer: bubble_renderer.BubbleRenderer,
    framebuffer_renderer: *grain_core.framebuffer_renderer.FramebufferRenderer,

    pub fn init(
        canvas_data: *canvas.Canvas,
        fb_renderer: *grain_core.framebuffer_renderer.FramebufferRenderer,
    ) CanvasRenderer {
        std.debug.assert(@intFromPtr(canvas_data) != 0);
        std.debug.assert(@intFromPtr(fb_renderer) != 0);
        const width = canvas_data.viewport.width;
        const height = canvas_data.viewport.height;
        const renderer = CanvasRenderer{
            .canvas = canvas_data,
            .bubble_renderer = bubble_renderer.BubbleRenderer.init(width, height),
            .framebuffer_renderer = fb_renderer,
        };
        std.debug.assert(renderer.canvas.viewport.width > 0);
        std.debug.assert(renderer.canvas.viewport.height > 0);
        return renderer;
    }

    // Render entire canvas to framebuffer.
    pub fn render_canvas(self: *const CanvasRenderer) void {
        std.debug.assert(@intFromPtr(self.canvas) != 0);
        std.debug.assert(@intFromPtr(self.framebuffer_renderer) != 0);
        // Set thread-local renderer context.
        current_renderer = self;
        // Clear framebuffer to background color.
        self.framebuffer_renderer.clear(0x1E1E2EFF);
        // Render layers in z-order (bottom to top).
        var layer_i: u32 = 0;
        while (layer_i < self.canvas.layers_len) : (layer_i += 1) {
            const layer = &self.canvas.layers[layer_i];
            if (!layer.visible) {
                continue;
            }
            // Render shapes in z-order.
            var shape_i: u32 = 0;
            while (shape_i < layer.shapes_len) : (shape_i += 1) {
                const shape = &layer.shapes[shape_i];
                self.render_shape(shape);
            }
            // Render text in z-order.
            var text_i: u32 = 0;
            while (text_i < layer.texts_len) : (text_i += 1) {
                const text = &layer.texts[text_i];
                self.render_text(text);
            }
        }
        // Clear thread-local renderer context.
        current_renderer = null;
    }

    // Render single shape.
    fn render_shape(self: *const CanvasRenderer, shape: *const canvas.Shape) void {
        std.debug.assert(@intFromPtr(shape) != 0);
        std.debug.assert(current_renderer == self);
        // Use bubble renderer to render shape with draw callback.
        self.bubble_renderer.render_shape(shape, &self.canvas.viewport, draw_pixel_callback);
    }

    // Render single text element.
    fn render_text(self: *const CanvasRenderer, text: *const canvas.Text) void {
        std.debug.assert(@intFromPtr(text) != 0);
        const screen_pos = self.canvas.world_to_screen(text.x, text.y);
        const screen_x = if (screen_pos.x < 0) 0 else @as(u32, @intCast(screen_pos.x));
        const screen_y = if (screen_pos.y < 0) 0 else @as(u32, @intCast(screen_pos.y));
        if (screen_x < self.canvas.viewport.width and
            screen_y < self.canvas.viewport.height)
        {
            const text_content = text.content[0..text.content_len];
            self.framebuffer_renderer.draw_text(
                text_content,
                screen_x,
                screen_y,
                text.color,
            );
        }
    }
};

// Draw pixel callback for bubble renderer (uses thread-local context).
fn draw_pixel_callback(x: u32, y: u32, color: u32) void {
    std.debug.assert(current_renderer != null);
    if (current_renderer) |renderer| {
        std.debug.assert(x < renderer.canvas.viewport.width);
        std.debug.assert(y < renderer.canvas.viewport.height);
        renderer.framebuffer_renderer.draw_pixel(x, y, color);
    }
}

