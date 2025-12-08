// Component specifications for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Defines component specifications (layout, spacing, colors, typography)
// Components are data structures, not UI code

const std = @import("std");
const colors = @import("colors.zig");
const typography = @import("typography.zig");
const spacing = @import("spacing.zig");
const breakpoints = @import("breakpoints.zig");
const themes = @import("themes.zig");

pub const ComponentType = enum(u8) {
    button,
    text_field,
    card,
    list_item,
    app_bar,
    bottom_nav,
    fab,
    chip,
    divider,
    icon,
};

pub const LayoutSpec = struct {
    padding_horizontal: u32,
    padding_vertical: u32,
    margin_horizontal: u32,
    margin_vertical: u32,
    min_width: u32,
    min_height: u32,
    max_width: u32,
    max_height: u32,

    pub fn init(
        padding_h: u32,
        padding_v: u32,
        margin_h: u32,
        margin_v: u32,
        min_w: u32,
        min_h: u32,
        max_w: u32,
        max_h: u32,
    ) LayoutSpec {
        std.debug.assert(padding_h <= 1000);
        std.debug.assert(padding_v <= 1000);
        std.debug.assert(margin_h <= 1000);
        std.debug.assert(margin_v <= 1000);
        std.debug.assert(min_w <= 10000);
        std.debug.assert(min_h <= 10000);
        std.debug.assert(max_w == 0 or max_w >= min_w);
        std.debug.assert(max_h == 0 or max_h >= min_h);
        
        return LayoutSpec{
            .padding_horizontal = padding_h,
            .padding_vertical = padding_v,
            .margin_horizontal = margin_h,
            .margin_vertical = margin_v,
            .min_width = min_w,
            .min_height = min_h,
            .max_width = max_w,
            .max_height = max_h,
        };
    }
};

pub const ColorSpec = struct {
    background: colors.Color,
    foreground: colors.Color,
    border: colors.Color,
    accent: colors.Color,

    pub fn init(
        bg: colors.Color,
        fg: colors.Color,
        border: colors.Color,
        accent: colors.Color,
    ) ColorSpec {
        std.debug.assert(bg.r <= 255);
        std.debug.assert(fg.r <= 255);
        std.debug.assert(border.r <= 255);
        std.debug.assert(accent.r <= 255);
        
        return ColorSpec{
            .background = bg,
            .foreground = fg,
            .border = border,
            .accent = accent,
        };
    }
};

pub const ComponentSpec = struct {
    component_type: ComponentType,
    layout: LayoutSpec,
    colors: ColorSpec,
    typography: typography.TextStyle,
    border_radius: u32,
    elevation: u32,

    pub fn init(
        comp_type: ComponentType,
        layout_spec: LayoutSpec,
        color_spec: ColorSpec,
        text_style: typography.TextStyle,
        radius: u32,
        elev: u32,
    ) ComponentSpec {
        std.debug.assert(@intFromEnum(comp_type) < 10);
        std.debug.assert(radius <= 100);
        std.debug.assert(elev <= 24);
        
        return ComponentSpec{
            .component_type = comp_type,
            .layout = layout_spec,
            .colors = color_spec,
            .typography = text_style,
            .border_radius = radius,
            .elevation = elev,
        };
    }
};

