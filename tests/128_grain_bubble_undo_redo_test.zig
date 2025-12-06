//! Grain Bubble Undo/Redo Tests.
//!
//! Why: Test undo/redo functionality for canvas operations.
//! Architecture: Unit tests for undo/redo system.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-062930-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const canvas = @import("grain_bubble").canvas;
const undo_redo = @import("grain_bubble").undo_redo;

test "undo redo manager init" {
    var manager = undo_redo.UndoRedoManager.init();
    std.debug.assert(manager.undo_stack_len == 0);
    std.debug.assert(manager.redo_stack_len == 0);
    std.debug.assert(!manager.can_undo());
    std.debug.assert(!manager.can_redo());
}

test "undo redo manager push pop" {
    var manager = undo_redo.UndoRedoManager.init();
    var command = undo_redo.Command.init();
    command.command_type = .add_shape;
    command.shape_id = 1;
    manager.push_undo(command);
    std.debug.assert(manager.can_undo());
    std.debug.assert(manager.undo_stack_len == 1);
    const popped = manager.pop_undo();
    std.debug.assert(popped != null);
    std.debug.assert(popped.?.shape_id == 1);
    std.debug.assert(!manager.can_undo());
}

test "undo redo manager redo stack" {
    var manager = undo_redo.UndoRedoManager.init();
    var command = undo_redo.Command.init();
    command.command_type = .move_shape;
    command.shape_id = 2;
    manager.push_undo(command);
    _ = manager.pop_undo();
    // Redo stack should be cleared on new operation.
    var command2 = undo_redo.Command.init();
    command2.command_type = .add_shape;
    manager.push_undo(command2);
    std.debug.assert(manager.redo_stack_len == 0);
}

test "canvas undo add shape" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    var manager = undo_redo.UndoRedoManager.init();
    canvas_data.set_undo_redo_manager(&manager);
    const layer_id = canvas_data.create_layer("Test Layer").?;
    _ = canvas_data.add_shape(
        layer_id,
        .rectangle,
        10.0,
        20.0,
        100.0,
        50.0,
        0xFF0000FF,
        0.0,
    );
    std.debug.assert(canvas_data.get_layer(layer_id).?.shapes_len == 1);
    _ = canvas_data.undo();
    std.debug.assert(canvas_data.get_layer(layer_id).?.shapes_len == 0);
}

test "canvas undo delete shape" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    var manager = undo_redo.UndoRedoManager.init();
    canvas_data.set_undo_redo_manager(&manager);
    const layer_id = canvas_data.create_layer("Test Layer").?;
    const shape_id = canvas_data.add_shape(
        layer_id,
        .circle,
        10.0,
        20.0,
        50.0,
        50.0,
        0x00FF00FF,
        0.0,
    ).?;
    std.debug.assert(canvas_data.get_layer(layer_id).?.shapes_len == 1);
    canvas_data.delete_shape(shape_id);
    std.debug.assert(canvas_data.get_layer(layer_id).?.shapes_len == 0);
    _ = canvas_data.undo();
    std.debug.assert(canvas_data.get_layer(layer_id).?.shapes_len == 1);
}

test "canvas undo move shape" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    var manager = undo_redo.UndoRedoManager.init();
    canvas_data.set_undo_redo_manager(&manager);
    const layer_id = canvas_data.create_layer("Test Layer").?;
    const shape_id = canvas_data.add_shape(
        layer_id,
        .rectangle,
        10.0,
        20.0,
        100.0,
        50.0,
        0xFF0000FF,
        0.0,
    ).?;
    _ = canvas_data.move_shape(shape_id, 5.0, 10.0);
    if (canvas_data.get_shape(shape_id)) |shape| {
        std.debug.assert(shape.x == 15.0);
        std.debug.assert(shape.y == 30.0);
    }
    _ = canvas_data.undo();
    if (canvas_data.get_shape(shape_id)) |shape| {
        std.debug.assert(shape.x == 10.0);
        std.debug.assert(shape.y == 20.0);
    }
}

test "canvas redo add shape" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    var manager = undo_redo.UndoRedoManager.init();
    canvas_data.set_undo_redo_manager(&manager);
    const layer_id = canvas_data.create_layer("Test Layer").?;
    const shape_id = canvas_data.add_shape(
        layer_id,
        .rectangle,
        10.0,
        20.0,
        100.0,
        50.0,
        0xFF0000FF,
        0.0,
    ).?;
    _ = canvas_data.undo();
    std.debug.assert(canvas_data.get_layer(layer_id).?.shapes_len == 0);
    _ = canvas_data.redo();
    std.debug.assert(canvas_data.get_layer(layer_id).?.shapes_len == 1);
    if (canvas_data.get_shape(shape_id)) |shape| {
        std.debug.assert(shape.x == 10.0);
        std.debug.assert(shape.y == 20.0);
    }
}

test "canvas redo move shape" {
    var canvas_data = canvas.Canvas.init(1024, 768);
    var manager = undo_redo.UndoRedoManager.init();
    canvas_data.set_undo_redo_manager(&manager);
    const layer_id = canvas_data.create_layer("Test Layer").?;
    const shape_id = canvas_data.add_shape(
        layer_id,
        .rectangle,
        10.0,
        20.0,
        100.0,
        50.0,
        0xFF0000FF,
        0.0,
    ).?;
    _ = canvas_data.move_shape(shape_id, 5.0, 10.0);
    _ = canvas_data.undo();
    if (canvas_data.get_shape(shape_id)) |shape| {
        std.debug.assert(shape.x == 10.0);
        std.debug.assert(shape.y == 20.0);
    }
    _ = canvas_data.redo();
    if (canvas_data.get_shape(shape_id)) |shape| {
        std.debug.assert(shape.x == 15.0);
        std.debug.assert(shape.y == 30.0);
    }
}

