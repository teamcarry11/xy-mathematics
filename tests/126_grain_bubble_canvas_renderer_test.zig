//! Grain Bubble Canvas Renderer Tests.
//!
//! Why: Test canvas rendering integration with framebuffer.
//! Architecture: Unit tests for canvas renderer.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-011503-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const grain_bubble = @import("grain_bubble");
const grain_core = @import("grain_core");

test "canvas renderer init" {
    var canvas_data = grain_bubble.canvas.Canvas.init(1024, 768);
    var fb_renderer = grain_core.framebuffer_renderer.FramebufferRenderer.init();
    const renderer = grain_bubble.canvas_renderer.CanvasRenderer.init(
        &canvas_data,
        &fb_renderer,
    );
    std.debug.assert(renderer.canvas.viewport.width == 1024);
    std.debug.assert(renderer.canvas.viewport.height == 768);
    std.debug.assert(@intFromPtr(renderer.framebuffer_renderer) != 0);
}

test "canvas renderer render empty canvas" {
    var canvas_data = grain_bubble.canvas.Canvas.init(1024, 768);
    var fb_renderer = grain_core.framebuffer_renderer.FramebufferRenderer.init();
    var renderer = grain_bubble.canvas_renderer.CanvasRenderer.init(
        &canvas_data,
        &fb_renderer,
    );
    // Render empty canvas (should clear framebuffer).
    renderer.render_canvas();
    std.debug.assert(canvas_data.layers_len == 0);
}

test "canvas renderer render with shapes" {
    var canvas_data = grain_bubble.canvas.Canvas.init(1024, 768);
    var fb_renderer = grain_core.framebuffer_renderer.FramebufferRenderer.init();
    var renderer = grain_bubble.canvas_renderer.CanvasRenderer.init(
        &canvas_data,
        &fb_renderer,
    );
    // Create layer and add shape.
    const layer_id = canvas_data.create_layer("Test Layer");
    std.debug.assert(layer_id != null);
    const shape_id = canvas_data.add_shape(
        layer_id.?,
        .rectangle,
        10.0,
        20.0,
        100.0,
        50.0,
        0xFF0000FF,
        0.0,
    );
    std.debug.assert(shape_id != null);
    // Render canvas (should render shape).
    renderer.render_canvas();
    std.debug.assert(canvas_data.layers_len == 1);
    std.debug.assert(canvas_data.layers[0].shapes_len == 1);
}

test "canvas renderer render with text" {
    var canvas_data = grain_bubble.canvas.Canvas.init(1024, 768);
    var fb_renderer = grain_core.framebuffer_renderer.FramebufferRenderer.init();
    var renderer = grain_bubble.canvas_renderer.CanvasRenderer.init(
        &canvas_data,
        &fb_renderer,
    );
    // Create layer and add text.
    const layer_id = canvas_data.create_layer("Test Layer");
    std.debug.assert(layer_id != null);
    const text_id = canvas_data.add_text(
        layer_id.?,
        10.0,
        20.0,
        "Hello, World!",
        16,
        0x000000FF,
    );
    std.debug.assert(text_id != null);
    // Render canvas (should render text).
    renderer.render_canvas();
    std.debug.assert(canvas_data.layers_len == 1);
    std.debug.assert(canvas_data.layers[0].texts_len == 1);
}

