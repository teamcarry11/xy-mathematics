// Typography scales for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Defines typography scales (font sizes, line heights, letter spacing)
// Sizes in points (iOS) / SP (Android)

const std = @import("std");

pub const FontWeight = enum(u8) {
    thin = 100,
    light = 300,
    regular = 400,
    medium = 500,
    semibold = 600,
    bold = 700,
    black = 900,
};

pub const TextStyle = struct {
    font_size: u32,
    line_height: u32,
    letter_spacing: i32,
    font_weight: FontWeight,

    pub fn init(
        font_size: u32,
        line_height: u32,
        letter_spacing: i32,
        font_weight: FontWeight,
    ) TextStyle {
        std.debug.assert(font_size > 0);
        std.debug.assert(font_size <= 200);
        std.debug.assert(line_height > 0);
        std.debug.assert(line_height <= 300);
        std.debug.assert(letter_spacing >= -10);
        std.debug.assert(letter_spacing <= 10);
        
        return TextStyle{
            .font_size = font_size,
            .line_height = line_height,
            .letter_spacing = letter_spacing,
            .font_weight = font_weight,
        };
    }
};

pub const TypographyScale = struct {
    display_large: TextStyle,
    display_medium: TextStyle,
    display_small: TextStyle,
    headline_large: TextStyle,
    headline_medium: TextStyle,
    headline_small: TextStyle,
    title_large: TextStyle,
    title_medium: TextStyle,
    title_small: TextStyle,
    body_large: TextStyle,
    body_medium: TextStyle,
    body_small: TextStyle,
    label_large: TextStyle,
    label_medium: TextStyle,
    label_small: TextStyle,

    pub fn init() TypographyScale {
        return TypographyScale{
            .display_large = TextStyle.init(57, 64, 0, .regular),
            .display_medium = TextStyle.init(45, 52, 0, .regular),
            .display_small = TextStyle.init(36, 44, 0, .regular),
            .headline_large = TextStyle.init(32, 40, 0, .regular),
            .headline_medium = TextStyle.init(28, 36, 0, .regular),
            .headline_small = TextStyle.init(24, 32, 0, .regular),
            .title_large = TextStyle.init(22, 28, 0, .medium),
            .title_medium = TextStyle.init(16, 24, 0, .medium),
            .title_small = TextStyle.init(14, 20, 0, .medium),
            .body_large = TextStyle.init(16, 24, 0, .regular),
            .body_medium = TextStyle.init(14, 20, 0, .regular),
            .body_small = TextStyle.init(12, 16, 0, .regular),
            .label_large = TextStyle.init(14, 20, 0, .medium),
            .label_medium = TextStyle.init(12, 16, 0, .medium),
            .label_small = TextStyle.init(11, 16, 0, .medium),
        };
    }
};

