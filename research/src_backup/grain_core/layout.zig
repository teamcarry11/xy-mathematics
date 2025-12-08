//! Grain OS Layout: Layout generators for dynamic tiling.
//!
//! Why: River-inspired layout system with built-in layouts.
//! Architecture: Layout function interface, multiple layout types.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const tiling = @import("tiling.zig");
const math = std.math;

// Bounded: Max number of layout types.
pub const MAX_LAYOUT_TYPES: u32 = 16;

// Layout type enumeration.
pub const LayoutType = enum(u8) {
    tall, // Tall layout (main window on left, stack on right)
    wide, // Wide layout (main window on top, stack on bottom)
    grid, // Grid layout (equal-sized grid)
    monocle, // Monocle layout (fullscreen, one at a time)
    floating, // Floating layout (manual positioning)
};

// Layout function signature.
// Why: VTable-style function pointer for layout calculation.
pub const LayoutFn = *const fn (
    *tiling.TilingEngine,
    u32, // container_id
    i32, // x
    i32, // y
    u32, // width
    u32, // height
) void;

// Layout generator: manages layout functions.
pub const LayoutGenerator = struct {
    layout_type: LayoutType,
    layout_fn: LayoutFn,

    pub fn init(layout_type: LayoutType, layout_fn: LayoutFn) LayoutGenerator {
        std.debug.assert(@intFromPtr(layout_fn) != 0);
        const generator = LayoutGenerator{
            .layout_type = layout_type,
            .layout_fn = layout_fn,
        };
        std.debug.assert(@intFromPtr(generator.layout_fn) != 0);
        return generator;
    }
};

// Tall layout: main window on left, stack on right.
pub fn layout_tall(
    engine: *tiling.TilingEngine,
    container_id: u32,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
) void {
    std.debug.assert(container_id > 0);
    std.debug.assert(width > 0);
    std.debug.assert(height > 0);
    const container = engine.get_container(container_id) orelse return;
    if (container.children_len == 0) {
        return;
    }
    const main_width = width * 2 / 3;
    const stack_width = width - main_width;
    var i: u32 = 0;
    while (i < container.children_len) : (i += 1) {
        const child_id = container.children[i];
        if (i == 0) {
            // Main window (left side)
            if (container.is_view) {
                if (engine.get_view(child_id)) |view| {
                    view.x = x;
                    view.y = y;
                    view.width = main_width;
                    view.height = height;
                }
            } else {
                engine.calculate_layout(child_id, x, y, main_width, height);
            }
        } else {
            // Stack windows (right side)
            const stack_y = y + @as(i32, @intCast((i - 1) * height / (container.children_len - 1)));
            const stack_height = height / (container.children_len - 1);
            if (container.is_view) {
                if (engine.get_view(child_id)) |view| {
                    view.x = x + @as(i32, @intCast(main_width));
                    view.y = stack_y;
                    view.width = stack_width;
                    view.height = stack_height;
                }
            } else {
                engine.calculate_layout(
                    child_id,
                    x + @as(i32, @intCast(main_width)),
                    stack_y,
                    stack_width,
                    stack_height,
                );
            }
        }
    }
}

// Wide layout: main window on top, stack on bottom.
pub fn layout_wide(
    engine: *tiling.TilingEngine,
    container_id: u32,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
) void {
    std.debug.assert(container_id > 0);
    std.debug.assert(width > 0);
    std.debug.assert(height > 0);
    const container = engine.get_container(container_id) orelse return;
    if (container.children_len == 0) {
        return;
    }
    const main_height = height * 2 / 3;
    const stack_height = height - main_height;
    var i: u32 = 0;
    while (i < container.children_len) : (i += 1) {
        const child_id = container.children[i];
        if (i == 0) {
            // Main window (top)
            if (container.is_view) {
                if (engine.get_view(child_id)) |view| {
                    view.x = x;
                    view.y = y;
                    view.width = width;
                    view.height = main_height;
                }
            } else {
                engine.calculate_layout(child_id, x, y, width, main_height);
            }
        } else {
            // Stack windows (bottom)
            const stack_x = x + @as(i32, @intCast((i - 1) * width / (container.children_len - 1)));
            const stack_width = width / (container.children_len - 1);
            if (container.is_view) {
                if (engine.get_view(child_id)) |view| {
                    view.x = stack_x;
                    view.y = y + @as(i32, @intCast(main_height));
                    view.width = stack_width;
                    view.height = stack_height;
                }
            } else {
                engine.calculate_layout(
                    child_id,
                    stack_x,
                    y + @as(i32, @intCast(main_height)),
                    stack_width,
                    stack_height,
                );
            }
        }
    }
}

