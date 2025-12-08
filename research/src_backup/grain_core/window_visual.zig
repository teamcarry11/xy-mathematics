//! Grain OS Window Visual Enhancements: Shadows, focus indicators.
//!
//! Why: Provide visual depth and feedback for window operations.
//! Architecture: Visual enhancement rendering for windows.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const framebuffer_renderer = @import("framebuffer_renderer.zig");

// Bounded: Shadow offset and blur.
pub const SHADOW_OFFSET_X: i32 = 4;
pub const SHADOW_OFFSET_Y: i32 = 4;
pub const SHADOW_BLUR: u32 = 8;
pub const SHADOW_ALPHA: u32 = 0x80; // 50% opacity.

// Bounded: Focus glow size.
pub const FOCUS_GLOW_SIZE: u32 = 3;
pub const FOCUS_GLOW_ALPHA: u32 = 0xC0; // 75% opacity.

// Bounded: Hover highlight size.
pub const HOVER_HIGHLIGHT_SIZE: u32 = 2;

// Window visual state.
pub const WindowVisualState = struct {
    has_shadow: bool,
    has_focus_glow: bool,
    has_hover: bool,
    shadow_color: u32,
    focus_glow_color: u32,
    hover_color: u32,
};

// Initialize default visual state.
pub fn init_visual_state() WindowVisualState {
    return WindowVisualState{
        .has_shadow = true,
        .has_focus_glow = true,
        .has_hover = false,
        .shadow_color = 0x00000000 | SHADOW_ALPHA,
        .focus_glow_color = 0x0000FFFF | (FOCUS_GLOW_ALPHA << 24),
        .hover_color = 0xFFFFFF00 | 0x80000000,
    };
}

// Calculate shadow color with alpha.
pub fn calc_shadow_color(_base_color: u32, alpha: u32) u32 {
    const r = (_base_color >> 16) & 0xFF;
    const g = (_base_color >> 8) & 0xFF;
    const b = _base_color & 0xFF;
    return (alpha << 24) | (r << 16) | (g << 8) | b;
}

// Calculate focus glow color.
pub fn calc_focus_glow_color(base_color: u32) u32 {
    const r = (base_color >> 16) & 0xFF;
    const g = (base_color >> 8) & 0xFF;
    const b = base_color & 0xFF;
    return (FOCUS_GLOW_ALPHA << 24) | (r << 16) | (g << 8) | b;
}

// Check if window should have shadow.
pub fn should_render_shadow(minimized: bool) bool {
    return !minimized;
}

// Check if window should have focus glow.
pub fn should_render_focus_glow(focused: bool) bool {
    return focused;
}

// Check if window should have hover effect.
pub fn should_render_hover(hovered: bool) bool {
    return hovered;
}

