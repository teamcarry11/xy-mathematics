// Color palettes for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Defines color palettes for light/dark themes
// Colors are RGBA (8-bit per channel)

const std = @import("std");

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn init(r: u8, g: u8, b: u8, a: u8) Color {
        std.debug.assert(r <= 255);
        std.debug.assert(g <= 255);
        std.debug.assert(b <= 255);
        std.debug.assert(a <= 255);
        
        return Color{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }

    pub fn to_argb(self: Color) u32 {
        std.debug.assert(self.r <= 255);
        std.debug.assert(self.g <= 255);
        std.debug.assert(self.b <= 255);
        std.debug.assert(self.a <= 255);
        
        return (@as(u32, self.a) << 24) |
            (@as(u32, self.r) << 16) |
            (@as(u32, self.g) << 8) |
            @as(u32, self.b);
    }
};

pub const ColorPalette = struct {
    primary: Color,
    secondary: Color,
    background: Color,
    surface: Color,
    error: Color,
    on_primary: Color,
    on_secondary: Color,
    on_background: Color,
    on_surface: Color,
    on_error: Color,

    pub fn init_light() ColorPalette {
        return ColorPalette{
            .primary = Color.init(33, 150, 243, 255),
            .secondary = Color.init(156, 39, 176, 255),
            .background = Color.init(255, 255, 255, 255),
            .surface = Color.init(250, 250, 250, 255),
            .error = Color.init(211, 47, 47, 255),
            .on_primary = Color.init(255, 255, 255, 255),
            .on_secondary = Color.init(255, 255, 255, 255),
            .on_background = Color.init(0, 0, 0, 255),
            .on_surface = Color.init(0, 0, 0, 255),
            .on_error = Color.init(255, 255, 255, 255),
        };
    }

    pub fn init_dark() ColorPalette {
        return ColorPalette{
            .primary = Color.init(100, 181, 246, 255),
            .secondary = Color.init(186, 104, 200, 255),
            .background = Color.init(18, 18, 18, 255),
            .surface = Color.init(30, 30, 30, 255),
            .error = Color.init(239, 83, 80, 255),
            .on_primary = Color.init(0, 0, 0, 255),
            .on_secondary = Color.init(0, 0, 0, 255),
            .on_background = Color.init(255, 255, 255, 255),
            .on_surface = Color.init(255, 255, 255, 255),
            .on_error = Color.init(0, 0, 0, 255),
        };
    }
};

