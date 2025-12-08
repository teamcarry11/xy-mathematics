//! Grain Bubble Canvas Input: Handle mouse and keyboard input for canvas.
//!
//! Why: Enable interactive canvas operations (select, pan, zoom).
//! Architecture: Input events → Canvas operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-014041-pst: Grain Bubble Agent

const std = @import("std");
const canvas = @import("canvas.zig");
const grain_core = @import("grain_core");

// Input mode: what operation is active.
pub const InputMode = enum(u8) {
    select, // Select and manipulate shapes
    pan, // Pan canvas
    none, // No active operation
};

// Canvas input handler: processes input events for canvas.
pub const CanvasInputHandler = struct {
    canvas: *canvas.Canvas,
    mode: InputMode,
    is_dragging: bool,
    drag_start_x: i32,
    drag_start_y: i32,
    drag_last_x: i32,
    drag_last_y: i32,

    pub fn init(canvas_data: *canvas.Canvas) CanvasInputHandler {
        std.debug.assert(@intFromPtr(canvas_data) != 0);
        const handler = CanvasInputHandler{
            .canvas = canvas_data,
            .mode = .select,
            .is_dragging = false,
            .drag_start_x = 0,
            .drag_start_y = 0,
            .drag_last_x = 0,
            .drag_last_y = 0,
        };
        std.debug.assert(handler.canvas.viewport.width > 0);
        std.debug.assert(handler.canvas.viewport.height > 0);
        return handler;
    }

    // Process mouse event.
    pub fn handle_mouse_event(
        self: *CanvasInputHandler,
        event: grain_core.input_handler.InputEvent,
    ) void {
        std.debug.assert(event.event_type == .mouse);
        switch (event.mouse.kind) {
            .down => {
                self.handle_mouse_down(event.mouse.x, event.mouse.y, event.mouse.button);
            },
            .up => {
                self.handle_mouse_up(event.mouse.x, event.mouse.y);
            },
            .move => {
                self.handle_mouse_move(event.mouse.x, event.mouse.y);
            },
            .drag => {
                self.handle_mouse_drag(event.mouse.x, event.mouse.y);
            },
        }
    }

    // Handle mouse button down.
    fn handle_mouse_down(
        self: *CanvasInputHandler,
        screen_x: u32,
        screen_y: u32,
        button: u8,
    ) void {
        std.debug.assert(screen_x < self.canvas.viewport.width);
        std.debug.assert(screen_y < self.canvas.viewport.height);
        const world_pos = self.canvas.screen_to_world(
            @as(i32, @intCast(screen_x)),
            @as(i32, @intCast(screen_y)),
        );
        if (button == 0) {
            // Left button: select or start pan.
            if (self.mode == .pan) {
                self.is_dragging = true;
                self.drag_start_x = @as(i32, @intCast(screen_x));
                self.drag_start_y = @as(i32, @intCast(screen_y));
                self.drag_last_x = self.drag_start_x;
                self.drag_last_y = self.drag_start_y;
            } else {
                // Select mode: find shape at position.
                if (self.canvas.find_shape_at(world_pos.x, world_pos.y)) |shape_id| {
                    self.canvas.clear_selection();
                    _ = self.canvas.select_shape(shape_id);
                    self.is_dragging = true;
                    self.drag_start_x = @as(i32, @intCast(screen_x));
                    self.drag_start_y = @as(i32, @intCast(screen_y));
                    self.drag_last_x = self.drag_start_x;
                    self.drag_last_y = self.drag_start_y;
                } else {
                    // No shape: clear selection.
                    self.canvas.clear_selection();
                }
            }
        }
    }

    // Handle mouse button up.
    fn handle_mouse_up(
        self: *CanvasInputHandler,
        screen_x: u32,
        screen_y: u32,
    ) void {
        std.debug.assert(screen_x < self.canvas.viewport.width);
        std.debug.assert(screen_y < self.canvas.viewport.height);
        self.is_dragging = false;
        self.drag_start_x = 0;
        self.drag_start_y = 0;
        self.drag_last_x = 0;
        self.drag_last_y = 0;
    }

    // Handle mouse move.
    fn handle_mouse_move(
        self: *CanvasInputHandler,
        screen_x: u32,
        screen_y: u32,
    ) void {
        std.debug.assert(screen_x < self.canvas.viewport.width);
        std.debug.assert(screen_y < self.canvas.viewport.height);
        if (self.is_dragging) {
            const dx = @as(i32, @intCast(screen_x)) - self.drag_last_x;
            const dy = @as(i32, @intCast(screen_y)) - self.drag_last_y;
            if (self.mode == .pan) {
                // Pan canvas.
                const world_dx = @as(f64, @floatFromInt(dx)) / self.canvas.viewport.zoom;
                const world_dy = @as(f64, @floatFromInt(dy)) / self.canvas.viewport.zoom;
                self.canvas.pan(-world_dx, -world_dy);
            } else {
                // Move selected shape.
                if (self.canvas.selection_len > 0) {
                    const world_dx = @as(f64, @floatFromInt(dx)) / self.canvas.viewport.zoom;
                    const world_dy = @as(f64, @floatFromInt(dy)) / self.canvas.viewport.zoom;
                    var i: u32 = 0;
                    while (i < self.canvas.selection_len) : (i += 1) {
                        _ = self.canvas.move_shape(
                            self.canvas.selection[i],
                            world_dx,
                            world_dy,
                        );
                    }
                }
            }
            self.drag_last_x = @as(i32, @intCast(screen_x));
            self.drag_last_y = @as(i32, @intCast(screen_y));
        }
    }

    // Handle mouse drag (explicit drag event).
    fn handle_mouse_drag(
        self: *CanvasInputHandler,
        screen_x: u32,
        screen_y: u32,
    ) void {
        std.debug.assert(screen_x < self.canvas.viewport.width);
        std.debug.assert(screen_y < self.canvas.viewport.height);
        // Treat drag same as move when dragging.
        self.handle_mouse_move(screen_x, screen_y);
    }

    // Handle mouse wheel (zoom).
    pub fn handle_mouse_wheel(
        self: *CanvasInputHandler,
        delta: i32,
        screen_x: u32,
        screen_y: u32,
    ) void {
        std.debug.assert(screen_x < self.canvas.viewport.width);
        std.debug.assert(screen_y < self.canvas.viewport.height);
        // Zoom at mouse position.
        const world_pos = self.canvas.screen_to_world(
            @as(i32, @intCast(screen_x)),
            @as(i32, @intCast(screen_y)),
        );
        if (delta > 0) {
            self.canvas.zoom_in();
        } else {
            self.canvas.zoom_out();
        }
        // Adjust pan to keep world position under cursor.
        const new_world_pos = self.canvas.screen_to_world(
            @as(i32, @intCast(screen_x)),
            @as(i32, @intCast(screen_y)),
        );
        const pan_dx = world_pos.x - new_world_pos.x;
        const pan_dy = world_pos.y - new_world_pos.y;
        self.canvas.pan(pan_dx, pan_dy);
        std.debug.assert(self.canvas.viewport.zoom >= canvas.MIN_ZOOM);
        std.debug.assert(self.canvas.viewport.zoom <= canvas.MAX_ZOOM);
    }

    // Process keyboard event.
    pub fn handle_keyboard_event(
        self: *CanvasInputHandler,
        event: grain_core.input_handler.InputEvent,
    ) void {
        std.debug.assert(event.event_type == .keyboard);
        if (event.keyboard.kind == .down) {
            self.handle_key_down(event.keyboard.key_code, event.keyboard.modifiers);
        }
    }

    // Handle key down event.
    fn handle_key_down(
        self: *CanvasInputHandler,
        key_code: u32,
        modifiers: u8,
    ) void {
        const MODIFIER_CTRL: u8 = 0x01;
        const MODIFIER_SHIFT: u8 = 0x04;
        const KEY_DELETE: u32 = 0x2E;
        const KEY_BACKSPACE: u32 = 0x08;
        const KEY_SPACE: u32 = 0x20;
        const KEY_PLUS: u32 = 0x3D; // Equals key
        const KEY_MINUS: u32 = 0x2D;
        const KEY_LEFT: u32 = 0x25;
        const KEY_UP: u32 = 0x26;
        const KEY_RIGHT: u32 = 0x27;
        const KEY_DOWN: u32 = 0x28;
        const KEY_Z: u32 = 0x5A;
        const KEY_Y: u32 = 0x59;
        const KEY_C: u32 = 0x43;
        const KEY_V: u32 = 0x56;
        const KEY_D: u32 = 0x44;
        if (key_code == KEY_DELETE or key_code == KEY_BACKSPACE) {
            // Delete selected shapes.
            self.delete_selected_shapes();
        } else if ((modifiers & MODIFIER_CTRL) != 0 and key_code == KEY_Z) {
            // Ctrl+Z: Undo.
            _ = self.canvas.undo();
        } else if ((modifiers & MODIFIER_CTRL) != 0 and key_code == KEY_Y) {
            // Ctrl+Y: Redo.
            _ = self.canvas.redo();
        } else if ((modifiers & MODIFIER_CTRL) != 0 and key_code == KEY_C) {
            // Ctrl+C: Copy selected shapes.
            self.canvas.copy_selected_shapes();
        } else if ((modifiers & MODIFIER_CTRL) != 0 and key_code == KEY_V) {
            // Ctrl+V: Paste shapes at current position.
            const center_x = @as(f64, @floatFromInt(self.canvas.viewport.width)) / 2.0;
            const center_y = @as(f64, @floatFromInt(self.canvas.viewport.height)) / 2.0;
            if (self.canvas.selection_len > 0) {
                // Paste to same layer as first selected shape.
                const first_shape_id = self.canvas.selection[0];
                if (self.canvas.get_shape(first_shape_id)) |shape| {
                    if (self.canvas.get_layer(shape.layer_id)) |layer| {
                        const pasted = self.canvas.paste_shapes(layer.id, center_x, center_y);
                        if (pasted > 0) {
                            // Select pasted shapes.
                            self.canvas.clear_selection();
                            var i: u32 = 0;
                            while (i < pasted and i < canvas.MAX_SELECTION) : (i += 1) {
                                const new_shape_id = self.canvas.next_shape_id - pasted + i;
                                _ = self.canvas.select_shape(new_shape_id);
                            }
                        }
                    }
                }
            } else {
                // Paste to first layer if no selection.
                if (self.canvas.layers_len > 0) {
                    const pasted = self.canvas.paste_shapes(
                        self.canvas.layers[0].id,
                        center_x,
                        center_y,
                    );
                    if (pasted > 0) {
                        // Select pasted shapes.
                        self.canvas.clear_selection();
                        var i: u32 = 0;
                        while (i < pasted and i < canvas.MAX_SELECTION) : (i += 1) {
                            const new_shape_id = self.canvas.next_shape_id - pasted + i;
                            _ = self.canvas.select_shape(new_shape_id);
                        }
                    }
                }
            }
        } else if ((modifiers & MODIFIER_CTRL) != 0 and key_code == KEY_D) {
            // Ctrl+D: Duplicate selected shapes.
            const DUPLICATE_OFFSET: f64 = 10.0;
            const duplicated = self.canvas.duplicate_selected_shapes(
                DUPLICATE_OFFSET,
                DUPLICATE_OFFSET,
            );
            if (duplicated > 0) {
                // Select duplicated shapes.
                self.canvas.clear_selection();
                var i: u32 = 0;
                while (i < duplicated and i < canvas.MAX_SELECTION) : (i += 1) {
                    const new_shape_id = self.canvas.next_shape_id - duplicated + i;
                    _ = self.canvas.select_shape(new_shape_id);
                }
            }
        } else if (key_code == KEY_SPACE) {
            // Space: Toggle pan mode.
            if (self.mode == .pan) {
                self.set_mode(.select);
            } else {
                self.set_mode(.pan);
            }
        } else if (key_code == KEY_PLUS or key_code == KEY_MINUS) {
            // Plus/Minus: Zoom in/out at center.
            const center_x = self.canvas.viewport.width / 2;
            const center_y = self.canvas.viewport.height / 2;
            if (key_code == KEY_PLUS) {
                self.handle_mouse_wheel(1, center_x, center_y);
            } else {
                self.handle_mouse_wheel(-1, center_x, center_y);
            }
        } else if (key_code == KEY_LEFT or key_code == KEY_RIGHT or
            key_code == KEY_UP or key_code == KEY_DOWN)
        {
            // Arrow keys: Move selected shapes.
            const MOVE_STEP: f64 = 1.0;
            var dx: f64 = 0.0;
            var dy: f64 = 0.0;
            if (key_code == KEY_LEFT) {
                dx = -MOVE_STEP;
            } else if (key_code == KEY_RIGHT) {
                dx = MOVE_STEP;
            } else if (key_code == KEY_UP) {
                dy = -MOVE_STEP;
            } else if (key_code == KEY_DOWN) {
                dy = MOVE_STEP;
            }
            if ((modifiers & MODIFIER_SHIFT) != 0) {
                // Shift: Move by larger step.
                dx *= 10.0;
                dy *= 10.0;
            }
            self.move_selected_shapes(dx, dy);
        }
    }

    // Delete selected shapes.
    fn delete_selected_shapes(self: *CanvasInputHandler) void {
        var i: u32 = 0;
        while (i < self.canvas.selection_len) : (i += 1) {
            const shape_id = self.canvas.selection[i];
            self.delete_shape(shape_id);
        }
        self.canvas.clear_selection();
        std.debug.assert(self.canvas.selection_len == 0);
    }

    // Delete shape by ID.
    fn delete_shape(self: *CanvasInputHandler, shape_id: u32) void {
        std.debug.assert(shape_id > 0);
        var layer_i: u32 = 0;
        while (layer_i < self.canvas.layers_len) : (layer_i += 1) {
            const layer = &self.canvas.layers[layer_i];
            var shape_i: u32 = 0;
            while (shape_i < layer.shapes_len) : (shape_i += 1) {
                if (layer.shapes[shape_i].id == shape_id) {
                    // Remove shape by shifting remaining shapes.
                    var j: u32 = shape_i;
                    while (j < layer.shapes_len - 1) : (j += 1) {
                        layer.shapes[j] = layer.shapes[j + 1];
                    }
                    layer.shapes_len -= 1;
                    return;
                }
            }
        }
    }

    // Move selected shapes by offset.
    fn move_selected_shapes(
        self: *CanvasInputHandler,
        dx: f64,
        dy: f64,
    ) void {
        var i: u32 = 0;
        while (i < self.canvas.selection_len) : (i += 1) {
            _ = self.canvas.move_shape(
                self.canvas.selection[i],
                dx,
                dy,
            );
        }
    }

    // Set input mode.
    pub fn set_mode(self: *CanvasInputHandler, mode: InputMode) void {
        self.mode = mode;
        self.is_dragging = false;
        std.debug.assert(self.mode == mode);
    }
};

