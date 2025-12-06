//! Grain Skate Editor Renderer: Renders editor text to pixel buffer.
//!
//! Why: Display editor content, cursor, selections, and status in window.
//! Architecture: Pixel buffer rendering, monospace font, line-based layout.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-05-172208-pst: Active implementation (migrated to shared font renderer)

const std = @import("std");
const Editor = @import("editor.zig").Editor;
const LanguageDetector = @import("language_detector.zig").LanguageDetector;
const Language = @import("language_detector.zig").Language;
const LanguageKeywords = @import("language_keywords.zig").LanguageKeywords;
const BracketMatcher = @import("bracket_matching.zig").BracketMatcher;
const BracketMatch = @import("bracket_matching.zig").BracketMatch;
const FontRenderer = @import("../shared/font_renderer.zig").FontRenderer;

// Bounded: Max buffer width (explicit limit, in pixels)
// 2025-12-02-142853-pst: Active constant
pub const MAX_BUFFER_WIDTH: u32 = 4096;

// Bounded: Max buffer height (explicit limit, in pixels)
// 2025-12-02-142853-pst: Active constant
pub const MAX_BUFFER_HEIGHT: u32 = 4096;

// Bounded: Max visible lines (explicit limit)
// 2025-12-02-142853-pst: Active constant
pub const MAX_VISIBLE_LINES: u32 = 1000;

// Bounded: Max characters per line (explicit limit)
// 2025-12-02-142853-pst: Active constant
pub const MAX_CHARS_PER_LINE: u32 = 200;

// Font dimensions (8x8 bitmap font via shared font renderer)
// 2025-12-05-172208-pst: Active constants (migrated to shared font renderer)
pub const CHAR_WIDTH: u32 = 9; // 8 pixels + 1 spacing
pub const CHAR_HEIGHT: u32 = 9; // 8 pixels + 1 spacing
pub const LINE_SPACING: u32 = 2; // Additional spacing between lines

// Color constants (RGBA format)
// 2025-12-02-142853-pst: Active constants
pub const COLOR_BACKGROUND: u32 = 0xFF1E1E1E; // Dark gray background
pub const COLOR_TEXT: u32 = 0xFFFFFFFF; // White text
pub const COLOR_CURSOR: u32 = 0xFFFFFFFF; // White cursor
pub const COLOR_SELECTION: u32 = 0xFF4A90E2; // Blue selection
pub const COLOR_STATUS_BG: u32 = 0xFF2D2D2D; // Darker gray for status line
pub const COLOR_COMMAND_LINE: u32 = 0xFFFFFF00; // Yellow for command line
pub const COLOR_LINE_NUMBERS: u32 = 0xFF808080; // Gray for line numbers
pub const COLOR_LINE_NUMBERS_BG: u32 = 0xFF252525; // Slightly darker gray for line number column
pub const COLOR_ERROR: u32 = 0xFFFF0000; // Red for error messages
pub const COLOR_KEYWORD: u32 = 0xFF569CD6; // Blue for keywords
pub const COLOR_STRING: u32 = 0xFFCE9178; // Orange for strings
pub const COLOR_COMMENT: u32 = 0xFF6A9955; // Green for comments
pub const COLOR_NUMBER: u32 = 0xFFB5CEA8; // Light green for numbers
pub const COLOR_BRACKET_MATCH: u32 = 0xFFFFFF00; // Yellow for matching brackets

// Font patterns removed - now using shared font renderer
// 2025-12-05-172208-pst: Migrated to shared font renderer

