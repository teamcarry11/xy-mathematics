//! Tests for Grain OS window focus management.
//!
//! Why: Verify focus policy and focus history functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const FocusManager = grain_os.window_focus.FocusManager;
const FocusPolicy = grain_os.window_focus.FocusPolicy;

test "focus manager initialization" {
    const manager = FocusManager.init();
    std.debug.assert(manager.policy == FocusPolicy.click_to_focus);
    std.debug.assert(manager.focus_history_len == 0);
}

test "set focus policy" {
    var manager = FocusManager.init();
    manager.set_policy(FocusPolicy.focus_follows_mouse);
    std.debug.assert(manager.get_policy() == FocusPolicy.focus_follows_mouse);
}

test "add focus history" {
    var manager = FocusManager.init();
    manager.add_focus_history(1, 100);
    std.debug.assert(manager.focus_history_len == 1);
    std.debug.assert(manager.focus_history[0].window_id == 1);
}

test "get previous focus" {
    var manager = FocusManager.init();
    manager.add_focus_history(1, 100);
    manager.add_focus_history(2, 200);
    const prev_opt = manager.get_previous_focus();
    std.debug.assert(prev_opt != null);
    if (prev_opt) |prev| {
        std.debug.assert(prev == 1);
    }
}

test "should focus on mouse move" {
    var manager = FocusManager.init();
    manager.set_policy(FocusPolicy.click_to_focus);
    std.debug.assert(manager.should_focus_on_mouse_move() == false);
    manager.set_policy(FocusPolicy.focus_follows_mouse);
    std.debug.assert(manager.should_focus_on_mouse_move() == true);
    manager.set_policy(FocusPolicy.sloppy_focus);
    std.debug.assert(manager.should_focus_on_mouse_move() == true);
}

test "should unfocus on mouse leave" {
    var manager = FocusManager.init();
    manager.set_policy(FocusPolicy.click_to_focus);
    std.debug.assert(manager.should_unfocus_on_mouse_leave() == false);
    manager.set_policy(FocusPolicy.focus_follows_mouse);
    std.debug.assert(manager.should_unfocus_on_mouse_leave() == false);
    manager.set_policy(FocusPolicy.sloppy_focus);
    std.debug.assert(manager.should_unfocus_on_mouse_leave() == true);
}

test "compositor set focus policy" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.set_focus_policy(FocusPolicy.focus_follows_mouse);
    std.debug.assert(comp.get_focus_policy() == FocusPolicy.focus_follows_mouse);
}

test "compositor focus history" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id1 = try comp.create_window(800, 600);
    const window_id2 = try comp.create_window(800, 600);
    std.debug.assert(window_id1 > 0);
    std.debug.assert(window_id2 > 0);

    _ = comp.focus_window(window_id1);
    _ = comp.focus_window(window_id2);
    const prev_opt = comp.get_previous_focused_window();
    std.debug.assert(prev_opt != null);
    if (prev_opt) |prev| {
        std.debug.assert(prev == window_id1);
    }
}

test "compositor focus policy click to focus" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.set_focus_policy(FocusPolicy.click_to_focus);
    std.debug.assert(comp.focus_manager.should_focus_on_mouse_move() == false);
}

test "compositor focus policy focus follows mouse" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.set_focus_policy(FocusPolicy.focus_follows_mouse);
    std.debug.assert(comp.focus_manager.should_focus_on_mouse_move() == true);
}

