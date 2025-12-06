//! Grain OS Window Animation: Smooth transitions for window operations.
//!
//! Why: Provide smooth animations for window move, resize, minimize, maximize.
//! Architecture: Animation state management and interpolation.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");

// Bounded: Max active animations.
pub const MAX_ANIMATIONS: u32 = 64;

// Bounded: Animation duration (milliseconds).
pub const ANIMATION_DURATION_MS: u32 = 200;

// Animation type.
pub const AnimationType = enum(u8) {
    none,
    move,
    resize,
    minimize,
    maximize,
    opacity,
};

// Animation state.
pub const AnimationState = struct {
    window_id: u32,
    anim_type: AnimationType,
    start_x: i32,
    start_y: i32,
    start_width: u32,
    start_height: u32,
    start_opacity: u8,
    target_x: i32,
    target_y: i32,
    target_width: u32,
    target_height: u32,
    target_opacity: u8,
    start_time: u64, // Timestamp in milliseconds.
    duration_ms: u32,
    active: bool,
};

// Animation manager: manages window animations.
pub const AnimationManager = struct {
    animations: [MAX_ANIMATIONS]AnimationState,
    animations_len: u32,

    pub fn init() AnimationManager {
        var manager = AnimationManager{
            .animations = undefined,
            .animations_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_ANIMATIONS) : (i += 1) {
            manager.animations[i] = AnimationState{
                .window_id = 0,
                .anim_type = AnimationType.none,
                .start_x = 0,
                .start_y = 0,
                .start_width = 0,
                .start_height = 0,
                .start_opacity = 0,
                .target_x = 0,
                .target_y = 0,
                .target_width = 0,
                .target_height = 0,
                .target_opacity = 0,
                .start_time = 0,
                .duration_ms = 0,
                .active = false,
            };
        }
        return manager;
    }

    // Start animation for window.
    pub fn start_animation(
        self: *AnimationManager,
        window_id: u32,
        anim_type: AnimationType,
        start_x: i32,
        start_y: i32,
        start_width: u32,
        start_height: u32,
        start_opacity: u8,
        target_x: i32,
        target_y: i32,
        target_width: u32,
        target_height: u32,
        target_opacity: u8,
        start_time: u64,
    ) bool {
        std.debug.assert(window_id > 0);
        if (self.animations_len >= MAX_ANIMATIONS) {
            return false;
        }
        // Check if animation already exists, update it.
        var i: u32 = 0;
        while (i < self.animations_len) : (i += 1) {
            if (self.animations[i].window_id == window_id) {
                self.animations[i].anim_type = anim_type;
                self.animations[i].start_x = start_x;
                self.animations[i].start_y = start_y;
                self.animations[i].start_width = start_width;
                self.animations[i].start_height = start_height;
                self.animations[i].start_opacity = start_opacity;
                self.animations[i].target_x = target_x;
                self.animations[i].target_y = target_y;
                self.animations[i].target_width = target_width;
                self.animations[i].target_height = target_height;
                self.animations[i].target_opacity = target_opacity;
                self.animations[i].start_time = start_time;
                self.animations[i].duration_ms = ANIMATION_DURATION_MS;
                self.animations[i].active = true;
                return true;
            }
        }
        // Add new animation.
        self.animations[self.animations_len] = AnimationState{
            .window_id = window_id,
            .anim_type = anim_type,
            .start_x = start_x,
            .start_y = start_y,
            .start_width = start_width,
            .start_height = start_height,
            .start_opacity = start_opacity,
            .target_x = target_x,
            .target_y = target_y,
            .target_width = target_width,
            .target_height = target_height,
            .target_opacity = target_opacity,
            .start_time = start_time,
            .duration_ms = ANIMATION_DURATION_MS,
            .active = true,
        };
        self.animations_len += 1;
        return true;
    }

    // Get animation for window.
    pub fn get_animation(
        self: *AnimationManager,
        window_id: u32,
    ) ?*AnimationState {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        while (i < self.animations_len) : (i += 1) {
            if (self.animations[i].window_id == window_id and
                self.animations[i].active)
            {
                return &self.animations[i];
            }
        }
        return null;
    }

    // Remove animation for window.
    pub fn remove_animation(self: *AnimationManager, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        while (i < self.animations_len) : (i += 1) {
            if (self.animations[i].window_id == window_id) {
                self.animations[i].active = false;
                return true;
            }
        }
        return false;
    }

    // Calculate interpolation progress (0.0 to 1.0).
    pub fn calc_progress(
        _self: *const AnimationManager,
        anim: *const AnimationState,
        current_time: u64,
    ) f32 {
        _ = _self;
        if (current_time < anim.start_time) {
            return 0.0;
        }
        const elapsed: u64 = current_time - anim.start_time;
        if (elapsed >= anim.duration_ms) {
            return 1.0;
        }
        const progress: f32 = @as(f32, @floatFromInt(elapsed)) /
            @as(f32, @floatFromInt(anim.duration_ms));
        return progress;
    }

    // Linear interpolation between start and target.
    pub fn lerp(start: f32, target: f32, progress: f32) f32 {
        return start + (target - start) * progress;
    }

    // Update animation and return current values.
    pub fn update_animation(
        self: *AnimationManager,
        window_id: u32,
        current_time: u64,
    ) ?struct { x: i32, y: i32, width: u32, height: u32, opacity: u8, done: bool } {
        std.debug.assert(window_id > 0);
        if (self.get_animation(window_id)) |anim| {
            const progress = self.calc_progress(anim, current_time);
            const done = (progress >= 1.0);
            // Interpolate values.
            const x = @as(i32, @intFromFloat(AnimationManager.lerp(
                @as(f32, @floatFromInt(anim.start_x)),
                @as(f32, @floatFromInt(anim.target_x)),
                progress,
            )));
            const y = @as(i32, @intFromFloat(AnimationManager.lerp(
                @as(f32, @floatFromInt(anim.start_y)),
                @as(f32, @floatFromInt(anim.target_y)),
                progress,
            )));
            const width = @as(u32, @intFromFloat(AnimationManager.lerp(
                @as(f32, @floatFromInt(anim.start_width)),
                @as(f32, @floatFromInt(anim.target_width)),
                progress,
            )));
            const height = @as(u32, @intFromFloat(AnimationManager.lerp(
                @as(f32, @floatFromInt(anim.start_height)),
                @as(f32, @floatFromInt(anim.target_height)),
                progress,
            )));
            const opacity = @as(u8, @intFromFloat(AnimationManager.lerp(
                @as(f32, @floatFromInt(anim.start_opacity)),
                @as(f32, @floatFromInt(anim.target_opacity)),
                progress,
            )));
            if (done) {
                _ = self.remove_animation(window_id);
            }
            return .{ .x = x, .y = y, .width = width, .height = height, .opacity = opacity, .done = done };
        }
        return null;
    }

    // Clear all animations.
    pub fn clear_all(self: *AnimationManager) void {
        var i: u32 = 0;
        while (i < self.animations_len) : (i += 1) {
            self.animations[i].active = false;
        }
        self.animations_len = 0;
    }

    // Get animation count.
    pub fn get_count(self: *const AnimationManager) u32 {
        return self.animations_len;
    }
};

