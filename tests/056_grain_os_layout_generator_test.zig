//! Tests for Grain OS layout generator interface.
//! Why: Verify layout generator interface and layout switching.

const std = @import("std");
const testing = std.testing;
const layout_generator = @import("grain_os").layout_generator;
const tiling = @import("grain_os").tiling;
const compositor = @import("grain_os").compositor;

test "layout registry initialization" {
    const registry = layout_generator.LayoutRegistry.init();
    try testing.expect(registry.generators_len == 4);
    try testing.expect(registry.current_layout == .tall);
}

test "layout registry get layout" {
    const registry = layout_generator.LayoutRegistry.init();
    const tall_fn = registry.get_layout(.tall);
    const wide_fn = registry.get_layout(.wide);
    const grid_fn = registry.get_layout(.grid);
    const monocle_fn = registry.get_layout(.monocle);
    try testing.expect(tall_fn != null);
    try testing.expect(wide_fn != null);
    try testing.expect(grid_fn != null);
    try testing.expect(monocle_fn != null);
}

test "layout registry set current layout" {
    var registry = layout_generator.LayoutRegistry.init();
    const success = registry.set_current_layout(.grid);
    try testing.expect(success == true);
    try testing.expect(registry.current_layout == .grid);
}

test "layout registry apply layout tall" {
    var registry = layout_generator.LayoutRegistry.init();
    var tree = tiling.TilingTree.init();
    _ = try tree.add_window(1);
    _ = try tree.add_window(2);
    registry.apply_layout(&tree, 1024, 768);
    const bounds1 = tree.get_window_bounds(1);
    const bounds2 = tree.get_window_bounds(2);
    try testing.expect(bounds1 != null);
    try testing.expect(bounds2 != null);
}

test "layout registry apply layout grid" {
    var registry = layout_generator.LayoutRegistry.init();
    _ = registry.set_current_layout(.grid);
    var tree = tiling.TilingTree.init();
    _ = try tree.add_window(1);
    _ = try tree.add_window(2);
    _ = try tree.add_window(3);
    registry.apply_layout(&tree, 1024, 768);
    const bounds1 = tree.get_window_bounds(1);
    const bounds2 = tree.get_window_bounds(2);
    const bounds3 = tree.get_window_bounds(3);
    try testing.expect(bounds1 != null);
    try testing.expect(bounds2 != null);
    try testing.expect(bounds3 != null);
}

test "layout registry apply layout monocle" {
    var registry = layout_generator.LayoutRegistry.init();
    _ = registry.set_current_layout(.monocle);
    var tree = tiling.TilingTree.init();
    _ = try tree.add_window(1);
    _ = try tree.add_window(2);
    registry.apply_layout(&tree, 1024, 768);
    const bounds1 = tree.get_window_bounds(1);
    const bounds2 = tree.get_window_bounds(2);
    try testing.expect(bounds1 != null);
    try testing.expect(bounds2 != null);
    if (bounds1) |b1| {
        try testing.expect(b1.width > 0);
        try testing.expect(b1.height > 0);
    }
}

test "compositor layout switching" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var comp = compositor.Compositor.init(gpa.allocator());
    _ = try comp.create_window(100, 100);
    _ = try comp.create_window(200, 200);
    const current = comp.get_current_layout();
    try testing.expect(current == .tall);
    const success = comp.set_layout(.grid);
    try testing.expect(success == true);
    try testing.expect(comp.get_current_layout() == .grid);
}

test "compositor layout switching multiple" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var comp = compositor.Compositor.init(gpa.allocator());
    _ = try comp.create_window(100, 100);
    _ = try comp.create_window(200, 200);
    _ = comp.set_layout(.tall);
    try testing.expect(comp.get_current_layout() == .tall);
    _ = comp.set_layout(.wide);
    try testing.expect(comp.get_current_layout() == .wide);
    _ = comp.set_layout(.grid);
    try testing.expect(comp.get_current_layout() == .grid);
}

