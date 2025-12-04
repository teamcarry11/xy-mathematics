//! Tests for Grain Mobile Core style system.
//!
//! Why: Verify style system functionality (colors, typography, spacing, breakpoints).
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_mobile_core = @import("grain_mobile_core");
const style = grain_mobile_core.style;

test "color initialization" {
    const color = style.colors.Color.init(255, 128, 64, 200);
    
    std.debug.assert(color.r == 255);
    std.debug.assert(color.g == 128);
    std.debug.assert(color.b == 64);
    std.debug.assert(color.a == 200);
}

test "color to argb conversion" {
    const color = style.colors.Color.init(255, 128, 64, 200);
    const argb = color.to_argb();
    
    std.debug.assert(argb > 0);
}

test "color palette light theme" {
    const palette = style.colors.ColorPalette.init_light();
    
    std.debug.assert(palette.background.r == 255);
    std.debug.assert(palette.background.g == 255);
    std.debug.assert(palette.background.b == 255);
    std.debug.assert(palette.on_background.r == 0);
}

test "color palette dark theme" {
    const palette = style.colors.ColorPalette.init_dark();
    
    std.debug.assert(palette.background.r == 18);
    std.debug.assert(palette.background.g == 18);
    std.debug.assert(palette.background.b == 18);
    std.debug.assert(palette.on_background.r == 255);
}

test "typography scale initialization" {
    const scale = style.typography.TypographyScale.init();
    
    std.debug.assert(scale.display_large.font_size == 57);
    std.debug.assert(scale.body_large.font_size == 16);
    std.debug.assert(scale.label_small.font_size == 11);
}

test "spacing scale initialization" {
    const scale = style.spacing.SpacingScale.init();
    
    std.debug.assert(scale.xs == 4);
    std.debug.assert(scale.sm == 8);
    std.debug.assert(scale.md == 16);
    std.debug.assert(scale.lg == 24);
    std.debug.assert(scale.xl == 32);
    std.debug.assert(scale.xxl == 48);
}

test "spacing scale get" {
    var scale = style.spacing.SpacingScale.init();
    
    std.debug.assert(scale.get(.xs) == 4);
    std.debug.assert(scale.get(.sm) == 8);
    std.debug.assert(scale.get(.md) == 16);
    std.debug.assert(scale.get(.lg) == 24);
    std.debug.assert(scale.get(.xl) == 32);
    std.debug.assert(scale.get(.xxl) == 48);
}

test "breakpoint detection - phone small" {
    const bp = style.breakpoints.get_breakpoint(320, 568);
    
    std.debug.assert(bp == .phone_small);
}

test "breakpoint detection - phone medium" {
    const bp = style.breakpoints.get_breakpoint(375, 667);
    
    std.debug.assert(bp == .phone_medium);
}

test "breakpoint detection - phone large" {
    const bp = style.breakpoints.get_breakpoint(414, 896);
    
    std.debug.assert(bp == .phone_large);
}

test "breakpoint detection - tablet small" {
    const bp = style.breakpoints.get_breakpoint(600, 960);
    
    std.debug.assert(bp == .tablet_small);
}

test "breakpoint detection - tablet large" {
    const bp = style.breakpoints.get_breakpoint(768, 1024);
    
    std.debug.assert(bp == .tablet_large);
}

test "breakpoint detection - desktop" {
    const bp = style.breakpoints.get_breakpoint(1920, 1080);
    
    std.debug.assert(bp == .desktop);
}

test "theme data initialization - light" {
    const theme_data = style.themes.ThemeData.init(.light);
    
    std.debug.assert(theme_data.theme == .light);
    std.debug.assert(theme_data.colors.background.r == 255);
}

test "theme data initialization - dark" {
    const theme_data = style.themes.ThemeData.init(.dark);
    
    std.debug.assert(theme_data.theme == .dark);
    std.debug.assert(theme_data.colors.background.r == 18);
}

test "component spec - button" {
    var theme_data = style.themes.ThemeData.init(.light);
    const bp = style.breakpoints.get_breakpoint(375, 667);
    const spec = style.components.get_component_spec(.button, bp, &theme_data);
    
    std.debug.assert(spec.component_type == .button);
    std.debug.assert(spec.layout.min_height == 40);
    std.debug.assert(spec.border_radius == 4);
}

test "component spec - text field" {
    var theme_data = style.themes.ThemeData.init(.light);
    const bp = style.breakpoints.get_breakpoint(375, 667);
    const spec = style.components.get_component_spec(.text_field, bp, &theme_data);
    
    std.debug.assert(spec.component_type == .text_field);
    std.debug.assert(spec.layout.min_height == 56);
}

test "component spec - responsive padding" {
    var theme_data = style.themes.ThemeData.init(.light);
    const bp_phone = style.breakpoints.get_breakpoint(375, 667);
    const bp_tablet = style.breakpoints.get_breakpoint(768, 1024);
    const bp_desktop = style.breakpoints.get_breakpoint(1920, 1080);
    
    const spec_phone = style.components.get_component_spec(.button, bp_phone, &theme_data);
    const spec_tablet = style.components.get_component_spec(.button, bp_tablet, &theme_data);
    const spec_desktop = style.components.get_component_spec(.button, bp_desktop, &theme_data);
    
    std.debug.assert(spec_tablet.layout.padding_horizontal >= spec_phone.layout.padding_horizontal);
    std.debug.assert(spec_desktop.layout.padding_horizontal >= spec_tablet.layout.padding_horizontal);
}

