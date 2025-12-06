//! Grain Bubble Canvas Input Tests.
//!
//! Why: Test canvas input handling (mouse events, selection, pan, zoom).
//! Architecture: Unit tests for canvas input handler.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-012434-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const grain_bubble = @import("grain_bubble");
const grain_core = @import("grain_core");

test "canvas input handler init" {
    var canvas_data = grain_bubble.canvas.Canvas.init(1024, 768);
    const handler = grain_bubble.canvas_input.CanvasInputHandler.init(&canvas_data);
    std.debug.assert(handler.mode == .select);
    std.debug.assert(handler.is_dragging == false);
    std.debug.assert(handler.canvas.viewport.width == 1024);
}

test "canvas input handler mouse down select" {
    var canvas_data = grain_bubble.canvas.Canvas.init(1024, 768);
    var handler = grain_bubble.canvas_input.CanvasInputHandler.init(&canvas_data);
    // Create layer and add shape.
    const layer_id = canvas_data.create_layer("Test Layer");
    std.debug.assert(layer_id != null);
    const shape_id = canvas_data.add_shape(
        layer_id.?,
        .rectangle,
        100.0,
        100.0,
        50.0,
        50.0,
        0xFF0000FF,
        0.0,
    );
    std.debug.assert(shape_id != null);
    // Create mouse down event at shape position.
    const event = grain_core.input_handler.InputEvent{
        .event_type = .mouse,
        .mouse = .{
            .kind = .down,
            .button = 0,
            .x = 125, // Center of shape (100 + 50/2 = 125)
            .y = 125, // Center of shape (100 + 50/2 = 125)
            .modifiers = 0,
        },
        .keyboard = undefined,
    };
    handler.handle_mouse_event(event);
    // Shape should be selected.
    std.debug.assert(canvas_data.selection_len == 1);
    std.debug.assert(canvas_data.selection[0] == shape_id.?);
    std.debug.assert(handler.is_dragging == true);
}

test "canvas input handler mouse down clear selection" {
    var canvas_data = grain_bubble.canvas.Canvas.init(1024, 768);
    var handler = grain_bubble.canvas_input.CanvasInputHandler.init(&canvas_data);
    // Create mouse down event at empty position.
    const event = grain_core.input_handler.InputEvent{
        .event_type = .mouse,
        .mouse = .{
            .kind = .down,
            .button = 0,
            .x = 10,
            .y = 10,
            .modifiers = 0,
        },
        .keyboard = undefined,
    };
    handler.handle_mouse_event(event);
    // Selection should be cleared.
    std.debug.assert(canvas_data.selection_len == 0);
    std.debug.assert(handler.is_dragging == false);
}

test "canvas input handler mouse up" {
    var canvas_data = grain_bubble.canvas.Canvas.init(1024, 768);
    var handler = grain_bubble.canvas_input.CanvasInputHandler.init(&canvas_data);
    handler.is_dragging = true;
    handler.drag_start_x = 100;
    handler.drag_start_y = 100;
    // Create mouse up event.
    const event = grain_core.input_handler.InputEvent{
        .event_type = .mouse,
        .mouse = .{
            .kind = .up,
            .button = 0,
            .x = 200,
            .y = 200,
            .modifiers = 0,
        },
        .keyboard = undefined,
    };
    handler.handle_mouse_event(event);
    // Dragging should be stopped.
    std.debug.assert(handler.is_dragging == false);
    std.debug.assert(handler.drag_start_x == 0);
    std.debug.assert(handler.drag_start_y == 0);
}

test "canvas input handler set mode" {
    var canvas_data = grain_bubble.canvas.Canvas.init(1024, 768);
    var handler = grain_bubble.canvas_input.CanvasInputHandler.init(&canvas_data);
    std.debug.assert(handler.mode == .select);
    handler.set_mode(.pan);
    std.debug.assert(handler.mode == .pan);
    handler.set_mode(.select);
    std.debug.assert(handler.mode == .select);
}

test "canvas input handler mouse wheel zoom" {
    var canvas_data = grain_bubble.canvas.Canvas.init(1024, 768);
    var handler = grain_bubble.canvas_input.CanvasInputHandler.init(&canvas_data);
    const initial_zoom = canvas_data.viewport.zoom;
    // Zoom in.
    handler.handle_mouse_wheel(1, 512, 384);
    std.debug.assert(canvas_data.viewport.zoom > initial_zoom);
    // Zoom out.
    const zoom_after_in = canvas_data.viewport.zoom;
    handler.handle_mouse_wheel(-1, 512, 384);
    std.debug.assert(canvas_data.viewport.zoom < zoom_after_in);
}

test "canvas input handler keyboard delete" {
    var canvas_data = grain_bubble.canvas.Canvas.init(1024, 768);
    var handler = grain_bubble.canvas_input.CanvasInputHandler.init(&canvas_data);
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
    // Select shape.
    _ = canvas_data.select_shape(shape_id.?);
    std.debug.assert(canvas_data.selection_len == 1);
    // Create keyboard delete event.
    const event = grain_core.input_handler.InputEvent{
        .event_type = .keyboard,
        .mouse = undefined,
        .keyboard = .{
            .kind = .down,
            .key_code = 0x2E, // Delete key
            .character = 0,
            .modifiers = 0,
        },
    };
    handler.handle_keyboard_event(event);
    // Shape should be deleted and selection cleared.
    std.debug.assert(canvas_data.selection_len == 0);
    std.debug.assert(canvas_data.layers[0].shapes_len == 0);
}

test "canvas input handler keyboard toggle pan mode" {
    var canvas_data = grain_bubble.canvas.Canvas.init(1024, 768);
    var handler = grain_bubble.canvas_input.CanvasInputHandler.init(&canvas_data);
    std.debug.assert(handler.mode == .select);
    // Create keyboard space event.
    const event = grain_core.input_handler.InputEvent{
        .event_type = .keyboard,
        .mouse = undefined,
        .keyboard = .{
            .kind = .down,
            .key_code = 0x20, // Space key
            .character = 0,
            .modifiers = 0,
        },
    };
    handler.handle_keyboard_event(event);
    // Mode should toggle to pan.
    std.debug.assert(handler.mode == .pan);
    // Toggle again.
    handler.handle_keyboard_event(event);
    // Mode should toggle back to select.
    std.debug.assert(handler.mode == .select);
}

test "canvas input handler keyboard arrow keys" {
    var canvas_data = grain_bubble.canvas.Canvas.init(1024, 768);
    var handler = grain_bubble.canvas_input.CanvasInputHandler.init(&canvas_data);
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
    // Select shape.
    _ = canvas_data.select_shape(shape_id.?);
    const initial_x = canvas_data.layers[0].shapes[0].x;
    const initial_y = canvas_data.layers[0].shapes[0].y;
    // Create keyboard right arrow event.
    const event = grain_core.input_handler.InputEvent{
        .event_type = .keyboard,
        .mouse = undefined,
        .keyboard = .{
            .kind = .down,
            .key_code = 0x27, // Right arrow
            .character = 0,
            .modifiers = 0,
        },
    };
    handler.handle_keyboard_event(event);
    // Shape should move right.
    std.debug.assert(canvas_data.layers[0].shapes[0].x > initial_x);
    std.debug.assert(canvas_data.layers[0].shapes[0].y == initial_y);
}

