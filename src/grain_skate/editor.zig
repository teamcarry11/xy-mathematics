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
            std.debug.assert(self.allocator.ptr != null);

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
            std.debug.assert(self.allocator.ptr != null);

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
                .allocator = allocator,
            };
        }

        /// Deinitialize editor state and free memory.
        pub fn deinit(self: *EditorState) void {
            // Assert: Allocator must be valid
            std.debug.assert(self.allocator.ptr != null);

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

        /// Insert character at cursor (insert mode).
        pub fn insert_char(self: *EditorState, ch: u8) !void {
            // Assert: Must be in insert mode
            std.debug.assert(self.mode == .insert);

            // For now, this is a placeholder
            // In a full implementation, we would:
            // 1. Insert character at cursor position
            // 2. Update buffer
            // 3. Add to undo history
            // 4. Move cursor right
            _ = ch;
            // self will be used in full implementation
        }

        /// Delete character at cursor (Vim 'x').
        pub fn delete_char(self: *EditorState) !void {
            // Assert: Must be in normal mode
            std.debug.assert(self.mode == .normal);

            // For now, this is a placeholder
            // In a full implementation, we would:
            // 1. Delete character at cursor position
            // 2. Update buffer
            // 3. Add to undo history
            // self will be used in full implementation
        }
    };
};

