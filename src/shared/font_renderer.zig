//! Shared Font Renderer: Unified bitmap font rendering for all applications.
//!
//! Why: Reduce code duplication, share font rendering across Grain Skate, Aurora, and Grain OS.
//! Architecture: Multiple font sizes, multiple character sets, pixel data return.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-140357-pst: Active implementation

const std = @import("std");

// Bounded: Max font width (explicit limit, in pixels)
// 2025-12-03-140357-pst: Active constant
pub const MAX_FONT_WIDTH: u32 = 32;

// Bounded: Max font height (explicit limit, in pixels)
// 2025-12-03-140357-pst: Active constant
pub const MAX_FONT_HEIGHT: u32 = 32;

// Bounded: Max text length (explicit limit, in characters)
// 2025-12-03-140357-pst: Active constant
pub const MAX_TEXT_LEN: u32 = 1024;

// Font size enumeration.
// 2025-12-03-140357-pst: Active enum
pub const FontSize = enum(u8) {
    font_5x7, // 5x7 bitmap font (Grain Skate)
    font_8x8, // 8x8 bitmap font (Aurora, Grain OS)
};

// Character set enumeration.
// 2025-12-03-140357-pst: Active enum
pub const CharSet = enum(u8) {
    ascii_basic, // ASCII 32-126 (95 printable characters)
    ascii_alphanumeric, // A-Z, 0-9, space
};

