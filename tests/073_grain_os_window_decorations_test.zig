//! Tests for Grain OS window decorations (title bar buttons).
//!
//! Why: Verify window decoration button functionality and hit testing.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const window_decorations = grain_os.window_decorations;

test "button constants" {
    std.debug.assert(window_decorations.BUTTON_SIZE == 20);
    std.debug.assert(window_decorations.BUTTON_SPACING == 4);
    std.debug.assert(window_decorations.BUTTON_MARGIN == 4);
}

test "get close button bounds" {
    const bounds = window_decorations.get_close_button_bounds(100, 200, 800);
    std.debug.assert(bounds.width == window_decorations.BUTTON_SIZE);
    std.debug.assert(bounds.height == grain_os.compositor.TITLE_BAR_HEIGHT);
}

test "get minimize button bounds" {
    const bounds = window_decorations.get_minimize_button_bounds(100, 200, 800);
    std.debug.assert(bounds.width == window_decorations.BUTTON_SIZE);
    std.debug.assert(bounds.height == grain_os.compositor.TITLE_BAR_HEIGHT);
}

test "get maximize button bounds" {
    const bounds = window_decorations.get_maximize_button_bounds(100, 200, 800);
    std.debug.assert(bounds.width == window_decorations.BUTTON_SIZE);
    std.debug.assert(bounds.height == grain_os.compositor.TITLE_BAR_HEIGHT);
}

test "is in close button" {
    const win_x: i32 = 100;
    const win_y: i32 = 200;
    const win_width: u32 = 800;
    const bounds = window_decorations.get_close_button_bounds(win_x, win_y, win_width);
    const x = @as(u32, @intCast(bounds.x + @as(i32, @intCast(bounds.width / 2))));
    const y = @as(u32, @intCast(bounds.y + @as(i32, @intCast(bounds.height / 2))));
    const result = window_decorations.is_in_close_button(win_x, win_y, win_width, x, y);
    std.debug.assert(result);
}

test "is in minimize button" {
    const win_x: i32 = 100;
    const win_y: i32 = 200;
    const win_width: u32 = 800;
    const bounds = window_decorations.get_minimize_button_bounds(win_x, win_y, win_width);
    const x = @as(u32, @intCast(bounds.x + @as(i32, @intCast(bounds.width / 2))));
    const y = @as(u32, @intCast(bounds.y + @as(i32, @intCast(bounds.height / 2))));
    const result = window_decorations.is_in_minimize_button(win_x, win_y, win_width, x, y);
    std.debug.assert(result);
}

test "is in maximize button" {
    const win_x: i32 = 100;
    const win_y: i32 = 200;
    const win_width: u32 = 800;
    const bounds = window_decorations.get_maximize_button_bounds(win_x, win_y, win_width);
    const x = @as(u32, @intCast(bounds.x + @as(i32, @intCast(bounds.width / 2))));
    const y = @as(u32, @intCast(bounds.y + @as(i32, @intCast(bounds.height / 2))));
    const result = window_decorations.is_in_maximize_button(win_x, win_y, win_width, x, y);
    std.debug.assert(result);
}

test "get button at point" {
    const win_x: i32 = 100;
    const win_y: i32 = 200;
    const win_width: u32 = 800;
    const close_bounds = window_decorations.get_close_button_bounds(win_x, win_y, win_width);
    const x = @as(u32, @intCast(close_bounds.x + @as(i32, @intCast(close_bounds.width / 2))));
    const y = @as(u32, @intCast(close_bounds.y + @as(i32, @intCast(close_bounds.height / 2))));
    const button_type = window_decorations.get_button_at(win_x, win_y, win_width, x, y);
    std.debug.assert(button_type == window_decorations.ButtonType.close);
}

test "get button color" {
    const close_color = window_decorations.get_button_color(
        window_decorations.ButtonType.close,
        false,
        false,
        true,
    );
    std.debug.assert(close_color > 0);
    const hovered_color = window_decorations.get_button_color(
        window_decorations.ButtonType.close,
        true,
        false,
        true,
    );
    std.debug.assert(hovered_color > 0);
    std.debug.assert(hovered_color != close_color);
}

test "compositor is in title bar" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    if (comp.get_window(window_id)) |win| {
        const title_bar_x = @as(u32, @intCast(win.x + @as(i32, @intCast(grain_os.compositor.BORDER_WIDTH))));
        const title_bar_y = @as(u32, @intCast(win.y + @as(i32, @intCast(grain_os.compositor.BORDER_WIDTH))));
        const result = comp.is_in_title_bar(window_id, title_bar_x, title_bar_y);
        std.debug.assert(result);
    }
}

test "compositor button click handling" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    if (comp.get_window(window_id)) |win| {
        const minimize_bounds = window_decorations.get_minimize_button_bounds(
            win.x,
            win.y,
            win.width,
        );
        const x = @as(u32, @intCast(minimize_bounds.x + @as(i32, @intCast(minimize_bounds.width / 2))));
        const y = @as(u32, @intCast(minimize_bounds.y + @as(i32, @intCast(minimize_bounds.height / 2))));
        const button_type = window_decorations.get_button_at(win.x, win.y, win.width, x, y);
        std.debug.assert(button_type == window_decorations.ButtonType.minimize);
    }
}

