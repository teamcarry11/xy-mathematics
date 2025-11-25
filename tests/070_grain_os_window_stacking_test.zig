//! Tests for Grain OS window stacking order management.
//!
//! Why: Verify window z-order management and layering.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const WindowStack = grain_os.window_stacking.WindowStack;

test "window stack initialization" {
    const stack = WindowStack.init();
    std.debug.assert(stack.window_ids_len == 0);
}

test "add window to stack" {
    var stack = WindowStack.init();
    const result = stack.add_window(1);
    std.debug.assert(result);
    std.debug.assert(stack.window_ids_len == 1);
    std.debug.assert(stack.window_ids[0] == 1);
}

test "remove window from stack" {
    var stack = WindowStack.init();
    _ = stack.add_window(1);
    const result = stack.remove_window(1);
    std.debug.assert(result);
    std.debug.assert(stack.window_ids_len == 0);
}

test "raise window to top" {
    var stack = WindowStack.init();
    _ = stack.add_window(1);
    _ = stack.add_window(2);
    _ = stack.add_window(3);
    const result = stack.raise_to_top(1);
    std.debug.assert(result);
    std.debug.assert(stack.get_top_window() == 1);
}

test "lower window to bottom" {
    var stack = WindowStack.init();
    _ = stack.add_window(1);
    _ = stack.add_window(2);
    _ = stack.add_window(3);
    const result = stack.lower_to_bottom(3);
    std.debug.assert(result);
    std.debug.assert(stack.get_bottom_window() == 3);
}

test "get window at index" {
    var stack = WindowStack.init();
    _ = stack.add_window(1);
    _ = stack.add_window(2);
    _ = stack.add_window(3);
    const win1 = stack.get_window_at(0);
    const win2 = stack.get_window_at(1);
    const win3 = stack.get_window_at(2);
    std.debug.assert(win1 == 1);
    std.debug.assert(win2 == 2);
    std.debug.assert(win3 == 3);
}

test "get top and bottom windows" {
    var stack = WindowStack.init();
    _ = stack.add_window(1);
    _ = stack.add_window(2);
    _ = stack.add_window(3);
    std.debug.assert(stack.get_top_window() == 3);
    std.debug.assert(stack.get_bottom_window() == 1);
}

test "compositor window added to stack" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);
    std.debug.assert(comp.window_stack.window_ids_len == 1);
    std.debug.assert(comp.window_stack.get_top_window() == window_id);
}

test "compositor window removed from stack" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const win1 = try comp.create_window(800, 600);
    const win2 = try comp.create_window(900, 700);
    _ = comp.remove_window(win1);
    std.debug.assert(comp.window_stack.window_ids_len == 1);
    std.debug.assert(comp.window_stack.get_top_window() == win2);
}

test "compositor focus raises window" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const win1 = try comp.create_window(800, 600);
    const win2 = try comp.create_window(900, 700);
    _ = comp.focus_window(win1);
    std.debug.assert(comp.window_stack.get_top_window() == win1);
}

test "compositor raise window" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const win1 = try comp.create_window(800, 600);
    const win2 = try comp.create_window(900, 700);
    const result = comp.raise_window(win1);
    std.debug.assert(result);
    std.debug.assert(comp.window_stack.get_top_window() == win1);
}

test "compositor lower window" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const _win1 = try comp.create_window(800, 600);
    const win2 = try comp.create_window(900, 700);
    const result = comp.lower_window(win2);
    std.debug.assert(result);
    std.debug.assert(comp.window_stack.get_bottom_window() == win2);
}

test "compositor render uses stacking order" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = try comp.create_window(800, 600);
    _ = try comp.create_window(900, 700);
    // Render should use stacking order (should not crash).
    comp.render_to_framebuffer();
}

test "compositor hit testing uses stacking order" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const win1 = try comp.create_window(800, 600);
    const _win2 = try comp.create_window(900, 700);
    // Top window should be found first.
    _ = comp.raise_window(win1);
    const found = comp.find_window_at(100, 100);
    // Should find top window (win1).
    std.debug.assert(found == win1);
}

