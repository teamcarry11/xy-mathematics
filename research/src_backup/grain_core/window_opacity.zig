//! Grain OS Window Opacity: Transparency and opacity management.
//!
//! Why: Provide window transparency for visual effects.
//! Architecture: Opacity value management and alpha blending.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Opacity value range (0.0 to 1.0, stored as u8: 0-255).
pub const OPACITY_MIN: u8 = 0; // Fully transparent.
pub const OPACITY_MAX: u8 = 255; // Fully opaque.
pub const OPACITY_DEFAULT: u8 = 255; // Fully opaque by default.

// Opacity value: 0 = transparent, 255 = opaque.
pub const Opacity = u8;

// Apply opacity to color (alpha blending).
pub fn apply_opacity_to_color(color: u32, opacity: Opacity) u32 {
    const r = (color >> 16) & 0xFF;
    const g = (color >> 8) & 0xFF;
    const b = color & 0xFF;
    const alpha: u32 = opacity;
    return (alpha << 24) | (@as(u32, r) << 16) | (@as(u32, g) << 8) | b;
}

// Blend two colors with opacity.
pub fn blend_colors(
    foreground: u32,
    background: u32,
    opacity: Opacity,
) u32 {
    const fg_r = (foreground >> 16) & 0xFF;
    const fg_g = (foreground >> 8) & 0xFF;
    const fg_b = foreground & 0xFF;
    const bg_r = (background >> 16) & 0xFF;
    const bg_g = (background >> 8) & 0xFF;
    const bg_b = background & 0xFF;
    // Simple alpha blending: result = fg * opacity + bg * (1 - opacity).
    const opacity_f: f32 = @as(f32, @floatFromInt(opacity)) / 255.0;
    const inv_opacity_f: f32 = 1.0 - opacity_f;
    const r = @as(u8, @intFromFloat(@as(f32, @floatFromInt(fg_r)) * opacity_f +
        @as(f32, @floatFromInt(bg_r)) * inv_opacity_f));
    const g = @as(u8, @intFromFloat(@as(f32, @floatFromInt(fg_g)) * opacity_f +
        @as(f32, @floatFromInt(bg_g)) * inv_opacity_f));
    const b = @as(u8, @intFromFloat(@as(f32, @floatFromInt(fg_b)) * opacity_f +
        @as(f32, @floatFromInt(bg_b)) * inv_opacity_f));
    return (255 << 24) | (@as(u32, r) << 16) | (@as(u32, g) << 8) | b;
}

// Clamp opacity value to valid range.
pub fn clamp_opacity(opacity: Opacity) Opacity {
    if (opacity > OPACITY_MAX) {
        return OPACITY_MAX;
    }
    return opacity;
}

// Check if window is fully opaque.
pub fn is_fully_opaque(opacity: Opacity) bool {
    return opacity == OPACITY_MAX;
}

// Check if window is fully transparent.
pub fn is_fully_transparent(opacity: Opacity) bool {
    return opacity == OPACITY_MIN;
}

