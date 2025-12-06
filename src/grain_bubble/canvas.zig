//! Grain Bubble Canvas: Infinite canvas with zoom/pan.
//!
//! Why: Foundation for design tool with infinite canvas.
//! Architecture: Viewport transformation, world coordinates.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-05-143400-pst: Grain Bubble Agent

const std = @import("std");

// Bounded: Max number of layers.
pub const MAX_LAYERS: u32 = 256;

// Bounded: Max number of shapes per layer.
pub const MAX_SHAPES: u32 = 1024;

// Bounded: Max text length.
pub const MAX_TEXT_LEN: u32 = 512;

// Bounded: Max text items.
pub const MAX_TEXT_ITEMS: u32 = 256;

// Bounded: Max selection count.
pub const MAX_SELECTION: u32 = 64;

// Bounded: Min zoom level (10%).
pub const MIN_ZOOM: f64 = 0.1;

// Bounded: Max zoom level (1000%).
pub const MAX_ZOOM: f64 = 10.0;

// Bounded: Default zoom level (100%).
pub const DEFAULT_ZOOM: f64 = 1.0;

// Shape type.
pub const ShapeType = enum {
    rectangle,
    circle,
    rounded_rectangle,
};

// Shape: design element on canvas.
pub const Shape = struct {
    id: u32,
    shape_type: ShapeType,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    color: u32,
    corner_radius: f64,
    layer_id: u32,
    z_order: u32,
};

// Text: text element on canvas.
pub const Text = struct {
    id: u32,
    x: f64,
    y: f64,
    content: [MAX_TEXT_LEN]u8,
    content_len: u32,
    font_size: u32,
    color: u32,
    layer_id: u32,
    z_order: u32,
};

// Layer: container for shapes and text.
pub const Layer = struct {
    id: u32,
    name: [64]u8,
    name_len: u32,
    visible: bool,
    locked: bool,
    z_order: u32,
    shapes: [MAX_SHAPES]Shape,
    shapes_len: u32,
    texts: [MAX_TEXT_ITEMS]Text,
    texts_len: u32,
};

// Viewport: camera transformation for canvas.
pub const Viewport = struct {
    zoom: f64,
    pan_x: f64,
    pan_y: f64,
    width: u32,
    height: u32,
};

