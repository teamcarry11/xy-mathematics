//! Tests for Grain OS window decorations and operations.
//!
//! Why: Verify window decorations rendering and operations.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;

test "window decorations initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(800, 600);
    std.debug.assert(window_id > 0);

    if (compositor.get_window(window_id)) |win| {
        std.debug.assert(win.minimized == false);
        std.debug.assert(win.maximized == false);
    }
}

test "window minimize" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(800, 600);
    const minimized = compositor.minimize_window(window_id);
    std.debug.assert(minimized);

    if (compositor.get_window(window_id)) |win| {
        std.debug.assert(win.minimized == true);
        std.debug.assert(win.visible == false);
    }
}

test "window restore" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(800, 600);
    _ = compositor.minimize_window(window_id);
    const restored = compositor.restore_window(window_id);
    std.debug.assert(restored);

    if (compositor.get_window(window_id)) |win| {
        std.debug.assert(win.minimized == false);
        std.debug.assert(win.visible == true);
    }
}

test "window maximize" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(800, 600);
    const maximized = compositor.maximize_window(window_id);
    std.debug.assert(maximized);

    if (compositor.get_window(window_id)) |win| {
        std.debug.assert(win.maximized == true);
        std.debug.assert(win.width == compositor.output.width);
    }
}

test "window unmaximize" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(800, 600);
    _ = compositor.maximize_window(window_id);
    const unmaximized = compositor.unmaximize_window(window_id);
    std.debug.assert(unmaximized);

    if (compositor.get_window(window_id)) |win| {
        std.debug.assert(win.maximized == false);
    }
}

test "title bar hit testing" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(800, 600);
    if (compositor.get_window(window_id)) |win| {
        const win_x = @as(u32, @intCast(win.x));
        const win_y = @as(u32, @intCast(win.y));
        const title_x = win_x + grain_os.compositor.BORDER_WIDTH + 10;
        const title_y = win_y + grain_os.compositor.BORDER_WIDTH + 5;
        const in_title = compositor.is_in_title_bar(window_id, title_x, title_y);
        std.debug.assert(in_title);
    }
}

test "close button hit testing" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(800, 600);
    if (compositor.get_window(window_id)) |win| {
        const win_x = @as(u32, @intCast(win.x));
        const win_y = @as(u32, @intCast(win.y));
        const button_x = win_x + win.width - grain_os.compositor.BORDER_WIDTH - 10;
        const button_y = win_y + grain_os.compositor.BORDER_WIDTH + 5;
        const in_button = compositor.is_in_close_button(window_id, button_x, button_y);
        std.debug.assert(in_button);
    }
}

