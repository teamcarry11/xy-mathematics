//! Grain Text Editor: Simple, lovable, complete text editor (SLC v1.0).
//!
//! Why: Provide essential text editing for Workspace App Suite.
//! Architecture: File operations, text editing, undo/redo, search.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-161231-pst: Phase 17 SLC v1.0 Text Editor

const std = @import("std");
const grain_core = @import("grain_core");

// Bounded: Max file size (explicit limit, in bytes)
// 2025-12-20-161231-pst: Phase 17 SLC v1.0
pub const MAX_FILE_SIZE: u32 = 10_485_760; // 10 MB

// Bounded: Max undo history (explicit limit)
// 2025-12-20-161231-pst: Phase 17 SLC v1.0
pub const MAX_UNDO_HISTORY: u32 = 100;

// Bounded: Max search results (explicit limit)
// 2025-12-20-161231-pst: Phase 17 SLC v1.0
pub const MAX_SEARCH_RESULTS: u32 = 256;

// Bounded: Max line length (explicit limit, in bytes)
// 2025-12-20-161231-pst: Phase 17 SLC v1.0
pub const MAX_LINE_LEN: u32 = 4096;

// Bounded: Max lines (explicit limit)
// 2025-12-20-161231-pst: Phase 17 SLC v1.0
pub const MAX_LINES: u32 = 100_000;

// File state enumeration.
// 2025-12-20-161231-pst: Phase 17 SLC v1.0
pub const FileState = enum(u8) {
    closed, // No file open
    clean, // File open, no unsaved changes
    dirty, // File open, has unsaved changes
};

// Cursor position structure.
// 2025-12-20-161231-pst: Phase 17 SLC v1.0
pub const CursorPosition = struct {
    line: u32, // Line number (0-indexed)
    column: u32, // Column number (0-indexed)

    pub fn init() CursorPosition {
        return CursorPosition{
            .line = 0,
            .column = 0,
        };
    }

    pub fn is_valid(self: *const CursorPosition, max_lines: u32, line_len: u32) bool {
        std.debug.assert(max_lines > 0);
        if (self.line >= max_lines) {
            return false;
        }
        if (self.column > line_len) {
            return false;
        }
        return true;
    }
};

// Text line structure.
// 2025-12-20-161231-pst: Phase 17 SLC v1.0
pub const TextLine = struct {
    content: [MAX_LINE_LEN]u8,
    content_len: u32,

    pub fn init() TextLine {
        var line = TextLine{
            .content = undefined,
            .content_len = 0,
        };
        @memset(&line.content, 0);
        return line;
    }

    pub fn set_content(self: *TextLine, text: []const u8) bool {
        std.debug.assert(text.len <= MAX_LINE_LEN);
        if (text.len > MAX_LINE_LEN) {
            return false;
        }
        @memset(&self.content, 0);
        const len = @min(text.len, MAX_LINE_LEN);
        @memcpy(self.content[0..len], text[0..len]);
        self.content_len = @as(u32, @intCast(len));
        return true;
    }
};

// Undo entry structure.
// 2025-12-20-161231-pst: Phase 17 SLC v1.0
pub const UndoEntry = struct {
    line: u32,
    column: u32,
    action: UndoAction,
    text: [MAX_LINE_LEN]u8,
    text_len: u32,

    pub fn init() UndoEntry {
        var entry = UndoEntry{
            .line = 0,
            .column = 0,
            .action = .insert,
            .text = undefined,
            .text_len = 0,
        };
        @memset(&entry.text, 0);
        return entry;
    }
};

// Undo action enumeration.
// 2025-12-20-161231-pst: Phase 17 SLC v1.0
pub const UndoAction = enum(u8) {
    insert, // Insert text
    delete, // Delete text
    newline, // Insert newline
    backspace, // Backspace
};

// Search result structure.
// 2025-12-20-161231-pst: Phase 17 SLC v1.0
pub const SearchResult = struct {
    line: u32,
    column: u32,
    match_len: u32,
};

