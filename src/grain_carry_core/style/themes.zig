// Theme management for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Manages light/dark themes with color palettes

const std = @import("std");
const colors = @import("colors.zig");
const typography = @import("typography.zig");
const spacing = @import("spacing.zig");

pub const Theme = enum(u8) {
    light,
    dark,
};

pub const ThemeData = struct {
    theme: Theme,
    colors: colors.ColorPalette,
    typography: typography.TypographyScale,
    spacing: spacing.SpacingScale,

    pub fn init(theme: Theme) ThemeData {
        std.debug.assert(@intFromEnum(theme) < 2);
        
        const color_palette = switch (theme) {
            .light => colors.ColorPalette.init_light(),
            .dark => colors.ColorPalette.init_dark(),
        };
        
        return ThemeData{
            .theme = theme,
            .colors = color_palette,
            .typography = typography.TypographyScale.init(),
            .spacing = spacing.SpacingScale.init(),
        };
    }
};

