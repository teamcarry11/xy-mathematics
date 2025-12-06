//! Tests for Grain Mobile Core style system FFI layer.
//!
//! Why: Verify FFI exports for style queries work correctly.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_carry_core = @import("grain_carry_core");
const style = grain_carry_core.style;
const style_api = grain_carry_core.c_api.style_api;

test "FFI breakpoint query" {
    const bp = style_api.grain_mobile_get_breakpoint(375, 667);
    
    std.debug.assert(bp < 6);
    std.debug.assert(bp == @intFromEnum(style.breakpoints.Breakpoint.phone_medium));
}

test "FFI color palette light theme" {
    var palette: style.colors.ColorPalette = undefined;
    const result = style_api.grain_mobile_init_color_palette_light(&palette);
    
    std.debug.assert(result == style_api.RESULT_OK);
    std.debug.assert(palette.background.r == 255);
}

test "FFI color palette dark theme" {
    var palette: style.colors.ColorPalette = undefined;
    const result = style_api.grain_mobile_init_color_palette_dark(&palette);
    
    std.debug.assert(result == style_api.RESULT_OK);
    std.debug.assert(palette.background.r == 18);
}

test "FFI color to ARGB" {
    const color = style.colors.Color.init(255, 128, 64, 200);
    const argb = style_api.grain_mobile_color_to_argb(&color);
    
    std.debug.assert(argb > 0);
}

test "FFI typography scale initialization" {
    var scale: style.typography.TypographyScale = undefined;
    const result = style_api.grain_mobile_init_typography_scale(&scale);
    
    std.debug.assert(result == style_api.RESULT_OK);
    std.debug.assert(scale.display_large.font_size == 57);
}

test "FFI spacing scale initialization" {
    var scale: style.spacing.SpacingScale = undefined;
    const result = style_api.grain_mobile_init_spacing_scale(&scale);
    
    std.debug.assert(result == style_api.RESULT_OK);
    std.debug.assert(scale.md == 16);
}

test "FFI spacing getter" {
    var scale: style.spacing.SpacingScale = undefined;
    style_api.grain_mobile_init_spacing_scale(&scale);
    
    var spacing_value: u32 = 0;
    const result = style_api.grain_mobile_get_spacing(&scale, @intFromEnum(style.spacing.SpacingSize.md), &spacing_value);
    
    std.debug.assert(result == style_api.RESULT_OK);
    std.debug.assert(spacing_value == 16);
}

test "FFI theme data initialization" {
    var theme_data: style.themes.ThemeData = undefined;
    const result = style_api.grain_mobile_init_theme_data(@intFromEnum(style.themes.Theme.light), &theme_data);
    
    std.debug.assert(result == style_api.RESULT_OK);
    std.debug.assert(theme_data.theme == .light);
}

test "FFI component spec query" {
    var theme_data: style.themes.ThemeData = undefined;
    style_api.grain_mobile_init_theme_data(@intFromEnum(style.themes.Theme.light), &theme_data);
    
    var spec: style.components.ComponentSpec = undefined;
    const bp = style_api.grain_mobile_get_breakpoint(375, 667);
    const result = style_api.grain_mobile_get_component_spec(
        @intFromEnum(style.components.ComponentType.button),
        bp,
        &theme_data,
        &spec,
    );
    
    std.debug.assert(result == style_api.RESULT_OK);
    std.debug.assert(spec.component_type == .button);
    std.debug.assert(spec.layout.min_height == 40);
}

