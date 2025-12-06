//! Grain OS Window Effects: Fade, slide animations for window lifecycle.
//!
//! Why: Provide smooth visual effects for window open/close operations.
//! Architecture: Window effect management and animation integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");
const window_animation = @import("window_animation.zig");
const window_opacity = @import("window_opacity.zig");

// Bounded: Effect duration (milliseconds).
pub const FADE_DURATION_MS: u32 = 150;
pub const SLIDE_DURATION_MS: u32 = 200;

// Effect type.
pub const EffectType = enum(u8) {
    none,
    fade_in,
    fade_out,
    slide_in,
    slide_out,
};

// Effect direction for slide.
pub const SlideDirection = enum(u8) {
    from_top,
    from_bottom,
    from_left,
    from_right,
};

// Window effect state.
pub const WindowEffectState = struct {
    effect_type: EffectType,
    slide_direction: SlideDirection,
    active: bool,
};

// Calculate fade-in opacity.
pub fn calc_fade_in_opacity(progress: f32) u8 {
    std.debug.assert(progress >= 0.0);
    std.debug.assert(progress <= 1.0);
    const opacity_f = progress;
    return @as(u8, @intFromFloat(opacity_f * 255.0));
}

// Calculate fade-out opacity.
pub fn calc_fade_out_opacity(progress: f32) u8 {
    std.debug.assert(progress >= 0.0);
    std.debug.assert(progress <= 1.0);
    const opacity_f = 1.0 - progress;
    return @as(u8, @intFromFloat(opacity_f * 255.0));
}

// Calculate slide-in position.
pub fn calc_slide_in_position(
    _start_pos: i32,
    target_pos: i32,
    progress: f32,
    direction: SlideDirection,
    _screen_size: u32,
) i32 {
    _ = _start_pos;
    _ = _screen_size;
    std.debug.assert(progress >= 0.0);
    std.debug.assert(progress <= 1.0);
    const offset = switch (direction) {
        .from_top => -@as(i32, @intFromFloat((1.0 - progress) * 100.0)),
        .from_bottom => @as(i32, @intFromFloat((1.0 - progress) * 100.0)),
        .from_left => -@as(i32, @intFromFloat((1.0 - progress) * 100.0)),
        .from_right => @as(i32, @intFromFloat((1.0 - progress) * 100.0)),
    };
    return target_pos + offset;
}

// Calculate slide-out position.
pub fn calc_slide_out_position(
    _start_pos: i32,
    target_pos: i32,
    progress: f32,
    direction: SlideDirection,
    _screen_size: u32,
) i32 {
    _ = _start_pos;
    _ = _screen_size;
    std.debug.assert(progress >= 0.0);
    std.debug.assert(progress <= 1.0);
    const offset = switch (direction) {
        .from_top => -@as(i32, @intFromFloat(progress * 100.0)),
        .from_bottom => @as(i32, @intFromFloat(progress * 100.0)),
        .from_left => -@as(i32, @intFromFloat(progress * 100.0)),
        .from_right => @as(i32, @intFromFloat(progress * 100.0)),
    };
    return target_pos + offset;
}

// Start fade-in effect for window.
pub fn start_fade_in(
    anim_manager: *window_animation.AnimationManager,
    window_id: u32,
    start_time: u64,
) bool {
    std.debug.assert(window_id > 0);
    // Fade-in: opacity from 0 to 255.
    return anim_manager.start_animation(
        window_id,
        window_animation.AnimationType.opacity,
        0, // start_x (not used for fade).
        0, // start_y (not used for fade).
        0, // start_width (not used for fade).
        0, // start_height (not used for fade).
        0, // start_opacity (transparent).
        0, // target_x (not used for fade).
        0, // target_y (not used for fade).
        0, // target_width (not used for fade).
        0, // target_height (not used for fade).
        255, // target_opacity (opaque).
        start_time,
    );
}

// Start fade-out effect for window.
pub fn start_fade_out(
    anim_manager: *window_animation.AnimationManager,
    window_id: u32,
    current_opacity: u8,
    start_time: u64,
) bool {
    std.debug.assert(window_id > 0);
    // Fade-out: opacity from current to 0.
    return anim_manager.start_animation(
        window_id,
        window_animation.AnimationType.opacity,
        0, // start_x (not used for fade).
        0, // start_y (not used for fade).
        0, // start_width (not used for fade).
        0, // start_height (not used for fade).
        current_opacity, // start_opacity (current).
        0, // target_x (not used for fade).
        0, // target_y (not used for fade).
        0, // target_width (not used for fade).
        0, // target_height (not used for fade).
        0, // target_opacity (transparent).
        start_time,
    );
}

// Check if effect should be applied.
pub fn should_apply_effect(effect_type: EffectType) bool {
    return effect_type != EffectType.none;
}

