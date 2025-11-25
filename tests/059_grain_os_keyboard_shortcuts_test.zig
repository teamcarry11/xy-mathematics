//! Tests for Grain OS keyboard shortcuts and window actions.
//!
//! Why: Verify keyboard shortcuts trigger correct window actions.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const ShortcutRegistry = grain_os.keyboard_shortcuts.ShortcutRegistry;
const window_actions = grain_os.window_actions;

test "shortcut registry initialization" {
    const registry = ShortcutRegistry.init();
    std.debug.assert(registry.shortcuts_len > 0);
    std.debug.assert(registry.shortcuts_len <= grain_os.keyboard_shortcuts.MAX_SHORTCUTS);
}

test "find shortcut" {
    const registry = ShortcutRegistry.init();
    const action_opt = registry.find_shortcut(
        grain_os.keyboard_shortcuts.MODIFIER_CTRL | grain_os.keyboard_shortcuts.MODIFIER_ALT,
        grain_os.keyboard_shortcuts.KEY_LEFT,
    );
    std.debug.assert(action_opt != null);
}

test "action left half" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(800, 600);
    const result = window_actions.action_left_half(&compositor, window_id);
    std.debug.assert(result);

    if (compositor.get_window(window_id)) |win| {
        std.debug.assert(win.width == compositor.output.width / 2);
        std.debug.assert(win.x == @as(i32, @intCast(grain_os.compositor.BORDER_WIDTH)));
    }
}

test "action right half" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(800, 600);
    const result = window_actions.action_right_half(&compositor, window_id);
    std.debug.assert(result);

    if (compositor.get_window(window_id)) |win| {
        std.debug.assert(win.width == compositor.output.width / 2);
        std.debug.assert(win.x == @as(i32, @intCast(compositor.output.width / 2)));
    }
}

test "action top left quarter" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(800, 600);
    const result = window_actions.action_top_left(&compositor, window_id);
    std.debug.assert(result);

    if (compositor.get_window(window_id)) |win| {
        std.debug.assert(win.width == compositor.output.width / 2);
        std.debug.assert(win.x == @as(i32, @intCast(grain_os.compositor.BORDER_WIDTH)));
    }
}

test "action center" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(400, 300);
    const result = window_actions.action_center(&compositor, window_id);
    std.debug.assert(result);

    if (compositor.get_window(window_id)) |win| {
        const content_width = compositor.output.width - (grain_os.compositor.BORDER_WIDTH * 2);
        const center_x = (content_width - win.width) / 2;
        std.debug.assert(win.x >= @as(i32, @intCast(grain_os.compositor.BORDER_WIDTH + center_x - 1)));
        std.debug.assert(win.x <= @as(i32, @intCast(grain_os.compositor.BORDER_WIDTH + center_x + 1)));
    }
}

test "action larger" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(400, 300);
    if (compositor.get_window(window_id)) |win| {
        const old_width = win.width;
        const old_height = win.height;
        const result = window_actions.action_larger(&compositor, window_id);
        std.debug.assert(result);
        std.debug.assert(win.width >= old_width);
        std.debug.assert(win.height >= old_height);
    }
}

test "action smaller" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(400, 300);
    if (compositor.get_window(window_id)) |win| {
        const old_width = win.width;
        const old_height = win.height;
        const result = window_actions.action_smaller(&compositor, window_id);
        std.debug.assert(result);
        std.debug.assert(win.width <= old_width);
        std.debug.assert(win.height <= old_height);
    }
}

