//! Tests for Grain OS window state persistence.
//!
//! Why: Verify window state save/restore functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const WindowStateManager = grain_os.window_state.WindowStateManager;

test "window state manager initialization" {
    const manager = WindowStateManager.init();
    std.debug.assert(manager.entries_len == 0);
}

test "save window state" {
    var manager = WindowStateManager.init();
    const result = manager.save_window(
        1, // window_id
        100, // x
        200, // y
        400, // width
        300, // height
        false, // minimized
        false, // maximized
        1, // workspace_id
        "Test Window", // title
    );
    std.debug.assert(result);
    std.debug.assert(manager.entries_len == 1);
    std.debug.assert(manager.entries[0].window_id == 1);
    std.debug.assert(manager.entries[0].x == 100);
    std.debug.assert(manager.entries[0].y == 200);
    std.debug.assert(manager.entries[0].width == 400);
    std.debug.assert(manager.entries[0].height == 300);
}

test "get window state" {
    var manager = WindowStateManager.init();
    _ = manager.save_window(1, 100, 200, 400, 300, false, false, 1, "Test");
    const state_opt = manager.get_window_state(1);
    std.debug.assert(state_opt != null);
    if (state_opt) |state| {
        std.debug.assert(state.window_id == 1);
        std.debug.assert(state.x == 100);
        std.debug.assert(state.width == 400);
    }
}

test "remove window state" {
    var manager = WindowStateManager.init();
    _ = manager.save_window(1, 100, 200, 400, 300, false, false, 1, "Test");
    const result = manager.remove_window(1);
    std.debug.assert(result);
    std.debug.assert(manager.entries_len == 0);
}

test "update existing window state" {
    var manager = WindowStateManager.init();
    _ = manager.save_window(1, 100, 200, 400, 300, false, false, 1, "Test");
    const result = manager.save_window(1, 150, 250, 500, 350, true, false, 2, "Updated");
    std.debug.assert(result);
    std.debug.assert(manager.entries_len == 1);
    std.debug.assert(manager.entries[0].x == 150);
    std.debug.assert(manager.entries[0].width == 500);
    std.debug.assert(manager.entries[0].minimized == true);
}

test "clear all states" {
    var manager = WindowStateManager.init();
    _ = manager.save_window(1, 100, 200, 400, 300, false, false, 1, "Test1");
    _ = manager.save_window(2, 200, 300, 500, 400, false, false, 1, "Test2");
    manager.clear();
    std.debug.assert(manager.entries_len == 0);
}

test "compositor save window state" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(400, 300);
    std.debug.assert(window_id > 0);

    if (comp.get_window(window_id)) |win| {
        win.x = 100;
        win.y = 200;
        win.set_title("Test Window");
    }

    const result = comp.save_window_state(window_id);
    std.debug.assert(result);
    std.debug.assert(comp.state_manager.entries_len == 1);
}

test "compositor restore window state" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(400, 300);
    std.debug.assert(window_id > 0);

    // Save state.
    if (comp.get_window(window_id)) |win| {
        win.x = 100;
        win.y = 200;
        win.width = 500;
        win.height = 400;
        win.set_title("Saved Window");
    }
    _ = comp.save_window_state(window_id);

    // Modify window.
    if (comp.get_window(window_id)) |win| {
        win.x = 0;
        win.y = 0;
        win.width = 200;
        win.height = 150;
    }

    // Restore state.
    const result = comp.restore_window_state(window_id);
    std.debug.assert(result);

    if (comp.get_window(window_id)) |win| {
        std.debug.assert(win.x == 100);
        std.debug.assert(win.y == 200);
        std.debug.assert(win.width == 500);
        std.debug.assert(win.height == 400);
    }
}

test "compositor save all window states" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = try comp.create_window(400, 300);
    _ = try comp.create_window(500, 400);
    _ = try comp.create_window(600, 500);

    comp.save_all_window_states();
    std.debug.assert(comp.state_manager.entries_len == 3);
}

test "compositor window removed from state on deletion" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const win1 = try comp.create_window(400, 300);
    const win2 = try comp.create_window(500, 400);
    _ = comp.save_window_state(win1);
    _ = comp.save_window_state(win2);

    _ = comp.remove_window(win1);
    std.debug.assert(comp.state_manager.entries_len == 1);
    std.debug.assert(comp.state_manager.entries[0].window_id == win2);
}

