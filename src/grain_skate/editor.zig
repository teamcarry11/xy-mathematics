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

    /// Editor mode enumeration.
    pub const EditorMode = enum(u8) {
        normal, // Normal mode (Vim)
        insert, // Insert mode (Vim)
        visual, // Visual mode (Vim)
        command, // Command mode (Vim)
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

        /// Exit visual mode (Vim ESC).
        // 2025-12-02-121512-pst: Active function
        pub fn exit_visual_mode(self: *EditorState) void {
            self.mode = .normal;
        }

        /// Switch editor mode.
        pub fn switch_mode(self: *EditorState, new_mode: EditorMode) void {
            if (self.mode == .visual) {
                self.exit_visual_mode();
            }
            self.mode = new_mode;
            if (new_mode == .visual) {
                self.enter_visual_mode();
            }
        }

        /// Get visual selection bounds (normalized: start <= end).
        // 2025-12-02-121512-pst: Active function
        pub fn get_visual_selection(self: *const EditorState) struct {
            start_line: u32,
            start_column: u32,
            end_line: u32,
            end_column: u32,
        } {
            std.debug.assert(self.mode == .visual);
            // Normalize selection (start <= end)
            const anchor_line = self.visual_anchor_line;
            const anchor_col = self.visual_anchor_column;
            const cursor_line = self.cursor_line;
            const cursor_col = self.cursor_column;
            // Compare positions (line first, then column)
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

        /// Yank selected text in visual mode.
        // 2025-12-02-121512-pst: Active function
        pub fn yank_selection(self: *EditorState) !void {
            std.debug.assert(self.mode == .visual);
            const selection = self.get_visual_selection();
            // Calculate total size of selected text
            var total_size: u32 = 0;
            var line: u32 = selection.start_line;
            while (line <= selection.end_line) : (line += 1) {
                std.debug.assert(line < self.buffer.lines_len);
                const line_text = self.buffer.lines[line];
                const line_len = @as(u32, @intCast(line_text.len));
                if (line == selection.start_line and line == selection.end_line) {
                    // Single line selection
                    const start_col = selection.start_column;
                    const end_col = selection.end_column;
                    std.debug.assert(start_col <= end_col);
                    std.debug.assert(end_col <= line_len);
                    total_size += end_col - start_col;
                } else if (line == selection.start_line) {
                    // First line of multi-line selection
                    const start_col = selection.start_column;
                    std.debug.assert(start_col <= line_len);
                    total_size += line_len - start_col + 1; // +1 for newline
                } else if (line == selection.end_line) {
                    // Last line of multi-line selection
                    const end_col = selection.end_column;
                    std.debug.assert(end_col <= line_len);
                    total_size += end_col;
                } else {
                    // Middle line of multi-line selection
                    total_size += line_len + 1; // +1 for newline
                }
            }
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
            var pos: u32 = 0;
            line = selection.start_line;
            while (line <= selection.end_line) : (line += 1) {
                const line_text = self.buffer.lines[line];
                const line_len = @as(u32, @intCast(line_text.len));
                if (line == selection.start_line and line == selection.end_line) {
                    // Single line selection
                    const start_col = selection.start_column;
                    const end_col = selection.end_column;
                    const copy_len = end_col - start_col;
                    if (copy_len > 0) {
                        @memcpy(yank_buf[pos..][0..copy_len], line_text[start_col..end_col]);
                        pos += copy_len;
                    }
                } else if (line == selection.start_line) {
                    // First line of multi-line selection
                    const start_col = selection.start_column;
                    const copy_len = line_len - start_col;
                    if (copy_len > 0) {
                        @memcpy(yank_buf[pos..][0..copy_len], line_text[start_col..]);
                        pos += copy_len;
                    }
                    yank_buf[pos] = '\n';
                    pos += 1;
                } else if (line == selection.end_line) {
                    // Last line of multi-line selection
                    const end_col = selection.end_column;
                    if (end_col > 0) {
                        @memcpy(yank_buf[pos..][0..end_col], line_text[0..end_col]);
                        pos += end_col;
                    }
                } else {
                    // Middle line of multi-line selection
                    if (line_len > 0) {
                        @memcpy(yank_buf[pos..][0..line_len], line_text);
                        pos += line_len;
                    }
                    yank_buf[pos] = '\n';
                    pos += 1;
                }
            }
            self.yank_buffer = yank_buf;
            self.yank_buffer_len = pos;
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
                .replace => {
                    // Undo replace: restore original text (not implemented yet)
                    _ = undo_op;
                },
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
                .replace => {
                    // Redo replace: restore replaced text (not implemented yet)
                    _ = redo_op;
                },
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

        /// Paste yank buffer at cursor.
        // 2025-12-02-115753-pst: Active function
        pub fn paste(self: *EditorState) !void {
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

