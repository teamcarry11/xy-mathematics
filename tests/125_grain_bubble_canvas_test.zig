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
    const c = canvas.Canvas.init(1024, 768);
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
        std.debug.assert(layer.shapes[0].stroke_width == 0.0);
    }
}

test "canvas add shape with stroke" {
    var c = canvas.Canvas.init(1024, 768);
    const layer_id = c.create_layer("Test Layer");
    std.debug.assert(layer_id != null);
    const shape_id = c.add_shape_with_stroke(
        layer_id.?,
        .rectangle,
        10.0,
        20.0,
        100.0,
        50.0,
        0xFF0000FF,
        0.0,
        2.0,
        0x000000FF,
    );
    std.debug.assert(shape_id != null);
    if (c.get_layer(layer_id.?)) |layer| {
        std.debug.assert(layer.shapes_len == 1);
        std.debug.assert(layer.shapes[0].stroke_width == 2.0);
        std.debug.assert(layer.shapes[0].stroke_color == 0x000000FF);
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

test "canvas duplicate shape" {
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
    const duplicated_id = c.duplicate_shape(shape_id.?, 10.0, 10.0);
    std.debug.assert(duplicated_id != null);
    if (c.get_layer(layer_id.?)) |layer| {
        std.debug.assert(layer.shapes_len == 2);
        std.debug.assert(layer.shapes[1].x == 20.0);
        std.debug.assert(layer.shapes[1].y == 30.0);
    }
}

test "canvas copy and paste shapes" {
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
    _ = c.select_shape(shape_id.?);
    const copied = c.copy_selected_shapes();
    std.debug.assert(copied == true);
    std.debug.assert(c.clipboard_len == 1);
    const pasted = c.paste_shapes(layer_id.?, 100.0, 100.0);
    std.debug.assert(pasted == 1);
    if (c.get_layer(layer_id.?)) |layer| {
        std.debug.assert(layer.shapes_len == 2);
        std.debug.assert(layer.shapes[1].x == 110.0);
        std.debug.assert(layer.shapes[1].y == 120.0);
    }
}

test "canvas duplicate selected shapes" {
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
    _ = c.select_shape(shape_id.?);
    const duplicated = c.duplicate_selected_shapes(5.0, 5.0);
    std.debug.assert(duplicated == 1);
    if (c.get_layer(layer_id.?)) |layer| {
        std.debug.assert(layer.shapes_len == 2);
    }
}

test "canvas hit testing rectangle" {
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
    // Point inside rectangle.
    const found_id = c.find_shape_at(50.0, 40.0);
    std.debug.assert(found_id != null);
    std.debug.assert(found_id.? == shape_id.?);
    // Point outside rectangle.
    const not_found = c.find_shape_at(200.0, 200.0);
    std.debug.assert(not_found == null);
}

test "canvas hit testing circle" {
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
    // Point inside circle (center).
    const found_id = c.find_shape_at(35.0, 45.0);
    std.debug.assert(found_id != null);
    std.debug.assert(found_id.? == shape_id.?);
    // Point outside circle.
    const not_found = c.find_shape_at(100.0, 100.0);
    std.debug.assert(not_found == null);
}

test "canvas move shape" {
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
    const moved = c.move_shape(shape_id.?, 5.0, 10.0);
    std.debug.assert(moved == true);
    if (c.get_layer(layer_id.?)) |layer| {
        std.debug.assert(layer.shapes[0].x == 15.0);
        std.debug.assert(layer.shapes[0].y == 30.0);
    }
}

test "canvas resize shape" {
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
    const resized = c.resize_shape(shape_id.?, 150.0, 75.0);
    std.debug.assert(resized == true);
    if (c.get_layer(layer_id.?)) |layer| {
        std.debug.assert(layer.shapes[0].width == 150.0);
        std.debug.assert(layer.shapes[0].height == 75.0);
    }
}

