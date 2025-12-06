// C-compatible FFI exports for Grain Mobile Core Style System
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Provides C-compatible API for style queries (breakpoints, colors, typography, spacing, components)

const std = @import("std");
const colors = @import("../style/colors.zig");
const typography = @import("../style/typography.zig");
const spacing = @import("../style/spacing.zig");
const breakpoints = @import("../style/breakpoints.zig");
const themes = @import("../style/themes.zig");
const components = @import("../style/components.zig");

// C-compatible return codes
pub const RESULT_OK: c_int = 0;
pub const RESULT_ERROR: c_int = 1;

// Export C-compatible breakpoint query function
export fn grain_mobile_get_breakpoint(
    width_dp: u32,
    height_dp: u32,
) u8 {
    std.debug.assert(width_dp > 0);
    std.debug.assert(width_dp <= 10000);
    std.debug.assert(height_dp > 0);
    std.debug.assert(height_dp <= 10000);
    
    const bp = breakpoints.get_breakpoint(width_dp, height_dp);
    
    std.debug.assert(@intFromEnum(bp) < 6);
    
    return @intFromEnum(bp);
}

// Export C-compatible color palette initialization (light theme)
export fn grain_mobile_init_color_palette_light(
    palette_out: *colors.ColorPalette,
) c_int {
    std.debug.assert(palette_out != null);
    
    palette_out.* = colors.ColorPalette.init_light();
    
    std.debug.assert(palette_out.background.r == 255);
    
    return RESULT_OK;
}

// Export C-compatible color palette initialization (dark theme)
export fn grain_mobile_init_color_palette_dark(
    palette_out: *colors.ColorPalette,
) c_int {
    std.debug.assert(palette_out != null);
    
    palette_out.* = colors.ColorPalette.init_dark();
    
    std.debug.assert(palette_out.background.r == 18);
    
    return RESULT_OK;
}

// Export C-compatible color to ARGB conversion
export fn grain_mobile_color_to_argb(
    color: *const colors.Color,
) u32 {
    std.debug.assert(color != null);
    std.debug.assert(color.r <= 255);
    std.debug.assert(color.g <= 255);
    std.debug.assert(color.b <= 255);
    std.debug.assert(color.a <= 255);
    
    const argb = color.to_argb();
    
    std.debug.assert(argb > 0 or (color.r == 0 and color.g == 0 and color.b == 0 and color.a == 0));
    
    return argb;
}

// Export C-compatible typography scale initialization
export fn grain_mobile_init_typography_scale(
    scale_out: *typography.TypographyScale,
) c_int {
    std.debug.assert(scale_out != null);
    
    scale_out.* = typography.TypographyScale.init();
    
    std.debug.assert(scale_out.display_large.font_size == 57);
    
    return RESULT_OK;
}

// Export C-compatible spacing scale initialization
export fn grain_mobile_init_spacing_scale(
    scale_out: *spacing.SpacingScale,
) c_int {
    std.debug.assert(scale_out != null);
    
    scale_out.* = spacing.SpacingScale.init();
    
    std.debug.assert(scale_out.md == 16);
    
    return RESULT_OK;
}

// Export C-compatible spacing value getter
export fn grain_mobile_get_spacing(
    scale: *const spacing.SpacingScale,
    size: u8,
    spacing_out: *u32,
) c_int {
    std.debug.assert(scale != null);
    std.debug.assert(size < 6);
    std.debug.assert(spacing_out != null);
    
    const spacing_size = @as(spacing.SpacingSize, @enumFromInt(size));
    const value = scale.get(spacing_size);
    
    std.debug.assert(value > 0);
    std.debug.assert(value <= 1000);
    
    spacing_out.* = value;
    
    return RESULT_OK;
}

// Export C-compatible theme data initialization
export fn grain_mobile_init_theme_data(
    theme: u8,
    theme_data_out: *themes.ThemeData,
) c_int {
    std.debug.assert(theme < 2);
    std.debug.assert(theme_data_out != null);
    
    const theme_enum = @as(themes.Theme, @enumFromInt(theme));
    theme_data_out.* = themes.ThemeData.init(theme_enum);
    
    std.debug.assert(theme_data_out.theme == theme_enum);
    
    return RESULT_OK;
}

// Export C-compatible component specification query
export fn grain_mobile_get_component_spec(
    component_type: u8,
    breakpoint: u8,
    theme_data: *const themes.ThemeData,
    spec_out: *components.ComponentSpec,
) c_int {
    std.debug.assert(component_type < 10);
    std.debug.assert(breakpoint < 6);
    std.debug.assert(theme_data != null);
    std.debug.assert(spec_out != null);
    
    const comp_type = @as(components.ComponentType, @enumFromInt(component_type));
    const bp = @as(breakpoints.Breakpoint, @enumFromInt(breakpoint));
    
    spec_out.* = components.get_component_spec(comp_type, bp, theme_data);
    
    std.debug.assert(spec_out.component_type == comp_type);
    
    return RESULT_OK;
}

