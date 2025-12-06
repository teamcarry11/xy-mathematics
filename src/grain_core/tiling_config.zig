//! Grain OS Tiling Configuration: Tiling settings and preferences.
//!
//! Why: Allow users to configure tiling behavior (gaps, ratios, layouts).
//! Architecture: Configuration structure and management functions.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const layout_generator = @import("layout_generator.zig");

// Bounded: Default window gap (pixels).
pub const DEFAULT_WINDOW_GAP: u32 = 4;

// Bounded: Default split ratio (0.0 to 1.0).
pub const DEFAULT_SPLIT_RATIO: f64 = 0.5;

// Bounded: Min split ratio.
pub const MIN_SPLIT_RATIO: f64 = 0.1;

// Bounded: Max split ratio.
pub const MAX_SPLIT_RATIO: f64 = 0.9;

// Tiling configuration: user preferences for tiling.
pub const TilingConfig = struct {
    window_gap: u32,
    split_ratio: f64,
    default_layout: layout_generator.LayoutType,
    auto_tile: bool,
    smart_gaps: bool, // Hide gaps when only one window.

    pub fn init() TilingConfig {
        return TilingConfig{
            .window_gap = DEFAULT_WINDOW_GAP,
            .split_ratio = DEFAULT_SPLIT_RATIO,
            .default_layout = .tall,
            .auto_tile = true,
            .smart_gaps = false,
        };
    }

    // Set window gap.
    pub fn set_window_gap(self: *TilingConfig, gap: u32) void {
        self.window_gap = gap;
    }

    // Get window gap.
    pub fn get_window_gap(self: *const TilingConfig) u32 {
        return self.window_gap;
    }

    // Set split ratio.
    pub fn set_split_ratio(self: *TilingConfig, ratio: f64) void {
        std.debug.assert(ratio >= MIN_SPLIT_RATIO);
        std.debug.assert(ratio <= MAX_SPLIT_RATIO);
        self.split_ratio = ratio;
    }

    // Get split ratio.
    pub fn get_split_ratio(self: *const TilingConfig) f64 {
        return self.split_ratio;
    }

    // Set default layout.
    pub fn set_default_layout(self: *TilingConfig, layout: layout_generator.LayoutType) void {
        self.default_layout = layout;
    }

    // Get default layout.
    pub fn get_default_layout(self: *const TilingConfig) layout_generator.LayoutType {
        return self.default_layout;
    }

    // Set auto-tile.
    pub fn set_auto_tile(self: *TilingConfig, enabled: bool) void {
        self.auto_tile = enabled;
    }

    // Get auto-tile.
    pub fn get_auto_tile(self: *const TilingConfig) bool {
        return self.auto_tile;
    }

    // Set smart gaps.
    pub fn set_smart_gaps(self: *TilingConfig, enabled: bool) void {
        self.smart_gaps = enabled;
    }

    // Get smart gaps.
    pub fn get_smart_gaps(self: *const TilingConfig) bool {
        return self.smart_gaps;
    }

    // Clamp split ratio to valid range.
    pub fn clamp_split_ratio(ratio: f64) f64 {
        if (ratio < MIN_SPLIT_RATIO) {
            return MIN_SPLIT_RATIO;
        }
        if (ratio > MAX_SPLIT_RATIO) {
            return MAX_SPLIT_RATIO;
        }
        return ratio;
    }

    // Calculate effective gap (with smart gaps).
    pub fn calc_effective_gap(
        self: *const TilingConfig,
        window_count: u32,
    ) u32 {
        if (self.smart_gaps and window_count <= 1) {
            return 0;
        }
        return self.window_gap;
    }
};

