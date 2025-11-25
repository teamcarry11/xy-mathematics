//! Tests for Grain OS window animation system.
//!
//! Why: Verify window animation functionality and interpolation.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const AnimationManager = grain_os.window_animation.AnimationManager;
const AnimationType = grain_os.window_animation.AnimationType;

test "animation manager initialization" {
    const manager = AnimationManager.init();
    std.debug.assert(manager.animations_len == 0);
}

test "start animation" {
    var manager = AnimationManager.init();
    const result = manager.start_animation(
        1, // window_id
        AnimationType.move,
        0, // start_x
        0, // start_y
        100, // start_width
        200, // start_height
        255, // start_opacity
        100, // target_x
        200, // target_y
        100, // target_width
        200, // target_height
        255, // target_opacity
        0, // start_time
    );
    std.debug.assert(result);
    std.debug.assert(manager.animations_len == 1);
    std.debug.assert(manager.animations[0].window_id == 1);
    std.debug.assert(manager.animations[0].active == true);
}

test "get animation" {
    var manager = AnimationManager.init();
    _ = manager.start_animation(1, AnimationType.move, 0, 0, 100, 200, 255, 100, 200, 100, 200, 255, 0);
    const anim_opt = manager.get_animation(1);
    std.debug.assert(anim_opt != null);
    if (anim_opt) |anim| {
        std.debug.assert(anim.window_id == 1);
        std.debug.assert(anim.anim_type == AnimationType.move);
    }
}

test "remove animation" {
    var manager = AnimationManager.init();
    _ = manager.start_animation(1, AnimationType.move, 0, 0, 100, 200, 255, 100, 200, 100, 200, 255, 0);
    const result = manager.remove_animation(1);
    std.debug.assert(result);
    std.debug.assert(manager.get_animation(1) == null);
}

test "calc progress" {
    var manager = AnimationManager.init();
    _ = manager.start_animation(1, AnimationType.move, 0, 0, 100, 200, 255, 100, 200, 100, 200, 255, 0);
    if (manager.get_animation(1)) |anim| {
        const progress_start = manager.calc_progress(anim, 0);
        std.debug.assert(progress_start == 0.0);
        const progress_mid = manager.calc_progress(anim, 100);
        std.debug.assert(progress_mid > 0.0);
        std.debug.assert(progress_mid < 1.0);
        const progress_end = manager.calc_progress(anim, 200);
        std.debug.assert(progress_end >= 1.0);
    }
}

test "lerp function" {
    const result1 = AnimationManager.lerp(0.0, 100.0, 0.0);
    std.debug.assert(result1 == 0.0);
    const result2 = AnimationManager.lerp(0.0, 100.0, 1.0);
    std.debug.assert(result2 == 100.0);
    const result3 = AnimationManager.lerp(0.0, 100.0, 0.5);
    std.debug.assert(result3 == 50.0);
}

test "update animation" {
    var manager = AnimationManager.init();
    _ = manager.start_animation(1, AnimationType.move, 0, 0, 100, 200, 255, 100, 200, 100, 200, 255, 0);
    const values_opt = manager.update_animation(1, 100);
    std.debug.assert(values_opt != null);
    if (values_opt) |values| {
        std.debug.assert(values.x > 0);
        std.debug.assert(values.x < 100);
        std.debug.assert(values.done == false);
    }
}

test "compositor animate move" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    const result = comp.animate_move(window_id, 100, 200, 0);
    std.debug.assert(result);
    std.debug.assert(comp.animation_manager.animations_len == 1);
}

test "compositor animate resize" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    const result = comp.animate_resize(window_id, 1000, 800, 0);
    std.debug.assert(result);
    std.debug.assert(comp.animation_manager.animations_len == 1);
}

test "compositor update animations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    _ = comp.animate_move(window_id, 100, 200, 0);
    comp.update_animations(100);
    // Window position should be updated.
    if (comp.get_window(window_id)) |win| {
        std.debug.assert(win.x > 0);
        std.debug.assert(win.x < 100);
    }
}

test "animation constants" {
    std.debug.assert(grain_os.window_animation.MAX_ANIMATIONS == 64);
    std.debug.assert(grain_os.window_animation.ANIMATION_DURATION_MS == 200);
}

