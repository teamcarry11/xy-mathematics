const std = @import("std");
const Terminal = @import("terminal.zig").Terminal;

/// Grain Terminal Renderer: Renders terminal cells to framebuffer.
/// ~<~ Glow Airbend: explicit rendering state, bounded buffers.
/// ~~~~ Glow Waterbend: deterministic rendering, iterative algorithms.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
pub const Renderer = struct {
    // Bounded: Max character width in pixels (explicit limit)
    pub const CHAR_WIDTH: u32 = 8;

    // Bounded: Max character height in pixels (explicit limit)
    pub const CHAR_HEIGHT: u32 = 16;

    // ANSI color palette (16 colors: 0-7 standard, 8-15 bright)
    pub const ANSI_COLORS: [16]u32 = .{
        0x000000FF, // 0: Black
        0x800000FF, // 1: Red
        0x008000FF, // 2: Green
        0x808000FF, // 3: Yellow
        0x000080FF, // 4: Blue
        0x800080FF, // 5: Magenta
        0x008080FF, // 6: Cyan
        0xC0C0C0FF, // 7: White (light gray)
        0x808080FF, // 8: Bright Black (dark gray)
        0xFF0000FF, // 9: Bright Red
        0x00FF00FF, // 10: Bright Green
        0xFFFF00FF, // 11: Bright Yellow
        0x0000FFFF, // 12: Bright Blue
        0xFF00FFFF, // 13: Bright Magenta
        0x00FFFFFF, // 14: Bright Cyan
        0xFFFFFFFF, // 15: Bright White
    };

    /// Render terminal cells to framebuffer.
    /// Contract:
    ///   Input: terminal, cells array, framebuffer memory
    ///   Output: Renders cells to framebuffer
    ///   Errors: None (assertions for bounds checking)
    pub fn render_cells(
        terminal: *const Terminal,
        cells: []const Terminal.Cell,
        framebuffer_memory: []u8,
        fb_width: u32,
        fb_height: u32,
        offset_x: u32,
        offset_y: u32,
    ) void {
        // Assert: Terminal must be valid
        std.debug.assert(terminal.width > 0 and terminal.width <= Terminal.MAX_WIDTH);
        std.debug.assert(terminal.height > 0 and terminal.height <= Terminal.MAX_HEIGHT);

        // Assert: Cells buffer must be valid
        std.debug.assert(cells.len >= terminal.width * terminal.height);

        // Assert: Framebuffer must be valid
        std.debug.assert(fb_width > 0);
        std.debug.assert(fb_height > 0);
        std.debug.assert(framebuffer_memory.len >= fb_width * fb_height * 4);

        // Render each cell
        var y: u32 = 0;
        while (y < terminal.height) : (y += 1) {
            var x: u32 = 0;
            while (x < terminal.width) : (x += 1) {
                const cell_idx = y * terminal.width + x;
                const cell = cells[cell_idx];

                // Calculate pixel position
                const px = offset_x + x * CHAR_WIDTH;
                const py = offset_y + y * CHAR_HEIGHT;

                // Get colors
                var fg_color = ANSI_COLORS[cell.attrs.fg_color];
                var bg_color = ANSI_COLORS[cell.attrs.bg_color];

                // Apply reverse video
                if (cell.attrs.reverse) {
                    const temp = fg_color;
                    fg_color = bg_color;
                    bg_color = temp;
                }

                // Render character cell
                render_char_cell(
                    cell.ch,
                    px,
                    py,
                    fg_color,
                    bg_color,
                    cell.attrs.bold,
                    framebuffer_memory,
                    fb_width,
                    fb_height,
                );
            }
        }
    }

    /// Render single character cell.
    fn render_char_cell(
        ch: u8,
        x: u32,
        y: u32,
        fg_color: u32,
        bg_color: u32,
        bold: bool,
        framebuffer_memory: []u8,
        fb_width: u32,
        fb_height: u32,
    ) void {
        // Assert: Position must be within bounds
        std.debug.assert(x + CHAR_WIDTH <= fb_width);
        std.debug.assert(y + CHAR_HEIGHT <= fb_height);
        std.debug.assert(framebuffer_memory.len >= fb_width * fb_height * 4);

        // Get character pattern (simplified 8x8 bitmap)
        const pattern = get_char_pattern(ch);

        // Extract colors
        const fg_r: u8 = @truncate((fg_color >> 24) & 0xFF);
        const fg_g: u8 = @truncate((fg_color >> 16) & 0xFF);
        const fg_b: u8 = @truncate((fg_color >> 8) & 0xFF);
        const bg_r: u8 = @truncate((bg_color >> 24) & 0xFF);
        const bg_g: u8 = @truncate((bg_color >> 16) & 0xFF);
        const bg_b: u8 = @truncate((bg_color >> 8) & 0xFF);

        // Render character (8x8 pixels, centered in 8x16 cell)
        var py: u32 = 0;
        while (py < CHAR_HEIGHT) : (py += 1) {
            var px: u32 = 0;
            while (px < CHAR_WIDTH) : (px += 1) {
                const pixel_x = x + px;
                const pixel_y = y + py;

                // Check bounds
                if (pixel_x >= fb_width or pixel_y >= fb_height) {
                    continue;
                }

                const offset: u32 = (pixel_y * fb_width + pixel_x) * 4;
                std.debug.assert(offset + 3 < framebuffer_memory.len);

                // Use pattern for top 8 rows, background for bottom 8 rows
                var bit: u1 = 0;
                if (py < 8 and px < 8) {
                    const bit_idx = py * 8 + px;
                    const shift: u6 = @as(u6, @intCast(63 - bit_idx));
                    bit = @as(u1, @truncate((pattern >> shift) & 1));
                }

                if (bit == 1) {
                    // Foreground color (apply bold by making it brighter)
                    if (bold) {
                        framebuffer_memory[offset + 0] = @min(255, fg_r + 64);
                        framebuffer_memory[offset + 1] = @min(255, fg_g + 64);
                        framebuffer_memory[offset + 2] = @min(255, fg_b + 64);
                    } else {
                        framebuffer_memory[offset + 0] = fg_r;
                        framebuffer_memory[offset + 1] = fg_g;
                        framebuffer_memory[offset + 2] = fg_b;
                    }
                } else {
                    // Background color
                    framebuffer_memory[offset + 0] = bg_r;
                    framebuffer_memory[offset + 1] = bg_g;
                    framebuffer_memory[offset + 2] = bg_b;
                }
                framebuffer_memory[offset + 3] = 0xFF; // Alpha
            }
        }
    }

    /// Get character pattern (8x8 bitmap, 64 bits).
    /// Simplified font pattern for ASCII characters.
    pub fn get_char_pattern(ch: u8) u64 {
        // Basic 8x8 font patterns for ASCII characters
        // This is a simplified implementation; a full font would have all 256 characters
        return switch (ch) {
            ' ' => 0x0000000000000000, // Space
            '!' => 0x1818181818001800,
            '"' => 0x3636000000000000,
            '#' => 0x36367F367F363600,
            '$' => 0x0C3E033E301E0000,
            '%' => 0x006333180C666300,
            '&' => 0x1E33331E6E333E00,
            '\'' => 0x0606000000000000,
            '(' => 0x0C18181818180C00,
            ')' => 0x180C0C0C0C0C1800,
            '*' => 0x0000361C7F1C3600,
            '+' => 0x00000C0C3F0C0C00,
            ',' => 0x00000000000C0C18,
            '-' => 0x000000003F000000,
            '.' => 0x0000000000181800,
            '/' => 0x0030180C06030100,
            '0' => 0x1E33373F3B331E00,
            '1' => 0x0E0C0C0C0C0C1E00,
            '2' => 0x1E3303060C18331F,
            '3' => 0x1E3303060E03331E,
            '4' => 0x060E1E36367F0606,
            '5' => 0x1F031F300303331E,
            '6' => 0x1E33031F3333331E,
            '7' => 0x3F3303060C0C0C0C,
            '8' => 0x1E33331E3333331E,
            '9' => 0x1E33333E3003031E,
            ':' => 0x0000181800181800,
            ';' => 0x0000181800181830,
            '<' => 0x060C18180C060000,
            '=' => 0x00003F00003F0000,
            '>' => 0x180C0606060C1800,
            '?' => 0x1E3303060C000C00,
            '@' => 0x1E33373B3B031E00,
            'A' => 0x0C1E33333F333300,
            'B' => 0x1F33331F3333331F,
            'C' => 0x1E3303030303331E,
            'D' => 0x1F3633333333361F,
            'E' => 0x3F03031F0303033F,
            'F' => 0x3F03031F03030303,
            'G' => 0x1E3303033B33331E,
            'H' => 0x3333333F33333333,
            'I' => 0x1E0C0C0C0C0C0C1E,
            'J' => 0x1E3030303030331E,
            'K' => 0x33331E0C0C1E3333,
            'L' => 0x030303030303033F,
            'M' => 0x63777F7F6B636363,
            'N' => 0x33373F3B3B333333,
            'O' => 0x1E3333333333331E,
            'P' => 0x1F33331F03030303,
            'Q' => 0x1E333333333B361D,
            'R' => 0x1F33331F1B333333,
            'S' => 0x1E33031E3003331E,
            'T' => 0x3F0C0C0C0C0C0C0C,
            'U' => 0x333333333333331E,
            'V' => 0x3333333333331E0C,
            'W' => 0x6363636B7F7F7763,
            'X' => 0x33331E0C0C1E3333,
            'Y' => 0x3333331E0C0C0C0C,
            'Z' => 0x3F30060C1830033F,
            '[' => 0x1E0606060606061E,
            '\\' => 0x000103060C183060,
            ']' => 0x1E1818181818181E,
            '^' => 0x0C1E330000000000,
            '_' => 0x000000000000003F,
            '`' => 0x180C000000000000,
            'a' => 0x00001E303E333E00,
            'b' => 0x03031F3333331F00,
            'c' => 0x00001E3303331E00,
            'd' => 0x30303E3333333E00,
            'e' => 0x00001E333F031E00,
            'f' => 0x1C36061F06060606,
            'g' => 0x00003E33333E301E,
            'h' => 0x03031F3333333300,
            'i' => 0x0C000C0C0C0C0C00,
            'j' => 0x1800181818181B0E,
            'k' => 0x0303331E0E1B3300,
            'l' => 0x0C0C0C0C0C0C0C00,
            'm' => 0x00001F7F6B6B6300,
            'n' => 0x00001F3333333300,
            'o' => 0x00001E3333331E00,
            'p' => 0x00001F33331F0303,
            'q' => 0x00003E33333E3030,
            'r' => 0x00001B0E06060600,
            's' => 0x00001E031E301E00,
            't' => 0x06061F060606360C,
            'u' => 0x0000333333333E00,
            'v' => 0x00003333331E0C00,
            'w' => 0x0000636B7F3E3600,
            'x' => 0x0000331E0C1E3300,
            'y' => 0x00003333333E301E,
            'z' => 0x00003F180C063F00,
            '{' => 0x1C180C0C180C181C,
            '|' => 0x0C0C0C0C0C0C0C0C,
            '}' => 0x1C0C1818180C0C1C,
            '~' => 0x0000001B36000000,
            else => 0x3F3F3F3F3F3F3F3F, // Unknown character (filled block)
        };
    }
};

