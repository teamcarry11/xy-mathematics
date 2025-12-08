//! Grain OS Layout Generator: Interface for different tiling layouts.
//!
//! Why: Allow switching between layout algorithms (tall, wide, grid, monocle).
//! Architecture: Function pointer interface, works with TilingTree.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const tiling = @import("tiling.zig");
const compositor = @import("compositor.zig");

// Bounded: Max number of layout types.
pub const MAX_LAYOUT_TYPES: u32 = 16;

// Layout type enumeration.
pub const LayoutType = enum(u8) {
    tall, // Tall layout (main window on left, stack on right)
    wide, // Wide layout (main window on top, stack on bottom)
    grid, // Grid layout (equal-sized grid)
    monocle, // Monocle layout (fullscreen, one at a time)
};

// Layout function signature: applies layout to tiling tree.
// Why: VTable-style function pointer for layout calculation.
pub const LayoutFn = *const fn (
    *tiling.TilingTree,
    u32, // output_width
    u32, // output_height
) void;

// Layout generator: manages layout functions.
pub const LayoutGenerator = struct {
    layout_type: LayoutType,
    layout_fn: LayoutFn,
    name: [32]u8,
    name_len: u32,

    pub fn init(
        layout_type: LayoutType,
        layout_fn: LayoutFn,
        name: []const u8,
    ) LayoutGenerator {
        std.debug.assert(@intFromPtr(layout_fn) != 0);
        std.debug.assert(name.len <= 32);
        var generator = LayoutGenerator{
            .layout_type = layout_type,
            .layout_fn = layout_fn,
            .name = undefined,
            .name_len = 0,
        };
        @memset(&generator.name, 0);
        const copy_len = @min(name.len, 32);
        var i: u32 = 0;
        while (i < copy_len) : (i += 1) {
            generator.name[i] = name[i];
        }
        generator.name_len = @intCast(copy_len);
        std.debug.assert(@intFromPtr(generator.layout_fn) != 0);
        return generator;
    }
};

// Tall layout: main window on left, stack on right (vertical split).
pub fn layout_tall(
    tree: *tiling.TilingTree,
    output_width: u32,
    output_height: u32,
) void {
    std.debug.assert(output_width > 0);
    std.debug.assert(output_height > 0);
    // Use default tiling tree calculation (already does vertical splits).
    tree.calculate_layout(0, 0, output_width, output_height);
}

// Wide layout: main window on top, stack on bottom (horizontal split).
pub fn layout_wide(
    tree: *tiling.TilingTree,
    output_width: u32,
    output_height: u32,
) void {
    std.debug.assert(output_width > 0);
    std.debug.assert(output_height > 0);
    // For wide layout, we need to modify split directions to horizontal.
    // For now, use default calculation (can be enhanced later).
    tree.calculate_layout(0, 0, output_width, output_height);
}

// Grid layout: equal-sized grid of windows.
pub fn layout_grid(
    tree: *tiling.TilingTree,
    output_width: u32,
    output_height: u32,
) void {
    std.debug.assert(output_width > 0);
    std.debug.assert(output_height > 0);
    // Grid layout: calculate grid dimensions and positions.
    if (tree.nodes_len == 0) {
        return;
    }
    // Count window nodes.
    var window_count: u32 = 0;
    var i: u32 = 0;
    while (i < tree.nodes_len) : (i += 1) {
        if (tree.nodes[i].node_type == .window) {
            window_count += 1;
        }
    }
    if (window_count == 0) {
        return;
    }
    // Calculate grid dimensions (square-ish grid).
    var cols: u32 = 1;
    while (cols * cols < window_count) : (cols += 1) {}
    const rows = (window_count + cols - 1) / cols;
    const cell_width = output_width / cols;
    const cell_height = output_height / rows;
    // Assign positions to windows.
    var window_idx: u32 = 0;
    i = 0;
    while (i < tree.nodes_len) : (i += 1) {
        if (tree.nodes[i].node_type == .window) {
            const col = window_idx % cols;
            const row = window_idx / cols;
            const cell_x = @as(i32, @intCast(col * cell_width));
            const cell_y = @as(i32, @intCast(row * cell_height));
            tree.nodes[i].set_bounds(cell_x, cell_y, cell_width, cell_height);
            window_idx += 1;
        }
    }
}

// Monocle layout: fullscreen, one window at a time.
pub fn layout_monocle(
    tree: *tiling.TilingTree,
    output_width: u32,
    output_height: u32,
) void {
    std.debug.assert(output_width > 0);
    std.debug.assert(output_height > 0);
    // Monocle: find focused window and make it fullscreen.
    var focused_window_index: u32 = tiling.MAX_LAYOUT_WINDOWS;
    var i: u32 = 0;
    while (i < tree.nodes_len) : (i += 1) {
        if (tree.nodes[i].node_type == .window) {
            // For now, use first window as focused (can be enhanced later).
            if (focused_window_index == tiling.MAX_LAYOUT_WINDOWS) {
                focused_window_index = i;
            }
        }
    }
    // Make focused window fullscreen, hide others.
    i = 0;
    while (i < tree.nodes_len) : (i += 1) {
        if (tree.nodes[i].node_type == .window) {
            if (i == focused_window_index) {
                tree.nodes[i].set_bounds(0, 0, output_width, output_height);
            } else {
                // Hide window (set to zero size).
                tree.nodes[i].set_bounds(0, 0, 0, 0);
            }
        }
    }
}

// Layout registry: manages available layouts.
pub const LayoutRegistry = struct {
    generators: [MAX_LAYOUT_TYPES]LayoutGenerator,
    generators_len: u32,
    current_layout: LayoutType,

    pub fn init() LayoutRegistry {
        var registry = LayoutRegistry{
            .generators = undefined,
            .generators_len = 0,
            .current_layout = .tall,
        };
        var i: u32 = 0;
        while (i < MAX_LAYOUT_TYPES) : (i += 1) {
            registry.generators[i] = LayoutGenerator.init(.tall, layout_tall, "tall");
        }
        registry.generators[0] = LayoutGenerator.init(.tall, layout_tall, "tall");
        registry.generators[1] = LayoutGenerator.init(.wide, layout_wide, "wide");
        registry.generators[2] = LayoutGenerator.init(.grid, layout_grid, "grid");
        registry.generators[3] = LayoutGenerator.init(.monocle, layout_monocle, "monocle");
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

    pub fn set_current_layout(self: *LayoutRegistry, layout_type: LayoutType) bool {
        var i: u32 = 0;
        while (i < self.generators_len) : (i += 1) {
            if (self.generators[i].layout_type == layout_type) {
                self.current_layout = layout_type;
                return true;
            }
        }
        return false;
    }

    pub fn apply_layout(
        self: *const LayoutRegistry,
        tree: *tiling.TilingTree,
        output_width: u32,
        output_height: u32,
    ) void {
        std.debug.assert(output_width > 0);
        std.debug.assert(output_height > 0);
        if (self.get_layout(self.current_layout)) |layout_fn| {
            layout_fn(tree, output_width, output_height);
        }
    }
};

