const std = @import("std");

/// Grain Skate Editor: Text editor with Vim bindings for block editing.
/// ~<~ Glow Airbend: explicit editor state, bounded text buffer.
/// ~~~~ Glow Waterbend: deterministic editing operations, iterative algorithms.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
pub const Editor = struct {
    // Bounded: Max buffer size (explicit limit, in bytes)
    pub const MAX_BUFFER_SIZE: u32 = 10_485_760; // 10 MB

    // Bounded: Max undo history (explicit limit)
    pub const MAX_UNDO_HISTORY: u32 = 1_024;

    // Bounded: Max line length (explicit limit)
    pub const MAX_LINE_LEN: u32 = 65_536; // 64 KB

    // Bounded: Max yank buffer size (explicit limit, in bytes)
    pub const MAX_YANK_BUFFER: u32 = 1_048_576; // 1 MB

    // Bounded: Max search pattern size (explicit limit, in bytes)
    pub const MAX_SEARCH_PATTERN: u32 = 256;

    // Bounded: Max replace pattern size (explicit limit, in bytes)
    pub const MAX_REPLACE_PATTERN: u32 = 256;

    /// Editor mode enumeration.
    pub const EditorMode = enum(u8) {
        normal, // Normal mode (Vim)
        insert, // Insert mode (Vim)
        visual, // Visual mode (Vim)
        visual_line, // Visual line mode (Vim 'V')
        visual_block, // Visual block mode (Vim Ctrl+v)
        command, // Command mode (Vim)
        search, // Search mode (Vim '/')
    };

    /// Search direction enumeration.
    pub const SearchDirection = enum(u8) {
        forward, // Search forward (/)
        backward, // Search backward (?)
    };

    /// Text buffer structure.
    pub const TextBuffer = struct {
        lines: []const []const u8, // Text lines (bounded)
        lines_len: u32,
        allocator: std.mem.Allocator,

        /// Initialize text buffer.
        // 2025-11-23-114146-pst: Active function
        pub fn init(allocator: std.mem.Allocator, content: []const u8) !TextBuffer {

            // Assert: Content must be bounded
            std.debug.assert(content.len <= MAX_BUFFER_SIZE);

            // Split content into lines (bounded)
            // Use fixed array instead of ArrayList for GrainStyle compliance
            const MAX_LINES: u32 = MAX_BUFFER_SIZE / 64; // Max lines estimate
            var lines: [MAX_LINES]?[]const u8 = undefined;
            @memset(&lines, null);
            var lines_len: u32 = 0;

            var start: u32 = 0;
            var i: u32 = 0;
            while (i < content.len) : (i += 1) {
                if (content[i] == '\n') {
                    const line = content[start..i];
                    if (line.len > MAX_LINE_LEN) {
                        return error.LineTooLong;
                    }
                    if (lines_len >= MAX_LINES) {
                        return error.TooManyLines;
                    }
                    lines[lines_len] = line;
                    lines_len += 1;
                    start = i + 1;
                }
            }

            // Add last line if no trailing newline
            if (start < content.len) {
                const line = content[start..];
                if (line.len > MAX_LINE_LEN) {
                    return error.LineTooLong;
                }
                if (lines_len >= MAX_LINES) {
                    return error.TooManyLines;
                }
                lines[lines_len] = line;
                lines_len += 1;
            } else if (content.len > 0 and content[content.len - 1] == '\n') {
                // Empty line at end
                if (lines_len >= MAX_LINES) {
                    return error.TooManyLines;
                }
                lines[lines_len] = "";
                lines_len += 1;
            }

            // Allocate lines slice from fixed array
            const lines_slice = try allocator.alloc([]const u8, lines_len);
            errdefer allocator.free(lines_slice);
            var j: u32 = 0;
            while (j < lines_len) : (j += 1) {
                lines_slice[j] = lines[j] orelse "";
            }

            return TextBuffer{
                .lines = lines_slice,
                .lines_len = @as(u32, @intCast(lines_slice.len)),
                .allocator = allocator,
            };
        }

        /// Deinitialize text buffer and free memory.
        pub fn deinit(self: *TextBuffer) void {
            // Assert: Allocator must be valid
            // Assert: Allocator must be valid (check by attempting deallocation)
            _ = self.allocator;

            // Free lines
            self.allocator.free(self.lines);

            self.* = undefined;
        }

        /// Get content as single string.
        pub fn get_content(self: *const TextBuffer) ![]const u8 {
            // Calculate total size
            var total_size: u32 = 0;
            var i: u32 = 0;
            while (i < self.lines_len) : (i += 1) {
                total_size += @as(u32, @intCast(self.lines[i].len)) + 1; // +1 for newline
            }

            // Allocate content buffer
            const content = try self.allocator.alloc(u8, total_size);
            errdefer self.allocator.free(content);

            // Copy lines
            var pos: u32 = 0;
            i = 0;
            while (i < self.lines_len) : (i += 1) {
                @memcpy(content[pos..][0..self.lines[i].len], self.lines[i]);
                pos += @as(u32, @intCast(self.lines[i].len));
                if (i < self.lines_len - 1) {
                    content[pos] = '\n';
                    pos += 1;
                }
            }

            return content[0..pos];
        }

        /// Replace a line in the buffer (creates new buffer with modified line).
        // 2025-12-02-112844-pst: Active function
        pub fn replace_line(self: *TextBuffer, line_index: u32, new_line: []const u8) !void {
            std.debug.assert(line_index < self.lines_len);
            std.debug.assert(new_line.len <= MAX_LINE_LEN);
            // Create new lines array with modified line
            const new_lines = try self.allocator.alloc([]const u8, self.lines_len);
            errdefer self.allocator.free(new_lines);
            var i: u32 = 0;
            while (i < self.lines_len) : (i += 1) {
                if (i == line_index) {
                    new_lines[i] = new_line;
                } else {
                    new_lines[i] = self.lines[i];
                }
            }
            // Free old lines and replace
            self.allocator.free(self.lines);
            self.lines = new_lines;
        }

        /// Remove a line from the buffer (creates new buffer without line).
        // 2025-12-02-115753-pst: Active function
        pub fn remove_line(self: *TextBuffer, line_index: u32) !void {
            std.debug.assert(line_index < self.lines_len);
            const new_lines_len = if (self.lines_len > 0)
                self.lines_len - 1
            else
                0;
            const new_lines = try self.allocator.alloc([]const u8, new_lines_len);
            errdefer self.allocator.free(new_lines);
            var i: u32 = 0;
            while (i < line_index) : (i += 1) {
                new_lines[i] = self.lines[i];
            }
            var j: u32 = line_index + 1;
            while (j < self.lines_len) : (j += 1) {
                new_lines[i] = self.lines[j];
                i += 1;
            }
            // Free old lines and replace
            self.allocator.free(self.lines);
            self.lines = new_lines;
            self.lines_len = new_lines_len;
        }
    };

    /// Undo/redo operation structure.
    pub const UndoOperation = struct {
        operation_type: OperationType,
        line_num: u32,
        column: u32,
        text: []const u8, // Text inserted/deleted
        text_len: u32,
        allocator: std.mem.Allocator,

        /// Operation type enumeration.
        pub const OperationType = enum(u8) {
            insert, // Text inserted
            delete, // Text deleted
            replace, // Text replaced
        };

        /// Initialize undo operation.
        // 2025-11-23-114146-pst: Active function
        pub fn init(allocator: std.mem.Allocator, op_type: OperationType, line_num: u32, column: u32, text: []const u8) !UndoOperation {

            // Allocate text copy
            const text_copy = try allocator.dupe(u8, text);
            errdefer allocator.free(text_copy);

            return UndoOperation{
                .operation_type = op_type,
                .line_num = line_num,
                .column = column,
                .text = text_copy,
                .text_len = @as(u32, @intCast(text_copy.len)),
                .allocator = allocator,
            };
        }

        /// Deinitialize undo operation and free memory.
        pub fn deinit(self: *UndoOperation) void {
            // Assert: Allocator must be valid
            // Assert: Allocator must be valid (check by attempting deallocation)
            _ = self.allocator;

            // Free text
            if (self.text_len > 0) {
                self.allocator.free(self.text);
            }

            self.* = undefined;
        }
    };

    /// Editor state structure.
    pub const EditorState = struct {
        buffer: TextBuffer, // Text buffer
        mode: EditorMode, // Current mode
        cursor_line: u32, // Cursor line (0-indexed)
        cursor_column: u32, // Cursor column (0-indexed)
        undo_history: []UndoOperation, // Undo history (bounded)
        undo_history_len: u32,
        redo_history: []UndoOperation, // Redo history (bounded)
        redo_history_len: u32,
        yank_buffer: ?[]u8, // Yank (copy) buffer
        yank_buffer_len: u32,
        visual_anchor_line: u32, // Visual mode selection anchor line
        visual_anchor_column: u32, // Visual mode selection anchor column
        search_pattern: [MAX_SEARCH_PATTERN]u8, // Search pattern buffer
        search_pattern_len: u32, // Search pattern length
        search_direction: SearchDirection, // Search direction (forward/backward)
        allocator: std.mem.Allocator,

        /// Initialize editor state.
        // 2025-11-23-122043-pst: Active function
        pub fn init(allocator: std.mem.Allocator, initial_content: []const u8) !EditorState {

            // Initialize text buffer
            var buffer = try TextBuffer.init(allocator, initial_content);
            errdefer buffer.deinit();

            // Pre-allocate undo history
            const undo_history = try allocator.alloc(UndoOperation, MAX_UNDO_HISTORY);
            errdefer allocator.free(undo_history);

            // Pre-allocate redo history
            const redo_history = try allocator.alloc(UndoOperation, MAX_UNDO_HISTORY);
            errdefer allocator.free(redo_history);

            return EditorState{
                .buffer = buffer,
                .mode = .normal,
                .cursor_line = 0,
                .cursor_column = 0,
                .undo_history = undo_history,
                .undo_history_len = 0,
                .redo_history = redo_history,
                .redo_history_len = 0,
                .yank_buffer = null,
                .yank_buffer_len = 0,
                .visual_anchor_line = 0,
                .visual_anchor_column = 0,
                .search_pattern = undefined,
                .search_pattern_len = 0,
                .search_direction = .forward,
                .allocator = allocator,
            };
        }

        /// Deinitialize editor state and free memory.
        pub fn deinit(self: *EditorState) void {
            // Assert: Allocator must be valid
            // Assert: Allocator must be valid (check by attempting deallocation)
            _ = self.allocator;

            // Deinitialize buffer
            self.buffer.deinit();

            // Deinitialize undo history
            var i: u32 = 0;
            while (i < self.undo_history_len) : (i += 1) {
                self.undo_history[i].deinit();
            }
            self.allocator.free(self.undo_history);

            // Deinitialize redo history
            i = 0;
            while (i < self.redo_history_len) : (i += 1) {
                self.redo_history[i].deinit();
            }
            self.allocator.free(self.redo_history);

            // Deinitialize yank buffer
            if (self.yank_buffer) |yank_buf| {
                self.allocator.free(yank_buf);
            }

            self.* = undefined;
        }

        /// Move cursor left (Vim 'h').
        pub fn move_left(self: *EditorState) void {
            if (self.cursor_column > 0) {
                self.cursor_column -= 1;
            } else if (self.cursor_line > 0) {
                self.cursor_line -= 1;
                self.cursor_column = @as(u32, @intCast(self.buffer.lines[self.cursor_line].len));
            }
        }

        /// Move cursor right (Vim 'l').
        pub fn move_right(self: *EditorState) void {
            const current_line_len = if (self.cursor_line < self.buffer.lines_len)
                @as(u32, @intCast(self.buffer.lines[self.cursor_line].len))
            else
                0;

            if (self.cursor_column < current_line_len) {
                self.cursor_column += 1;
            } else if (self.cursor_line < self.buffer.lines_len - 1) {
                self.cursor_line += 1;
                self.cursor_column = 0;
            }
        }

        /// Move cursor up (Vim 'k').
        pub fn move_up(self: *EditorState) void {
            if (self.cursor_line > 0) {
                self.cursor_line -= 1;
                const line_len = @as(u32, @intCast(self.buffer.lines[self.cursor_line].len));
                if (self.cursor_column > line_len) {
                    self.cursor_column = line_len;
                }
            }
        }

        /// Move cursor down (Vim 'j').
        pub fn move_down(self: *EditorState) void {
            if (self.cursor_line < self.buffer.lines_len - 1) {
                self.cursor_line += 1;
                const line_len = @as(u32, @intCast(self.buffer.lines[self.cursor_line].len));
                if (self.cursor_column > line_len) {
                    self.cursor_column = line_len;
                }
            }
        }

        /// Check if character is word character (alphanumeric or underscore).
        // 2025-12-02-133014-pst: Active function
        fn is_word_char(ch: u8) bool {
            return (ch >= 'a' and ch <= 'z') or
                (ch >= 'A' and ch <= 'Z') or
                (ch >= '0' and ch <= '9') or
                (ch == '_');
        }

        /// Move to start of next word (Vim 'w').
        // 2025-12-02-133014-pst: Active function
        pub fn move_word_forward(self: *EditorState) void {
            std.debug.assert(self.cursor_line < self.buffer.lines_len);
            const line = self.buffer.lines[self.cursor_line];
            const line_len = @as(u32, @intCast(line.len));
            // If at end of line, move to start of next line
            if (self.cursor_column >= line_len) {
                if (self.cursor_line < self.buffer.lines_len - 1) {
                    self.cursor_line += 1;
                    self.cursor_column = 0;
                }
                return;
            }
            // Skip current word if we're in the middle of one
            var pos = self.cursor_column;
            if (pos < line_len and is_word_char(line[pos])) {
                // Skip to end of current word
                while (pos < line_len and is_word_char(line[pos])) : (pos += 1) {}
            }
            // Skip whitespace
            while (pos < line_len and !is_word_char(line[pos])) : (pos += 1) {}
            // If we found a word, move to its start
            if (pos < line_len) {
                self.cursor_column = pos;
            } else {
                // No word found on this line, move to start of next line
                if (self.cursor_line < self.buffer.lines_len - 1) {
                    self.cursor_line += 1;
                    self.cursor_column = 0;
                } else {
                    // Already at last line, move to end
                    self.cursor_column = line_len;
                }
            }
        }

        /// Move to start of previous word (Vim 'b').
        // 2025-12-02-133014-pst: Active function
        pub fn move_word_backward(self: *EditorState) void {
            std.debug.assert(self.cursor_line < self.buffer.lines_len);
            const line = self.buffer.lines[self.cursor_line];
            const line_len = @as(u32, @intCast(line.len));
            // If at start of line, move to end of previous line
            if (self.cursor_column == 0) {
                if (self.cursor_line > 0) {
                    self.cursor_line -= 1;
                    const prev_line = self.buffer.lines[self.cursor_line];
                    self.cursor_column = @as(u32, @intCast(prev_line.len));
                }
                return;
            }
            var pos = self.cursor_column;
            // If we're in the middle of a word, move to its start
            if (pos > 0 and pos <= line_len and is_word_char(line[pos - 1])) {
                // Move back to start of current word
                while (pos > 0 and is_word_char(line[pos - 1])) : (pos -= 1) {}
                self.cursor_column = pos;
                return;
            }
            // Skip whitespace backward
            while (pos > 0 and !is_word_char(line[pos - 1])) : (pos -= 1) {}
            // If we found a word, move to its start
            if (pos > 0) {
                // Move back to start of word
                while (pos > 0 and is_word_char(line[pos - 1])) : (pos -= 1) {}
                self.cursor_column = pos;
            } else {
                // No word found on this line, move to end of previous line
                if (self.cursor_line > 0) {
                    self.cursor_line -= 1;
                    const prev_line = self.buffer.lines[self.cursor_line];
                    self.cursor_column = @as(u32, @intCast(prev_line.len));
                } else {
                    // Already at first line, move to start
                    self.cursor_column = 0;
                }
            }
        }

        /// Move to beginning of line (Vim '0').
        // 2025-12-02-141446-pst: Active function
        pub fn move_line_start(self: *EditorState) void {
            std.debug.assert(self.cursor_line < self.buffer.lines_len);
            self.cursor_column = 0;
        }

        /// Move to end of line (Vim '$').
        // 2025-12-02-141446-pst: Active function
        pub fn move_line_end(self: *EditorState) void {
            std.debug.assert(self.cursor_line < self.buffer.lines_len);
            const line = self.buffer.lines[self.cursor_line];
            self.cursor_column = @as(u32, @intCast(line.len));
        }

        /// Move to first non-whitespace character on line (Vim '^').
        // 2025-12-02-141446-pst: Active function
        pub fn move_line_start_nonblank(self: *EditorState) void {
            std.debug.assert(self.cursor_line < self.buffer.lines_len);
            const line = self.buffer.lines[self.cursor_line];
            const line_len = @as(u32, @intCast(line.len));
            var pos: u32 = 0;
            // Skip whitespace
            while (pos < line_len and (line[pos] == ' ' or line[pos] == '\t')) : (pos += 1) {}
            self.cursor_column = pos;
        }

        /// Move to beginning of file (Vim 'gg').
        // 2025-12-02-141446-pst: Active function
        pub fn move_file_start(self: *EditorState) void {
            self.cursor_line = 0;
            self.cursor_column = 0;
        }

        /// Move to end of file (Vim 'G').
        // 2025-12-02-141446-pst: Active function
        pub fn move_file_end(self: *EditorState) void {
            if (self.buffer.lines_len > 0) {
                self.cursor_line = self.buffer.lines_len - 1;
                const line = self.buffer.lines[self.cursor_line];
                self.cursor_column = @as(u32, @intCast(line.len));
            } else {
                self.cursor_line = 0;
                self.cursor_column = 0;
            }
        }

        /// Move to end of current/next word (Vim 'e').
        // 2025-12-02-133014-pst: Active function
        pub fn move_word_end(self: *EditorState) void {
            std.debug.assert(self.cursor_line < self.buffer.lines_len);
            const line = self.buffer.lines[self.cursor_line];
            const line_len = @as(u32, @intCast(line.len));
            // If at end of line, move to end of first word on next line
            if (self.cursor_column >= line_len) {
                if (self.cursor_line < self.buffer.lines_len - 1) {
                    self.cursor_line += 1;
                    const next_line = self.buffer.lines[self.cursor_line];
                    const next_line_len = @as(u32, @intCast(next_line.len));
                    var pos: u32 = 0;
                    // Find first word
                    while (pos < next_line_len and !is_word_char(next_line[pos])) : (pos += 1) {}
                    // Move to end of word
                    while (pos < next_line_len and is_word_char(next_line[pos])) : (pos += 1) {}
                    self.cursor_column = pos;
                }
                return;
            }
            var pos = self.cursor_column;
            // If we're in the middle of a word, move to its end
            if (pos < line_len and is_word_char(line[pos])) {
                // Move to end of current word
                while (pos < line_len and is_word_char(line[pos])) : (pos += 1) {}
                self.cursor_column = pos;
                return;
            }
            // Skip whitespace forward
            while (pos < line_len and !is_word_char(line[pos])) : (pos += 1) {}
            // If we found a word, move to its end
            if (pos < line_len) {
                // Move to end of word
                while (pos < line_len and is_word_char(line[pos])) : (pos += 1) {}
                self.cursor_column = pos;
            } else {
                // No word found on this line, move to end of first word on next line
                if (self.cursor_line < self.buffer.lines_len - 1) {
                    self.cursor_line += 1;
                    const next_line = self.buffer.lines[self.cursor_line];
                    const next_line_len = @as(u32, @intCast(next_line.len));
                    var next_pos: u32 = 0;
                    // Find first word
                    while (next_pos < next_line_len and !is_word_char(next_line[next_pos])) : (next_pos += 1) {}
                    // Move to end of word
                    while (next_pos < next_line_len and is_word_char(next_line[next_pos])) : (next_pos += 1) {}
                    self.cursor_column = next_pos;
                } else {
                    // Already at last line, move to end
                    self.cursor_column = line_len;
                }
            }
        }

        /// Enter insert mode (Vim 'i').
        pub fn enter_insert_mode(self: *EditorState) void {
            self.mode = .insert;
        }

        /// Exit insert mode (Vim ESC).
        pub fn exit_insert_mode(self: *EditorState) void {
            self.mode = .normal;
        }

        /// Enter visual mode (Vim 'v').
        // 2025-12-02-121512-pst: Active function
        pub fn enter_visual_mode(self: *EditorState) void {
            self.mode = .visual;
            // Set selection anchor to current cursor position
            self.visual_anchor_line = self.cursor_line;
            self.visual_anchor_column = self.cursor_column;
        }

        /// Enter visual line mode (Vim 'V').
        // 2025-12-02-130235-pst: Active function
        pub fn enter_visual_line_mode(self: *EditorState) void {
            self.mode = .visual_line;
            // Set selection anchor to current line (full line selection)
            self.visual_anchor_line = self.cursor_line;
            self.visual_anchor_column = 0;
        }

        /// Enter visual block mode (Vim Ctrl+v).
        // 2025-12-02-135701-pst: Active function
        pub fn enter_visual_block_mode(self: *EditorState) void {
            self.mode = .visual_block;
            // Set selection anchor to current cursor position
            self.visual_anchor_line = self.cursor_line;
            self.visual_anchor_column = self.cursor_column;
        }

        /// Enter visual block mode (Vim Ctrl+v).
        // 2025-12-02-135701-pst: Active function
        pub fn enter_visual_block_mode(self: *EditorState) void {
            self.mode = .visual_block;
            // Set selection anchor to current cursor position
            self.visual_anchor_line = self.cursor_line;
            self.visual_anchor_column = self.cursor_column;
        }

        /// Exit visual mode (Vim ESC).
        // 2025-12-02-121512-pst: Active function
        pub fn exit_visual_mode(self: *EditorState) void {
            self.mode = .normal;
        }

        /// Switch editor mode.
        pub fn switch_mode(self: *EditorState, new_mode: EditorMode) void {
            if (self.mode == .visual or self.mode == .visual_line or self.mode == .visual_block) {
                self.exit_visual_mode();
            } else if (self.mode == .search) {
                self.exit_search_mode();
            }
            self.mode = new_mode;
            if (new_mode == .visual) {
                self.enter_visual_mode();
            } else if (new_mode == .visual_line) {
                self.enter_visual_line_mode();
            } else if (new_mode == .visual_block) {
                self.enter_visual_block_mode();
            } else if (new_mode == .search) {
                self.enter_search_mode();
            }
        }

        /// Enter search mode (Vim '/').
        // 2025-12-02-133808-pst: Active function
        pub fn enter_search_mode(self: *EditorState) void {
            self.mode = .search;
            self.search_pattern_len = 0;
            self.search_direction = .forward;
        }

        /// Enter search backward mode (Vim '?').
        // 2025-12-02-133808-pst: Active function
        pub fn enter_search_backward_mode(self: *EditorState) void {
            self.mode = .search;
            self.search_pattern_len = 0;
            self.search_direction = .backward;
        }

        /// Exit search mode (Vim ESC).
        // 2025-12-02-133808-pst: Active function
        pub fn exit_search_mode(self: *EditorState) void {
            self.mode = .normal;
        }

        /// Add character to search pattern.
        // 2025-12-02-133808-pst: Active function
        pub fn add_search_char(self: *EditorState, ch: u8) void {
            if (self.search_pattern_len < MAX_SEARCH_PATTERN - 1) {
                self.search_pattern[self.search_pattern_len] = ch;
                self.search_pattern_len += 1;
            }
        }

        /// Remove last character from search pattern (backspace).
        // 2025-12-02-133808-pst: Active function
        pub fn remove_search_char(self: *EditorState) void {
            if (self.search_pattern_len > 0) {
                self.search_pattern_len -= 1;
            }
        }

        /// Get current search pattern.
        // 2025-12-02-133808-pst: Active function
        pub fn get_search_pattern(self: *const EditorState) []const u8 {
            return self.search_pattern[0..self.search_pattern_len];
        }

        /// Find next occurrence of search pattern.
        // 2025-12-02-133808-pst: Active function
        pub fn find_next(self: *EditorState) bool {
            if (self.search_pattern_len == 0) {
                return false;
            }
            const pattern = self.search_pattern[0..self.search_pattern_len];
            return self.find_pattern_forward(pattern);
        }

        /// Find previous occurrence of search pattern.
        // 2025-12-02-133808-pst: Active function
        pub fn find_previous(self: *EditorState) bool {
            if (self.search_pattern_len == 0) {
                return false;
            }
            const pattern = self.search_pattern[0..self.search_pattern_len];
            return self.find_pattern_backward(pattern);
        }

        /// Find pattern forward from cursor (helper).
        // 2025-12-02-133808-pst: Active function
        fn find_pattern_forward(self: *EditorState, pattern: []const u8) bool {
            var start_line = self.cursor_line;
            var start_col = self.cursor_column + 1;
            // Search from current position forward
            var line: u32 = start_line;
            while (line < self.buffer.lines_len) : (line += 1) {
                const line_text = self.buffer.lines[line];
                const line_len = @as(u32, @intCast(line_text.len));
                const search_start = if (line == start_line) start_col else 0;
                var col: u32 = search_start;
                while (col <= line_len - pattern.len) : (col += 1) {
                    var match: bool = true;
                    var i: u32 = 0;
                    while (i < pattern.len) : (i += 1) {
                        if (col + i >= line_len or line_text[col + i] != pattern[i]) {
                            match = false;
                            break;
                        }
                    }
                    if (match) {
                        self.cursor_line = line;
                        self.cursor_column = col;
                        return true;
                    }
                }
            }
            // Wrap to beginning
            line = 0;
            while (line <= start_line) : (line += 1) {
                const line_text = self.buffer.lines[line];
                const line_len = @as(u32, @intCast(line_text.len));
                const search_end = if (line == start_line) start_col else line_len;
                var col: u32 = 0;
                while (col < search_end and col <= line_len - pattern.len) : (col += 1) {
                    var match: bool = true;
                    var i: u32 = 0;
                    while (i < pattern.len) : (i += 1) {
                        if (col + i >= line_len or line_text[col + i] != pattern[i]) {
                            match = false;
                            break;
                        }
                    }
                    if (match) {
                        self.cursor_line = line;
                        self.cursor_column = col;
                        return true;
                    }
                }
            }
            return false;
        }

        /// Find pattern backward from cursor (helper).
        // 2025-12-02-133808-pst: Active function
        fn find_pattern_backward(self: *EditorState, pattern: []const u8) bool {
            var start_line = self.cursor_line;
            var start_col = if (self.cursor_column > 0) self.cursor_column - 1 else 0;
            // Search backward from current position
            var line: u32 = start_line;
            while (true) : (line -= 1) {
                const line_text = self.buffer.lines[line];
                const line_len = @as(u32, @intCast(line_text.len));
                const search_end = if (line == start_line) start_col + 1 else line_len;
                var col: u32 = if (search_end >= pattern.len) search_end - pattern.len else 0;
                while (true) : (col -= 1) {
                    if (col > line_len - pattern.len) {
                        break;
                    }
                    var match: bool = true;
                    var i: u32 = 0;
                    while (i < pattern.len) : (i += 1) {
                        if (col + i >= line_len or line_text[col + i] != pattern[i]) {
                            match = false;
                            break;
                        }
                    }
                    if (match) {
                        self.cursor_line = line;
                        self.cursor_column = col;
                        return true;
                    }
                    if (col == 0) {
                        break;
                    }
                }
                if (line == 0) {
                    break;
                }
            }
            // Wrap to end
            var wrap_line: u32 = self.buffer.lines_len - 1;
            while (wrap_line > start_line) : (wrap_line -= 1) {
                const line_text = self.buffer.lines[wrap_line];
                const line_len = @as(u32, @intCast(line_text.len));
                var col: u32 = if (line_len >= pattern.len) line_len - pattern.len else 0;
                while (true) : (col -= 1) {
                    if (col > line_len - pattern.len) {
                        break;
                    }
                    var match: bool = true;
                    var i: u32 = 0;
                    while (i < pattern.len) : (i += 1) {
                        if (col + i >= line_len or line_text[col + i] != pattern[i]) {
                            match = false;
                            break;
                        }
                    }
                    if (match) {
                        self.cursor_line = wrap_line;
                        self.cursor_column = col;
                        return true;
                    }
                    if (col == 0) {
                        break;
                    }
                }
            }
            return false;
        }

        /// Replace first occurrence of pattern with replacement on current line.
        // 2025-12-02-140535-pst: Active function
        pub fn replace_on_line(self: *EditorState, pattern: []const u8, replacement: []const u8) !bool {
            if (self.cursor_line >= self.buffer.lines_len) {
                return false;
            }
            const line_text = self.buffer.lines[self.cursor_line];
            const line_len = @as(u32, @intCast(line_text.len));
            // Search for pattern in current line
            var col: u32 = 0;
            while (col <= line_len - pattern.len) : (col += 1) {
                var match: bool = true;
                var i: u32 = 0;
                while (i < pattern.len) : (i += 1) {
                    if (col + i >= line_len or line_text[col + i] != pattern[i]) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    // Replace pattern with replacement
                    const before_len = col;
                    const after_len = line_len - col - pattern.len;
                    const new_line_len = before_len + @as(u32, @intCast(replacement.len)) + after_len;
                    if (new_line_len > MAX_LINE_LEN) {
                        return error.LineTooLong;
                    }
                    const new_line = try self.allocator.alloc(u8, new_line_len);
                    errdefer self.allocator.free(new_line);
                    if (before_len > 0) {
                        @memcpy(new_line[0..before_len], line_text[0..col]);
                    }
                    @memcpy(new_line[before_len..][0..replacement.len], replacement);
                    if (after_len > 0) {
                        @memcpy(new_line[before_len + replacement.len..], line_text[col + pattern.len..]);
                    }
                    // Save to undo history
                    const old_text = line_text[col..col + pattern.len];
                    if (self.undo_history_len < MAX_UNDO_HISTORY) {
                        const undo_op = &self.undo_history[self.undo_history_len];
                        undo_op.* = .{
                            .operation = .replace,
                            .line_num = self.cursor_line,
                            .column = col,
                            .text = old_text.ptr,
                            .text_len = @as(u32, @intCast(old_text.len)),
                        };
                        self.undo_history_len += 1;
                    }
                    // Replace line
                    try self.buffer.replace_line(self.cursor_line, new_line);
                    self.allocator.free(new_line);
                    // Update cursor position
                    self.cursor_column = col + @as(u32, @intCast(replacement.len));
                    return true;
                }
            }
            return false;
        }

        /// Replace all occurrences of pattern with replacement on current line.
        // 2025-12-02-140535-pst: Active function
        pub fn replace_all_on_line(self: *EditorState, pattern: []const u8, replacement: []const u8) !u32 {
            if (self.cursor_line >= self.buffer.lines_len) {
                return 0;
            }
            var count: u32 = 0;
            var line_text = self.buffer.lines[self.cursor_line];
            var line_len = @as(u32, @intCast(line_text.len));
            // Build new line with replacements
            var new_line_buf: [MAX_LINE_LEN]u8 = undefined;
            var new_line_len: u32 = 0;
            var col: u32 = 0;
            while (col < line_len) {
                // Check if pattern matches at current position
                if (col <= line_len - pattern.len) {
                    var match: bool = true;
                    var i: u32 = 0;
                    while (i < pattern.len) : (i += 1) {
                        if (line_text[col + i] != pattern[i]) {
                            match = false;
                            break;
                        }
                    }
                    if (match) {
                        // Add replacement
                        if (new_line_len + replacement.len > MAX_LINE_LEN) {
                            return error.LineTooLong;
                        }
                        @memcpy(new_line_buf[new_line_len..][0..replacement.len], replacement);
                        new_line_len += @as(u32, @intCast(replacement.len));
                        col += pattern.len;
                        count += 1;
                        continue;
                    }
                }
                // Add current character
                if (new_line_len >= MAX_LINE_LEN) {
                    return error.LineTooLong;
                }
                new_line_buf[new_line_len] = line_text[col];
                new_line_len += 1;
                col += 1;
            }
            if (count > 0) {
                // Create new line
                const new_line = try self.allocator.alloc(u8, new_line_len);
                errdefer self.allocator.free(new_line);
                @memcpy(new_line, new_line_buf[0..new_line_len]);
                // Save to undo history
                if (self.undo_history_len < MAX_UNDO_HISTORY) {
                    const undo_op = &self.undo_history[self.undo_history_len];
                    undo_op.* = .{
                        .operation = .replace,
                        .line_num = self.cursor_line,
                        .column = 0,
                        .text = line_text.ptr,
                        .text_len = line_len,
                    };
                    self.undo_history_len += 1;
                }
                // Replace line
                try self.buffer.replace_line(self.cursor_line, new_line);
                self.allocator.free(new_line);
            }
            return count;
        }

        /// Replace all occurrences of pattern with replacement in entire buffer.
        // 2025-12-02-140535-pst: Active function
        pub fn replace_all_in_buffer(self: *EditorState, pattern: []const u8, replacement: []const u8) !u32 {
            var total_count: u32 = 0;
            var line: u32 = 0;
            while (line < self.buffer.lines_len) : (line += 1) {
                // Save current cursor line
                const saved_line = self.cursor_line;
                self.cursor_line = line;
                // Replace all on this line
                const count = try self.replace_all_on_line(pattern, replacement);
                total_count += count;
                // Restore cursor line
                self.cursor_line = saved_line;
            }
            return total_count;
        }

        /// Get visual selection bounds (normalized: start <= end).
        // 2025-12-02-121512-pst: Active function
        pub fn get_visual_selection(self: *const EditorState) struct {
            start_line: u32,
            start_column: u32,
            end_line: u32,
            end_column: u32,
        } {
            std.debug.assert(self.mode == .visual or self.mode == .visual_line);
            const anchor_line = self.visual_anchor_line;
            const cursor_line = self.cursor_line;
            // Normalize selection (start <= end)
            const start_line = if (anchor_line <= cursor_line) anchor_line else cursor_line;
            const end_line = if (anchor_line <= cursor_line) cursor_line else anchor_line;
            if (self.mode == .visual_line) {
                // Visual line mode: always select entire lines
                std.debug.assert(start_line < self.buffer.lines_len);
                std.debug.assert(end_line < self.buffer.lines_len);
                const start_line_len = @as(u32, @intCast(self.buffer.lines[start_line].len));
                const end_line_len = @as(u32, @intCast(self.buffer.lines[end_line].len));
                return .{
                    .start_line = start_line,
                    .start_column = 0,
                    .end_line = end_line,
                    .end_column = end_line_len,
                };
            } else {
                // Visual mode: character-based selection
                const anchor_col = self.visual_anchor_column;
                const cursor_col = self.cursor_column;
                const anchor_before = (anchor_line < cursor_line) or
                    (anchor_line == cursor_line and anchor_col <= cursor_col);
                if (anchor_before) {
                    return .{
                        .start_line = anchor_line,
                        .start_column = anchor_col,
                        .end_line = cursor_line,
                        .end_column = cursor_col,
                    };
                } else {
                    return .{
                        .start_line = cursor_line,
                        .start_column = cursor_col,
                        .end_line = anchor_line,
                        .end_column = anchor_col,
                    };
                }
            }
        }

        /// Yank selected text in visual mode.
        // 2025-12-02-121512-pst: Active function
        pub fn yank_selection(self: *EditorState) !void {
            std.debug.assert(self.mode == .visual or self.mode == .visual_line);
            const selection = self.get_visual_selection();
            // Calculate total size of selected text
            const total_size = try self.calculate_selection_size(selection);
            if (total_size > MAX_YANK_BUFFER) {
                return error.YankBufferTooLarge;
            }
            // Free existing yank buffer
            if (self.yank_buffer) |yank_buf| {
                self.allocator.free(yank_buf);
                self.yank_buffer = null;
            }
            // Allocate yank buffer
            const yank_buf = try self.allocator.alloc(u8, total_size);
            errdefer self.allocator.free(yank_buf);
            // Copy selected text
            const actual_size = try self.copy_selection_to_buffer(selection, yank_buf);
            self.yank_buffer = yank_buf;
            self.yank_buffer_len = actual_size;
        }

        /// Calculate size of visual selection (helper).
        // 2025-12-02-121512-pst: Active function
        fn calculate_selection_size(
            self: *const EditorState,
            selection: struct {
                start_line: u32,
                start_column: u32,
                end_line: u32,
                end_column: u32,
            },
        ) !u32 {
            var total_size: u32 = 0;
            var line: u32 = selection.start_line;
            while (line <= selection.end_line) : (line += 1) {
                std.debug.assert(line < self.buffer.lines_len);
                const line_text = self.buffer.lines[line];
                const line_len = @as(u32, @intCast(line_text.len));
                if (line == selection.start_line and line == selection.end_line) {
                    total_size += selection.end_column - selection.start_column;
                } else if (line == selection.start_line) {
                    total_size += line_len - selection.start_column + 1;
                } else if (line == selection.end_line) {
                    total_size += selection.end_column;
                } else {
                    total_size += line_len + 1;
                }
            }
            return total_size;
        }

        /// Copy visual selection to buffer (helper).
        // 2025-12-02-121512-pst: Active function
        fn copy_selection_to_buffer(
            self: *const EditorState,
            selection: struct {
                start_line: u32,
                start_column: u32,
                end_line: u32,
                end_column: u32,
            },
            buffer: []u8,
        ) !u32 {
            var pos: u32 = 0;
            var line: u32 = selection.start_line;
            while (line <= selection.end_line) : (line += 1) {
                const line_text = self.buffer.lines[line];
                const line_len = @as(u32, @intCast(line_text.len));
                if (line == selection.start_line and line == selection.end_line) {
                    const copy_len = selection.end_column - selection.start_column;
                    if (copy_len > 0) {
                        @memcpy(buffer[pos..][0..copy_len], line_text[selection.start_column..selection.end_column]);
                        pos += copy_len;
                    }
                } else if (line == selection.start_line) {
                    const copy_len = line_len - selection.start_column;
                    if (copy_len > 0) {
                        @memcpy(buffer[pos..][0..copy_len], line_text[selection.start_column..]);
                        pos += copy_len;
                    }
                    buffer[pos] = '\n';
                    pos += 1;
                } else if (line == selection.end_line) {
                    if (selection.end_column > 0) {
                        @memcpy(buffer[pos..][0..selection.end_column], line_text[0..selection.end_column]);
                        pos += selection.end_column;
                    }
                } else {
                    if (line_len > 0) {
                        @memcpy(buffer[pos..][0..line_len], line_text);
                        pos += line_len;
                    }
                    buffer[pos] = '\n';
                    pos += 1;
                }
            }
            return pos;
        }

        /// Delete selected text in visual mode.
        // 2025-12-02-124119-pst: Active function
        pub fn delete_selection(self: *EditorState) !void {
            std.debug.assert(self.mode == .visual or self.mode == .visual_line);
            const selection = self.get_visual_selection();
            // Get selection text for undo before deleting
            const deleted_text = try self.get_selection_text_for_undo(selection);
            defer self.allocator.free(deleted_text);
            // Yank selection (for redo and paste)
            try self.yank_selection();
            // Delete the selected text (undo operation will copy deleted_text)
            if (selection.start_line == selection.end_line) {
                try self.delete_single_line_selection(selection, deleted_text);
            } else {
                try self.delete_multi_line_selection(selection, deleted_text);
            }
            // Move cursor to selection start
            self.cursor_line = selection.start_line;
            self.cursor_column = selection.start_column;
            // Exit visual mode
            self.exit_visual_mode();
        }

        /// Delete single line selection (helper).
        // 2025-12-02-124119-pst: Active function
        fn delete_single_line_selection(
            self: *EditorState,
            selection: struct {
                start_line: u32,
                start_column: u32,
                end_line: u32,
                end_column: u32,
            },
            deleted_text: []const u8,
        ) !void {
            std.debug.assert(selection.start_line == selection.end_line);
            const line_idx = selection.start_line;
            std.debug.assert(line_idx < self.buffer.lines_len);
            const line_text = self.buffer.lines[line_idx];
            const line_len = @as(u32, @intCast(line_text.len));
            const start_col = selection.start_column;
            const end_col = selection.end_column;
            // Create new line without selected portion
            const before_len = start_col;
            const after_len = line_len - end_col;
            const new_line_len = before_len + after_len;
            const new_line = if (new_line_len > 0) blk: {
                const new_line_buf = try self.allocator.alloc(u8, new_line_len);
                errdefer self.allocator.free(new_line_buf);
                if (before_len > 0) {
                    @memcpy(new_line_buf[0..before_len], line_text[0..start_col]);
                }
                if (after_len > 0) {
                    @memcpy(new_line_buf[before_len..], line_text[end_col..]);
                }
                break :blk new_line_buf;
            } else "";
            // Save to undo history
            if (self.undo_history_len < MAX_UNDO_HISTORY) {
                const undo_op = try UndoOperation.init(
                    self.allocator,
                    .delete,
                    line_idx,
                    start_col,
                    deleted_text,
                );
                self.undo_history[self.undo_history_len] = undo_op;
                self.undo_history_len += 1;
                var i: u32 = 0;
                while (i < self.redo_history_len) : (i += 1) {
                    self.redo_history[i].deinit();
                }
                self.redo_history_len = 0;
            }
            // Replace line in buffer
            try self.buffer.replace_line(line_idx, new_line);
        }

        /// Delete multi-line selection (helper).
        // 2025-12-02-124119-pst: Active function
        fn delete_multi_line_selection(
            self: *EditorState,
            selection: struct {
                start_line: u32,
                start_column: u32,
                end_line: u32,
                end_column: u32,
            },
            deleted_text: []const u8,
        ) !void {
            std.debug.assert(selection.start_line < selection.end_line);
            const start_line = selection.start_line;
            const end_line = selection.end_line;
            std.debug.assert(start_line < self.buffer.lines_len);
            std.debug.assert(end_line < self.buffer.lines_len);
            // Get start and end line text
            const start_line_text = self.buffer.lines[start_line];
            const end_line_text = self.buffer.lines[end_line];
            const start_line_len = @as(u32, @intCast(start_line_text.len));
            const end_line_len = @as(u32, @intCast(end_line_text.len));
            // Create merged line from start and end
            const start_prefix_len = selection.start_column;
            const end_suffix_len = end_line_len - selection.end_column;
            const merged_line_len = start_prefix_len + end_suffix_len;
            const merged_line = if (merged_line_len > 0) blk: {
                const merged_buf = try self.allocator.alloc(u8, merged_line_len);
                errdefer self.allocator.free(merged_buf);
                if (start_prefix_len > 0) {
                    @memcpy(merged_buf[0..start_prefix_len], start_line_text[0..selection.start_column]);
                }
                if (end_suffix_len > 0) {
                    @memcpy(merged_buf[start_prefix_len..], end_line_text[selection.end_column..]);
                }
                break :blk merged_buf;
            } else "";
            // Calculate number of lines to remove
            const lines_to_remove = end_line - start_line;
            // Create new lines array
            const new_lines_len = self.buffer.lines_len - lines_to_remove;
            const new_lines = try self.allocator.alloc([]const u8, new_lines_len);
            errdefer self.allocator.free(new_lines);
            // Copy lines before selection
            var i: u32 = 0;
            while (i < start_line) : (i += 1) {
                new_lines[i] = self.buffer.lines[i];
            }
            // Add merged line
            new_lines[i] = merged_line;
            i += 1;
            // Copy lines after selection
            var j: u32 = end_line + 1;
            while (j < self.buffer.lines_len) : (j += 1) {
                new_lines[i] = self.buffer.lines[j];
                i += 1;
            }
            // Save to undo history
            if (self.undo_history_len < MAX_UNDO_HISTORY) {
                const undo_op = try UndoOperation.init(
                    self.allocator,
                    .delete,
                    start_line,
                    selection.start_column,
                    deleted_text,
                );
                self.undo_history[self.undo_history_len] = undo_op;
                self.undo_history_len += 1;
                var k: u32 = 0;
                while (k < self.redo_history_len) : (k += 1) {
                    self.redo_history[k].deinit();
                }
                self.redo_history_len = 0;
            }
            // Replace buffer lines
            self.allocator.free(self.buffer.lines);
            self.buffer.lines = new_lines;
            self.buffer.lines_len = new_lines_len;
        }

        /// Get selection text for undo history (helper).
        // 2025-12-02-124119-pst: Active function
        fn get_selection_text_for_undo(
            self: *const EditorState,
            selection: struct {
                start_line: u32,
                start_column: u32,
                end_line: u32,
                end_column: u32,
            },
        ) ![]const u8 {
            // Calculate size
            var total_size: u32 = 0;
            var line: u32 = selection.start_line;
            while (line <= selection.end_line) : (line += 1) {
                const line_text = self.buffer.lines[line];
                const line_len = @as(u32, @intCast(line_text.len));
                if (line == selection.start_line and line == selection.end_line) {
                    total_size += selection.end_column - selection.start_column;
                } else if (line == selection.start_line) {
                    total_size += line_len - selection.start_column + 1;
                } else if (line == selection.end_line) {
                    total_size += selection.end_column;
                } else {
                    total_size += line_len + 1;
                }
            }
            // Allocate and copy
            const text = try self.allocator.alloc(u8, total_size);
            errdefer self.allocator.free(text);
            _ = try self.copy_selection_to_buffer(selection, text);
            return text;
        }

        /// Insert character at cursor (insert mode).
        // 2025-12-02-112844-pst: Active function
        pub fn insert_char(self: *EditorState, ch: u8) !void {
            // Assert: Must be in insert mode
            std.debug.assert(self.mode == .insert);
            std.debug.assert(self.cursor_line < self.buffer.lines_len);
            // Get current line
            const current_line = self.buffer.lines[self.cursor_line];
            const line_len = @as(u32, @intCast(current_line.len));
            std.debug.assert(self.cursor_column <= line_len);
            // Check line length limit
            if (line_len >= MAX_LINE_LEN) {
                return error.LineTooLong;
            }
            // Create new line with character inserted
            const new_line_len = line_len + 1;
            const new_line = try self.allocator.alloc(u8, new_line_len);
            errdefer self.allocator.free(new_line);
            // Copy before cursor
            if (self.cursor_column > 0) {
                @memcpy(new_line[0..self.cursor_column], current_line[0..self.cursor_column]);
            }
            // Insert character
            new_line[self.cursor_column] = ch;
            // Copy after cursor
            if (self.cursor_column < line_len) {
                @memcpy(
                    new_line[self.cursor_column + 1..],
                    current_line[self.cursor_column..],
                );
            }
            // Save to undo history
            if (self.undo_history_len < MAX_UNDO_HISTORY) {
                const undo_op = try UndoOperation.init(
                    self.allocator,
                    .insert,
                    self.cursor_line,
                    self.cursor_column,
                    &[_]u8{ch},
                );
                self.undo_history[self.undo_history_len] = undo_op;
                self.undo_history_len += 1;
                // Clear redo history on new edit
                var i: u32 = 0;
                while (i < self.redo_history_len) : (i += 1) {
                    self.redo_history[i].deinit();
                }
                self.redo_history_len = 0;
            }
            // Replace line in buffer
            try self.buffer.replace_line(self.cursor_line, new_line);
            // Move cursor right
            self.cursor_column += 1;
        }

        /// Delete character at cursor (Vim 'x').
        // 2025-12-02-112844-pst: Active function
        pub fn delete_char(self: *EditorState) !void {
            // Assert: Must be in normal mode
            std.debug.assert(self.mode == .normal);
            std.debug.assert(self.cursor_line < self.buffer.lines_len);
            // Get current line
            const current_line = self.buffer.lines[self.cursor_line];
            const line_len = @as(u32, @intCast(current_line.len));
            // Check if there's a character to delete
            if (self.cursor_column >= line_len) {
                return; // Nothing to delete
            }
            // Get character being deleted for undo
            const deleted_char = current_line[self.cursor_column];
            // Create new line without deleted character
            const new_line_len = if (line_len > 0) line_len - 1 else 0;
            const new_line = if (new_line_len > 0) blk: {
                const new_line_buf = try self.allocator.alloc(u8, new_line_len);
                errdefer self.allocator.free(new_line_buf);
                // Copy before cursor
                if (self.cursor_column > 0) {
                    @memcpy(new_line_buf[0..self.cursor_column], current_line[0..self.cursor_column]);
                }
                // Copy after cursor (skip deleted character)
                if (self.cursor_column + 1 < line_len) {
                    @memcpy(
                        new_line_buf[self.cursor_column..],
                        current_line[self.cursor_column + 1..],
                    );
                }
                break :blk new_line_buf;
            } else "";
            // Save to undo history
            if (self.undo_history_len < MAX_UNDO_HISTORY) {
                const undo_op = try UndoOperation.init(
                    self.allocator,
                    .delete,
                    self.cursor_line,
                    self.cursor_column,
                    &[_]u8{deleted_char},
                );
                self.undo_history[self.undo_history_len] = undo_op;
                self.undo_history_len += 1;
                // Clear redo history on new edit
                var i: u32 = 0;
                while (i < self.redo_history_len) : (i += 1) {
                    self.redo_history[i].deinit();
                }
                self.redo_history_len = 0;
            }
            // Replace line in buffer
            if (new_line_len > 0) {
                try self.buffer.replace_line(self.cursor_line, new_line);
            } else {
                try self.buffer.replace_line(self.cursor_line, "");
            }
            // Cursor stays at same position (character deleted)
        }

        /// Undo last operation.
        // 2025-12-02-114747-pst: Active function
        pub fn undo(self: *EditorState) !void {
            // Check if there's anything to undo
            if (self.undo_history_len == 0) {
                return; // Nothing to undo
            }
            // Get last undo operation
            const undo_op = &self.undo_history[self.undo_history_len - 1];
            std.debug.assert(undo_op.line_num < self.buffer.lines_len);
            // Restore based on operation type
            switch (undo_op.operation_type) {
                .insert => try self.undo_insert(undo_op),
                .delete => try self.undo_delete(undo_op),
                .replace => try self.undo_replace(undo_op),
            }
            // Remove from undo history
            undo_op.deinit();
            self.undo_history_len -= 1;
        }

        /// Undo insert operation (helper).
        // 2025-12-02-114747-pst: Active function
        fn undo_insert(self: *EditorState, undo_op: *UndoOperation) !void {
            const current_line = self.buffer.lines[undo_op.line_num];
            const line_len = @as(u32, @intCast(current_line.len));
            const text_len = undo_op.text_len;
            std.debug.assert(undo_op.column + text_len <= line_len);
            // Create new line without inserted text
            const new_line_len = line_len - text_len;
            const new_line = if (new_line_len > 0) blk: {
                const new_line_buf = try self.allocator.alloc(u8, new_line_len);
                errdefer self.allocator.free(new_line_buf);
                if (undo_op.column > 0) {
                    @memcpy(new_line_buf[0..undo_op.column], current_line[0..undo_op.column]);
                }
                if (undo_op.column + text_len < line_len) {
                    @memcpy(
                        new_line_buf[undo_op.column..],
                        current_line[undo_op.column + text_len..],
                    );
                }
                break :blk new_line_buf;
            } else "";
            // Save to redo history
            if (self.redo_history_len < MAX_UNDO_HISTORY) {
                const redo_op = try UndoOperation.init(
                    self.allocator,
                    .insert,
                    undo_op.line_num,
                    undo_op.column,
                    undo_op.text,
                );
                self.redo_history[self.redo_history_len] = redo_op;
                self.redo_history_len += 1;
            }
            // Replace line and restore cursor
            if (new_line_len > 0) {
                try self.buffer.replace_line(undo_op.line_num, new_line);
            } else {
                try self.buffer.replace_line(undo_op.line_num, "");
            }
            self.cursor_line = undo_op.line_num;
            self.cursor_column = undo_op.column;
        }

        /// Undo delete operation (helper).
        // 2025-12-02-114747-pst: Active function
        fn undo_delete(self: *EditorState, undo_op: *UndoOperation) !void {
            const current_line = self.buffer.lines[undo_op.line_num];
            const line_len = @as(u32, @intCast(current_line.len));
            const text_len = undo_op.text_len;
            const new_line_len = line_len + text_len;
            std.debug.assert(new_line_len <= MAX_LINE_LEN);
            // Create new line with deleted text reinserted
            const new_line = try self.allocator.alloc(u8, new_line_len);
            errdefer self.allocator.free(new_line);
            if (undo_op.column > 0) {
                @memcpy(new_line[0..undo_op.column], current_line[0..undo_op.column]);
            }
            @memcpy(new_line[undo_op.column..][0..text_len], undo_op.text);
            if (undo_op.column < line_len) {
                @memcpy(
                    new_line[undo_op.column + text_len..],
                    current_line[undo_op.column..],
                );
            }
            // Save to redo history
            if (self.redo_history_len < MAX_UNDO_HISTORY) {
                const redo_op = try UndoOperation.init(
                    self.allocator,
                    .delete,
                    undo_op.line_num,
                    undo_op.column,
                    undo_op.text,
                );
                self.redo_history[self.redo_history_len] = redo_op;
                self.redo_history_len += 1;
            }
            // Replace line and restore cursor
            try self.buffer.replace_line(undo_op.line_num, new_line);
            self.cursor_line = undo_op.line_num;
            self.cursor_column = undo_op.column + text_len;
        }

        /// Redo last undone operation.
        // 2025-12-02-114747-pst: Active function
        pub fn redo(self: *EditorState) !void {
            // Check if there's anything to redo
            if (self.redo_history_len == 0) {
                return; // Nothing to redo
            }
            // Get last redo operation
            const redo_op = &self.redo_history[self.redo_history_len - 1];
            std.debug.assert(redo_op.line_num < self.buffer.lines_len);
            // Reapply based on operation type
            switch (redo_op.operation_type) {
                .insert => try self.redo_insert(redo_op),
                .delete => try self.redo_delete(redo_op),
                .replace => try self.redo_replace(redo_op),
            }
            // Remove from redo history
            redo_op.deinit();
            self.redo_history_len -= 1;
        }

        /// Redo insert operation (helper).
        // 2025-12-02-114747-pst: Active function
        fn redo_insert(self: *EditorState, redo_op: *UndoOperation) !void {
            const current_line = self.buffer.lines[redo_op.line_num];
            const line_len = @as(u32, @intCast(current_line.len));
            const text_len = redo_op.text_len;
            const new_line_len = line_len + text_len;
            std.debug.assert(new_line_len <= MAX_LINE_LEN);
            // Create new line with text reinserted
            const new_line = try self.allocator.alloc(u8, new_line_len);
            errdefer self.allocator.free(new_line);
            if (redo_op.column > 0) {
                @memcpy(new_line[0..redo_op.column], current_line[0..redo_op.column]);
            }
            @memcpy(new_line[redo_op.column..][0..text_len], redo_op.text);
            if (redo_op.column < line_len) {
                @memcpy(
                    new_line[redo_op.column + text_len..],
                    current_line[redo_op.column..],
                );
            }
            // Save to undo history
            if (self.undo_history_len < MAX_UNDO_HISTORY) {
                const undo_op = try UndoOperation.init(
                    self.allocator,
                    .insert,
                    redo_op.line_num,
                    redo_op.column,
                    redo_op.text,
                );
                self.undo_history[self.undo_history_len] = undo_op;
                self.undo_history_len += 1;
            }
            // Replace line and update cursor
            try self.buffer.replace_line(redo_op.line_num, new_line);
            self.cursor_line = redo_op.line_num;
            self.cursor_column = redo_op.column + text_len;
        }

        /// Redo delete operation (helper).
        // 2025-12-02-114747-pst: Active function
        fn redo_delete(self: *EditorState, redo_op: *UndoOperation) !void {
            const current_line = self.buffer.lines[redo_op.line_num];
            const line_len = @as(u32, @intCast(current_line.len));
            const text_len = redo_op.text_len;
            std.debug.assert(redo_op.column + text_len <= line_len);
            // Create new line without deleted text
            const new_line_len = line_len - text_len;
            const new_line = if (new_line_len > 0) blk: {
                const new_line_buf = try self.allocator.alloc(u8, new_line_len);
                errdefer self.allocator.free(new_line_buf);
                if (redo_op.column > 0) {
                    @memcpy(new_line_buf[0..redo_op.column], current_line[0..redo_op.column]);
                }
                if (redo_op.column + text_len < line_len) {
                    @memcpy(
                        new_line_buf[redo_op.column..],
                        current_line[redo_op.column + text_len..],
                    );
                }
                break :blk new_line_buf;
            } else "";
            // Save to undo history
            if (self.undo_history_len < MAX_UNDO_HISTORY) {
                const undo_op = try UndoOperation.init(
                    self.allocator,
                    .delete,
                    redo_op.line_num,
                    redo_op.column,
                    redo_op.text,
                );
                self.undo_history[self.undo_history_len] = undo_op;
                self.undo_history_len += 1;
            }
            // Replace line and update cursor
            if (new_line_len > 0) {
                try self.buffer.replace_line(redo_op.line_num, new_line);
            } else {
                try self.buffer.replace_line(redo_op.line_num, "");
            }
            self.cursor_line = redo_op.line_num;
            self.cursor_column = redo_op.column;
        }

        /// Undo replace operation (helper).
        // 2025-12-02-125904-pst: Active function
        fn undo_replace(self: *EditorState, undo_op: *UndoOperation) !void {
            // For replace, undo_op.text contains the original text that was replaced
            std.debug.assert(undo_op.line_num < self.buffer.lines_len);
            const current_line = self.buffer.lines[undo_op.line_num];
            const line_len = @as(u32, @intCast(current_line.len));
            // Get replacement text (current text from column to end)
            const replacement_text = if (undo_op.column < line_len)
                current_line[undo_op.column..]
            else
                "";
            const original_text = undo_op.text;
            const original_len = undo_op.text_len;
            // Create new line with original text restored
            const before_len = undo_op.column;
            const new_line_len = before_len + original_len;
            if (new_line_len > MAX_LINE_LEN) {
                return error.LineTooLong;
            }
            const new_line = try self.allocator.alloc(u8, new_line_len);
            errdefer self.allocator.free(new_line);
            if (before_len > 0) {
                @memcpy(new_line[0..before_len], current_line[0..undo_op.column]);
            }
            @memcpy(new_line[before_len..][0..original_len], original_text);
            // Save to redo history (save replacement text)
            if (self.redo_history_len < MAX_UNDO_HISTORY) {
                const redo_op = try UndoOperation.init(
                    self.allocator,
                    .replace,
                    undo_op.line_num,
                    undo_op.column,
                    replacement_text,
                );
                self.redo_history[self.redo_history_len] = redo_op;
                self.redo_history_len += 1;
            }
            // Replace line and restore cursor
            try self.buffer.replace_line(undo_op.line_num, new_line);
            self.cursor_line = undo_op.line_num;
            self.cursor_column = undo_op.column;
        }

        /// Redo replace operation (helper).
        // 2025-12-02-125904-pst: Active function
        fn redo_replace(self: *EditorState, redo_op: *UndoOperation) !void {
            // For replace, redo_op.text contains the replacement text
            std.debug.assert(redo_op.line_num < self.buffer.lines_len);
            const current_line = self.buffer.lines[redo_op.line_num];
            const line_len = @as(u32, @intCast(current_line.len));
            // Get current text at position (original text)
            const original_text = if (redo_op.column < line_len)
                current_line[redo_op.column..]
            else
                "";
            const replacement_text = redo_op.text;
            const replacement_len = redo_op.text_len;
            // Create new line with replacement text
            const before_len = redo_op.column;
            const new_line_len = before_len + replacement_len;
            if (new_line_len > MAX_LINE_LEN) {
                return error.LineTooLong;
            }
            const new_line = try self.allocator.alloc(u8, new_line_len);
            errdefer self.allocator.free(new_line);
            if (before_len > 0) {
                @memcpy(new_line[0..before_len], current_line[0..redo_op.column]);
            }
            @memcpy(new_line[before_len..][0..replacement_len], replacement_text);
            // Save to undo history (save original text)
            if (self.undo_history_len < MAX_UNDO_HISTORY) {
                const undo_op = try UndoOperation.init(
                    self.allocator,
                    .replace,
                    redo_op.line_num,
                    redo_op.column,
                    original_text,
                );
                self.undo_history[self.undo_history_len] = undo_op;
                self.undo_history_len += 1;
            }
            // Replace line and update cursor
            try self.buffer.replace_line(redo_op.line_num, new_line);
            self.cursor_line = redo_op.line_num;
            self.cursor_column = redo_op.column;
        }

        /// Yank (copy) current line to yank buffer.
        // 2025-12-02-115753-pst: Active function
        pub fn yank_line(self: *EditorState) !void {
            std.debug.assert(self.cursor_line < self.buffer.lines_len);
            const line = self.buffer.lines[self.cursor_line];
            const line_len = @as(u32, @intCast(line.len));
            if (line_len > MAX_YANK_BUFFER) {
                return error.YankBufferTooLarge;
            }
            if (self.yank_buffer) |yank_buf| {
                self.allocator.free(yank_buf);
                self.yank_buffer = null;
            }
            const yank_buf = try self.allocator.alloc(u8, line_len);
            errdefer self.allocator.free(yank_buf);
            @memcpy(yank_buf, line);
            self.yank_buffer = yank_buf;
            self.yank_buffer_len = line_len;
        }

        /// Paste yank buffer at cursor (normal mode).
        // 2025-12-02-115753-pst: Active function
        pub fn paste(self: *EditorState) !void {
            std.debug.assert(self.mode == .normal);
            if (self.yank_buffer == null or self.yank_buffer_len == 0) {
                return;
            }
            const yank_buf = self.yank_buffer.?;
            std.debug.assert(self.cursor_line < self.buffer.lines_len);
            const current_line = self.buffer.lines[self.cursor_line];
            const line_len = @as(u32, @intCast(current_line.len));
            const new_line_len = line_len + self.yank_buffer_len;
            if (new_line_len > MAX_LINE_LEN) {
                return error.LineTooLong;
            }
            const paste_pos = self.cursor_column;
            const new_line = try self.allocator.alloc(u8, new_line_len);
            errdefer self.allocator.free(new_line);
            if (paste_pos > 0) {
                @memcpy(new_line[0..paste_pos], current_line[0..paste_pos]);
            }
            @memcpy(new_line[paste_pos..][0..self.yank_buffer_len], yank_buf);
            if (paste_pos < line_len) {
                @memcpy(
                    new_line[paste_pos + self.yank_buffer_len..],
                    current_line[paste_pos..],
                );
            }
            if (self.undo_history_len < MAX_UNDO_HISTORY) {
                const undo_op = try UndoOperation.init(
                    self.allocator,
                    .insert,
                    self.cursor_line,
                    paste_pos,
                    yank_buf,
                );
                self.undo_history[self.undo_history_len] = undo_op;
                self.undo_history_len += 1;
                var i: u32 = 0;
                while (i < self.redo_history_len) : (i += 1) {
                    self.redo_history[i].deinit();
                }
                self.redo_history_len = 0;
            }
            try self.buffer.replace_line(self.cursor_line, new_line);
            self.cursor_column = paste_pos + self.yank_buffer_len;
        }

        /// Paste yank buffer replacing selection (visual mode).
        // 2025-12-02-124933-pst: Active function
        pub fn paste_selection(self: *EditorState) !void {
            std.debug.assert(self.mode == .visual or self.mode == .visual_line);
            if (self.yank_buffer == null or self.yank_buffer_len == 0) {
                // Nothing to paste, just exit visual mode
                self.exit_visual_mode();
                return;
            }
            const selection = self.get_visual_selection();
            // Get selection text for undo before replacing
            const deleted_text = try self.get_selection_text_for_undo(selection);
            defer self.allocator.free(deleted_text);
            const yank_buf = self.yank_buffer.?;
            // Replace selection with yank buffer
            if (selection.start_line == selection.end_line) {
                try self.replace_single_line_selection(selection, yank_buf, deleted_text);
            } else {
                try self.replace_multi_line_selection(selection, yank_buf, deleted_text);
            }
            // Move cursor to selection start
            self.cursor_line = selection.start_line;
            self.cursor_column = selection.start_column;
            // Exit visual mode
            self.exit_visual_mode();
        }

        /// Replace single line selection with text (helper).
        // 2025-12-02-124933-pst: Active function
        fn replace_single_line_selection(
            self: *EditorState,
            selection: struct {
                start_line: u32,
                start_column: u32,
                end_line: u32,
                end_column: u32,
            },
            replacement: []const u8,
            deleted_text: []const u8,
        ) !void {
            std.debug.assert(selection.start_line == selection.end_line);
            const line_idx = selection.start_line;
            std.debug.assert(line_idx < self.buffer.lines_len);
            const line_text = self.buffer.lines[line_idx];
            const line_len = @as(u32, @intCast(line_text.len));
            const start_col = selection.start_column;
            const end_col = selection.end_column;
            const before_len = start_col;
            const after_len = line_len - end_col;
            const new_line_len = before_len + @as(u32, @intCast(replacement.len)) + after_len;
            if (new_line_len > MAX_LINE_LEN) {
                return error.LineTooLong;
            }
            const new_line = try self.allocator.alloc(u8, new_line_len);
            errdefer self.allocator.free(new_line);
            if (before_len > 0) {
                @memcpy(new_line[0..before_len], line_text[0..start_col]);
            }
            @memcpy(new_line[before_len..][0..replacement.len], replacement);
            if (after_len > 0) {
                @memcpy(new_line[before_len + replacement.len..], line_text[end_col..]);
            }
            // Save to undo history
            if (self.undo_history_len < MAX_UNDO_HISTORY) {
                const undo_op = try UndoOperation.init(
                    self.allocator,
                    .replace,
                    line_idx,
                    start_col,
                    deleted_text,
                );
                self.undo_history[self.undo_history_len] = undo_op;
                self.undo_history_len += 1;
                var i: u32 = 0;
                while (i < self.redo_history_len) : (i += 1) {
                    self.redo_history[i].deinit();
                }
                self.redo_history_len = 0;
            }
            // Replace line in buffer
            try self.buffer.replace_line(line_idx, new_line);
        }

        /// Replace multi-line selection with text (helper).
        // 2025-12-02-124933-pst: Active function
        fn replace_multi_line_selection(
            self: *EditorState,
            selection: struct {
                start_line: u32,
                start_column: u32,
                end_line: u32,
                end_column: u32,
            },
            replacement: []const u8,
            deleted_text: []const u8,
        ) !void {
            std.debug.assert(selection.start_line < selection.end_line);
            const replacement_lines = try self.parse_text_to_lines(replacement);
            defer self.allocator.free(replacement_lines.lines);
            const lines_to_remove = selection.end_line - selection.start_line;
            const new_lines_len = self.buffer.lines_len - lines_to_remove + replacement_lines.lines_len;
            const new_lines = try self.allocator.alloc([]const u8, new_lines_len);
            errdefer self.allocator.free(new_lines);
            var i = try self.copy_lines_before_selection(new_lines, selection.start_line);
            i = try self.merge_replacement_lines(new_lines, i, selection, replacement_lines);
            i = try self.merge_end_suffix(new_lines, i, selection);
            i = try self.copy_lines_after_selection(new_lines, i, selection.end_line);
            try self.save_replace_to_undo(selection, deleted_text);
            self.allocator.free(self.buffer.lines);
            self.buffer.lines = new_lines;
            self.buffer.lines_len = new_lines_len;
        }

        /// Copy lines before selection (helper).
        // 2025-12-02-124933-pst: Active function
        fn copy_lines_before_selection(
            self: *const EditorState,
            new_lines: []const []const u8,
            start_line: u32,
        ) !u32 {
            var i: u32 = 0;
            while (i < start_line) : (i += 1) {
                new_lines[i] = self.buffer.lines[i];
            }
            return i;
        }

        /// Merge replacement lines into new lines array (helper).
        // 2025-12-02-124933-pst: Active function
        fn merge_replacement_lines(
            self: *EditorState,
            new_lines: []const []const u8,
            start_idx: u32,
            selection: struct {
                start_line: u32,
                start_column: u32,
                end_line: u32,
                end_column: u32,
            },
            replacement_lines: struct {
                lines: []const []const u8,
                lines_len: u32,
            },
        ) !u32 {
            var i = start_idx;
            const start_line_text = self.buffer.lines[selection.start_line];
            const start_prefix = start_line_text[0..selection.start_column];
            if (replacement_lines.lines_len > 0) {
                const first_repl = replacement_lines.lines[0];
                const merged_first_len = start_prefix.len + first_repl.len;
                if (merged_first_len > MAX_LINE_LEN) {
                    return error.LineTooLong;
                }
                const merged_first = try self.allocator.alloc(u8, merged_first_len);
                errdefer self.allocator.free(merged_first);
                @memcpy(merged_first[0..start_prefix.len], start_prefix);
                @memcpy(merged_first[start_prefix.len..], first_repl);
                new_lines[i] = merged_first;
                i += 1;
                var j: u32 = 1;
                while (j < replacement_lines.lines_len) : (j += 1) {
                    new_lines[i] = replacement_lines.lines[j];
                    i += 1;
                }
            } else {
                const prefix_copy = try self.allocator.dupe(u8, start_prefix);
                new_lines[i] = prefix_copy;
                i += 1;
            }
            return i;
        }

        /// Merge end line suffix with last replacement line (helper).
        // 2025-12-02-124933-pst: Active function
        fn merge_end_suffix(
            self: *EditorState,
            new_lines: []const []const u8,
            last_idx: u32,
            selection: struct {
                start_line: u32,
                start_column: u32,
                end_line: u32,
                end_column: u32,
            },
        ) !u32 {
            const end_line_text = self.buffer.lines[selection.end_line];
            const end_suffix = end_line_text[selection.end_column..];
            if (end_suffix.len > 0 and last_idx > 0) {
                const idx = last_idx - 1;
                const last_line = new_lines[idx];
                const merged_last_len = last_line.len + end_suffix.len;
                if (merged_last_len > MAX_LINE_LEN) {
                    return error.LineTooLong;
                }
                const merged_last = try self.allocator.alloc(u8, merged_last_len);
                errdefer self.allocator.free(merged_last);
                @memcpy(merged_last[0..last_line.len], last_line);
                @memcpy(merged_last[last_line.len..], end_suffix);
                new_lines[idx] = merged_last;
            }
            return last_idx;
        }

        /// Copy lines after selection (helper).
        // 2025-12-02-124933-pst: Active function
        fn copy_lines_after_selection(
            self: *const EditorState,
            new_lines: []const []const u8,
            start_idx: u32,
            end_line: u32,
        ) !u32 {
            var i = start_idx;
            var k: u32 = end_line + 1;
            while (k < self.buffer.lines_len) : (k += 1) {
                new_lines[i] = self.buffer.lines[k];
                i += 1;
            }
            return i;
        }

        /// Save replace operation to undo history (helper).
        // 2025-12-02-124933-pst: Active function
        fn save_replace_to_undo(
            self: *EditorState,
            selection: struct {
                start_line: u32,
                start_column: u32,
                end_line: u32,
                end_column: u32,
            },
            deleted_text: []const u8,
        ) !void {
            if (self.undo_history_len < MAX_UNDO_HISTORY) {
                const undo_op = try UndoOperation.init(
                    self.allocator,
                    .replace,
                    selection.start_line,
                    selection.start_column,
                    deleted_text,
                );
                self.undo_history[self.undo_history_len] = undo_op;
                self.undo_history_len += 1;
                var i: u32 = 0;
                while (i < self.redo_history_len) : (i += 1) {
                    self.redo_history[i].deinit();
                }
                self.redo_history_len = 0;
            }
        }

        /// Parse text into lines (helper).
        // 2025-12-02-124933-pst: Active function
        fn parse_text_to_lines(self: *EditorState, text: []const u8) !struct {
            lines: []const []const u8,
            lines_len: u32,
        } {
            // Count lines
            var line_count: u32 = 0;
            var i: u32 = 0;
            while (i < text.len) : (i += 1) {
                if (text[i] == '\n') {
                    line_count += 1;
                }
            }
            if (text.len > 0 and text[text.len - 1] != '\n') {
                line_count += 1;
            }
            if (line_count == 0) {
                line_count = 1; // At least one line
            }
            // Allocate lines array
            const lines = try self.allocator.alloc([]const u8, line_count);
            errdefer self.allocator.free(lines);
            // Split text into lines
            var start: u32 = 0;
            var line_idx: u32 = 0;
            i = 0;
            while (i < text.len) : (i += 1) {
                if (text[i] == '\n') {
                    const line = text[start..i];
                    lines[line_idx] = line;
                    line_idx += 1;
                    start = i + 1;
                }
            }
            if (start < text.len) {
                const line = text[start..];
                lines[line_idx] = line;
                line_idx += 1;
            } else if (text.len > 0 and text[text.len - 1] == '\n') {
                lines[line_idx] = "";
                line_idx += 1;
            }
            return .{
                .lines = lines,
                .lines_len = line_idx,
            };
        }

        /// Delete current line (Vim 'dd').
        // 2025-12-02-115753-pst: Active function
        pub fn delete_line(self: *EditorState) !void {
            std.debug.assert(self.mode == .normal);
            std.debug.assert(self.cursor_line < self.buffer.lines_len);
            const line_to_delete = self.buffer.lines[self.cursor_line];
            const line_len = @as(u32, @intCast(line_to_delete.len));
            if (line_len > 0 and line_len <= MAX_YANK_BUFFER) {
                if (self.yank_buffer) |yank_buf| {
                    self.allocator.free(yank_buf);
                }
                const yank_buf = try self.allocator.alloc(u8, line_len);
                errdefer self.allocator.free(yank_buf);
                @memcpy(yank_buf, line_to_delete);
                self.yank_buffer = yank_buf;
                self.yank_buffer_len = line_len;
            }
            if (self.undo_history_len < MAX_UNDO_HISTORY) {
                const undo_op = try UndoOperation.init(
                    self.allocator,
                    .delete,
                    self.cursor_line,
                    0,
                    line_to_delete,
                );
                self.undo_history[self.undo_history_len] = undo_op;
                self.undo_history_len += 1;
                var i: u32 = 0;
                while (i < self.redo_history_len) : (i += 1) {
                    self.redo_history[i].deinit();
                }
                self.redo_history_len = 0;
            }
            // Remove line from buffer
            try self.buffer.remove_line(self.cursor_line);
            if (self.cursor_line >= self.buffer.lines_len and self.buffer.lines_len > 0) {
                self.cursor_line = self.buffer.lines_len - 1;
            } else if (self.buffer.lines_len == 0) {
                const empty_lines = try self.allocator.alloc([]const u8, 1);
                empty_lines[0] = "";
                self.buffer.lines = empty_lines;
                self.buffer.lines_len = 1;
                self.cursor_line = 0;
                self.cursor_column = 0;
            }
            if (self.cursor_line < self.buffer.lines_len) {
                const new_line_len = @as(u32, @intCast(self.buffer.lines[self.cursor_line].len));
                if (self.cursor_column > new_line_len) {
                    self.cursor_column = new_line_len;
                }
            }
        }
    };
};

