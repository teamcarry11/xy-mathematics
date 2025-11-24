//! Tests for Grain OS tiling layout system.
//! Why: Verify tiling algorithm correctness and Grain Style compliance.

const std = @import("std");
const testing = std.testing;
const tiling = @import("grain_os").tiling;
const compositor = @import("grain_os").compositor;

test "tiling tree initialization" {
    const tree = tiling.TilingTree.init();
    try testing.expect(tree.nodes_len == 0);
    try testing.expect(tree.root_index == tiling.MAX_LAYOUT_WINDOWS);
    try testing.expect(tree.next_node_index == 0);
}

test "tiling tree add single window" {
    var tree = tiling.TilingTree.init();
    try tree.add_window(1);
    try testing.expect(tree.nodes_len == 1);
    try testing.expect(tree.root_index < tiling.MAX_LAYOUT_WINDOWS);
    const root = tree.nodes[tree.root_index];
    try testing.expect(root.node_type == .window);
    try testing.expect(root.window_id == 1);
}

test "tiling tree add multiple windows" {
    var tree = tiling.TilingTree.init();
    try tree.add_window(1);
    try tree.add_window(2);
    try tree.add_window(3);
    try testing.expect(tree.nodes_len >= 3);
    try testing.expect(tree.root_index < tiling.MAX_LAYOUT_WINDOWS);
    const root = tree.nodes[tree.root_index];
    try testing.expect(root.node_type == .split);
}

test "tiling tree calculate layout single window" {
    var tree = tiling.TilingTree.init();
    try tree.add_window(1);
    tree.calculate_layout(0, 0, 1024, 768);
    const bounds = tree.get_window_bounds(1);
    try testing.expect(bounds != null);
    if (bounds) |b| {
        try testing.expect(b.x == 0);
        try testing.expect(b.y == 0);
        try testing.expect(b.width == 1024);
        try testing.expect(b.height == 768);
    }
}

test "tiling tree calculate layout multiple windows" {
    var tree = tiling.TilingTree.init();
    try tree.add_window(1);
    try tree.add_window(2);
    tree.calculate_layout(0, 0, 1024, 768);
    const bounds1 = tree.get_window_bounds(1);
    const bounds2 = tree.get_window_bounds(2);
    try testing.expect(bounds1 != null);
    try testing.expect(bounds2 != null);
    if (bounds1) |b1| {
        try testing.expect(b1.width > 0);
        try testing.expect(b1.height > 0);
    }
    if (bounds2) |b2| {
        try testing.expect(b2.width > 0);
        try testing.expect(b2.height > 0);
    }
}

test "tiling tree remove window" {
    var tree = tiling.TilingTree.init();
    try tree.add_window(1);
    try tree.add_window(2);
    const removed = tree.remove_window(1);
    try testing.expect(removed == true);
    const bounds1 = tree.get_window_bounds(1);
    const bounds2 = tree.get_window_bounds(2);
    try testing.expect(bounds1 == null);
    try testing.expect(bounds2 != null);
}

test "compositor tiling integration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var comp = compositor.Compositor.init(gpa.allocator());
    const win1 = try comp.create_window(100, 100);
    const win2 = try comp.create_window(200, 200);
    try testing.expect(win1 > 0);
    try testing.expect(win2 > 0);
    const w1 = comp.get_window(win1);
    const w2 = comp.get_window(win2);
    try testing.expect(w1 != null);
    try testing.expect(w2 != null);
    if (w1) |window1| {
        try testing.expect(window1.width > 0);
        try testing.expect(window1.height > 0);
    }
    if (w2) |window2| {
        try testing.expect(window2.width > 0);
        try testing.expect(window2.height > 0);
    }
}

test "compositor remove window with tiling" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var comp = compositor.Compositor.init(gpa.allocator());
    const win1 = try comp.create_window(100, 100);
    const win2 = try comp.create_window(200, 200);
    const removed = comp.remove_window(win1);
    try testing.expect(removed == true);
    try testing.expect(comp.windows_len == 1);
    const w2 = comp.get_window(win2);
    try testing.expect(w2 != null);
}

test "compositor recalculate layout" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var comp = compositor.Compositor.init(gpa.allocator());
    _ = try comp.create_window(100, 100);
    _ = try comp.create_window(200, 200);
    comp.output.width = 1920;
    comp.output.height = 1080;
    comp.recalculate_layout();
    var i: u32 = 0;
    while (i < comp.windows_len) : (i += 1) {
        const win = comp.windows[i];
        try testing.expect(win.width > 0);
        try testing.expect(win.height > 0);
    }
}
