//! Grain OS Window Constraints: Min/max size and aspect ratio limits.
//!
//! Why: Enforce window size limits and aspect ratios for proper layout.
//! Architecture: Constraint validation and application for window resizing.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Default minimum window size.
pub const DEFAULT_MIN_WIDTH: u32 = 100;
pub const DEFAULT_MIN_HEIGHT: u32 = 100;

// Bounded: Default maximum window size (unlimited = 0).
pub const DEFAULT_MAX_WIDTH: u32 = 0; // 0 = unlimited.
pub const DEFAULT_MAX_HEIGHT: u32 = 0; // 0 = unlimited.

// Bounded: Default aspect ratio (0 = no constraint).
pub const DEFAULT_ASPECT_RATIO: f32 = 0.0; // 0 = no constraint.

// Window constraints: size and aspect ratio limits.
pub const WindowConstraints = struct {
    min_width: u32,
    min_height: u32,
    max_width: u32, // 0 = unlimited.
    max_height: u32, // 0 = unlimited.
    aspect_ratio: f32, // 0 = no constraint, >0 = width/height.

    pub fn init() WindowConstraints {
        return WindowConstraints{
            .min_width = DEFAULT_MIN_WIDTH,
            .min_height = DEFAULT_MIN_HEIGHT,
            .max_width = DEFAULT_MAX_WIDTH,
            .max_height = DEFAULT_MAX_HEIGHT,
            .aspect_ratio = DEFAULT_ASPECT_RATIO,
        };
    }

    // Apply constraints to width and height.
    pub fn apply_constraints(
        self: *const WindowConstraints,
        width: u32,
        height: u32,
    ) struct { width: u32, height: u32 } {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        var result_width = width;
        var result_height = height;
        // Apply minimum size.
        if (result_width < self.min_width) {
            result_width = self.min_width;
        }
        if (result_height < self.min_height) {
            result_height = self.min_height;
        }
        // Apply maximum size.
        if (self.max_width > 0 and result_width > self.max_width) {
            result_width = self.max_width;
        }
        if (self.max_height > 0 and result_height > self.max_height) {
            result_height = self.max_height;
        }
        // Apply aspect ratio constraint.
        if (self.aspect_ratio > 0.0) {
            const current_ratio = @as(f32, @floatFromInt(result_width)) /
                @as(f32, @floatFromInt(result_height));
            if (current_ratio > self.aspect_ratio) {
                // Too wide, adjust height.
                result_height = @as(u32, @intFromFloat(@as(f32, @floatFromInt(result_width)) /
                    self.aspect_ratio));
                // Re-apply min/max after aspect adjustment.
                if (result_height < self.min_height) {
                    result_height = self.min_height;
                    result_width = @as(u32, @intFromFloat(@as(f32, @floatFromInt(result_height)) *
                        self.aspect_ratio));
                }
                if (self.max_height > 0 and result_height > self.max_height) {
                    result_height = self.max_height;
                    result_width = @as(u32, @intFromFloat(@as(f32, @floatFromInt(result_height)) *
                        self.aspect_ratio));
                }
            } else if (current_ratio < self.aspect_ratio) {
                // Too tall, adjust width.
                result_width = @as(u32, @intFromFloat(@as(f32, @floatFromInt(result_height)) *
                    self.aspect_ratio));
                // Re-apply min/max after aspect adjustment.
                if (result_width < self.min_width) {
                    result_width = self.min_width;
                    result_height = @as(u32, @intFromFloat(@as(f32, @floatFromInt(result_width)) /
                        self.aspect_ratio));
                }
                if (self.max_width > 0 and result_width > self.max_width) {
                    result_width = self.max_width;
                    result_height = @as(u32, @intFromFloat(@as(f32, @floatFromInt(result_width)) /
                        self.aspect_ratio));
                }
            }
        }
        std.debug.assert(result_width > 0);
        std.debug.assert(result_height > 0);
        return .{ .width = result_width, .height = result_height };
    }

    // Check if size is valid according to constraints.
    pub fn is_valid_size(
        self: *const WindowConstraints,
        width: u32,
        height: u32,
    ) bool {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        if (width < self.min_width or height < self.min_height) {
            return false;
        }
        if (self.max_width > 0 and width > self.max_width) {
            return false;
        }
        if (self.max_height > 0 and height > self.max_height) {
            return false;
        }
        if (self.aspect_ratio > 0.0) {
            const ratio = @as(f32, @floatFromInt(width)) /
                @as(f32, @floatFromInt(height));
            const tolerance: f32 = 0.01; // Allow small floating point errors.
            const diff = if (ratio > self.aspect_ratio)
                ratio - self.aspect_ratio
            else
                self.aspect_ratio - ratio;
            if (diff > tolerance) {
                return false;
            }
        }
        return true;
    }

    // Set minimum size.
    pub fn set_min_size(
        self: *WindowConstraints,
        min_width: u32,
        min_height: u32,
    ) void {
        std.debug.assert(min_width > 0);
        std.debug.assert(min_height > 0);
        self.min_width = min_width;
        self.min_height = min_height;
    }

    // Set maximum size.
    pub fn set_max_size(
        self: *WindowConstraints,
        max_width: u32,
        max_height: u32,
    ) void {
        std.debug.assert(max_width == 0 or max_width > 0);
        std.debug.assert(max_height == 0 or max_height > 0);
        self.max_width = max_width;
        self.max_height = max_height;
    }

    // Set aspect ratio (0 = no constraint).
    pub fn set_aspect_ratio(self: *WindowConstraints, aspect_ratio: f32) void {
        std.debug.assert(aspect_ratio >= 0.0);
        self.aspect_ratio = aspect_ratio;
    }
};

