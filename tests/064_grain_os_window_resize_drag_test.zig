//! Tests for Grain OS window resizing and dragging.
//!
//! Why: Verify window resize and drag functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const ResizeHandle = grain_os.compositor.ResizeHandle;

test "window resize handle detection" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(400, 300);
    if (compositor.get_window(window_id)) |win| {
        const win_x = @as(u32, @intCast(win.x));
        const win_y = @as(u32, @intCast(win.y));
        // Test top-left corner.
        const handle = compositor.get_resize_handle(window_id, win_x + 2, win_y + 2);
        std.debug.assert(handle != null);
        std.debug.assert(handle.? == ResizeHandle.top_left);
    }
}

test "window drag start" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(400, 300);
    if (compositor.get_window(window_id)) |win| {
        const win_x = @as(u32, @intCast(win.x));
        const win_y = @as(u32, @intCast(win.y));
        const title_x = win_x + grain_os.compositor.BORDER_WIDTH + 10;
        const title_y = win_y + grain_os.compositor.BORDER_WIDTH + 5;
        // Start drag from title bar.
        compositor.start_drag(window_id, title_x, title_y);
        std.debug.assert(win.drag_state.active == true);
    }
}

test "window resize start" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(400, 300);
    if (compositor.get_window(window_id)) |win| {
        const win_x = @as(u32, @intCast(win.x));
        const win_y = @as(u32, @intCast(win.y));
        // Start resize from bottom-right corner.
        compositor.start_resize(window_id, ResizeHandle.bottom_right, win_x + win.width - 2, win_y + win.height - 2);
        std.debug.assert(win.resize_state.active == true);
        std.debug.assert(win.resize_state.handle == ResizeHandle.bottom_right);
    }
}

test "window drag end" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(400, 300);
    _ = compositor.focus_window(window_id);
    if (compositor.get_window(window_id)) |win| {
        const win_x = @as(u32, @intCast(win.x));
        const win_y = @as(u32, @intCast(win.y));
        compositor.start_drag(window_id, win_x + 10, win_y + 10);
        compositor.end_drag();
        std.debug.assert(win.drag_state.active == false);
    }
}

test "window resize end" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(400, 300);
    if (compositor.get_window(window_id)) |win| {
        const win_x = @as(u32, @intCast(win.x));
        const win_y = @as(u32, @intCast(win.y));
        compositor.start_resize(window_id, ResizeHandle.bottom_right, win_x + win.width - 2, win_y + win.height - 2);
        compositor.end_resize();
        std.debug.assert(win.resize_state.active == false);
        std.debug.assert(win.resize_state.handle == ResizeHandle.none);
    }
}

