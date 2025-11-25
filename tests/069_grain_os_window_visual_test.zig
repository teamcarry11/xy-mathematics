//! Tests for Grain OS window visual enhancements.
//!
//! Why: Verify window shadows, focus glow, and visual feedback.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const window_visual = grain_os.window_visual;

test "init visual state" {
    const state = window_visual.init_visual_state();
    std.debug.assert(state.has_shadow == true);
    std.debug.assert(state.has_focus_glow == true);
    std.debug.assert(state.has_hover == false);
}

test "calc shadow color" {
    const base_color: u32 = 0x000000FF;
    const alpha: u32 = 0x80;
    const shadow = window_visual.calc_shadow_color(base_color, alpha);
    std.debug.assert((shadow >> 24) == alpha);
}

test "calc focus glow color" {
    const base_color: u32 = 0x0000FFFF;
    const glow = window_visual.calc_focus_glow_color(base_color);
    std.debug.assert((glow >> 24) == window_visual.FOCUS_GLOW_ALPHA);
}

test "should render shadow" {
    std.debug.assert(window_visual.should_render_shadow(false) == true);
    std.debug.assert(window_visual.should_render_shadow(false) == true);
    std.debug.assert(window_visual.should_render_shadow(true) == false);
}

test "should render focus glow" {
    std.debug.assert(window_visual.should_render_focus_glow(true) == true);
    std.debug.assert(window_visual.should_render_focus_glow(false) == false);
}

test "should render hover" {
    std.debug.assert(window_visual.should_render_hover(true) == true);
    std.debug.assert(window_visual.should_render_hover(false) == false);
}

test "compositor render window with shadow" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = grain_os.compositor.Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    if (comp.get_window(window_id)) |win| {
        win.focused = false;
        win.minimized = false;
    }

    // Render should not crash (shadow rendering).
    comp.render_to_framebuffer();
}

test "compositor render window with focus glow" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = grain_os.compositor.Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    _ = comp.focus_window(window_id);

    // Render should not crash (focus glow rendering).
    comp.render_to_framebuffer();
}

test "compositor visual constants" {
    std.debug.assert(window_visual.SHADOW_OFFSET_X == 4);
    std.debug.assert(window_visual.SHADOW_OFFSET_Y == 4);
    std.debug.assert(window_visual.SHADOW_BLUR == 8);
    std.debug.assert(window_visual.FOCUS_GLOW_SIZE == 3);
}