// Canvas: main canvas state.
pub const Canvas = struct {
    layers: [MAX_LAYERS]Layer,
    layers_len: u32,
    next_shape_id: u32,
    next_text_id: u32,
    next_layer_id: u32,
    viewport: Viewport,
    selection: [MAX_SELECTION]u32,
    selection_len: u32,
    selection_type: SelectionType,

    const SelectionType = enum {
        shape,
        text,
        none,
    };

    pub fn init(width: u32, height: u32) Canvas {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        var canvas = Canvas{
            .layers = undefined,
            .layers_len = 0,
            .next_shape_id = 1,
            .next_text_id = 1,
            .next_layer_id = 1,
            .viewport = Viewport{
                .zoom = DEFAULT_ZOOM,
                .pan_x = 0.0,
                .pan_y = 0.0,
                .width = width,
                .height = height,
            },
            .selection = undefined,
            .selection_len = 0,
            .selection_type = .none,
        };
        std.debug.assert(canvas.viewport.zoom >= MIN_ZOOM);
        std.debug.assert(canvas.viewport.zoom <= MAX_ZOOM);
        return canvas;
    }

    // World to screen coordinate transformation.
    pub fn world_to_screen(
        self: *const Canvas,
        world_x: f64,
        world_y: f64,
    ) struct { x: i32, y: i32 } {
        std.debug.assert(self.viewport.zoom >= MIN_ZOOM);
        std.debug.assert(self.viewport.zoom <= MAX_ZOOM);
        const screen_x = @as(i32, @intFromFloat(
            (world_x + self.viewport.pan_x) * self.viewport.zoom,
        ));
        const screen_y = @as(i32, @intFromFloat(
            (world_y + self.viewport.pan_y) * self.viewport.zoom,
        ));
        return .{ .x = screen_x, .y = screen_y };
    }

    // Screen to world coordinate transformation.
    pub fn screen_to_world(
        self: *const Canvas,
        screen_x: i32,
        screen_y: i32,
    ) struct { x: f64, y: f64 } {
        std.debug.assert(self.viewport.zoom >= MIN_ZOOM);
        std.debug.assert(self.viewport.zoom <= MAX_ZOOM);
        const world_x = (@as(f64, @floatFromInt(screen_x)) / self.viewport.zoom) -
            self.viewport.pan_x;
        const world_y = (@as(f64, @floatFromInt(screen_y)) / self.viewport.zoom) -
            self.viewport.pan_y;
        return .{ .x = world_x, .y = world_y };
    }

    // Set zoom level.
    pub fn set_zoom(self: *Canvas, zoom: f64) void {
        std.debug.assert(zoom >= MIN_ZOOM);
        std.debug.assert(zoom <= MAX_ZOOM);
        self.viewport.zoom = zoom;
        std.debug.assert(self.viewport.zoom >= MIN_ZOOM);
        std.debug.assert(self.viewport.zoom <= MAX_ZOOM);
    }

    // Zoom in.
    pub fn zoom_in(self: *Canvas) void {
        const new_zoom = self.viewport.zoom * 1.2;
        if (new_zoom <= MAX_ZOOM) {
            self.set_zoom(new_zoom);
        } else {
            self.set_zoom(MAX_ZOOM);
        }
    }

    // Zoom out.
    pub fn zoom_out(self: *Canvas) void {
        const new_zoom = self.viewport.zoom / 1.2;
        if (new_zoom >= MIN_ZOOM) {
            self.set_zoom(new_zoom);
        } else {
            self.set_zoom(MIN_ZOOM);
        }
    }

    // Pan canvas.
    pub fn pan(self: *Canvas, dx: f64, dy: f64) void {
        self.viewport.pan_x += dx;
        self.viewport.pan_y += dy;
    }

    // Create new layer.
    pub fn create_layer(self: *Canvas, name: []const u8) ?u32 {
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= 64);
        if (self.layers_len >= MAX_LAYERS) {
            return null;
        }
        const layer_id = self.next_layer_id;
        self.next_layer_id += 1;
        var layer = Layer{
            .id = layer_id,
            .name = undefined,
            .name_len = 0,
            .visible = true,
            .locked = false,
            .z_order = self.layers_len,
            .shapes = undefined,
            .shapes_len = 0,
            .texts = undefined,
            .texts_len = 0,
        };
        const name_len = @min(name.len, 64);
        @memset(layer.name[0..name_len], 0);
        @memcpy(layer.name[0..name_len], name[0..name_len]);
        layer.name_len = @as(u32, @intCast(name_len));
        self.layers[self.layers_len] = layer;
        self.layers_len += 1;
        std.debug.assert(self.layers_len <= MAX_LAYERS);
        return layer_id;
    }

    // Get layer by ID.
    pub fn get_layer(self: *Canvas, layer_id: u32) ?*Layer {
        std.debug.assert(layer_id > 0);
        var i: u32 = 0;
        while (i < self.layers_len) : (i += 1) {
            if (self.layers[i].id == layer_id) {
                return &self.layers[i];
            }
        }
        return null;
    }

    // Add shape to layer.
    pub fn add_shape(
        self: *Canvas,
        layer_id: u32,
        shape_type: ShapeType,
        x: f64,
        y: f64,
        width: f64,
        height: f64,
        color: u32,
        corner_radius: f64,
    ) ?u32 {
        std.debug.assert(layer_id > 0);
        std.debug.assert(width > 0.0);
        std.debug.assert(height > 0.0);
        std.debug.assert(corner_radius >= 0.0);
        if (self.get_layer(layer_id)) |layer| {
            if (layer.shapes_len >= MAX_SHAPES) {
                return null;
            }
            const shape_id = self.next_shape_id;
            self.next_shape_id += 1;
            const z_order = layer.shapes_len;
            var shape = Shape{
                .id = shape_id,
                .shape_type = shape_type,
                .x = x,
                .y = y,
                .width = width,
                .height = height,
                .color = color,
                .corner_radius = corner_radius,
                .layer_id = layer_id,
                .z_order = z_order,
            };
            layer.shapes[layer.shapes_len] = shape;
            layer.shapes_len += 1;
            std.debug.assert(layer.shapes_len <= MAX_SHAPES);
            return shape_id;
        }
        return null;
    }

    // Add text to layer.
    pub fn add_text(
        self: *Canvas,
        layer_id: u32,
        x: f64,
        y: f64,
        content: []const u8,
        font_size: u32,
        color: u32,
    ) ?u32 {
        std.debug.assert(layer_id > 0);
        std.debug.assert(content.len > 0);
        std.debug.assert(content.len <= MAX_TEXT_LEN);
        std.debug.assert(font_size > 0);
        if (self.get_layer(layer_id)) |layer| {
            if (layer.texts_len >= MAX_TEXT_ITEMS) {
                return null;
            }
            const text_id = self.next_text_id;
            self.next_text_id += 1;
            const z_order = layer.texts_len;
            var text = Text{
                .id = text_id,
                .x = x,
                .y = y,
                .content = undefined,
                .content_len = 0,
                .font_size = font_size,
                .color = color,
                .layer_id = layer_id,
                .z_order = z_order,
            };
            const content_len = @min(content.len, MAX_TEXT_LEN);
            @memset(text.content[0..content_len], 0);
            @memcpy(text.content[0..content_len], content[0..content_len]);
            text.content_len = @as(u32, @intCast(content_len));
            layer.texts[layer.texts_len] = text;
            layer.texts_len += 1;
            std.debug.assert(layer.texts_len <= MAX_TEXT_ITEMS);
            return text_id;
        }
        return null;
    }

    // Clear selection.
    pub fn clear_selection(self: *Canvas) void {
        self.selection_len = 0;
        self.selection_type = .none;
        std.debug.assert(self.selection_len == 0);
    }

    // Select shape by ID.
    pub fn select_shape(self: *Canvas, shape_id: u32) bool {
        std.debug.assert(shape_id > 0);
        if (self.selection_len >= MAX_SELECTION) {
            return false;
        }
        self.selection[self.selection_len] = shape_id;
        self.selection_len += 1;
        self.selection_type = .shape;
        std.debug.assert(self.selection_len <= MAX_SELECTION);
        return true;
    }
};