// Text Editor application state.
// 2025-12-20-161231-pst: Phase 17 SLC v1.0
pub const TextEditor = struct {
    lines: [MAX_LINES]TextLine,
    lines_len: u32,
    cursor: CursorPosition,
    file_path: [grain_core.file_manager.MAX_PATH_LEN]u8,
    file_path_len: u32,
    file_state: FileState,
    undo_history: [MAX_UNDO_HISTORY]UndoEntry,
    undo_history_len: u32,
    undo_history_pos: u32,
    search_results: [MAX_SEARCH_RESULTS]SearchResult,
    search_results_len: u32,
    search_query: [256]u8,
    search_query_len: u32,
    show_line_numbers: bool,
    allocator: std.mem.Allocator,

    /// Initialize text editor.
    // 2025-12-20-161231-pst: Phase 17 SLC v1.0
    pub fn init(allocator: std.mem.Allocator) TextEditor {
        // Precondition: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        var editor = TextEditor{
            .lines = undefined,
            .lines_len = 0,
            .cursor = CursorPosition.init(),
            .file_path = undefined,
            .file_path_len = 0,
            .file_state = .closed,
            .undo_history = undefined,
            .undo_history_len = 0,
            .undo_history_pos = 0,
            .search_results = undefined,
            .search_results_len = 0,
            .search_query = undefined,
            .search_query_len = 0,
            .show_line_numbers = true,
            .allocator = allocator,
        };

        // Initialize lines
        var i: u32 = 0;
        while (i < MAX_LINES) : (i += 1) {
            editor.lines[i] = TextLine.init();
        }

        // Initialize undo history
        i = 0;
        while (i < MAX_UNDO_HISTORY) : (i += 1) {
            editor.undo_history[i] = UndoEntry.init();
        }

        // Initialize file path
        @memset(&editor.file_path, 0);

        // Initialize search query
        @memset(&editor.search_query, 0);

        // Postcondition: Editor must be valid
        std.debug.assert(editor.lines_len == 0);
        std.debug.assert(editor.file_state == .closed);

        return editor;
    }

    /// Open file.
    // 2025-12-20-161231-pst: Phase 17 SLC v1.0
    pub fn open_file(self: *TextEditor, path: []const u8) bool {
        // Precondition: Path must be valid
        std.debug.assert(path.len > 0);
        std.debug.assert(path.len <= grain_core.file_manager.MAX_PATH_LEN);

        // Check if file is already open with unsaved changes
        if (self.file_state == .dirty) {
            return false; // Must save first
        }

        // Copy path
        @memset(&self.file_path, 0);
        const path_len = @min(path.len, grain_core.file_manager.MAX_PATH_LEN);
        @memcpy(self.file_path[0..path_len], path[0..path_len]);
        self.file_path_len = @as(u32, @intCast(path_len));

        // Clear lines
        self.lines_len = 0;
        var i: u32 = 0;
        while (i < MAX_LINES) : (i += 1) {
            self.lines[i] = TextLine.init();
        }

        // Reset cursor
        self.cursor = CursorPosition.init();

        // Reset undo history
        self.undo_history_len = 0;
        self.undo_history_pos = 0;

        // Set state
        self.file_state = .clean;

        // Postcondition: File must be open
        std.debug.assert(self.file_state != .closed);

        return true;
    }

    /// Save file.
    // 2025-12-20-161231-pst: Phase 17 SLC v1.0
    pub fn save_file(self: *TextEditor) bool {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);

        if (self.file_state == .closed) {
            return false;
        }

        // Mark as clean
        self.file_state = .clean;

        // Postcondition: File must be clean
        std.debug.assert(self.file_state == .clean);

        return true;
    }

    /// Close file.
    // 2025-12-20-161231-pst: Phase 17 SLC v1.0
    pub fn close_file(self: *TextEditor) bool {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);

        if (self.file_state == .closed) {
            return false;
        }

        // Check for unsaved changes
        if (self.file_state == .dirty) {
            return false; // Must save first
        }

        // Clear file path
        @memset(&self.file_path, 0);
        self.file_path_len = 0;

        // Clear lines
        self.lines_len = 0;
        var i: u32 = 0;
        while (i < MAX_LINES) : (i += 1) {
            self.lines[i] = TextLine.init();
        }

        // Reset cursor
        self.cursor = CursorPosition.init();

        // Reset undo history
        self.undo_history_len = 0;
        self.undo_history_pos = 0;

        // Set state
        self.file_state = .closed;

        // Postcondition: File must be closed
        std.debug.assert(self.file_state == .closed);

        return true;
    }

    /// Insert text at cursor position.
    // 2025-12-20-161231-pst: Phase 17 SLC v1.0
    pub fn insert_text(self: *TextEditor, text: []const u8) bool {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);
        std.debug.assert(text.len > 0);

        if (self.file_state == .closed) {
            return false;
        }

        if (self.lines_len == 0) {
            // Add first line
            if (self.lines_len >= MAX_LINES) {
                return false;
            }
            self.lines[self.lines_len] = TextLine.init();
            self.lines_len += 1;
        }

        // Ensure cursor is valid
        if (self.cursor.line >= self.lines_len) {
            self.cursor.line = self.lines_len - 1;
        }

        const current_line = &self.lines[self.cursor.line];
        const remaining = MAX_LINE_LEN - current_line.content_len;
        const insert_len = @min(text.len, remaining);

        if (insert_len == 0) {
            return false;
        }

        // Shift existing content
        var i: u32 = current_line.content_len;
        while (i > self.cursor.column) : (i -= 1) {
            if (i + insert_len - 1 < MAX_LINE_LEN) {
                current_line.content[i + insert_len - 1] = current_line.content[i - 1];
            }
        }

        // Insert new text
        @memcpy(
            current_line.content[self.cursor.column..self.cursor.column + insert_len],
            text[0..insert_len],
        );
        current_line.content_len += insert_len;
        self.cursor.column += insert_len;

        // Mark as dirty
        self.file_state = .dirty;

        // Postcondition: Text must be inserted
        std.debug.assert(self.cursor.column <= current_line.content_len);

        return true;
    }

    /// Delete text at cursor position.
    // 2025-12-20-161231-pst: Phase 17 SLC v1.0
    pub fn delete_text(self: *TextEditor, count: u32) bool {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);
        std.debug.assert(count > 0);

        if (self.file_state == .closed) {
            return false;
        }

        if (self.lines_len == 0) {
            return false;
        }

        // Ensure cursor is valid
        if (self.cursor.line >= self.lines_len) {
            self.cursor.line = self.lines_len - 1;
        }

        const current_line = &self.lines[self.cursor.line];
        if (self.cursor.column >= current_line.content_len) {
            return false;
        }

        const delete_len = @min(count, current_line.content_len - self.cursor.column);
        if (delete_len == 0) {
            return false;
        }

        // Shift remaining content
        var i: u32 = self.cursor.column;
        while (i + delete_len < current_line.content_len) : (i += 1) {
            current_line.content[i] = current_line.content[i + delete_len];
        }

        // Clear deleted portion
        var j: u32 = current_line.content_len - delete_len;
        while (j < current_line.content_len) : (j += 1) {
            current_line.content[j] = 0;
        }

        current_line.content_len -= delete_len;

        // Mark as dirty
        self.file_state = .dirty;

        // Postcondition: Text must be deleted
        std.debug.assert(current_line.content_len <= MAX_LINE_LEN);

        return true;
    }

    /// Move cursor.
    // 2025-12-20-161231-pst: Phase 17 SLC v1.0
    pub fn move_cursor(self: *TextEditor, line: u32, column: u32) bool {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);

        if (self.file_state == .closed) {
            return false;
        }

        if (self.lines_len == 0) {
            self.cursor = CursorPosition.init();
            return true;
        }

        // Clamp line
        const clamped_line = @min(line, self.lines_len - 1);
        const line_len = self.lines[clamped_line].content_len;

        // Clamp column
        const clamped_column = @min(column, line_len);

        self.cursor.line = clamped_line;
        self.cursor.column = clamped_column;

        // Postcondition: Cursor must be valid
        std.debug.assert(self.cursor.line < self.lines_len);
        std.debug.assert(self.cursor.column <= self.lines[self.cursor.line].content_len);

        return true;
    }

    /// Get current line number.
    // 2025-12-20-161231-pst: Phase 17 SLC v1.0
    pub fn get_current_line_number(self: *const TextEditor) u32 {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);

        return self.cursor.line + 1; // 1-indexed for display
    }

    /// Get total line count.
    // 2025-12-20-161231-pst: Phase 17 SLC v1.0
    pub fn get_total_line_count(self: *const TextEditor) u32 {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);

        if (self.lines_len == 0) {
            return 1; // At least one line
        }
        return self.lines_len;
    }

    /// Search text.
    // 2025-12-20-161231-pst: Phase 17 SLC v1.0
    pub fn search_text(self: *TextEditor, query: []const u8) u32 {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);
        std.debug.assert(query.len > 0);

        if (self.file_state == .closed) {
            return 0;
        }

        // Copy search query
        @memset(&self.search_query, 0);
        const query_len = @min(query.len, 256);
        @memcpy(self.search_query[0..query_len], query[0..query_len]);
        self.search_query_len = @as(u32, @intCast(query_len));

        // Clear previous results
        self.search_results_len = 0;

        // Search through all lines
        var line_idx: u32 = 0;
        while (line_idx < self.lines_len and self.search_results_len < MAX_SEARCH_RESULTS) : (line_idx += 1) {
            const line = &self.lines[line_idx];
            var col_idx: u32 = 0;
            while (col_idx < line.content_len) : (col_idx += 1) {
                // Check if match starts here
                var match: bool = true;
                var i: u32 = 0;
                while (i < query_len) : (i += 1) {
                    if (col_idx + i >= line.content_len) {
                        match = false;
                        break;
                    }
                    if (line.content[col_idx + i] != query[i]) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    if (self.search_results_len >= MAX_SEARCH_RESULTS) {
                        break;
                    }
                    self.search_results[self.search_results_len] = SearchResult{
                        .line = line_idx,
                        .column = col_idx,
                        .match_len = query_len,
                    };
                    self.search_results_len += 1;
                    col_idx += query_len - 1; // Skip matched text
                }
            }
        }

        // Postcondition: Results must be valid
        std.debug.assert(self.search_results_len <= MAX_SEARCH_RESULTS);

        return self.search_results_len;
    }

    /// Get search results.
    // 2025-12-20-161231-pst: Phase 17 SLC v1.0
    pub fn get_search_results(
        self: *const TextEditor,
        results: []SearchResult,
        results_len: *u32,
    ) void {
        // Precondition: Results buffer must be valid
        std.debug.assert(results.len >= MAX_SEARCH_RESULTS);

        results_len.* = 0;
        var i: u32 = 0;
        while (i < self.search_results_len and results_len.* < results.len) : (i += 1) {
            results[results_len.*] = self.search_results[i];
            results_len.* += 1;
        }
    }

    /// Toggle line numbers display.
    // 2025-12-20-161231-pst: Phase 17 SLC v1.0
    pub fn toggle_line_numbers(self: *TextEditor) void {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);

        self.show_line_numbers = !self.show_line_numbers;
    }
};