// Grid layout: equal-sized grid.
pub fn layout_grid(
    engine: *tiling.TilingEngine,
    container_id: u32,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
) void {
    std.debug.assert(container_id > 0);
    std.debug.assert(width > 0);
    std.debug.assert(height > 0);
    const container = engine.get_container(container_id) orelse return;
    if (container.children_len == 0) {
        return;
    }
    // Calculate grid dimensions (square-ish grid)
    var cols: u32 = 1;
    while (cols * cols < container.children_len) : (cols += 1) {}
    const rows = (container.children_len + cols - 1) / cols;
    const cell_width = width / cols;
    const cell_height = height / rows;
    var i: u32 = 0;
    while (i < container.children_len) : (i += 1) {
        const col = i % cols;
        const row = i / cols;
        const cell_x = x + @as(i32, @intCast(col * cell_width));
        const cell_y = y + @as(i32, @intCast(row * cell_height));
        const child_id = container.children[i];
        if (container.is_view) {
            if (engine.get_view(child_id)) |view| {
                view.x = cell_x;
                view.y = cell_y;
                view.width = cell_width;
                view.height = cell_height;
            }
        } else {
            engine.calculate_layout(child_id, cell_x, cell_y, cell_width, cell_height);
        }
    }
}

// Monocle layout: fullscreen, one at a time.
pub fn layout_monocle(
    engine: *tiling.TilingEngine,
    container_id: u32,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
) void {
    std.debug.assert(container_id > 0);
    std.debug.assert(width > 0);
    std.debug.assert(height > 0);
    const container = engine.get_container(container_id) orelse return;
    if (container.children_len == 0) {
        return;
    }
    var focused_index: u32 = 0;
    var i: u32 = 0;
    while (i < container.children_len) : (i += 1) {
        const child_id = container.children[i];
        if (container.is_view) {
            if (engine.get_view(child_id)) |view| {
                if (view.focused) {
                    focused_index = i;
                }
            }
        }
    }
    i = 0;
    while (i < container.children_len) : (i += 1) {
        const child_id = container.children[i];
        if (i == focused_index) {
            // Show focused window
            if (container.is_view) {
                if (engine.get_view(child_id)) |view| {
                    view.x = x;
                    view.y = y;
                    view.width = width;
                    view.height = height;
                    view.visible = true;
                }
            } else {
                engine.calculate_layout(child_id, x, y, width, height);
            }
        } else {
            // Hide other windows
            if (container.is_view) {
                if (engine.get_view(child_id)) |view| {
                    view.visible = false;
                }
            }
        }
    }
}

// Layout registry: manages available layouts.
pub const LayoutRegistry = struct {
    generators: [MAX_LAYOUT_TYPES]LayoutGenerator,
    generators_len: u32,

    pub fn init() LayoutRegistry {
        var registry = LayoutRegistry{
            .generators = undefined,
            .generators_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_LAYOUT_TYPES) : (i += 1) {
            registry.generators[i] = LayoutGenerator.init(.tall, layout_tall);
        }
        registry.generators[0] = LayoutGenerator.init(.tall, layout_tall);
        registry.generators[1] = LayoutGenerator.init(.wide, layout_wide);
        registry.generators[2] = LayoutGenerator.init(.grid, layout_grid);
        registry.generators[3] = LayoutGenerator.init(.monocle, layout_monocle);
        registry.generators_len = 4;
        std.debug.assert(registry.generators_len <= MAX_LAYOUT_TYPES);
        return registry;
    }

    pub fn get_layout(self: *const LayoutRegistry, layout_type: LayoutType) ?LayoutFn {
        var i: u32 = 0;
        while (i < self.generators_len) : (i += 1) {
            if (self.generators[i].layout_type == layout_type) {
                return self.generators[i].layout_fn;
            }
        }
        return null;
    }
};