// Editor renderer state.
// 2025-12-02-142853-pst: Active struct
pub const EditorRenderer = struct {
    editor: *Editor.EditorState,
    buffer_width: u32,
    buffer_height: u32,
    viewport_line: u32, // First visible line (for scrolling)
    viewport_column: u32, // First visible column (for horizontal scrolling)
    command_buffer: []const u8, // Command buffer for command mode display
    block_title: []const u8, // Block title for status line display
    modified: bool, // Whether editor content has been modified since last save
    error_message: []const u8, // Error message to display (empty if no error)
    error_message_timeout: u64, // Timestamp when error message should be cleared (0 = no timeout)
    syntax_highlighting_enabled: bool, // Whether syntax highlighting is enabled
    detected_language: Language, // Detected programming language (for language-specific highlighting)

    /// Initialize editor renderer.
    // 2025-12-05-172208-pst: Active function (migrated to shared font renderer)
    pub fn init(editor: *Editor.EditorState, buffer_width: u32, buffer_height: u32) EditorRenderer {
        std.debug.assert(buffer_width > 0);
        std.debug.assert(buffer_width <= MAX_BUFFER_WIDTH);
        std.debug.assert(buffer_height > 0);
        std.debug.assert(buffer_height <= MAX_BUFFER_HEIGHT);
        std.debug.assert(editor.buffer.lines_len > 0 or editor.buffer.lines_len == 0);

        // Initialize shared font renderer (8x8 font, ASCII basic character set)
        const font_renderer = FontRenderer.init(.font_8x8, .ascii_basic);

        return EditorRenderer{
            .editor = editor,
            .buffer_width = buffer_width,
            .buffer_height = buffer_height,
            .viewport_line = 0,
            .viewport_column = 0,
            .command_buffer = "",
            .block_title = "",
            .modified = false,
            .error_message = "",
            .error_message_timeout = 0,
            .syntax_highlighting_enabled = true, // Enable by default
            .detected_language = .unknown, // Default to unknown language
            .font_renderer = font_renderer,
        };
    }

    /// Update viewport to keep cursor visible.
    // 2025-12-02-142853-pst: Active function
    pub fn update_viewport(self: *EditorRenderer) void {
        const visible_lines = self.get_visible_line_count();
        const visible_cols = self.get_visible_column_count();
        // Adjust viewport to keep cursor visible
        if (self.editor.cursor_line < self.viewport_line) {
            self.viewport_line = self.editor.cursor_line;
        } else if (self.editor.cursor_line >= self.viewport_line + visible_lines) {
            self.viewport_line = if (self.editor.cursor_line >= visible_lines)
                self.editor.cursor_line - visible_lines + 1
            else
                0;
        }
        if (self.editor.cursor_column < self.viewport_column) {
            self.viewport_column = self.editor.cursor_column;
        } else if (self.editor.cursor_column >= self.viewport_column + visible_cols) {
            self.viewport_column = if (self.editor.cursor_column >= visible_cols)
                self.editor.cursor_column - visible_cols + 1
            else
                0;
        }
    }

    /// Get number of visible lines.
    // 2025-12-02-142853-pst: Active function
    fn get_visible_line_count(self: *const EditorRenderer) u32 {
        const status_height = CHAR_HEIGHT + LINE_SPACING;
        const available_height = if (self.buffer_height > status_height)
            self.buffer_height - status_height
        else
            self.buffer_height;
        const line_height = CHAR_HEIGHT + LINE_SPACING;
        return if (line_height > 0) available_height / line_height else 1;
    }

    /// Get number of visible columns (accounting for line number column).
    // 2025-12-02-163144-pst: Active function
    fn get_visible_column_count(self: *const EditorRenderer) u32 {
        const line_num_width = self.get_line_number_column_width();
        const available_width = if (self.buffer_width > line_num_width)
            self.buffer_width - line_num_width
        else
            0;
        return if (CHAR_WIDTH > 0) available_width / CHAR_WIDTH else 1;
    }

    /// Get line number column width in pixels.
    // 2025-12-02-163144-pst: Active function
    fn get_line_number_column_width(self: *const EditorRenderer) u32 {
        const total_lines = self.editor.buffer.lines_len;
        // Calculate number of digits needed (max 6 digits for line numbers)
        const max_line_num = @max(total_lines, 1);
        var digit_count: u32 = 1;
        var num = max_line_num;
        while (num >= 10) : (num /= 10) {
            digit_count += 1;
        }
        // Limit to 6 digits max (999,999 lines)
        digit_count = @min(digit_count, 6);
        // Add padding: digits + 2 spaces on each side = (digits + 4) * CHAR_WIDTH
        const column_width = (digit_count + 4) * CHAR_WIDTH;
        return column_width;
    }

    /// Render editor to RGBA buffer.
    // 2025-12-02-142853-pst: Active function
    pub fn render(self: *EditorRenderer, buffer: []u8) void {
        std.debug.assert(buffer.len >= self.buffer_width * self.buffer_height * 4);
        // Check and clear expired error messages
        self.check_error_timeout();
        // Update viewport to keep cursor visible
        self.update_viewport();
        // Clear buffer with background color
        self.clear_buffer(buffer);
        // Render line number column background
        self.render_line_number_column(buffer);
        // Render line numbers
        self.render_line_numbers(buffer);
        // Render text lines
        self.render_text_lines(buffer);
        // Render visual mode selections
        if (self.editor.mode == .visual or self.editor.mode == .visual_line or self.editor.mode == .visual_block) {
            self.render_selection(buffer);
        }
        // Render bracket matching (highlight matching bracket if cursor is on bracket)
        self.render_bracket_match(buffer);
        // Render cursor
        self.render_cursor(buffer);
        // Render status line
        self.render_status_line(buffer);
        // Render command line or search pattern if active
        if (self.editor.mode == .command) {
            self.render_command_line(buffer);
        } else if (self.editor.mode == .search) {
            self.render_search_line(buffer);
        }
    }

    /// Clear buffer with background color.
    // 2025-12-02-142853-pst: Active function
    fn clear_buffer(self: *const EditorRenderer, buffer: []u8) void {
        const bg_r = @as(u8, @truncate((COLOR_BACKGROUND >> 16) & 0xFF));
        const bg_g = @as(u8, @truncate((COLOR_BACKGROUND >> 8) & 0xFF));
        const bg_b = @as(u8, @truncate(COLOR_BACKGROUND & 0xFF));
        const bg_a = @as(u8, @truncate((COLOR_BACKGROUND >> 24) & 0xFF));
        var i: u32 = 0;
        const total_pixels = self.buffer_width * self.buffer_height;
        while (i < total_pixels) : (i += 1) {
            const idx = i * 4;
            buffer[idx + 0] = bg_r;
            buffer[idx + 1] = bg_g;
            buffer[idx + 2] = bg_b;
            buffer[idx + 3] = bg_a;
        }
    }

    /// Render line number column background.
    // 2025-12-02-163144-pst: Active function
    fn render_line_number_column(self: *const EditorRenderer, buffer: []u8) void {
        const line_num_width = self.get_line_number_column_width();
        const visible_lines = self.get_visible_line_count();
        const status_height = CHAR_HEIGHT + LINE_SPACING;
        const content_height = self.buffer_height - status_height;
        const bg_r = @as(u8, @truncate((COLOR_LINE_NUMBERS_BG >> 16) & 0xFF));
        const bg_g = @as(u8, @truncate((COLOR_LINE_NUMBERS_BG >> 8) & 0xFF));
        const bg_b = @as(u8, @truncate(COLOR_LINE_NUMBERS_BG & 0xFF));
        const bg_a = @as(u8, @truncate((COLOR_LINE_NUMBERS_BG >> 24) & 0xFF));
        self.draw_rect(buffer, 0, 0, line_num_width, content_height, bg_r, bg_g, bg_b, bg_a);
    }

    /// Render line numbers for visible lines.
    // 2025-12-02-163144-pst: Active function
    fn render_line_numbers(self: *const EditorRenderer, buffer: []u8) void {
        const visible_lines = self.get_visible_line_count();
        const line_num_r = @as(u8, @truncate((COLOR_LINE_NUMBERS >> 16) & 0xFF));
        const line_num_g = @as(u8, @truncate((COLOR_LINE_NUMBERS >> 8) & 0xFF));
        const line_num_b = @as(u8, @truncate(COLOR_LINE_NUMBERS & 0xFF));
        const line_num_a = @as(u8, @truncate((COLOR_LINE_NUMBERS >> 24) & 0xFF));
        const total_lines = self.editor.buffer.lines_len;
        var line_idx: u32 = 0;
        while (line_idx < visible_lines and self.viewport_line + line_idx < total_lines) : (line_idx += 1) {
            const line_num = self.viewport_line + line_idx + 1; // 1-based line numbers
            const line_y = line_idx * (CHAR_HEIGHT + LINE_SPACING);
            // Format line number as string
            var num_buf: [16]u8 = undefined;
            const num_str = self.format_number(line_num, &num_buf);
            // Right-align line number (calculate padding)
            const line_num_width = self.get_line_number_column_width();
            const num_width = num_str.len * CHAR_WIDTH;
            const padding = if (line_num_width > num_width + 2 * CHAR_WIDTH)
                line_num_width - num_width - 2 * CHAR_WIDTH
            else
                0;
            const num_x = padding;
            // Render line number
            self.draw_text(buffer, num_str, num_x, line_y, line_num_r, line_num_g, line_num_b, line_num_a);
        }
    }

    /// Render text lines from editor buffer.
    // 2025-12-02-142853-pst: Active function
    fn render_text_lines(self: *const EditorRenderer, buffer: []u8) void {
        const visible_lines = self.get_visible_line_count();
        var line_idx: u32 = 0;
        while (line_idx < visible_lines and self.viewport_line + line_idx < self.editor.buffer.lines_len) : (line_idx += 1) {
            const buffer_line = self.viewport_line + line_idx;
            const line_text = self.editor.buffer.lines[buffer_line];
            const line_y = line_idx * (CHAR_HEIGHT + LINE_SPACING);
            // Render line text (truncate to visible columns)
            const visible_cols = self.get_visible_column_count();
            const start_col = self.viewport_column;
            const end_col = @min(start_col + visible_cols, @as(u32, @intCast(line_text.len)));
            if (start_col < line_text.len) {
                const visible_text = line_text[start_col..end_col];
                const line_num_width = self.get_line_number_column_width();
                // Render with syntax highlighting if enabled
                if (self.syntax_highlighting_enabled) {
                    self.render_text_with_syntax(buffer, visible_text, line_num_width, line_y, start_col);
                } else {
                    // Render without syntax highlighting
                    const text_r = @as(u8, @truncate((COLOR_TEXT >> 16) & 0xFF));
                    const text_g = @as(u8, @truncate((COLOR_TEXT >> 8) & 0xFF));
                    const text_b = @as(u8, @truncate(COLOR_TEXT & 0xFF));
                    const text_a = @as(u8, @truncate((COLOR_TEXT >> 24) & 0xFF));
                    self.draw_text(buffer, visible_text, line_num_width, line_y, text_r, text_g, text_b, text_a);
                }
            }
        }
    }

    /// Render text with syntax highlighting.
    // 2025-12-02-180222-pst: Active function
    fn render_text_with_syntax(self: *const EditorRenderer, buffer: []u8, text: []const u8, x: u32, y: u32, line_start_col: u32) void {
        // Default text color
        const default_r = @as(u8, @truncate((COLOR_TEXT >> 16) & 0xFF));
        const default_g = @as(u8, @truncate((COLOR_TEXT >> 8) & 0xFF));
        const default_b = @as(u8, @truncate(COLOR_TEXT & 0xFF));
        const default_a = @as(u8, @truncate((COLOR_TEXT >> 24) & 0xFF));
        // Syntax colors
        const keyword_r = @as(u8, @truncate((COLOR_KEYWORD >> 16) & 0xFF));
        const keyword_g = @as(u8, @truncate((COLOR_KEYWORD >> 8) & 0xFF));
        const keyword_b = @as(u8, @truncate(COLOR_KEYWORD & 0xFF));
        const keyword_a = @as(u8, @truncate((COLOR_KEYWORD >> 24) & 0xFF));
        const string_r = @as(u8, @truncate((COLOR_STRING >> 16) & 0xFF));
        const string_g = @as(u8, @truncate((COLOR_STRING >> 8) & 0xFF));
        const string_b = @as(u8, @truncate(COLOR_STRING & 0xFF));
        const string_a = @as(u8, @truncate((COLOR_STRING >> 24) & 0xFF));
        const comment_r = @as(u8, @truncate((COLOR_COMMENT >> 16) & 0xFF));
        const comment_g = @as(u8, @truncate((COLOR_COMMENT >> 8) & 0xFF));
        const comment_b = @as(u8, @truncate(COLOR_COMMENT & 0xFF));
        const comment_a = @as(u8, @truncate((COLOR_COMMENT >> 24) & 0xFF));
        const number_r = @as(u8, @truncate((COLOR_NUMBER >> 16) & 0xFF));
        const number_g = @as(u8, @truncate((COLOR_NUMBER >> 8) & 0xFF));
        const number_b = @as(u8, @truncate(COLOR_NUMBER & 0xFF));
        const number_a = @as(u8, @truncate((COLOR_NUMBER >> 24) & 0xFF));
        // Parse syntax and render segments
        var i: u32 = 0;
        var char_x = x;
        var in_string = false;
        var string_char: u8 = 0; // ' or "
        var in_block_comment = false;
        while (i < text.len) : (i += 1) {
            const ch = text[i];
            // Check for comment start (// or /*)
            if (!in_string and !in_block_comment) {
                if (i + 1 < text.len) {
                    const next_ch = text[i + 1];
                    if (ch == '/' and next_ch == '/') {
                        // Single-line comment
                        const remaining = text[i..];
                        self.draw_text(buffer, remaining, char_x, y, comment_r, comment_g, comment_b, comment_a);
                        break; // Rest of line is comment
                    }
                    if (ch == '/' and next_ch == '*') {
                        // Block comment start
                        in_block_comment = true;
                        self.draw_char(buffer, ch, char_x, y, comment_r, comment_g, comment_b, comment_a);
                        char_x += CHAR_WIDTH;
                        i += 1;
                        if (i < text.len) {
                            self.draw_char(buffer, next_ch, char_x, y, comment_r, comment_g, comment_b, comment_a);
                            char_x += CHAR_WIDTH;
                        }
                        continue;
                    }
                }
            }
            // Check for block comment end (*/)
            if (in_block_comment) {
                if (i + 1 < text.len and ch == '*' and text[i + 1] == '/') {
                    in_block_comment = false;
                    self.draw_char(buffer, ch, char_x, y, comment_r, comment_g, comment_b, comment_a);
                    char_x += CHAR_WIDTH;
                    i += 1;
                    if (i < text.len) {
                        self.draw_char(buffer, text[i], char_x, y, comment_r, comment_g, comment_b, comment_a);
                        char_x += CHAR_WIDTH;
                    }
                    continue;
                }
                // Still in block comment
                self.draw_char(buffer, ch, char_x, y, comment_r, comment_g, comment_b, comment_a);
                char_x += CHAR_WIDTH;
                continue;
            }
            // Check for string start/end
            if (!in_block_comment) {
                if ((ch == '"' or ch == '\'') and (i == 0 or text[i - 1] != '\\')) {
                    if (!in_string) {
                        in_string = true;
                        string_char = ch;
                    } else if (ch == string_char) {
                        in_string = false;
                    }
                }
            }
            // Determine color based on syntax state
            var r = default_r;
            var g = default_g;
            var b = default_b;
            var a = default_a;
            if (in_string) {
                r = string_r;
                g = string_g;
                b = string_b;
                a = string_a;
            } else if (in_block_comment) {
                r = comment_r;
                g = comment_g;
                b = comment_b;
                a = comment_a;
            } else if (self.is_digit_start(ch)) {
                // Check if this is a number
                var j = i;
                var is_number = true;
                while (j < text.len and (self.is_digit(text[j]) or text[j] == '.' or text[j] == '_')) : (j += 1) {
                    if (text[j] == '.' and j + 1 < text.len and !self.is_digit(text[j + 1])) {
                        is_number = false;
                        break;
                    }
                }
                if (is_number and j > i) {
                    // Render number
                    const num_text = text[i..j];
                    self.draw_text(buffer, num_text, char_x, y, number_r, number_g, number_b, number_a);
                    char_x += @as(u32, @intCast(num_text.len)) * CHAR_WIDTH;
                    i = j - 1; // Will increment in loop
                    continue;
                }
            } else if (self.is_word_start(ch)) {
                // Check if this is a keyword
                var j = i;
                while (j < text.len and self.is_word_char(text[j])) : (j += 1) {}
                const word = text[i..j];
                if (self.is_keyword(word)) {
                    // Render keyword
                    self.draw_text(buffer, word, char_x, y, keyword_r, keyword_g, keyword_b, keyword_a);
                    char_x += @as(u32, @intCast(word.len)) * CHAR_WIDTH;
                    i = j - 1; // Will increment in loop
                    continue;
                }
            }
            // Render character with determined color
            if (self.draw_char(buffer, ch, char_x, y, r, g, b, a)) {
                char_x += CHAR_WIDTH;
            }
        }
    }

    /// Render visual mode selection.
    // 2025-12-02-142853-pst: Active function
    fn render_selection(self: *const EditorRenderer, buffer: []u8) void {
        const selection = self.editor.get_visual_selection();
        const sel_r = @as(u8, @truncate((COLOR_SELECTION >> 16) & 0xFF));
        const sel_g = @as(u8, @truncate((COLOR_SELECTION >> 8) & 0xFF));
        const sel_b = @as(u8, @truncate(COLOR_SELECTION & 0xFF));
        const sel_a = @as(u8, @truncate((COLOR_SELECTION >> 24) & 0xFF));
        // Render selection rectangle
        var line: u32 = selection.start_line;
        while (line <= selection.end_line and line < self.editor.buffer.lines_len) : (line += 1) {
            if (line < self.viewport_line or line >= self.viewport_line + self.get_visible_line_count()) {
                continue; // Line not visible
            }
            const line_text = self.editor.buffer.lines[line];
            const line_len = @as(u32, @intCast(line_text.len));
            const start_col = if (line == selection.start_line) selection.start_column else 0;
            const end_col = if (line == selection.end_line) selection.end_column else line_len;
            if (start_col < self.viewport_column + self.get_visible_column_count() and end_col >= self.viewport_column) {
                const vis_start = if (start_col > self.viewport_column) start_col - self.viewport_column else 0;
                const vis_end = @min(end_col - self.viewport_column, self.get_visible_column_count());
                const line_y = (line - self.viewport_line) * (CHAR_HEIGHT + LINE_SPACING);
                const line_num_width = self.get_line_number_column_width();
                const sel_x = line_num_width + vis_start * CHAR_WIDTH;
                const sel_w = (vis_end - vis_start) * CHAR_WIDTH;
                const sel_y = line_y;
                const sel_h = CHAR_HEIGHT;
                self.draw_rect(buffer, sel_x, sel_y, sel_w, sel_h, sel_r, sel_g, sel_b, sel_a / 2);
            }
        }
    }

    /// Render cursor.
    // 2025-12-02-142853-pst: Active function
    fn render_cursor(self: *const EditorRenderer, buffer: []u8) void {
        if (self.editor.cursor_line < self.viewport_line or
            self.editor.cursor_line >= self.viewport_line + self.get_visible_line_count())
        {
            return; // Cursor not visible
        }
        if (self.editor.cursor_column < self.viewport_column or
            self.editor.cursor_column >= self.viewport_column + self.get_visible_column_count())
        {
            return; // Cursor not visible
        }
        const cursor_r = @as(u8, @truncate((COLOR_CURSOR >> 16) & 0xFF));
        const cursor_g = @as(u8, @truncate((COLOR_CURSOR >> 8) & 0xFF));
        const cursor_b = @as(u8, @truncate(COLOR_CURSOR & 0xFF));
        const cursor_a = @as(u8, @truncate((COLOR_CURSOR >> 24) & 0xFF));
        const line_num_width = self.get_line_number_column_width();
        const cursor_x = line_num_width + (self.editor.cursor_column - self.viewport_column) * CHAR_WIDTH;
        const cursor_y = (self.editor.cursor_line - self.viewport_line) * (CHAR_HEIGHT + LINE_SPACING);
        // Draw vertical line cursor (1 pixel wide)
        self.draw_rect(buffer, cursor_x, cursor_y, 1, CHAR_HEIGHT, cursor_r, cursor_g, cursor_b, cursor_a);
    }

    /// Render status line (mode, line/column info).
    // 2025-12-02-142853-pst: Active function
    fn render_status_line(self: *const EditorRenderer, buffer: []u8) void {
        const status_y = self.buffer_height - CHAR_HEIGHT - LINE_SPACING;
        // Draw status line background
        const bg_r = @as(u8, @truncate((COLOR_STATUS_BG >> 16) & 0xFF));
        const bg_g = @as(u8, @truncate((COLOR_STATUS_BG >> 8) & 0xFF));
        const bg_b = @as(u8, @truncate(COLOR_STATUS_BG & 0xFF));
        const bg_a = @as(u8, @truncate((COLOR_STATUS_BG >> 24) & 0xFF));
        self.draw_rect(buffer, 0, status_y, self.buffer_width, CHAR_HEIGHT + LINE_SPACING, bg_r, bg_g, bg_b, bg_a);
        // Build status text
        var status_buf: [128]u8 = undefined;
        var status_len: u32 = 0;
        // Block title (if available)
        if (self.block_title.len > 0) {
            const title_len = @min(self.block_title.len, 32); // Limit title length
            @memcpy(status_buf[status_len..][0..title_len], self.block_title[0..title_len]);
            status_len += title_len;
            status_buf[status_len] = ' ';
            status_len += 1;
        }
        // Mode indicator
        const mode_str = switch (self.editor.mode) {
            .normal => "NORMAL",
            .insert => "INSERT",
            .visual => "VISUAL",
            .visual_line => "VISUAL LINE",
            .visual_block => "VISUAL BLOCK",
            .command => "COMMAND",
            .search => "SEARCH",
        };
        @memcpy(status_buf[status_len..][0..mode_str.len], mode_str);
        status_len += @as(u32, @intCast(mode_str.len));
        // Add separator
        status_buf[status_len] = ' ';
        status_len += 1;
        // Line/column info
        const line_str = "L:";
        @memcpy(status_buf[status_len..][0..line_str.len], line_str);
        status_len += @as(u32, @intCast(line_str.len));
        var num_buf: [16]u8 = undefined;
        const line_num_str = self.format_number(self.editor.cursor_line + 1, &num_buf);
        @memcpy(status_buf[status_len..][0..line_num_str.len], line_num_str);
        status_len += @as(u32, @intCast(line_num_str.len));
        status_buf[status_len] = ' ';
        status_len += 1;
        const col_str = "C:";
        @memcpy(status_buf[status_len..][0..col_str.len], col_str);
        status_len += @as(u32, @intCast(col_str.len));
        const col_num_str = self.format_number(self.editor.cursor_column + 1, &num_buf);
        @memcpy(status_buf[status_len..][0..col_num_str.len], col_num_str);
        status_len += @as(u32, @intCast(col_num_str.len));
        // Add modified indicator if content has unsaved changes
        if (self.modified) {
            status_buf[status_len] = ' ';
            status_len += 1;
            const mod_str = "[+]";
            @memcpy(status_buf[status_len..][0..mod_str.len], mod_str);
            status_len += @as(u32, @intCast(mod_str.len));
        }
        // Add error message if present (replaces normal status info)
        var use_error_color = false;
        if (self.error_message.len > 0) {
            status_buf[status_len] = ' ';
            status_len += 1;
            const err_prefix = "ERROR:";
            @memcpy(status_buf[status_len..][0..err_prefix.len], err_prefix);
            status_len += @as(u32, @intCast(err_prefix.len));
            status_buf[status_len] = ' ';
            status_len += 1;
            const err_len = @min(self.error_message.len, 64); // Limit error message length
            @memcpy(status_buf[status_len..][0..err_len], self.error_message[0..err_len]);
            status_len += @as(u32, @intCast(err_len));
            use_error_color = true;
        }
        // Render status text (use error color if error message present)
        const text_r = if (use_error_color)
            @as(u8, @truncate((COLOR_ERROR >> 16) & 0xFF))
        else
            @as(u8, @truncate((COLOR_TEXT >> 16) & 0xFF));
        const text_g = if (use_error_color)
            @as(u8, @truncate((COLOR_ERROR >> 8) & 0xFF))
        else
            @as(u8, @truncate((COLOR_TEXT >> 8) & 0xFF));
        const text_b = if (use_error_color)
            @as(u8, @truncate(COLOR_ERROR & 0xFF))
        else
            @as(u8, @truncate(COLOR_TEXT & 0xFF));
        const text_a = if (use_error_color)
            @as(u8, @truncate((COLOR_ERROR >> 24) & 0xFF))
        else
            @as(u8, @truncate((COLOR_TEXT >> 24) & 0xFF));
        self.draw_text(buffer, status_buf[0..status_len], 0, status_y, text_r, text_g, text_b, text_a);
    }

    /// Set command buffer for command mode display.
    // 2025-12-02-154746-pst: Active function
    pub fn set_command_buffer(self: *EditorRenderer, cmd_buf: []const u8) void {
        self.command_buffer = cmd_buf;
    }

    /// Set block title for status line display.
    // 2025-12-02-160032-pst: Active function
    pub fn set_block_title(self: *EditorRenderer, title: []const u8) void {
        self.block_title = title;
    }

    /// Set modified flag (content has unsaved changes).
    // 2025-12-02-164404-pst: Active function
    pub fn set_modified(self: *EditorRenderer, modified: bool) void {
        self.modified = modified;
    }

    /// Detect and set language from block title/filename and content.
    // 2025-12-03-141818-pst: Active function
    pub fn detect_language(self: *EditorRenderer, filename: []const u8, content: []const u8) void {
        self.detected_language = LanguageDetector.detect(filename, content);
    }

    /// Render bracket matching highlight (highlight matching bracket if cursor is on bracket).
    // 2025-12-03-162613-pst: Active function
    fn render_bracket_match(self: *const EditorRenderer, buffer: []u8) void {
        // Find matching bracket at cursor position
        const match = BracketMatcher.find_matching_bracket(
            self.editor,
            self.editor.cursor_line,
            self.editor.cursor_column,
        );
        
        if (!match.found) {
            return; // No matching bracket found
        }
        
        // Highlight matching bracket if visible
        if (match.line >= self.viewport_line and
            match.line < self.viewport_line + self.get_visible_line_count())
        {
            const line_text = self.editor.buffer.lines[match.line];
            if (match.column < line_text.len) {
                if (match.column >= self.viewport_column and
                    match.column < self.viewport_column + self.get_visible_column_count())
                {
                    // Match is visible, highlight it
                    const match_r = @as(u8, @truncate((COLOR_BRACKET_MATCH >> 16) & 0xFF));
                    const match_g = @as(u8, @truncate((COLOR_BRACKET_MATCH >> 8) & 0xFF));
                    const match_b = @as(u8, @truncate(COLOR_BRACKET_MATCH & 0xFF));
                    const match_a = @as(u8, @truncate((COLOR_BRACKET_MATCH >> 24) & 0xFF));
                    const line_num_width = self.get_line_number_column_width();
                    const match_x = line_num_width + (match.column - self.viewport_column) * CHAR_WIDTH;
                    const match_y = (match.line - self.viewport_line) * (CHAR_HEIGHT + LINE_SPACING);
                    // Draw highlight rectangle (full character width/height)
                    self.draw_rect(buffer, match_x, match_y, CHAR_WIDTH, CHAR_HEIGHT, match_r, match_g, match_b, match_a / 2);
                }
            }
        }
    }

    /// Set error message to display (with timeout in seconds).
    // 2025-12-02-171119-pst: Active function
    pub fn set_error(self: *EditorRenderer, message: []const u8, timeout_sec: u64) void {
        self.error_message = message;
        if (timeout_sec > 0) {
            const now = std.time.timestamp();
            const now_u64 = @as(u64, @intCast(now));
            self.error_message_timeout = now_u64 + timeout_sec;
        } else {
            self.error_message_timeout = 0; // No timeout
        }
    }

    /// Clear error message.
    // 2025-12-02-171119-pst: Active function
    pub fn clear_error(self: *EditorRenderer) void {
        self.error_message = "";
        self.error_message_timeout = 0;
    }

    /// Check and clear expired error messages.
    // 2025-12-02-171119-pst: Active function
    fn check_error_timeout(self: *EditorRenderer) void {
        if (self.error_message_timeout > 0) {
            const now = std.time.timestamp();
            const now_u64 = @as(u64, @intCast(now));
            if (now_u64 >= self.error_message_timeout) {
                self.clear_error();
            }
        }
    }

    /// Check if character is a word start character.
    // 2025-12-02-180222-pst: Active function
    fn is_word_start(self: *const EditorRenderer, ch: u8) bool {
        _ = self;
        return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or ch == '_';
    }

    /// Check if character is a word character.
    // 2025-12-02-180222-pst: Active function
    fn is_word_char(self: *const EditorRenderer, ch: u8) bool {
        _ = self;
        return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or (ch >= '0' and ch <= '9') or ch == '_';
    }

    /// Check if character is a digit start (digit or sign + digit).
    // 2025-12-02-180222-pst: Active function
    fn is_digit_start(self: *const EditorRenderer, ch: u8) bool {
        _ = self;
        return ch >= '0' and ch <= '9';
    }

    /// Check if character is a digit.
    // 2025-12-02-180222-pst: Active function
    fn is_digit(self: *const EditorRenderer, ch: u8) bool {
        _ = self;
        return ch >= '0' and ch <= '9';
    }

    /// Check if word is a keyword (language-aware).
    // 2025-12-03-141818-pst: Active function
    fn is_keyword(self: *const EditorRenderer, word: []const u8) bool {
        // Use language-specific keywords if language is detected
        if (self.detected_language != .unknown) {
            return LanguageKeywords.is_keyword(self.detected_language, word);
        }
        // Fall back to generic keywords (Zig-focused but language-agnostic)
        const keywords = [_][]const u8{ "if", "else", "while", "for", "fn", "var", "const", "return", "break", "continue", "pub", "priv", "struct", "enum", "union", "error", "try", "catch", "defer", "switch", "case", "default", "true", "false", "null", "undefined", "void", "bool", "u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64", "f32", "f64", "usize", "isize", "comptime", "inline", "noinline", "export", "extern", "packed", "align", "test", "async", "await", "suspend", "resume" };
        for (keywords) |keyword| {
            if (word.len == keyword.len and std.mem.eql(u8, word, keyword)) {
                return true;
            }
        }
        return false;
    }

    /// Enable or disable syntax highlighting.
    // 2025-12-02-180222-pst: Active function
    pub fn set_syntax_highlighting(self: *EditorRenderer, enabled: bool) void {
        self.syntax_highlighting_enabled = enabled;
    }

    /// Render command line (command mode input).
    // 2025-12-02-142853-pst: Active function
    fn render_command_line(self: *const EditorRenderer, buffer: []u8) void {
        // Command line is rendered in status line area
        const status_y = self.buffer_height - CHAR_HEIGHT - LINE_SPACING;
        const cmd_r = @as(u8, @truncate((COLOR_COMMAND_LINE >> 16) & 0xFF));
        const cmd_g = @as(u8, @truncate((COLOR_COMMAND_LINE >> 8) & 0xFF));
        const cmd_b = @as(u8, @truncate(COLOR_COMMAND_LINE & 0xFF));
        const cmd_a = @as(u8, @truncate((COLOR_COMMAND_LINE >> 24) & 0xFF));
        const cmd_prompt = ":";
        self.draw_text(buffer, cmd_prompt, 0, status_y, cmd_r, cmd_g, cmd_b, cmd_a);
        // Render command buffer if present
        if (self.command_buffer.len > 0) {
            self.draw_text(buffer, self.command_buffer, CHAR_WIDTH, status_y, cmd_r, cmd_g, cmd_b, cmd_a);
        }
    }

    /// Render search line (search mode input).
    // 2025-12-02-142853-pst: Active function
    fn render_search_line(self: *const EditorRenderer, buffer: []u8) void {
        // Search line is rendered in status line area
        const status_y = self.buffer_height - CHAR_HEIGHT - LINE_SPACING;
        const search_r = @as(u8, @truncate((COLOR_COMMAND_LINE >> 16) & 0xFF));
        const search_g = @as(u8, @truncate((COLOR_COMMAND_LINE >> 8) & 0xFF));
        const search_b = @as(u8, @truncate(COLOR_COMMAND_LINE & 0xFF));
        const search_a = @as(u8, @truncate((COLOR_COMMAND_LINE >> 24) & 0xFF));
        const search_prompt = if (self.editor.search_direction == .forward) "/" else "?";
        self.draw_text(buffer, search_prompt, 0, status_y, search_r, search_g, search_b, search_a);
        // Render search pattern
        const pattern = self.editor.get_search_pattern();
        if (pattern.len > 0) {
            self.draw_text(buffer, pattern, CHAR_WIDTH, status_y, search_r, search_g, search_b, search_a);
        }
    }

    /// Draw rectangle (filled).
    // 2025-12-02-142853-pst: Active function
    fn draw_rect(self: *const EditorRenderer, buffer: []u8, x: u32, y: u32, w: u32, h: u32, r: u8, g: u8, b: u8, a: u8) void {
        var py: u32 = 0;
        while (py < h) : (py += 1) {
            const draw_y = y + py;
            if (draw_y >= self.buffer_height) {
                break;
            }
            var px: u32 = 0;
            while (px < w) : (px += 1) {
                const draw_x = x + px;
                if (draw_x >= self.buffer_width) {
                    break;
                }
                const idx = (draw_y * self.buffer_width + draw_x) * 4;
                buffer[idx + 0] = r;
                buffer[idx + 1] = g;
                buffer[idx + 2] = b;
                buffer[idx + 3] = a;
            }
        }
    }

    /// Draw text string (using shared font renderer).
    // 2025-12-05-172208-pst: Active function (migrated to shared font renderer)
    fn draw_text(self: *const EditorRenderer, buffer: []u8, text: []const u8, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) void {
        std.debug.assert(x < self.buffer_width); // Precondition
        std.debug.assert(y < self.buffer_height); // Precondition
        
        const text_len = @min(text.len, MAX_CHARS_PER_LINE);
        var char_x = x;
        var i: u32 = 0;
        while (i < text_len) : (i += 1) {
            const ch = text[i];
            if (self.draw_char(buffer, ch, char_x, y, r, g, b, a)) {
                char_x += CHAR_WIDTH;
            }
        }
        
        std.debug.assert(char_x <= x + (text_len * CHAR_WIDTH)); // Postcondition
    }

    /// Draw single character (using shared font renderer).
    // 2025-12-05-172208-pst: Active function (migrated to shared font renderer)
    fn draw_char(self: *const EditorRenderer, buffer: []u8, ch: u8, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) bool {
        std.debug.assert(x < self.buffer_width); // Precondition
        std.debug.assert(y < self.buffer_height); // Precondition
        
        // Get background color from buffer at this position (or use default)
        const bg_r = @as(u8, @truncate((COLOR_BACKGROUND >> 16) & 0xFF));
        const bg_g = @as(u8, @truncate((COLOR_BACKGROUND >> 8) & 0xFF));
        const bg_b = @as(u8, @truncate(COLOR_BACKGROUND & 0xFF));
        const bg_a = @as(u8, @truncate((COLOR_BACKGROUND >> 24) & 0xFF));
        
        // Allocate temporary pixel buffer for character
        const char_w = self.font_renderer.get_char_width();
        const char_h = self.font_renderer.get_char_height();
        var char_pixels: [9 * 9 * 4]u8 = undefined; // Max 9x9 pixels
        const pixel_buf = char_pixels[0..(char_w * char_h * 4)];
        
        // Render character to pixel buffer
        if (!self.font_renderer.render_char_to_pixels(ch, r, g, b, a, bg_r, bg_g, bg_b, bg_a, pixel_buf)) {
            return false; // Character not supported
        }
        
        // Copy pixel buffer to main buffer
        var row: u32 = 0;
        while (row < char_h) : (row += 1) {
            const py = y + row;
            if (py >= self.buffer_height) {
                break;
            }
            var col: u32 = 0;
            while (col < char_w) : (col += 1) {
                const px = x + col;
                if (px >= self.buffer_width) {
                    break;
                }
                const src_idx = (row * char_w + col) * 4;
                const dst_idx = (py * self.buffer_width + px) * 4;
                buffer[dst_idx + 0] = pixel_buf[src_idx + 0];
                buffer[dst_idx + 1] = pixel_buf[src_idx + 1];
                buffer[dst_idx + 2] = pixel_buf[src_idx + 2];
                buffer[dst_idx + 3] = pixel_buf[src_idx + 3];
            }
        }
        
        return true;
    }

    /// Format number as string (helper).
    // 2025-12-02-142853-pst: Active function
    fn format_number(self: *const EditorRenderer, num: u32, buf: []u8) []const u8 {
        _ = self;
        if (num == 0) {
            if (buf.len > 0) {
                buf[0] = '0';
                return buf[0..1];
            }
            return "";
        }
        var n = num;
        var i: u32 = 0;
        const max_digits = @min(buf.len, 16);
        while (n > 0 and i < max_digits) : (i += 1) {
            buf[max_digits - 1 - i] = @as(u8, @intCast('0' + (n % 10)));
            n /= 10;
        }
        return buf[max_digits - i..max_digits];
    }
};

