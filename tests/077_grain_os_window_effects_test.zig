//! Tests for Grain OS window effects (fade, slide animations).
//!
//! Why: Verify window effect functionality and calculations.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const window_effects = grain_os.window_effects;

test "fade in opacity calculation" {
    const opacity_start = window_effects.calc_fade_in_opacity(0.0);
    std.debug.assert(opacity_start == 0);
    const opacity_mid = window_effects.calc_fade_in_opacity(0.5);
    std.debug.assert(opacity_mid > 0);
    std.debug.assert(opacity_mid < 255);
    const opacity_end = window_effects.calc_fade_in_opacity(1.0);
    std.debug.assert(opacity_end == 255);
}

test "fade out opacity calculation" {
    const opacity_start = window_effects.calc_fade_out_opacity(0.0);
    std.debug.assert(opacity_start == 255);
    const opacity_mid = window_effects.calc_fade_out_opacity(0.5);
    std.debug.assert(opacity_mid > 0);
    std.debug.assert(opacity_mid < 255);
    const opacity_end = window_effects.calc_fade_out_opacity(1.0);
    std.debug.assert(opacity_end == 0);
}

test "slide in position calculation" {
    const pos_start = window_effects.calc_slide_in_position(
        0,
        100,
        0.0,
        window_effects.SlideDirection.from_top,
        800,
    );
    std.debug.assert(pos_start < 100);
    const pos_end = window_effects.calc_slide_in_position(
        0,
        100,
        1.0,
        window_effects.SlideDirection.from_top,
        800,
    );
    std.debug.assert(pos_end == 100);
}

test "slide out position calculation" {
    const pos_start = window_effects.calc_slide_out_position(
        0,
        100,
        0.0,
        window_effects.SlideDirection.from_top,
        800,
    );
    std.debug.assert(pos_start == 100);
    const pos_end = window_effects.calc_slide_out_position(
        0,
        100,
        1.0,
        window_effects.SlideDirection.from_top,
        800,
    );
    std.debug.assert(pos_end < 100);
}

test "should apply effect" {
    std.debug.assert(window_effects.should_apply_effect(window_effects.EffectType.fade_in) == true);
    std.debug.assert(window_effects.should_apply_effect(window_effects.EffectType.none) == false);
}

test "start fade in" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    const result = window_effects.start_fade_in(&comp.animation_manager, window_id, 0);
    std.debug.assert(result);
}

test "start fade out" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    if (comp.get_window(window_id)) |win| {
        const result = window_effects.start_fade_out(&comp.animation_manager, window_id, win.opacity, 0);
        std.debug.assert(result);
    }
}

test "compositor fade in on create" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    // Window should have fade-in animation started.
    const anim_opt = comp.animation_manager.get_animation(window_id);
    std.debug.assert(anim_opt != null);
}

test "effect constants" {
    std.debug.assert(window_effects.FADE_DURATION_MS == 150);
    std.debug.assert(window_effects.SLIDE_DURATION_MS == 200);
}

