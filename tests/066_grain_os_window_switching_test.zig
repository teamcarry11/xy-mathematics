//! Tests for Grain OS window switching.
//!
//! Why: Verify window switching (Alt+Tab) functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const WindowSwitchOrder = grain_os.window_switching.WindowSwitchOrder;

test "window switch order initialization" {
    const order = WindowSwitchOrder.init();
    std.debug.assert(order.window_ids_len == 0);
    std.debug.assert(order.current_index == 0);
}

test "add window to switch order" {
    var order = WindowSwitchOrder.init();
    const result = order.add_window(1);
    std.debug.assert(result);
    std.debug.assert(order.window_ids_len == 1);
    std.debug.assert(order.window_ids[0] == 1);
}

test "remove window from switch order" {
    var order = WindowSwitchOrder.init();
    _ = order.add_window(1);
    _ = order.add_window(2);
    const result = order.remove_window(1);
    std.debug.assert(result);
    std.debug.assert(order.window_ids_len == 1);
    std.debug.assert(order.window_ids[0] == 2);
}

test "move window to front" {
    var order = WindowSwitchOrder.init();
    _ = order.add_window(1);
    _ = order.add_window(2);
    _ = order.add_window(3);
    order.move_to_front(2);
    std.debug.assert(order.window_ids[0] == 2);
    std.debug.assert(order.current_index == 0);
}

test "get next window" {
    var order = WindowSwitchOrder.init();
    _ = order.add_window(1);
    _ = order.add_window(2);
    _ = order.add_window(3);
    const next = order.get_next();
    std.debug.assert(next != null);
    std.debug.assert(next.? == 2);
}

test "get previous window" {
    var order = WindowSwitchOrder.init();
    _ = order.add_window(1);
    _ = order.add_window(2);
    _ = order.add_window(3);
    order.current_index = 1;
    const prev = order.get_previous();
    std.debug.assert(prev != null);
    std.debug.assert(prev.? == 1);
}

test "get next window wraps around" {
    var order = WindowSwitchOrder.init();
    _ = order.add_window(1);
    _ = order.add_window(2);
    order.current_index = 1;
    const next = order.get_next();
    std.debug.assert(next != null);
    std.debug.assert(next.? == 1);
}

test "compositor switch to next window" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const win1 = try comp.create_window(400, 300);
    const win2 = try comp.create_window(400, 300);
    const win3 = try comp.create_window(400, 300);
    std.debug.assert(win1 > 0);
    std.debug.assert(win2 > 0);
    std.debug.assert(win3 > 0);

    // Focus first window.
    _ = comp.focus_window(win1);
    std.debug.assert(comp.get_focused_window_id() == win1);

    // Switch to next window.
    const result = comp.switch_to_next_window();
    std.debug.assert(result);
    std.debug.assert(comp.get_focused_window_id() == win2);
}

test "compositor switch to previous window" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const win1 = try comp.create_window(400, 300);
    const win2 = try comp.create_window(400, 300);
    std.debug.assert(win1 > 0);
    std.debug.assert(win2 > 0);

    // Focus second window.
    _ = comp.focus_window(win2);
    std.debug.assert(comp.get_focused_window_id() == win2);

    // Switch to previous window.
    const result = comp.switch_to_previous_window();
    std.debug.assert(result);
    std.debug.assert(comp.get_focused_window_id() == win1);
}

test "compositor window added to switch order on creation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = try comp.create_window(400, 300);
    _ = try comp.create_window(400, 300);

    // Check that windows are in switch order.
    std.debug.assert(comp.switch_order.window_ids_len >= 2);
}

test "compositor window removed from switch order on deletion" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const win1 = try comp.create_window(400, 300);
    _ = try comp.create_window(400, 300);
    const initial_len = comp.switch_order.window_ids_len;

    // Remove window.
    _ = comp.remove_window(win1);
    std.debug.assert(comp.switch_order.window_ids_len == initial_len - 1);
}

test "compositor focus moves window to front of switch order" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = try comp.create_window(400, 300);
    const win2 = try comp.create_window(400, 300);
    _ = try comp.create_window(400, 300);

    // Focus middle window.
    _ = comp.focus_window(win2);
    std.debug.assert(comp.switch_order.window_ids[0] == win2);
}