// Font renderer state.
// 2025-12-03-140357-pst: Active struct
pub const FontRenderer = struct {
    font_size: FontSize,
    char_set: CharSet,

    /// Initialize font renderer with specified font size and character set.
    // 2025-12-03-140357-pst: Active function
    pub fn init(font_size: FontSize, char_set: CharSet) FontRenderer {
        return FontRenderer{
            .font_size = font_size,
            .char_set = char_set,
        };
    }

    /// Get font width for current font size.
    // 2025-12-03-140357-pst: Active function
    pub fn get_font_width(self: *const FontRenderer) u32 {
        return switch (self.font_size) {
            .font_5x7 => 5,
            .font_8x8 => 8,
        };
    }

    /// Get font height for current font size.
    // 2025-12-03-140357-pst: Active function
    pub fn get_font_height(self: *const FontRenderer) u32 {
        return switch (self.font_size) {
            .font_5x7 => 7,
            .font_8x8 => 8,
        };
    }

    /// Get character width (includes spacing).
    // 2025-12-03-140357-pst: Active function
    pub fn get_char_width(self: *const FontRenderer) u32 {
        return self.get_font_width() + 1; // +1 for spacing
    }

    /// Get character height (includes spacing).
    // 2025-12-03-140357-pst: Active function
    pub fn get_char_height(self: *const FontRenderer) u32 {
        return self.get_font_height() + 1; // +1 for spacing
    }

    /// Get character pattern for given character (internal use only).
    // Returns pixel data as array of rows (each row is a bitmask).
    // 2025-12-03-140357-pst: Active function
    fn get_char_pattern(self: *const FontRenderer, ch: u8) ?[]const u8 {
        return switch (self.font_size) {
            .font_5x7 => self.get_char_pattern_5x7(ch),
            .font_8x8 => self.get_char_pattern_8x8(ch),
        };
    }

    /// Get character pattern for 5x7 font.
    // 2025-12-03-140357-pst: Active function
    fn get_char_pattern_5x7(self: *const FontRenderer, ch: u8) ?[]const u8 {
        _ = self;
        // 5x7 font patterns (7 rows of 5 bits each, stored as u8 per row)
        const patterns_5x7 = struct {
            fn get(c: u8) ?[7]u8 {
                return switch (c) {
                    'A', 'a' => [7]u8{ 0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001 },
                    'B', 'b' => [7]u8{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110 },
                    'C', 'c' => [7]u8{ 0b01110, 0b10001, 0b10000, 0b10000, 0b10000, 0b10001, 0b01110 },
                    'D', 'd' => [7]u8{ 0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110 },
                    'E', 'e' => [7]u8{ 0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111 },
                    'F', 'f' => [7]u8{ 0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000 },
                    'G', 'g' => [7]u8{ 0b01110, 0b10001, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110 },
                    'H', 'h' => [7]u8{ 0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001 },
                    'I', 'i' => [7]u8{ 0b01110, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110 },
                    'J', 'j' => [7]u8{ 0b00111, 0b00010, 0b00010, 0b00010, 0b00010, 0b10010, 0b01100 },
                    'K', 'k' => [7]u8{ 0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001 },
                    'L', 'l' => [7]u8{ 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111 },
                    'M', 'm' => [7]u8{ 0b10001, 0b11011, 0b10101, 0b10001, 0b10001, 0b10001, 0b10001 },
                    'N', 'n' => [7]u8{ 0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001 },
                    'O', 'o' => [7]u8{ 0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110 },
                    'P', 'p' => [7]u8{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000 },
                    'Q', 'q' => [7]u8{ 0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101 },
                    'R', 'r' => [7]u8{ 0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001 },
                    'S', 's' => [7]u8{ 0b01110, 0b10001, 0b10000, 0b01110, 0b00001, 0b10001, 0b01110 },
                    'T', 't' => [7]u8{ 0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100 },
                    'U', 'u' => [7]u8{ 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110 },
                    'V', 'v' => [7]u8{ 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b00100 },
                    'W', 'w' => [7]u8{ 0b10001, 0b10001, 0b10001, 0b10001, 0b10101, 0b11011, 0b10001 },
                    'X', 'x' => [7]u8{ 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b01010, 0b10001 },
                    'Y', 'y' => [7]u8{ 0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100 },
                    'Z', 'z' => [7]u8{ 0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111 },
                    '0' => [7]u8{ 0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110 },
                    '1' => [7]u8{ 0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110 },
                    '2' => [7]u8{ 0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b01000, 0b11111 },
                    '3' => [7]u8{ 0b11111, 0b00010, 0b00100, 0b00010, 0b00001, 0b10001, 0b01110 },
                    '4' => [7]u8{ 0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010 },
                    '5' => [7]u8{ 0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110 },
                    '6' => [7]u8{ 0b01110, 0b10001, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110 },
                    '7' => [7]u8{ 0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000 },
                    '8' => [7]u8{ 0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110 },
                    '9' => [7]u8{ 0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b10001, 0b01110 },
                    ' ' => [7]u8{ 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 },
                    else => null,
                };
            }
        }.get(ch);
        return if (patterns_5x7) |pattern| pattern[0..] else null;
    }

    /// Get character pattern for 8x8 font.
    // 2025-12-03-140357-pst: Active function
    fn get_char_pattern_8x8(self: *const FontRenderer, ch: u8) ?[]const u8 {
        _ = self;
        // 8x8 font patterns (8 rows of 8 bits each, stored as u8 per row)
        const patterns_8x8 = struct {
            fn get(c: u8) ?[8]u8 {
                return switch (c) {
                    ' ' => [8]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
                    '!' => [8]u8{ 0x18, 0x3C, 0x3C, 0x18, 0x18, 0x00, 0x18, 0x00 },
                    '"' => [8]u8{ 0x36, 0x36, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
                    '#' => [8]u8{ 0x36, 0x36, 0x7F, 0x36, 0x7F, 0x36, 0x36, 0x00 },
                    '$' => [8]u8{ 0x0C, 0x3E, 0x03, 0x1E, 0x30, 0x1F, 0x0C, 0x00 },
                    '%' => [8]u8{ 0x00, 0x63, 0x33, 0x18, 0x0C, 0x66, 0x63, 0x00 },
                    '&' => [8]u8{ 0x1C, 0x36, 0x1C, 0x3B, 0x6E, 0x66, 0x3F, 0x00 },
                    '\'' => [8]u8{ 0x06, 0x06, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00 },
                    '(' => [8]u8{ 0x18, 0x0C, 0x06, 0x06, 0x06, 0x0C, 0x18, 0x00 },
                    ')' => [8]u8{ 0x06, 0x0C, 0x18, 0x18, 0x18, 0x0C, 0x06, 0x00 },
                    '*' => [8]u8{ 0x00, 0x66, 0x3C, 0xFF, 0x3C, 0x66, 0x00, 0x00 },
                    '+' => [8]u8{ 0x00, 0x0C, 0x0C, 0x3F, 0x0C, 0x0C, 0x00, 0x00 },
                    ',' => [8]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x0C, 0x06, 0x00 },
                    '-' => [8]u8{ 0x00, 0x00, 0x00, 0x3F, 0x00, 0x00, 0x00, 0x00 },
                    '.' => [8]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x0C, 0x0C, 0x00 },
                    '/' => [8]u8{ 0x30, 0x18, 0x18, 0x0C, 0x0C, 0x06, 0x06, 0x03 },
                    '0' => [8]u8{ 0x3C, 0x66, 0x6E, 0x7E, 0x76, 0x66, 0x3C, 0x00 },
                    '1' => [8]u8{ 0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00 },
                    '2' => [8]u8{ 0x3C, 0x66, 0x06, 0x0C, 0x18, 0x30, 0x7E, 0x00 },
                    '3' => [8]u8{ 0x3C, 0x66, 0x06, 0x1C, 0x06, 0x66, 0x3C, 0x00 },
                    '4' => [8]u8{ 0x06, 0x0E, 0x1E, 0x36, 0x7F, 0x06, 0x06, 0x00 },
                    '5' => [8]u8{ 0x7E, 0x60, 0x7C, 0x06, 0x06, 0x66, 0x3C, 0x00 },
                    '6' => [8]u8{ 0x1C, 0x30, 0x60, 0x7C, 0x66, 0x66, 0x3C, 0x00 },
                    '7' => [8]u8{ 0x7E, 0x06, 0x0C, 0x18, 0x18, 0x18, 0x18, 0x00 },
                    '8' => [8]u8{ 0x3C, 0x66, 0x66, 0x3C, 0x66, 0x66, 0x3C, 0x00 },
                    '9' => [8]u8{ 0x3C, 0x66, 0x66, 0x3E, 0x06, 0x0C, 0x38, 0x00 },
                    ':' => [8]u8{ 0x00, 0x0C, 0x0C, 0x00, 0x00, 0x0C, 0x0C, 0x00 },
                    ';' => [8]u8{ 0x00, 0x0C, 0x0C, 0x00, 0x00, 0x0C, 0x06, 0x00 },
                    '<' => [8]u8{ 0x00, 0x0C, 0x18, 0x30, 0x18, 0x0C, 0x00, 0x00 },
                    '=' => [8]u8{ 0x00, 0x00, 0x7E, 0x00, 0x7E, 0x00, 0x00, 0x00 },
                    '>' => [8]u8{ 0x00, 0x30, 0x18, 0x0C, 0x18, 0x30, 0x00, 0x00 },
                    '?' => [8]u8{ 0x3C, 0x66, 0x06, 0x0C, 0x18, 0x00, 0x18, 0x00 },
                    '@' => [8]u8{ 0x3C, 0x66, 0x76, 0x6E, 0x60, 0x66, 0x3C, 0x00 },
                    'A' => [8]u8{ 0x18, 0x3C, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x00 },
                    'B' => [8]u8{ 0x7C, 0x66, 0x66, 0x7C, 0x66, 0x66, 0x7C, 0x00 },
                    'C' => [8]u8{ 0x3C, 0x66, 0x60, 0x60, 0x60, 0x66, 0x3C, 0x00 },
                    'D' => [8]u8{ 0x78, 0x6C, 0x66, 0x66, 0x66, 0x6C, 0x78, 0x00 },
                    'E' => [8]u8{ 0x7E, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x7E, 0x00 },
                    'F' => [8]u8{ 0x7E, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x60, 0x00 },
                    'G' => [8]u8{ 0x3C, 0x66, 0x60, 0x6E, 0x66, 0x66, 0x3C, 0x00 },
                    'H' => [8]u8{ 0x66, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00 },
                    'I' => [8]u8{ 0x3C, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00 },
                    'J' => [8]u8{ 0x1E, 0x0C, 0x0C, 0x0C, 0x6C, 0x6C, 0x38, 0x00 },
                    'K' => [8]u8{ 0x66, 0x6C, 0x78, 0x70, 0x78, 0x6C, 0x66, 0x00 },
                    'L' => [8]u8{ 0x60, 0x60, 0x60, 0x60, 0x60, 0x60, 0x7E, 0x00 },
                    'M' => [8]u8{ 0x63, 0x77, 0x7F, 0x6B, 0x63, 0x63, 0x63, 0x00 },
                    'N' => [8]u8{ 0x66, 0x76, 0x7E, 0x7E, 0x6E, 0x66, 0x66, 0x00 },
                    'O' => [8]u8{ 0x3C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00 },
                    'P' => [8]u8{ 0x7C, 0x66, 0x66, 0x7C, 0x60, 0x60, 0x60, 0x00 },
                    'Q' => [8]u8{ 0x3C, 0x66, 0x66, 0x66, 0x6E, 0x3C, 0x0E, 0x00 },
                    'R' => [8]u8{ 0x7C, 0x66, 0x66, 0x7C, 0x6C, 0x66, 0x66, 0x00 },
                    'S' => [8]u8{ 0x3C, 0x60, 0x3C, 0x06, 0x06, 0x66, 0x3C, 0x00 },
                    'T' => [8]u8{ 0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00 },
                    'U' => [8]u8{ 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00 },
                    'V' => [8]u8{ 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x18, 0x00 },
                    'W' => [8]u8{ 0x63, 0x6B, 0x7F, 0x77, 0x63, 0x63, 0x63, 0x00 },
                    'X' => [8]u8{ 0x66, 0x66, 0x3C, 0x18, 0x3C, 0x66, 0x66, 0x00 },
                    'Y' => [8]u8{ 0x66, 0x66, 0x3C, 0x18, 0x18, 0x18, 0x18, 0x00 },
                    'Z' => [8]u8{ 0x7E, 0x06, 0x0C, 0x18, 0x30, 0x60, 0x7E, 0x00 },
                    '[' => [8]u8{ 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00 },
                    '\\' => [8]u8{ 0x03, 0x06, 0x06, 0x0C, 0x0C, 0x18, 0x18, 0x30 },
                    ']' => [8]u8{ 0x3C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x3C, 0x00 },
                    '^' => [8]u8{ 0x18, 0x3C, 0x66, 0x00, 0x00, 0x00, 0x00, 0x00 },
                    '_' => [8]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7E, 0x00 },
                    '`' => [8]u8{ 0x18, 0x18, 0x0C, 0x00, 0x00, 0x00, 0x00, 0x00 },
                    'a' => [8]u8{ 0x00, 0x00, 0x3C, 0x06, 0x3E, 0x66, 0x3E, 0x00 },
                    'b' => [8]u8{ 0x60, 0x60, 0x7C, 0x66, 0x66, 0x66, 0x7C, 0x00 },
                    'c' => [8]u8{ 0x00, 0x00, 0x3C, 0x66, 0x60, 0x66, 0x3C, 0x00 },
                    'd' => [8]u8{ 0x06, 0x06, 0x3E, 0x66, 0x66, 0x66, 0x3E, 0x00 },
                    'e' => [8]u8{ 0x00, 0x00, 0x3C, 0x66, 0x7E, 0x60, 0x3C, 0x00 },
                    'f' => [8]u8{ 0x1C, 0x30, 0x7C, 0x30, 0x30, 0x30, 0x30, 0x00 },
                    'g' => [8]u8{ 0x00, 0x00, 0x3E, 0x66, 0x66, 0x3E, 0x06, 0x3C },
                    'h' => [8]u8{ 0x60, 0x60, 0x7C, 0x66, 0x66, 0x66, 0x66, 0x00 },
                    'i' => [8]u8{ 0x18, 0x00, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00 },
                    'j' => [8]u8{ 0x0C, 0x00, 0x0C, 0x0C, 0x0C, 0x6C, 0x38, 0x00 },
                    'k' => [8]u8{ 0x60, 0x60, 0x66, 0x6C, 0x78, 0x6C, 0x66, 0x00 },
                    'l' => [8]u8{ 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00 },
                    'm' => [8]u8{ 0x00, 0x00, 0x76, 0x7F, 0x6B, 0x63, 0x63, 0x00 },
                    'n' => [8]u8{ 0x00, 0x00, 0x7C, 0x66, 0x66, 0x66, 0x66, 0x00 },
                    'o' => [8]u8{ 0x00, 0x00, 0x3C, 0x66, 0x66, 0x66, 0x3C, 0x00 },
                    'p' => [8]u8{ 0x00, 0x00, 0x7C, 0x66, 0x66, 0x7C, 0x60, 0x60 },
                    'q' => [8]u8{ 0x00, 0x00, 0x3E, 0x66, 0x66, 0x3E, 0x06, 0x06 },
                    'r' => [8]u8{ 0x00, 0x00, 0x7C, 0x66, 0x60, 0x60, 0x60, 0x00 },
                    's' => [8]u8{ 0x00, 0x00, 0x3E, 0x60, 0x3C, 0x06, 0x7C, 0x00 },
                    't' => [8]u8{ 0x30, 0x30, 0x7C, 0x30, 0x30, 0x30, 0x1C, 0x00 },
                    'u' => [8]u8{ 0x00, 0x00, 0x66, 0x66, 0x66, 0x66, 0x3E, 0x00 },
                    'v' => [8]u8{ 0x00, 0x00, 0x66, 0x66, 0x66, 0x3C, 0x18, 0x00 },
                    'w' => [8]u8{ 0x00, 0x00, 0x63, 0x6B, 0x7F, 0x36, 0x00, 0x00 },
                    'x' => [8]u8{ 0x00, 0x00, 0x66, 0x3C, 0x18, 0x3C, 0x66, 0x00 },
                    'y' => [8]u8{ 0x00, 0x00, 0x66, 0x66, 0x66, 0x3E, 0x06, 0x3C },
                    'z' => [8]u8{ 0x00, 0x00, 0x7E, 0x0C, 0x18, 0x30, 0x7E, 0x00 },
                    '{' => [8]u8{ 0x0C, 0x18, 0x18, 0x70, 0x18, 0x18, 0x0C, 0x00 },
                    '|' => [8]u8{ 0x18, 0x18, 0x18, 0x00, 0x18, 0x18, 0x18, 0x00 },
                    '}' => [8]u8{ 0x30, 0x18, 0x18, 0x0E, 0x18, 0x18, 0x30, 0x00 },
                    '~' => [8]u8{ 0x00, 0x00, 0x3E, 0x6C, 0x00, 0x00, 0x00, 0x00 },
                    else => null,
                };
            }
        }.get(ch);
        return if (patterns_8x8) |pattern| pattern[0..] else null;
    }

    /// Render character to pixel buffer.
    // Returns pixel data as RGBA array (width * height * 4 bytes).
    // Caller is responsible for rendering pixels to their buffer.
    // 2025-12-03-140357-pst: Active function
    pub fn render_char_to_pixels(
        self: *const FontRenderer,
        ch: u8,
        fg_r: u8,
        fg_g: u8,
        fg_b: u8,
        fg_a: u8,
        bg_r: u8,
        bg_g: u8,
        bg_b: u8,
        bg_a: u8,
        pixel_buffer: []u8,
    ) bool {
        std.debug.assert(pixel_buffer.len >= self.get_char_width() * self.get_char_height() * 4);
        const pattern = self.get_char_pattern(ch) orelse return false;
        const font_w = self.get_font_width();
        const font_h = self.get_font_height();
        var row: u32 = 0;
        while (row < font_h) : (row += 1) {
            var col: u32 = 0;
            while (col < font_w) : (col += 1) {
                const bit_mask = switch (self.font_size) {
                    .font_5x7 => @as(u5, 1) << @as(u3, @intCast(4 - col)),
                    .font_8x8 => @as(u8, 1) << @as(u3, @intCast(7 - col)),
                };
                const pattern_row = pattern[@as(usize, @intCast(row))];
                const bit_set = (pattern_row & bit_mask) != 0;
                const pixel_idx = (row * self.get_char_width() + col) * 4;
                if (bit_set) {
                    pixel_buffer[pixel_idx + 0] = fg_r;
                    pixel_buffer[pixel_idx + 1] = fg_g;
                    pixel_buffer[pixel_idx + 2] = fg_b;
                    pixel_buffer[pixel_idx + 3] = fg_a;
                } else {
                    pixel_buffer[pixel_idx + 0] = bg_r;
                    pixel_buffer[pixel_idx + 1] = bg_g;
                    pixel_buffer[pixel_idx + 2] = bg_b;
                    pixel_buffer[pixel_idx + 3] = bg_a;
                }
            }
        }
        return true;
    }
};