pub fn get_component_spec(
    component_type: ComponentType,
    breakpoint: breakpoints.Breakpoint,
    theme_data: *const themes.ThemeData,
) ComponentSpec {
    std.debug.assert(@intFromEnum(component_type) < 10);
    std.debug.assert(@intFromEnum(breakpoint) < 6);
    
    const spacing_scale = &theme_data.spacing;
    const color_palette = &theme_data.colors;
    const typography_scale = &theme_data.typography;
    
    // Base spacing values
    const padding_base = spacing_scale.md;
    const margin_base = spacing_scale.sm;
    
    // Responsive adjustments based on breakpoint
    const padding_mult: u32 = switch (breakpoint) {
        .phone_small, .phone_medium, .phone_large => 1,
        .tablet_small, .tablet_large => 2,
        .desktop => 3,
    };
    
    const padding_h = padding_base * padding_mult;
    const padding_v = padding_base * padding_mult;
    
    return switch (component_type) {
        .button => ComponentSpec.init(
            .button,
            LayoutSpec.init(padding_h, padding_v, margin_base, margin_base, 64, 40, 0, 0),
            ColorSpec.init(
                color_palette.primary,
                color_palette.on_primary,
                color_palette.primary,
                color_palette.primary,
            ),
            typography_scale.label_large,
            4,
            2,
        ),
        .text_field => ComponentSpec.init(
            .text_field,
            LayoutSpec.init(padding_h, padding_v, margin_base, margin_base, 0, 56, 0, 0),
            ColorSpec.init(
                color_palette.surface,
                color_palette.on_surface,
                color_palette.on_surface,
                color_palette.primary,
            ),
            typography_scale.body_large,
            4,
            0,
        ),
        .card => ComponentSpec.init(
            .card,
            LayoutSpec.init(padding_h, padding_v, margin_base, margin_base, 0, 0, 0, 0),
            ColorSpec.init(
                color_palette.surface,
                color_palette.on_surface,
                color_palette.on_surface,
                color_palette.primary,
            ),
            typography_scale.body_medium,
            8,
            1,
        ),
        .list_item => ComponentSpec.init(
            .list_item,
            LayoutSpec.init(padding_h, padding_v, 0, 0, 0, 48, 0, 0),
            ColorSpec.init(
                color_palette.surface,
                color_palette.on_surface,
                color_palette.on_surface,
                color_palette.primary,
            ),
            typography_scale.body_medium,
            0,
            0,
        ),
        .app_bar => ComponentSpec.init(
            .app_bar,
            LayoutSpec.init(padding_h, padding_v, 0, 0, 0, 56, 0, 0),
            ColorSpec.init(
                color_palette.surface,
                color_palette.on_surface,
                color_palette.on_surface,
                color_palette.primary,
            ),
            typography_scale.title_medium,
            0,
            4,
        ),
        .bottom_nav => ComponentSpec.init(
            .bottom_nav,
            LayoutSpec.init(padding_h, padding_v, 0, 0, 0, 56, 0, 0),
            ColorSpec.init(
                color_palette.surface,
                color_palette.on_surface,
                color_palette.on_surface,
                color_palette.primary,
            ),
            typography_scale.label_medium,
            0,
            8,
        ),
        .fab => ComponentSpec.init(
            .fab,
            LayoutSpec.init(16, 16, margin_base, margin_base, 56, 56, 56, 56),
            ColorSpec.init(
                color_palette.primary,
                color_palette.on_primary,
                color_palette.primary,
                color_palette.primary,
            ),
            typography_scale.label_large,
            28,
            6,
        ),
        .chip => ComponentSpec.init(
            .chip,
            LayoutSpec.init(12, 8, margin_base, margin_base, 0, 32, 0, 0),
            ColorSpec.init(
                color_palette.surface,
                color_palette.on_surface,
                color_palette.on_surface,
                color_palette.primary,
            ),
            typography_scale.label_medium,
            16,
            0,
        ),
        .divider => ComponentSpec.init(
            .divider,
            LayoutSpec.init(0, 0, margin_base, margin_base, 0, 1, 0, 0),
            ColorSpec.init(
                color_palette.on_surface,
                color_palette.on_surface,
                color_palette.on_surface,
                color_palette.on_surface,
            ),
            typography_scale.body_small,
            0,
            0,
        ),
        .icon => ComponentSpec.init(
            .icon,
            LayoutSpec.init(0, 0, margin_base, margin_base, 24, 24, 24, 24),
            ColorSpec.init(
                colors.Color.init(0, 0, 0, 0),
                color_palette.on_surface,
                colors.Color.init(0, 0, 0, 0),
                color_palette.primary,
            ),
            typography_scale.body_medium,
            0,
            0,
        ),
    };
}

