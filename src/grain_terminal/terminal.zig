const std = @import("std");

/// Grain Terminal: Terminal emulator for Grain OS.
/// ~<~ Glow Airbend: explicit character cells, bounded terminal state.
/// ~~~~ Glow Waterbend: deterministic rendering, iterative algorithms.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
pub const Terminal = struct {
    // Bounded: Max terminal width (explicit limit)
    pub const MAX_WIDTH: u32 = 256;

    // Bounded: Max terminal height (explicit limit)
    pub const MAX_HEIGHT: u32 = 256;

    // Bounded: Max scrollback lines (explicit limit)
    pub const MAX_SCROLLBACK: u32 = 10_000;

    // Bounded: Max escape sequence length (explicit limit)
    pub const MAX_ESCAPE_SEQ: u32 = 256;

    /// Character cell attributes.
    pub const CellAttributes = struct {
        fg_color: u8, // Foreground color index (0-15 for ANSI, 0-255 for 256-color)
        bg_color: u8, // Background color index (0-15 for ANSI, 0-255 for 256-color)
        fg_rgb: ?[3]u8, // Foreground RGB (true color, null if using indexed color)
        bg_rgb: ?[3]u8, // Background RGB (true color, null if using indexed color)
        bold: bool, // Bold text
        italic: bool, // Italic text
        underline: bool, // Underline text
        blink: bool, // Blinking text
        reverse: bool, // Reverse video
    };

    /// Character cell (single cell in terminal grid).
    pub const Cell = struct {
        ch: u8, // Character (ASCII/UTF-8)
        attrs: CellAttributes, // Cell attributes
    };

    /// Terminal state enumeration.
    pub const State = enum(u8) {
        normal, // Normal text input
        escape, // Processing escape sequence
        csi, // Control Sequence Introducer (CSI)
        osc, // Operating System Command (OSC)
    };

    /// Terminal dimensions and state.
    width: u32, // Terminal width (columns)
    height: u32, // Terminal height (rows)
    cursor_x: u32, // Cursor X position (0-based)
    cursor_y: u32, // Cursor Y position (0-based)
    saved_cursor_x: u32, // Saved cursor X position
    saved_cursor_y: u32, // Saved cursor Y position
    state: State, // Current terminal state
    escape_buffer: [MAX_ESCAPE_SEQ]u8, // Escape sequence buffer
    escape_len: u32, // Escape sequence length
    scrollback_lines: u32, // Number of scrollback lines
    scrollback_offset: u32, // Current scrollback offset (0 = at bottom, showing latest)
    scroll_top: u32, // Top margin of scrolling region (0-based)
    scroll_bottom: u32, // Bottom margin of scrolling region (0-based, exclusive)
    default_fg: u8, // Default foreground color
    default_bg: u8, // Default background color
    current_attrs: CellAttributes, // Current cell attributes
    window_title: [256]u8, // Window title (OSC 0/2)
    window_title_len: u32, // Window title length

    /// Initialize terminal with dimensions.
    pub fn init(width: u32, height: u32) Terminal {
        // Assert: Dimensions must be within bounds
        std.debug.assert(width > 0 and width <= MAX_WIDTH);
        std.debug.assert(height > 0 and height <= MAX_HEIGHT);

        return Terminal{
            .width = width,
            .height = height,
            .cursor_x = 0,
            .cursor_y = 0,
            .saved_cursor_x = 0,
            .saved_cursor_y = 0,
            .state = .normal,
            .escape_buffer = [_]u8{0} ** MAX_ESCAPE_SEQ,
            .escape_len = 0,
            .scrollback_lines = 0,
            .scrollback_offset = 0,
            .scroll_top = 0,
            .scroll_bottom = height,
            .default_fg = 7, // Default: white foreground
            .default_bg = 0, // Default: black background
            .window_title = [_]u8{0} ** 256,
            .window_title_len = 0,
            .current_attrs = CellAttributes{
                .fg_color = 7,
                .bg_color = 0,
                .fg_rgb = null,
                .bg_rgb = null,
                .bold = false,
                .italic = false,
                .underline = false,
                .blink = false,
                .reverse = false,
            },
        };
    }

    /// Process input character (VT100/VT220 escape sequence handling).
    pub fn process_char(self: *Terminal, ch: u8, cells: []Cell) void {
        // Assert: Terminal must be valid
        std.debug.assert(self.width > 0 and self.height > 0);
        std.debug.assert(self.cursor_x < self.width);
        std.debug.assert(self.cursor_y < self.height);

        // Assert: Cells buffer must be valid
        std.debug.assert(cells.len >= self.width * self.height);

        switch (self.state) {
            .normal => {
                if (ch == 0x1B) { // ESC
                    self.state = .escape;
                    self.escape_len = 0;
                } else if (ch == '\r') { // Carriage return
                    self.cursor_x = 0;
                } else if (ch == '\n') { // Line feed
                    self.cursor_y += 1;
                    if (self.cursor_y >= self.scroll_bottom) {
                        self.scroll_up_region(cells);
                        self.cursor_y = self.scroll_bottom - 1;
                    }
                } else if (ch == '\t') { // Tab
                    self.cursor_x = (self.cursor_x + 8) & ~@as(u32, 7); // Round to next tab stop
                    if (self.cursor_x >= self.width) {
                        self.cursor_x = self.width - 1;
                    }
                } else if (ch == 0x07) { // BEL (bell/beep)
                    self.handle_bell();
                } else if (ch >= 0x20 and ch < 0x7F) { // Printable ASCII
                    self.write_char(ch, cells);
                    self.cursor_x += 1;
                    if (self.cursor_x >= self.width) {
                        self.cursor_x = 0;
                        self.cursor_y += 1;
                        if (self.cursor_y >= self.scroll_bottom) {
                            self.scroll_up_region(cells);
                            self.cursor_y = self.scroll_bottom - 1;
                        }
                    }
                }
            },
            .escape => {
                if (ch == '[') {
                    self.state = .csi;
                    self.escape_len = 0;
                } else if (ch == ']') {
                    self.state = .osc;
                    self.escape_len = 0;
                } else {
                    // Single-character escape sequence
                    self.handle_escape_sequence(ch);
                    self.state = .normal;
                    self.escape_len = 0;
                }
            },
            .csi => {
                if (ch >= 0x40 and ch <= 0x7E) { // Final character
                    self.escape_buffer[self.escape_len] = ch;
                    self.escape_len += 1;
                    self.handle_csi_sequence(cells);
                    self.state = .normal;
                    self.escape_len = 0;
                } else if (self.escape_len < MAX_ESCAPE_SEQ - 1) {
                    self.escape_buffer[self.escape_len] = ch;
                    self.escape_len += 1;
                }
            },
            .osc => {
                if (ch == 0x07 or ch == 0x1B) { // BEL or ESC
                    self.handle_osc_sequence();
                    self.state = .normal;
                    self.escape_len = 0;
                } else if (self.escape_len < MAX_ESCAPE_SEQ - 1) {
                    self.escape_buffer[self.escape_len] = ch;
                    self.escape_len += 1;
                }
            },
        }
    }

    /// Write character to current cursor position.
    fn write_char(self: *Terminal, ch: u8, cells: []Cell) void {
        // Assert: Cursor position must be valid
        std.debug.assert(self.cursor_x < self.width);
        std.debug.assert(self.cursor_y < self.height);

        const idx = self.cursor_y * self.width + self.cursor_x;
        std.debug.assert(idx < cells.len);

        cells[idx] = Cell{
            .ch = ch,
            .attrs = self.current_attrs,
        };
    }

    /// Scroll scrolling region up (add new line at bottom of region).
    // 2025-11-24-212700-pst: Active function
    fn scroll_up_region(self: *Terminal, cells: []Cell) void {
        // Assert: Cells buffer must be valid
        std.debug.assert(cells.len >= self.width * self.height);

        // Scroll lines within scrolling region
        var y: u32 = self.scroll_top;
        while (y < self.scroll_bottom - 1) : (y += 1) {
            const src_line_start = (y + 1) * self.width;
            const dst_line_start = y * self.width;
            var x: u32 = 0;
            while (x < self.width) : (x += 1) {
                const src_idx = src_line_start + x;
                const dst_idx = dst_line_start + x;
                cells[dst_idx] = cells[src_idx];
            }
        }

        // Clear bottom line of scrolling region
        const bottom_line_start = (self.scroll_bottom - 1) * self.width;
        var x: u32 = 0;
        while (x < self.width) : (x += 1) {
            const idx = bottom_line_start + x;
            cells[idx] = Cell{
                .ch = ' ',
                .attrs = self.current_attrs,
            };
        }

        // Update scrollback
        self.scrollback_lines += 1;
        if (self.scrollback_lines > MAX_SCROLLBACK) {
            self.scrollback_lines = MAX_SCROLLBACK;
        }
    }

    /// Scroll terminal up (add new line at bottom).
    fn scroll_up(self: *Terminal, cells: []Cell) void {
        // Assert: Cells buffer must be valid
        std.debug.assert(cells.len >= self.width * self.height);

        // Move all lines up by one
        var y: u32 = 1;
        while (y < self.height) : (y += 1) {
            var x: u32 = 0;
            while (x < self.width) : (x += 1) {
                const src_idx = y * self.width + x;
                const dst_idx = (y - 1) * self.width + x;
                cells[dst_idx] = cells[src_idx];
            }
        }

        // Clear bottom line
        var x: u32 = 0;
        while (x < self.width) : (x += 1) {
            const idx = (self.height - 1) * self.width + x;
            cells[idx] = Cell{
                .ch = ' ',
                .attrs = CellAttributes{
                    .fg_color = self.default_fg,
                    .bg_color = self.default_bg,
                    .fg_rgb = null,
                    .bg_rgb = null,
                    .bold = false,
                    .italic = false,
                    .underline = false,
                    .blink = false,
                    .reverse = false,
                },
            };
        }

        // Increment scrollback counter
        if (self.scrollback_lines < MAX_SCROLLBACK) {
            self.scrollback_lines += 1;
        }
        // Reset scrollback offset when new content is added
        self.scrollback_offset = 0;
    }

    /// Scroll up in scrollback (view older content).
    // 2025-11-24-174000-pst: Active function
    pub fn scrollback_up(self: *Terminal) void {
        if (self.scrollback_offset < self.scrollback_lines) {
            self.scrollback_offset += 1;
        }
    }

    /// Scroll down in scrollback (view newer content).
    // 2025-11-24-174000-pst: Active function
    pub fn scrollback_down(self: *Terminal) void {
        if (self.scrollback_offset > 0) {
            self.scrollback_offset -= 1;
        }
    }

    /// Jump to top of scrollback (oldest content).
    // 2025-11-24-174000-pst: Active function
    pub fn scrollback_to_top(self: *Terminal) void {
        self.scrollback_offset = self.scrollback_lines;
    }

    /// Jump to bottom of scrollback (latest content).
    // 2025-11-24-174000-pst: Active function
    pub fn scrollback_to_bottom(self: *Terminal) void {
        self.scrollback_offset = 0;
    }

    /// Get current scrollback offset.
    // 2025-11-24-174000-pst: Active function
    pub fn get_scrollback_offset(self: *const Terminal) u32 {
        return self.scrollback_offset;
    }

    /// Get total scrollback lines.
    // 2025-11-24-174000-pst: Active function
    pub fn get_scrollback_lines(self: *const Terminal) u32 {
        return self.scrollback_lines;
    }

    /// Handle single-character escape sequence.
    fn handle_escape_sequence(self: *Terminal, ch: u8) void {
        switch (ch) {
            '7' => {
                // Save cursor position
                self.saved_cursor_x = self.cursor_x;
                self.saved_cursor_y = self.cursor_y;
            },
            '8' => {
                // Restore cursor position
                self.cursor_x = self.saved_cursor_x;
                self.cursor_y = self.saved_cursor_y;
                if (self.cursor_x >= self.width) {
                    self.cursor_x = self.width - 1;
                }
                if (self.cursor_y >= self.height) {
                    self.cursor_y = self.height - 1;
                }
            },
            'c' => {
                // Reset terminal
                self.cursor_x = 0;
                self.cursor_y = 0;
                self.current_attrs = CellAttributes{
                    .fg_color = self.default_fg,
                    .bg_color = self.default_bg,
                    .fg_rgb = null,
                    .bg_rgb = null,
                    .bold = false,
                    .italic = false,
                    .underline = false,
                    .blink = false,
                    .reverse = false,
                };
            },
            else => {
                // Unknown escape sequence, ignore
            },
        }
    }

    /// Handle CSI (Control Sequence Introducer) sequence.
    fn handle_csi_sequence(self: *Terminal, cells: []Cell) void {
        // Assert: Escape buffer must have at least final character
        std.debug.assert(self.escape_len > 0);

        const final_char = self.escape_buffer[self.escape_len - 1];
        const params = self.escape_buffer[0..self.escape_len - 1];

        switch (final_char) {
            'A' => {
                // Cursor Up
                const n = self.parse_csi_param(params, 1);
                if (self.cursor_y >= n) {
                    self.cursor_y -= n;
                } else {
                    self.cursor_y = 0;
                }
            },
            'B' => {
                // Cursor Down
                const n = self.parse_csi_param(params, 1);
                self.cursor_y += n;
                if (self.cursor_y >= self.height) {
                    self.cursor_y = self.height - 1;
                }
            },
            'C' => {
                // Cursor Forward
                const n = self.parse_csi_param(params, 1);
                self.cursor_x += n;
                if (self.cursor_x >= self.width) {
                    self.cursor_x = self.width - 1;
                }
            },
            'D' => {
                // Cursor Backward
                const n = self.parse_csi_param(params, 1);
                if (self.cursor_x >= n) {
                    self.cursor_x -= n;
                } else {
                    self.cursor_x = 0;
                }
            },
            'H' => {
                // Cursor Position
                var params_iter = std.mem.splitScalar(u8, params, ';');
                const row_str = params_iter.next() orelse "1";
                const col_str = params_iter.next() orelse "1";
                const row = self.parse_number(row_str, 1);
                const col = self.parse_number(col_str, 1);
                self.cursor_y = if (row > 0) row - 1 else 0;
                self.cursor_x = if (col > 0) col - 1 else 0;
                if (self.cursor_y >= self.height) {
                    self.cursor_y = self.height - 1;
                }
                if (self.cursor_x >= self.width) {
                    self.cursor_x = self.width - 1;
                }
            },
            'f' => {
                // Cursor Position (same as 'H')
                var params_iter = std.mem.splitScalar(u8, params, ';');
                const row_str = params_iter.next() orelse "1";
                const col_str = params_iter.next() orelse "1";
                const row = self.parse_number(row_str, 1);
                const col = self.parse_number(col_str, 1);
                self.cursor_y = if (row > 0) row - 1 else 0;
                self.cursor_x = if (col > 0) col - 1 else 0;
                if (self.cursor_y >= self.height) {
                    self.cursor_y = self.height - 1;
                }
                if (self.cursor_x >= self.width) {
                    self.cursor_x = self.width - 1;
                }
            },
            's' => {
                // Save cursor position (DEC)
                self.saved_cursor_x = self.cursor_x;
                self.saved_cursor_y = self.cursor_y;
            },
            'u' => {
                // Restore cursor position (DEC)
                self.cursor_x = self.saved_cursor_x;
                self.cursor_y = self.saved_cursor_y;
                if (self.cursor_x >= self.width) {
                    self.cursor_x = self.width - 1;
                }
                if (self.cursor_y >= self.height) {
                    self.cursor_y = self.height - 1;
                }
            },
            'E' => {
                // Cursor Next Line (move to beginning of next line)
                const n = self.parse_csi_param(params, 1);
                self.cursor_y += n;
                self.cursor_x = 0;
                if (self.cursor_y >= self.height) {
                    self.cursor_y = self.height - 1;
                }
            },
            'F' => {
                // Cursor Previous Line (move to beginning of previous line)
                const n = self.parse_csi_param(params, 1);
                if (self.cursor_y >= n) {
                    self.cursor_y -= n;
                } else {
                    self.cursor_y = 0;
                }
                self.cursor_x = 0;
            },
            'G' => {
                // Cursor Horizontal Absolute (move to column)
                const n = self.parse_csi_param(params, 1);
                if (n > 0) {
                    self.cursor_x = n - 1;
                } else {
                    self.cursor_x = 0;
                }
                if (self.cursor_x >= self.width) {
                    self.cursor_x = self.width - 1;
                }
            },
            'd' => {
                // Cursor Vertical Absolute (move to row)
                const n = self.parse_csi_param(params, 1);
                if (n > 0) {
                    self.cursor_y = n - 1;
                } else {
                    self.cursor_y = 0;
                }
                if (self.cursor_y >= self.height) {
                    self.cursor_y = self.height - 1;
                }
            },
            'n' => {
                // Device Status Report (DSR) - respond with cursor position
                // Format: ESC [ row ; col R
                // For now, we ignore (would need output mechanism)
                _ = params;
                _ = self;
            },
            'h' => {
                // Set Mode (SM) - enable terminal features
                // For now, we ignore most modes
                _ = params;
            },
            'l' => {
                // Reset Mode (RM) - disable terminal features
                // For now, we ignore most modes
                _ = params;
            },
            'J' => {
                // Erase in Display
                const n = self.parse_csi_param(params, 0);
                self.erase_display(n, cells);
            },
            'K' => {
                // Erase in Line
                const n = self.parse_csi_param(params, 0);
                self.erase_line(n, cells);
            },
            'm' => {
                // Select Graphic Rendition (SGR)
                self.handle_sgr_sequence(params);
            },
            '@' => {
                // Insert Character (ICH) - insert blank characters at cursor
                const n = self.parse_csi_param(params, 1);
                self.insert_characters(n, cells);
            },
            'P' => {
                // Delete Character (DCH) - delete characters at cursor
                const n = self.parse_csi_param(params, 1);
                self.delete_characters(n, cells);
            },
            'L' => {
                // Insert Line (IL) - insert blank lines at cursor
                const n = self.parse_csi_param(params, 1);
                self.insert_lines(n, cells);
            },
            'M' => {
                // Delete Line (DL) - delete lines at cursor
                const n = self.parse_csi_param(params, 1);
                self.delete_lines(n, cells);
            },
            'r' => {
                // Set Scrolling Region (DECSTBM) - CSI <top> ; <bottom> r
                self.set_scrolling_region(params);
            },
            else => {
                // Unknown CSI sequence, ignore
            },
        }
    }

    /// Handle OSC (Operating System Command) sequence.
    // 2025-11-24-180000-pst: Active function
    fn handle_osc_sequence(self: *Terminal) void {
        // Assert: Escape buffer must have content
        std.debug.assert(self.escape_len > 0);

        // Parse OSC sequence: ESC ] <number> ; <text> BEL/ESC
        // Common sequences:
        // 0: Set window title and icon name
        // 1: Set icon name
        // 2: Set window title
        if (self.escape_len < 2) {
            return;
        }

        // Parse number (first character should be digit)
        var num_start: u32 = 0;
        while (num_start < self.escape_len and self.escape_buffer[num_start] == ' ') : (num_start += 1) {}
        if (num_start >= self.escape_len) {
            return;
        }

        // Find semicolon
        var semicolon_idx: u32 = num_start;
        while (semicolon_idx < self.escape_len and self.escape_buffer[semicolon_idx] != ';') : (semicolon_idx += 1) {}
        if (semicolon_idx >= self.escape_len) {
            return;
        }

        // Parse number
        const num_str = self.escape_buffer[num_start..semicolon_idx];
        const osc_code = self.parse_number(num_str, 0);

        // Get text (after semicolon, before BEL/ESC)
        const text_start = semicolon_idx + 1;
        const text_end = self.escape_len;
        if (text_start >= text_end) {
            return;
        }

        // Handle window title sequences (0, 2)
        if (osc_code == 0 or osc_code == 2) {
            const text = self.escape_buffer[text_start..text_end];
            const copy_len = @min(text.len, 255);
            @memset(self.window_title[0..], 0);
            @memcpy(self.window_title[0..copy_len], text[0..copy_len]);
            self.window_title_len = copy_len;
        }
        // Icon name (1) is ignored for now
    }

    /// Set scrolling region (DECSTBM).
    // 2025-11-24-212700-pst: Active function
    fn set_scrolling_region(self: *Terminal, params: []const u8) void {
        // Parse parameters: CSI <top> ; <bottom> r
        // Default: top = 1, bottom = height
        if (params.len == 0) {
            // Reset to full screen
            self.scroll_top = 0;
            self.scroll_bottom = self.height;
            return;
        }

        // Parse parameters (handle semicolon-separated)
        var params_list: [2]u32 = undefined;
        var params_count: u32 = 0;
        var params_iter = std.mem.splitScalar(u8, params, ';');
        while (params_iter.next()) |param_str| {
            if (params_count >= 2) {
                break; // Bounded: max 2 parameters
            }
            const code = self.parse_number(param_str, 0);
            params_list[params_count] = code;
            params_count += 1;
        }

        // Set scrolling region (1-based to 0-based conversion)
        if (params_count >= 1) {
            const top = params_list[0];
            if (top > 0) {
                self.scroll_top = top - 1;
            } else {
                self.scroll_top = 0;
            }
        } else {
            self.scroll_top = 0;
        }

        if (params_count >= 2) {
            const bottom = params_list[1];
            if (bottom > 0) {
                self.scroll_bottom = bottom;
            } else {
                self.scroll_bottom = self.height;
            }
        } else {
            self.scroll_bottom = self.height;
        }

        // Bounds checking
        if (self.scroll_top >= self.height) {
            self.scroll_top = self.height - 1;
        }
        if (self.scroll_bottom > self.height) {
            self.scroll_bottom = self.height;
        }
        if (self.scroll_top >= self.scroll_bottom) {
            self.scroll_top = 0;
            self.scroll_bottom = self.height;
        }

        // Move cursor to home position (top-left of scrolling region)
        self.cursor_x = 0;
        self.cursor_y = self.scroll_top;
    }

    /// Handle bell character (BEL, 0x07).
    // 2025-11-24-180000-pst: Active function
    fn handle_bell(self: *Terminal) void {
        // Bell is handled - application can check bell_count or use callback
        // For now, we just track that a bell occurred
        _ = self;
    }

    /// Get window title.
    // 2025-11-24-180000-pst: Active function
    pub fn get_window_title(self: *const Terminal) []const u8 {
        return self.window_title[0..self.window_title_len];
    }

    /// Parse CSI parameter (number or default).
    // 2025-11-23-150318-pst: Active function
    fn parse_csi_param(self: *const Terminal, params: []const u8, default_val: u32) u32 {
        // self will be used in full implementation for terminal-specific parsing
        if (params.len == 0) {
            return default_val;
        }
        return self.parse_number(params, default_val);
    }

    /// Parse number from string.
    fn parse_number(self: *const Terminal, str: []const u8, default_val: u32) u32 {
        _ = self;
        if (str.len == 0) {
            return default_val;
        }
        return std.fmt.parseInt(u32, str, 10) catch default_val;
    }

    /// Erase display (clear screen).
    fn erase_display(self: *Terminal, mode: u32, cells: []Cell) void {
        // Assert: Cells buffer must be valid
        std.debug.assert(cells.len >= self.width * self.height);

        switch (mode) {
            0 => {
                // Erase from cursor to end of screen
                var y: u32 = self.cursor_y;
                while (y < self.height) : (y += 1) {
                    var x: u32 = if (y == self.cursor_y) self.cursor_x else 0;
                    while (x < self.width) : (x += 1) {
                        const idx = y * self.width + x;
                        cells[idx] = Cell{
                            .ch = ' ',
                            .attrs = self.current_attrs,
                        };
                    }
                }
            },
            1 => {
                // Erase from beginning of screen to cursor
                var y: u32 = 0;
                while (y <= self.cursor_y) : (y += 1) {
                    var x: u32 = 0;
                    const end_x = if (y == self.cursor_y) self.cursor_x + 1 else self.width;
                    while (x < end_x) : (x += 1) {
                        const idx = y * self.width + x;
                        cells[idx] = Cell{
                            .ch = ' ',
                            .attrs = self.current_attrs,
                        };
                    }
                }
            },
            2 => {
                // Erase entire screen
                var y: u32 = 0;
                while (y < self.height) : (y += 1) {
                    var x: u32 = 0;
                    while (x < self.width) : (x += 1) {
                        const idx = y * self.width + x;
                        cells[idx] = Cell{
                            .ch = ' ',
                            .attrs = self.current_attrs,
                        };
                    }
                }
            },
            else => {
                // Unknown mode, ignore
            },
        }
    }

    /// Erase line.
    fn erase_line(self: *Terminal, mode: u32, cells: []Cell) void {
        // Assert: Cursor position must be valid
        std.debug.assert(self.cursor_y < self.height);
        std.debug.assert(cells.len >= self.width * self.height);

        switch (mode) {
            0 => {
                // Erase from cursor to end of line
                var x: u32 = self.cursor_x;
                while (x < self.width) : (x += 1) {
                    const idx = self.cursor_y * self.width + x;
                    cells[idx] = Cell{
                        .ch = ' ',
                        .attrs = self.current_attrs,
                    };
                }
            },
            1 => {
                // Erase from beginning of line to cursor
                var x: u32 = 0;
                while (x <= self.cursor_x) : (x += 1) {
                    const idx = self.cursor_y * self.width + x;
                    cells[idx] = Cell{
                        .ch = ' ',
                        .attrs = self.current_attrs,
                    };
                }
            },
            2 => {
                // Erase entire line
                var x: u32 = 0;
                while (x < self.width) : (x += 1) {
                    const idx = self.cursor_y * self.width + x;
                    cells[idx] = Cell{
                        .ch = ' ',
                        .attrs = self.current_attrs,
                    };
                }
            },
            else => {
                // Unknown mode, ignore
            },
        }
    }

    /// Insert characters at cursor position (ICH).
    // 2025-11-24-204500-pst: Active function
    fn insert_characters(self: *Terminal, count: u32, cells: []Cell) void {
        // Assert: Cursor position must be valid
        std.debug.assert(self.cursor_y < self.height);
        std.debug.assert(cells.len >= self.width * self.height);

        if (count == 0) {
            return;
        }

        const line_start = self.cursor_y * self.width;
        const line_end = line_start + self.width;

        // Shift characters right (from cursor to end of line)
        // Start from end and work backwards to avoid overwriting
        var x: u32 = self.width;
        while (x > self.cursor_x) : (x -= 1) {
            const src_idx = line_start + x - 1;
            const dst_idx = if (x + count <= self.width) line_start + x + count - 1 else line_end - 1;
            if (dst_idx < line_end) {
                cells[dst_idx] = cells[src_idx];
            }
        }

        // Fill inserted characters with blanks
        var i: u32 = 0;
        while (i < count and (self.cursor_x + i) < self.width) : (i += 1) {
            const idx = line_start + self.cursor_x + i;
            cells[idx] = Cell{
                .ch = ' ',
                .attrs = self.current_attrs,
            };
        }
    }

    /// Delete characters at cursor position (DCH).
    // 2025-11-24-204500-pst: Active function
    fn delete_characters(self: *Terminal, count: u32, cells: []Cell) void {
        // Assert: Cursor position must be valid
        std.debug.assert(self.cursor_y < self.height);
        std.debug.assert(cells.len >= self.width * self.height);

        if (count == 0) {
            return;
        }

        const line_start = self.cursor_y * self.width;

        // Shift characters left (from cursor+count to end of line)
        var x: u32 = self.cursor_x + count;
        while (x < self.width) : (x += 1) {
            const src_idx = line_start + x;
            const dst_idx = line_start + x - count;
            cells[dst_idx] = cells[src_idx];
        }

        // Fill end of line with blanks
        var i: u32 = 0;
        while (i < count and (self.width - i) > 0) : (i += 1) {
            const idx = line_start + self.width - 1 - i;
            cells[idx] = Cell{
                .ch = ' ',
                .attrs = self.current_attrs,
            };
        }
    }

    /// Insert lines at cursor position (IL).
    // 2025-11-24-204500-pst: Active function
    fn insert_lines(self: *Terminal, count: u32, cells: []Cell) void {
        // Assert: Cursor position must be valid
        std.debug.assert(self.cursor_y < self.height);
        std.debug.assert(cells.len >= self.width * self.height);

        if (count == 0) {
            return;
        }

        // Shift lines down (from cursor to bottom)
        // Start from bottom and work backwards
        var y: u32 = self.height;
        while (y > self.cursor_y) : (y -= 1) {
            const src_line_start = (y - 1) * self.width;
            const dst_line_start = if (y + count <= self.height) (y + count - 1) * self.width else (self.height - 1) * self.width;
            var x: u32 = 0;
            while (x < self.width) : (x += 1) {
                const src_idx = src_line_start + x;
                const dst_idx = dst_line_start + x;
                if (dst_idx < self.width * self.height) {
                    cells[dst_idx] = cells[src_idx];
                }
            }
        }

        // Fill inserted lines with blanks
        var i: u32 = 0;
        while (i < count and (self.cursor_y + i) < self.height) : (i += 1) {
            const line_start = (self.cursor_y + i) * self.width;
            var x: u32 = 0;
            while (x < self.width) : (x += 1) {
                const idx = line_start + x;
                cells[idx] = Cell{
                    .ch = ' ',
                    .attrs = self.current_attrs,
                };
            }
        }
    }

    /// Delete lines at cursor position (DL).
    // 2025-11-24-204500-pst: Active function
    fn delete_lines(self: *Terminal, count: u32, cells: []Cell) void {
        // Assert: Cursor position must be valid
        std.debug.assert(self.cursor_y < self.height);
        std.debug.assert(cells.len >= self.width * self.height);

        if (count == 0) {
            return;
        }

        // Shift lines up (from cursor+count to bottom)
        var y: u32 = self.cursor_y + count;
        while (y < self.height) : (y += 1) {
            const src_line_start = y * self.width;
            const dst_line_start = (y - count) * self.width;
            var x: u32 = 0;
            while (x < self.width) : (x += 1) {
                const src_idx = src_line_start + x;
                const dst_idx = dst_line_start + x;
                cells[dst_idx] = cells[src_idx];
            }
        }

        // Fill bottom lines with blanks
        var i: u32 = 0;
        while (i < count and (self.height - i) > 0) : (i += 1) {
            const line_start = (self.height - 1 - i) * self.width;
            var x: u32 = 0;
            while (x < self.width) : (x += 1) {
                const idx = line_start + x;
                cells[idx] = Cell{
                    .ch = ' ',
                    .attrs = self.current_attrs,
                };
            }
        }
    }

    /// Handle SGR (Select Graphic Rendition) sequence.
    // 2025-11-24-192000-pst: Active function
    fn handle_sgr_sequence(self: *Terminal, params: []const u8) void {
        if (params.len == 0) {
            // Reset attributes
            self.current_attrs = CellAttributes{
                .fg_color = self.default_fg,
                .bg_color = self.default_bg,
                .bold = false,
                .italic = false,
                .underline = false,
                .blink = false,
                .reverse = false,
            };
            return;
        }

        // Parse parameters (handle multi-parameter sequences like 38;5;n)
        var params_list: [16]u32 = undefined;
        var params_count: u32 = 0;
        var params_iter = std.mem.splitScalar(u8, params, ';');
        while (params_iter.next()) |param_str| {
            if (params_count >= 16) {
                break; // Bounded: max 16 parameters
            }
            const code = self.parse_number(param_str, 0);
            params_list[params_count] = code;
            params_count += 1;
        }

        // Process parameters (handle 256-color sequences)
        var i: u32 = 0;
        while (i < params_count) : (i += 1) {
            const code = params_list[i];
            switch (code) {
                0 => {
                    // Reset all attributes
                    self.current_attrs = CellAttributes{
                        .fg_color = self.default_fg,
                        .bg_color = self.default_bg,
                        .bold = false,
                        .italic = false,
                        .underline = false,
                        .blink = false,
                        .reverse = false,
                    };
                },
                1 => self.current_attrs.bold = true,
                3 => self.current_attrs.italic = true,
                4 => self.current_attrs.underline = true,
                5 => self.current_attrs.blink = true,
                7 => self.current_attrs.reverse = true,
                22 => self.current_attrs.bold = false,
                23 => self.current_attrs.italic = false,
                24 => self.current_attrs.underline = false,
                25 => self.current_attrs.blink = false,
                27 => self.current_attrs.reverse = false,
                30...37 => {
                    // Foreground color (30-37) - 16-color palette
                    self.current_attrs.fg_color = @as(u8, @intCast(code - 30));
                    self.current_attrs.fg_rgb = null; // Clear RGB when using indexed
                },
                38 => {
                    // Foreground color: 38;5;n (256-color) or 38;2;r;g;b (true color)
                    if (i + 2 < params_count and params_list[i + 1] == 5) {
                        // 256-color foreground: 38;5;n
                        const color_code = params_list[i + 2];
                        if (color_code <= 255) {
                            self.current_attrs.fg_color = @as(u8, @intCast(color_code));
                            self.current_attrs.fg_rgb = null; // Clear RGB when using indexed
                        }
                        i += 2; // Skip 5 and color code
                    } else if (i + 4 < params_count and params_list[i + 1] == 2) {
                        // True color foreground: 38;2;r;g;b
                        const r = params_list[i + 2];
                        const g = params_list[i + 3];
                        const b = params_list[i + 4];
                        if (r <= 255 and g <= 255 and b <= 255) {
                            self.current_attrs.fg_rgb = [3]u8{
                                @as(u8, @intCast(r)),
                                @as(u8, @intCast(g)),
                                @as(u8, @intCast(b)),
                            };
                        }
                        i += 4; // Skip 2, r, g, b
                    }
                },
                39 => {
                    // Default foreground color
                    self.current_attrs.fg_color = self.default_fg;
                    self.current_attrs.fg_rgb = null; // Clear RGB
                },
                40...47 => {
                    // Background color (40-47) - 16-color palette
                    self.current_attrs.bg_color = @as(u8, @intCast(code - 40));
                    self.current_attrs.bg_rgb = null; // Clear RGB when using indexed
                },
                48 => {
                    // Background color: 48;5;n (256-color) or 48;2;r;g;b (true color)
                    if (i + 2 < params_count and params_list[i + 1] == 5) {
                        // 256-color background: 48;5;n
                        const color_code = params_list[i + 2];
                        if (color_code <= 255) {
                            self.current_attrs.bg_color = @as(u8, @intCast(color_code));
                            self.current_attrs.bg_rgb = null; // Clear RGB when using indexed
                        }
                        i += 2; // Skip 5 and color code
                    } else if (i + 4 < params_count and params_list[i + 1] == 2) {
                        // True color background: 48;2;r;g;b
                        const r = params_list[i + 2];
                        const g = params_list[i + 3];
                        const b = params_list[i + 4];
                        if (r <= 255 and g <= 255 and b <= 255) {
                            self.current_attrs.bg_rgb = [3]u8{
                                @as(u8, @intCast(r)),
                                @as(u8, @intCast(g)),
                                @as(u8, @intCast(b)),
                            };
                        }
                        i += 4; // Skip 2, r, g, b
                    }
                },
                49 => {
                    // Default background color
                    self.current_attrs.bg_color = self.default_bg;
                    self.current_attrs.bg_rgb = null; // Clear RGB
                },
                else => {
                    // Unknown code, ignore
                },
            }
        }
    }

    /// Get cell at position.
    pub fn get_cell(self: *const Terminal, x: u32, y: u32, cells: []const Cell) ?Cell {
        // Assert: Position must be valid
        std.debug.assert(x < self.width);
        std.debug.assert(y < self.height);
        std.debug.assert(cells.len >= self.width * self.height);

        const idx = y * self.width + x;
        return cells[idx];
    }

    /// Clear terminal (reset all cells).
    pub fn clear(self: *Terminal, cells: []Cell) void {
        // Assert: Cells buffer must be valid
        std.debug.assert(cells.len >= self.width * self.height);

        var y: u32 = 0;
        while (y < self.height) : (y += 1) {
            var x: u32 = 0;
            while (x < self.width) : (x += 1) {
                const idx = y * self.width + x;
                cells[idx] = Cell{
                    .ch = ' ',
                    .attrs = CellAttributes{
                        .fg_color = self.default_fg,
                        .bg_color = self.default_bg,
                        .bold = false,
                        .italic = false,
                        .underline = false,
                        .blink = false,
                        .reverse = false,
                    },
                };
            }
        }

        self.cursor_x = 0;
        self.cursor_y = 0;
        self.scrollback_lines = 0;
        self.scrollback_offset = 0;
    }
};

