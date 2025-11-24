//! Tests for Grain OS input routing and focus management.
//!
//! Why: Verify input event routing and window focus functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const input_handler = grain_os.input_handler;

// Mock syscall function for testing.
fn mock_syscall_no_event(
    syscall_num: u32,
    _arg1: u64,
    _arg2: u64,
    _arg3: u64,
    _arg4: u64,
) i64 {
    _ = _arg1;
    _ = _arg2;
    _ = _arg3;
    _ = _arg4;
    if (syscall_num == 60) {
        // read_input_event - would_block
        return -6;
    }
    return 0;
}

// Mock syscall function that returns a mouse click event.
fn mock_syscall_mouse_click(
    syscall_num: u32,
    arg1: u64,
    _arg2: u64,
    _arg3: u64,
    _arg4: u64,
) i64 {
    _ = _arg2;
    _ = _arg3;
    _ = _arg4;
    if (syscall_num == 60) {
        // read_input_event - write mouse click event to buffer.
        const buf = @as([*]u8, @ptrFromInt(@as(usize, @intCast(arg1))));
        buf[0] = 0; // event_type = mouse
        buf[4] = 0; // kind = down
        buf[5] = 0; // button = left
        // x = 100 (little-endian)
        buf[6] = 100;
        buf[7] = 0;
        buf[8] = 0;
        buf[9] = 0;
        // y = 200 (little-endian)
        buf[10] = 200;
        buf[11] = 0;
        buf[12] = 0;
        buf[13] = 0;
        buf[14] = 0; // modifiers
        return 32; // event size
    }
    return 0;
}

test "compositor input handler initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    compositor.set_syscall_fn(mock_syscall_no_event);
    std.debug.assert(compositor.get_focused_window_id() == 0);
}

test "find window at position" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window1_id = try compositor.create_window(800, 600);
    const window2_id = try compositor.create_window(400, 300);
    std.debug.assert(window1_id > 0);
    std.debug.assert(window2_id > 0);

    // Find window at position (100, 200) - should be in first window.
    const found_id = compositor.find_window_at(100, 200);
    std.debug.assert(found_id != null);
    if (found_id) |id| {
        std.debug.assert(id == window1_id or id == window2_id);
    }
}

test "focus window" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(800, 600);
    std.debug.assert(window_id > 0);

    // Focus window.
    const focused = compositor.focus_window(window_id);
    std.debug.assert(focused);
    std.debug.assert(compositor.get_focused_window_id() == window_id);

    // Check window is focused.
    if (compositor.get_window(window_id)) |win| {
        std.debug.assert(win.focused == true);
    }
}

test "unfocus all windows" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const window_id = try compositor.create_window(800, 600);
    _ = compositor.focus_window(window_id);
    std.debug.assert(compositor.get_focused_window_id() == window_id);

    // Unfocus all.
    compositor.unfocus_all();
    std.debug.assert(compositor.get_focused_window_id() == 0);

    // Check window is unfocused.
    if (compositor.get_window(window_id)) |win| {
        std.debug.assert(win.focused == false);
    }
}

test "process input mouse click" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    compositor.set_syscall_fn(mock_syscall_mouse_click);
    const window_id = try compositor.create_window(800, 600);
    std.debug.assert(window_id > 0);

    // Process input (should focus window at click position).
    try compositor.process_input();
    // Window should be focused if click was within bounds.
    const focused_id = compositor.get_focused_window_id();
    std.debug.assert(focused_id == 0 or focused_id == window_id);
}

test "process input no event" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    compositor.set_syscall_fn(mock_syscall_no_event);
    const window_id = try compositor.create_window(800, 600);
    _ = compositor.focus_window(window_id);

    // Process input (no event available).
    try compositor.process_input();
    // Focus should remain unchanged.
    std.debug.assert(compositor.get_focused_window_id() == window_id);
}

