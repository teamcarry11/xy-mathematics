//! Grain Bubble Canvas Tests.
//!
//! Why: Test canvas functionality (infinite canvas, zoom/pan, shapes).
//! Architecture: Unit tests for canvas engine.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-05-143400-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const canvas = @import("grain_bubble").canvas;

test "canvas init" {
    var c = canvas.Canvas.init(1024, 768);
    std.debug.assert(c.viewport.width == 1024);
    std.debug.assert(c.viewport.height == 768);
    std.debug.assert(c.viewport.zoom == canvas.DEFAULT_ZOOM);
    std.debug.assert(c.layers_len == 0);
    std.debug.assert(c.next_shape_id == 1);
    std.debug.assert(c.next_text_id == 1);
    std.debug.assert(c.next_layer_id == 1);
}

test "canvas zoom" {
    var c = canvas.Canvas.init(1024, 768);
    c.set_zoom(2.0);
    std.debug.assert(c.viewport.zoom == 2.0);
    c.zoom_in();
    std.debug.assert(c.viewport.zoom > 2.0);
    c.zoom_out();
    std.debug.assert(c.viewport.zoom <= 2.0);
}

test "canvas pan" {
    var c = canvas.Canvas.init(1024, 768);
    const initial_pan_x = c.viewport.pan_x;
    const initial_pan_y = c.viewport.pan_y;
    c.pan(10.0, 20.0);
    std.debug.assert(c.viewport.pan_x == initial_pan_x + 10.0);
    std.debug.assert(c.viewport.pan_y == initial_pan_y + 20.0);
}

test "canvas world to screen" {
    var c = canvas.Canvas.init(1024, 768);
    c.set_zoom(2.0);
    c.pan(100.0, 200.0);
    const screen = c.world_to_screen(50.0, 100.0);
    // World (50, 100) with pan (100, 200) and zoom 2.0
    // Screen: (50 + 100) * 2 = 300, (100 + 200) * 2 = 600
    std.debug.assert(screen.x == 300);
    std.debug.assert(screen.y == 600);
}

test "canvas screen to world" {
    var c = canvas.Canvas.init(1024, 768);
    c.set_zoom(2.0);
    c.pan(100.0, 200.0);
    const world = c.screen_to_world(300, 600);
    // Screen (300, 600) with zoom 2.0 and pan (100, 200)
    // World: 300/2 - 100 = 50, 600/2 - 200 = 100
    std.debug.assert(world.x == 50.0);
    std.debug.assert(world.y == 100.0);
}

test "canvas create layer" {
    var c = canvas.Canvas.init(1024, 768);
    const layer_id = c.create_layer("Test Layer");
    std.debug.assert(layer_id != null);
    std.debug.assert(c.layers_len == 1);
    if (c.get_layer(layer_id.?)) |layer| {
        std.debug.assert(layer.visible == true);
        std.debug.assert(layer.locked == false);
        std.debug.assert(layer.shapes_len == 0);
        std.debug.assert(layer.texts_len == 0);
    }
}

test "canvas add shape" {
    var c = canvas.Canvas.init(1024, 768);
    const layer_id = c.create_layer("Test Layer");
    std.debug.assert(layer_id != null);
    const shape_id = c.add_shape(
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
    if (c.get_layer(layer_id.?)) |layer| {
        std.debug.assert(layer.shapes_len == 1);
        std.debug.assert(layer.shapes[0].id == shape_id.?);
        std.debug.assert(layer.shapes[0].shape_type == .rectangle);
        std.debug.assert(layer.shapes[0].x == 10.0);
        std.debug.assert(layer.shapes[0].y == 20.0);
    }
}

test "canvas add text" {
    var c = canvas.Canvas.init(1024, 768);
    const layer_id = c.create_layer("Test Layer");
    std.debug.assert(layer_id != null);
    const text_id = c.add_text(
        layer_id.?,
        10.0,
        20.0,
        "Hello, World!",
        16,
        0x000000FF,
    );
    std.debug.assert(text_id != null);
    if (c.get_layer(layer_id.?)) |layer| {
        std.debug.assert(layer.texts_len == 1);
        std.debug.assert(layer.texts[0].id == text_id.?);
        std.debug.assert(layer.texts[0].x == 10.0);
        std.debug.assert(layer.texts[0].y == 20.0);
        std.debug.assert(layer.texts[0].font_size == 16);
    }
}

test "canvas selection" {
    var c = canvas.Canvas.init(1024, 768);
    const layer_id = c.create_layer("Test Layer");
    std.debug.assert(layer_id != null);
    const shape_id = c.add_shape(
        layer_id.?,
        .circle,
        10.0,
        20.0,
        50.0,
        50.0,
        0x00FF00FF,
        0.0,
    );
    std.debug.assert(shape_id != null);
    c.clear_selection();
    std.debug.assert(c.selection_len == 0);
    const selected = c.select_shape(shape_id.?);
    std.debug.assert(selected == true);
    std.debug.assert(c.selection_len == 1);
    std.debug.assert(c.selection[0] == shape_id.?);
}

