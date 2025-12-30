//! Grain Text Editor: Simple, lovable, complete text editor (SLC v1.0).
//!
//! Why: Provide essential text editing for Workspace App Suite.
//! Architecture: File operations, text editing, undo/redo, search.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-20-161231-pst: Phase 17 SLC v1.0 Text Editor
//! 2025-12-21-184709-pst: Phase 28 Find and Replace
//! 2025-12-21-234422-pst: Phase 29 Go to Line
//! 2025-12-23-194527-pst: Phase 30 Text Selection
//! 2025-12-23-210000-pst: Phase 31 Syntax Highlighting
//! 2025-12-28-223816-pst: Phase 33 Bracket Matching
//! 2025-12-29-001544-pst: Phase 35 Code Folding
//! 2025-12-29-152539-pst: Phase 37 Visual Fold Indicators (helper functions)

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

// Bounded: Max replace query length (explicit limit, in bytes)
// 2025-12-21-184709-pst: Phase 28 Find and Replace
pub const MAX_REPLACE_QUERY_LEN: u32 = 256;

// Bounded: Max clipboard size (explicit limit, in bytes)
// 2025-12-23-194527-pst: Phase 30 Text Selection
pub const MAX_CLIPBOARD_SIZE: u32 = 1_048_576; // 1 MB

// Bounded: Max syntax tokens per line (explicit limit)
// 2025-12-23-210000-pst: Phase 31 Syntax Highlighting (Zig only)
pub const MAX_SYNTAX_TOKENS_PER_LINE: u32 = 256;

// Bounded: Max bracket pairs for matching (explicit limit)
// 2025-12-28-223816-pst: Phase 33 Bracket Matching
pub const MAX_BRACKET_PAIRS: u32 = 64;

// Bounded: Max fold ranges (explicit limit)
// 2025-12-29-001544-pst: Phase 35 Code Folding
pub const MAX_FOLD_RANGES: u32 = 256;

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

// Selection range structure.
// 2025-12-23-194527-pst: Phase 30 Text Selection
pub const SelectionRange = struct {
    start: CursorPosition,
    end: CursorPosition,
    active: bool, // True if selection is active

    pub fn init() SelectionRange {
        return SelectionRange{
            .start = CursorPosition.init(),
            .end = CursorPosition.init(),
            .active = false,
        };
    }

    pub fn is_valid(self: *const SelectionRange, max_lines: u32) bool {
        std.debug.assert(max_lines > 0);
        if (!self.active) {
            return false;
        }
        if (self.start.line >= max_lines or self.end.line >= max_lines) {
            return false;
        }
        return true;
    }

    pub fn normalize(self: *SelectionRange) void {
        std.debug.assert(self.active);
        // Ensure start is before end
        if (self.start.line > self.end.line or
            (self.start.line == self.end.line and self.start.column > self.end.column))
        {
            const temp = self.start;
            self.start = self.end;
            self.end = temp;
        }
    }
};

// Syntax token type enumeration (Zig only).
// 2025-12-23-210000-pst: Phase 31 Syntax Highlighting
pub const SyntaxTokenType = enum(u8) {
    keyword, // Zig keywords (const, var, fn, pub, etc.)
    string_literal, // String literals ("...", c"...")
    number_literal, // Number literals (123, 0x123, 0b101)
    comment, // Comments (// ..., //! ..., /// ...)
    identifier, // Identifiers (variable names, function names)
    operator, // Operators (+, -, *, /, ==, !=, etc.)
    punctuation, // Punctuation ({, }, (, ), [, ], etc.)
    normal, // Normal text (no special highlighting)
};

// Syntax token structure.
// 2025-12-23-210000-pst: Phase 31 Syntax Highlighting
pub const SyntaxToken = struct {
    start: u32, // Start column (0-indexed)
    end: u32, // End column (0-indexed, exclusive)
    token_type: SyntaxTokenType, // Token type

    pub fn init() SyntaxToken {
        return SyntaxToken{
            .start = 0,
            .end = 0,
            .token_type = .normal,
        };
    }
};

// Bracket pair structure for matching.
// 2025-12-28-223816-pst: Phase 33 Bracket Matching
pub const BracketPair = struct {
    open: u8, // Opening bracket character
    close: u8, // Closing bracket character

    pub fn init(open_char: u8, close_char: u8) BracketPair {
        std.debug.assert(open_char != 0);
        std.debug.assert(close_char != 0);
        return BracketPair{
            .open = open_char,
            .close = close_char,
        };
    }
};

// Bracket match result structure.
// 2025-12-28-223816-pst: Phase 33 Bracket Matching
pub const BracketMatch = struct {
    found: bool, // Whether a match was found
    line: u32, // Line number of matching bracket (0-indexed)
    column: u32, // Column number of matching bracket (0-indexed)
    is_opening: bool, // True if cursor is on opening bracket, false if closing

    pub fn init() BracketMatch {
        return BracketMatch{
            .found = false,
            .line = 0,
            .column = 0,
            .is_opening = false,
        };
    }
};

// Fold range structure for code folding.
// 2025-12-29-001544-pst: Phase 35 Code Folding
pub const FoldRange = struct {
    start_line: u32, // Start line of foldable block (0-indexed)
    end_line: u32, // End line of foldable block (0-indexed, inclusive)
    folded: bool, // Whether this range is currently folded
    fold_level: u32, // Nesting level (0 = top level)

    pub fn init(start: u32, end: u32, level: u32) FoldRange {
        std.debug.assert(start <= end);
        return FoldRange{
            .start_line = start,
            .end_line = end,
            .folded = false,
            .fold_level = level,
        };
    }

    pub fn toggle(self: *FoldRange) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.folded = !self.folded;
    }
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
    replace_query: [MAX_REPLACE_QUERY_LEN]u8,
    replace_query_len: u32,
    show_line_numbers: bool,
    plain_text_mode: bool,
    syntax_highlighting_enabled: bool, // Enable Zig syntax highlighting
    selection: SelectionRange,
    clipboard: [MAX_CLIPBOARD_SIZE]u8,
    clipboard_len: u32,
    bracket_matching_enabled: bool, // Enable bracket matching
    bracket_match: BracketMatch, // Current bracket match result
    fold_ranges: [MAX_FOLD_RANGES]FoldRange, // Fold ranges for code blocks
    fold_ranges_len: u32, // Number of active fold ranges
    code_folding_enabled: bool, // Enable code folding
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
            .replace_query = undefined,
            .replace_query_len = 0,
            .show_line_numbers = true,
            .plain_text_mode = false,
            .syntax_highlighting_enabled = true,
            .selection = SelectionRange.init(),
            .clipboard = undefined,
            .clipboard_len = 0,
            .bracket_matching_enabled = true,
            .bracket_match = BracketMatch.init(),
            .fold_ranges = undefined,
            .fold_ranges_len = 0,
            .code_folding_enabled = true,
            .allocator = allocator,
        };

        // Initialize lines
        var i: u32 = 0;
        while (i < MAX_LINES) : (i += 1) {
            editor.lines[i] = TextLine.init();
        }

        // Initialize fold ranges
        i = 0;
        while (i < MAX_FOLD_RANGES) : (i += 1) {
            editor.fold_ranges[i] = FoldRange.init(0, 0, 0);
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
        @memset(&editor.replace_query, 0);

        // Postcondition: Editor must be valid
        std.debug.assert(editor.lines_len == 0);
        std.debug.assert(editor.file_state == .closed);

        return editor;
    }

    /// Open file.
    // 2025-12-20-161231-pst: Phase 17 SLC v1.0
    // 2025-12-20-180043-pst: Phase 19 File I/O - load file content
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

        // Load file content (if file exists)
        _ = self.load_file_content();

        // Set state
        self.file_state = .clean;

        // Postcondition: File must be open
        std.debug.assert(self.file_state != .closed);

        return true;
    }

    /// Load file content into editor.
    // 2025-12-20-180043-pst: Phase 19 File I/O
    fn load_file_content(self: *TextEditor) bool {
        // Precondition: File path must be set
        std.debug.assert(self.file_path_len > 0);

        // For now, this is a placeholder that will be integrated with kernel file I/O
        // In production, this would read from the file system via kernel syscalls
        // For SLC v1.0, we provide the structure and API

        // Clear existing content
        self.lines_len = 0;
        var i: u32 = 0;
        while (i < MAX_LINES) : (i += 1) {
            self.lines[i] = TextLine.init();
        }

        // Add empty first line
        if (self.lines_len < MAX_LINES) {
            self.lines[self.lines_len] = TextLine.init();
            self.lines_len += 1;
        }

        // Reset cursor
        self.cursor = CursorPosition.init();

        // Postcondition: Editor must have at least one line
        std.debug.assert(self.lines_len > 0);

        return true;
    }

    /// Save file.
    // 2025-12-20-161231-pst: Phase 17 SLC v1.0
    // 2025-12-20-180043-pst: Phase 19 File I/O - write file content
    pub fn save_file(self: *TextEditor) bool {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);

        if (self.file_state == .closed) {
            return false;
        }

        // Write file content
        const written = self.save_file_content();
        if (!written) {
            return false;
        }

        // Mark as clean
        self.file_state = .clean;

        // Postcondition: File must be clean
        std.debug.assert(self.file_state == .clean);

        return true;
    }

    /// Save file content to disk.
    // 2025-12-20-180043-pst: Phase 19 File I/O
    fn save_file_content(self: *TextEditor) bool {
        // Precondition: File path must be set
        std.debug.assert(self.file_path_len > 0);

        // For now, this is a placeholder that will be integrated with kernel file I/O
        // In production, this would write to the file system via kernel syscalls
        // For SLC v1.0, we provide the structure and API

        // Calculate total content size
        var total_size: u32 = 0;
        var i: u32 = 0;
        while (i < self.lines_len) : (i += 1) {
            total_size += self.lines[i].content_len;
            if (i < self.lines_len - 1) {
                total_size += 1; // Newline character
            }
        }

        // Check file size limit
        if (total_size > MAX_FILE_SIZE) {
            return false;
        }

        // Postcondition: Content size must be valid
        std.debug.assert(total_size <= MAX_FILE_SIZE);

        return true;
    }

    /// Get file content as single buffer (for export/save).
    // 2025-12-20-180043-pst: Phase 19 File I/O
    pub fn get_file_content(
        self: *const TextEditor,
        buffer: []u8,
        buffer_len: *u32,
    ) bool {
        // Precondition: Buffer must be valid
        std.debug.assert(buffer.len >= MAX_FILE_SIZE);
        std.debug.assert(self.file_state != .closed);

        if (self.file_state == .closed) {
            return false;
        }

        buffer_len.* = 0;
        var i: u32 = 0;
        while (i < self.lines_len and buffer_len.* < buffer.len) : (i += 1) {
            const line = &self.lines[i];
            const remaining = buffer.len - buffer_len.*;
            const copy_len = @min(line.content_len, remaining);
            if (copy_len > 0) {
                @memcpy(buffer[buffer_len.*..buffer_len.* + copy_len], line.content[0..copy_len]);
                buffer_len.* += copy_len;
            }
            // Add newline (except for last line)
            if (i < self.lines_len - 1 and buffer_len.* < buffer.len) {
                buffer[buffer_len.*] = '\n';
                buffer_len.* += 1;
            }
        }

        // Postcondition: Buffer length must be valid
        std.debug.assert(buffer_len.* <= buffer.len);

        return true;
    }

    /// Set file content from buffer (for import/load).
    // 2025-12-20-180043-pst: Phase 19 File I/O
    pub fn set_file_content(self: *TextEditor, content: []const u8) bool {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);
        std.debug.assert(content.len <= MAX_FILE_SIZE);

        if (self.file_state == .closed) {
            return false;
        }

        if (content.len > MAX_FILE_SIZE) {
            return false;
        }

        // Clear existing content
        self.lines_len = 0;
        var i: u32 = 0;
        while (i < MAX_LINES) : (i += 1) {
            self.lines[i] = TextLine.init();
        }

        // Parse content into lines
        var line_start: u32 = 0;
        var line_idx: u32 = 0;
        i = 0;
        while (i < content.len and line_idx < MAX_LINES) : (i += 1) {
            if (content[i] == '\n' or i == content.len - 1) {
                // Create new line
                const line_end = if (content[i] == '\n') i else i + 1;
                const line_content = content[line_start..line_end];
                if (line_idx >= MAX_LINES) {
                    break;
                }
                const line = &self.lines[line_idx];
                const line_len = @min(line_content.len, MAX_LINE_LEN);
                @memcpy(line.content[0..line_len], line_content[0..line_len]);
                line.content_len = @as(u32, @intCast(line_len));
                line_idx += 1;
                line_start = i + 1;
            }
        }

        // If no newlines, create single line
        if (line_idx == 0 and content.len > 0) {
            const line = &self.lines[0];
            const line_len = @min(content.len, MAX_LINE_LEN);
            @memcpy(line.content[0..line_len], content[0..line_len]);
            line.content_len = @as(u32, @intCast(line_len));
            line_idx = 1;
        }

        self.lines_len = line_idx;

        // Reset cursor
        self.cursor = CursorPosition.init();

        // Reset undo history
        self.undo_history_len = 0;
        self.undo_history_pos = 0;

        // Mark as dirty
        self.file_state = .dirty;

        // Postcondition: Editor must have at least one line
        std.debug.assert(self.lines_len > 0);

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
        return self.insert_text_internal(text, true);
    }

    /// Internal insert text (with optional undo recording).
    // 2025-12-20-175102-pst: Phase 18 Undo/Redo
    // 2025-12-20-180855-pst: Phase 20 Plain Text Mode - auto-conversion
    fn insert_text_internal(self: *TextEditor, text: []const u8, record_undo: bool) bool {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);
        std.debug.assert(text.len > 0);

        if (self.file_state == .closed) {
            return false;
        }

        // Convert to plain ASCII if plain text mode is enabled
        var converted_text = text;
        var conversion_buffer: [MAX_LINE_LEN * 3]u8 = undefined;
        var conversion_len: u32 = 0;
        if (self.plain_text_mode) {
            const converted = self.convert_to_plain_ascii(text, &conversion_buffer, &conversion_len);
            if (converted and conversion_len > 0) {
                converted_text = conversion_buffer[0..conversion_len];
            }
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
        const insert_len = @min(converted_text.len, remaining);

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

        // Record undo entry before inserting (if not from undo/redo)
        if (record_undo) {
            const old_cursor_line = self.cursor.line;
            const old_cursor_col = self.cursor.column;
            self.add_undo_entry(old_cursor_line, old_cursor_col, .insert, converted_text[0..insert_len]);
        }

        // Insert new text
        @memcpy(
            current_line.content[self.cursor.column..self.cursor.column + insert_len],
            converted_text[0..insert_len],
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
        return self.delete_text_internal(count, true);
    }

    /// Internal delete text (with optional undo recording).
    // 2025-12-20-175102-pst: Phase 18 Undo/Redo
    fn delete_text_internal(self: *TextEditor, count: u32, record_undo: bool) bool {
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

        // Record undo entry before deleting (if not from undo/redo)
        if (record_undo) {
            const old_cursor_line = self.cursor.line;
            const old_cursor_col = self.cursor.column;
            const deleted_text = current_line.content[self.cursor.column..self.cursor.column + delete_len];
            self.add_undo_entry(old_cursor_line, old_cursor_col, .delete, deleted_text);
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

    /// Go to line number (1-indexed for user input).
    // 2025-12-21-234422-pst: Phase 29 Go to Line
    pub fn go_to_line(self: *TextEditor, line_number: u32) bool {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);
        std.debug.assert(line_number > 0); // 1-indexed

        if (self.file_state == .closed) {
            return false;
        }

        if (line_number == 0) {
            return false; // Line numbers are 1-indexed
        }

        // Convert 1-indexed to 0-indexed
        const line_idx = line_number - 1;

        if (self.lines_len == 0) {
            // Empty file - move to first line
            self.cursor = CursorPosition.init();
            return true;
        }

        // Clamp to valid line range
        const clamped_line = @min(line_idx, self.lines_len - 1);
        const line_len = self.lines[clamped_line].content_len;

        // Move cursor to start of line (column 0)
        self.cursor.line = clamped_line;
        self.cursor.column = 0;

        // Postcondition: Cursor must be valid
        std.debug.assert(self.cursor.line < self.lines_len);
        std.debug.assert(self.cursor.column <= self.lines[self.cursor.line].content_len);

        return true;
    }

    /// Go to line and column (1-indexed line, 0-indexed column for user input).
    // 2025-12-21-234422-pst: Phase 29 Go to Line
    pub fn go_to_line_column(self: *TextEditor, line_number: u32, column: u32) bool {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);
        std.debug.assert(line_number > 0); // 1-indexed

        if (self.file_state == .closed) {
            return false;
        }

        if (line_number == 0) {
            return false; // Line numbers are 1-indexed
        }

        // Convert 1-indexed to 0-indexed
        const line_idx = line_number - 1;

        if (self.lines_len == 0) {
            // Empty file - move to first line
            self.cursor = CursorPosition.init();
            return true;
        }

        // Clamp to valid line range
        const clamped_line = @min(line_idx, self.lines_len - 1);
        const line_len = self.lines[clamped_line].content_len;

        // Clamp column to valid range
        const clamped_column = @min(column, line_len);

        self.cursor.line = clamped_line;
        self.cursor.column = clamped_column;

        // Postcondition: Cursor must be valid
        std.debug.assert(self.cursor.line < self.lines_len);
        std.debug.assert(self.cursor.column <= self.lines[self.cursor.line].content_len);

        return true;
    }

    /// Go to line number (1-indexed for user convenience).
    // 2025-12-21-234422-pst: Phase 29 Go to Line
    pub fn go_to_line(self: *TextEditor, line_number: u32) bool {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);

        if (self.file_state == .closed) {
            return false;
        }

        if (line_number == 0) {
            return false; // Line numbers are 1-indexed
        }

        // Convert 1-indexed to 0-indexed
        const line_idx = line_number - 1;

        if (self.lines_len == 0) {
            // Empty file - move to first line
            self.cursor = CursorPosition.init();
            return true;
        }

        // Clamp to valid range
        const clamped_line = @min(line_idx, self.lines_len - 1);
        const line_len = self.lines[clamped_line].content_len;

        // Move cursor to start of line (column 0)
        self.cursor.line = clamped_line;
        self.cursor.column = 0;

        // Postcondition: Cursor must be valid
        std.debug.assert(self.cursor.line < self.lines_len);
        std.debug.assert(self.cursor.column <= self.lines[self.cursor.line].content_len);

        return true;
    }

    /// Go to line and column (1-indexed line, 0-indexed column for user convenience).
    // 2025-12-21-234422-pst: Phase 29 Go to Line
    pub fn go_to_line_and_column(self: *TextEditor, line_number: u32, column: u32) bool {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);

        if (self.file_state == .closed) {
            return false;
        }

        if (line_number == 0) {
            return false; // Line numbers are 1-indexed
        }

        // Convert 1-indexed to 0-indexed
        const line_idx = line_number - 1;

        if (self.lines_len == 0) {
            // Empty file - move to first line
            self.cursor = CursorPosition.init();
            return true;
        }

        // Clamp to valid range
        const clamped_line = @min(line_idx, self.lines_len - 1);
        const line_len = self.lines[clamped_line].content_len;

        // Clamp column to valid range
        const clamped_column = @min(column, line_len);

        self.cursor.line = clamped_line;
        self.cursor.column = clamped_column;

        // Postcondition: Cursor must be valid
        std.debug.assert(self.cursor.line < self.lines_len);
        std.debug.assert(self.cursor.column <= self.lines[self.cursor.line].content_len);

        return true;
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

    /// Set replace query.
    // 2025-12-21-184709-pst: Phase 28 Find and Replace
    pub fn set_replace_query(self: *TextEditor, query: []const u8) bool {
        // Precondition: Query must be valid
        std.debug.assert(query.len <= MAX_REPLACE_QUERY_LEN);

        if (query.len > MAX_REPLACE_QUERY_LEN) {
            return false;
        }

        @memset(&self.replace_query, 0);
        @memcpy(self.replace_query[0..query.len], query[0..query.len]);
        self.replace_query_len = @as(u32, @intCast(query.len));

        // Postcondition: Replace query must be set
        std.debug.assert(self.replace_query_len <= MAX_REPLACE_QUERY_LEN);

        return true;
    }

    /// Get replace query.
    // 2025-12-21-184709-pst: Phase 28 Find and Replace
    pub fn get_replace_query(
        self: *const TextEditor,
        query: []u8,
        query_len: *u32,
    ) void {
        // Precondition: Query buffer must be valid
        std.debug.assert(query.len >= MAX_REPLACE_QUERY_LEN);

        query_len.* = 0;
        const len = @min(self.replace_query_len, query.len);
        @memcpy(query[0..len], self.replace_query[0..len]);
        query_len.* = len;
    }

    /// Replace text at specific search result.
    // 2025-12-21-184709-pst: Phase 28 Find and Replace
    pub fn replace_at_result(self: *TextEditor, result_idx: u32) bool {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);
        std.debug.assert(result_idx < self.search_results_len);

        if (self.file_state == .closed) {
            return false;
        }

        if (result_idx >= self.search_results_len) {
            return false;
        }

        if (self.replace_query_len == 0) {
            return false; // No replace query set
        }

        const result = self.search_results[result_idx];
        if (result.line >= self.lines_len) {
            return false;
        }

        const line = &self.lines[result.line];
        if (result.column + result.match_len > line.content_len) {
            return false;
        }

        // Move cursor to replacement location
        self.cursor.line = result.line;
        self.cursor.column = result.column;

        // Delete matched text
        if (!self.delete_text_internal(result.match_len, true)) {
            return false;
        }

        // Insert replacement text
        const replace_text = self.replace_query[0..self.replace_query_len];
        if (!self.insert_text_internal(replace_text, true)) {
            return false;
        }

        // Mark as dirty
        self.file_state = .dirty;

        // Postcondition: Replacement must be done
        std.debug.assert(self.file_state == .dirty);

        return true;
    }

    /// Replace all occurrences of search query.
    // 2025-12-21-184709-pst: Phase 28 Find and Replace
    pub fn replace_all(self: *TextEditor) u32 {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);

        if (self.file_state == .closed) {
            return 0;
        }

        const initial_results_len = self.search_results_len;
        if (initial_results_len == 0) {
            return 0; // No search results
        }

        if (self.replace_query_len == 0) {
            return 0; // No replace query set
        }

        // Replace in reverse order to preserve indices
        var replace_count: u32 = 0;
        var i: u32 = initial_results_len;
        while (i > 0) : (i -= 1) {
            const result_idx = i - 1;
            if (self.replace_at_result(result_idx)) {
                replace_count += 1;
            }
        }

        // Clear search results after replacement
        self.search_results_len = 0;

        // Postcondition: Replace count must be valid
        std.debug.assert(replace_count <= initial_results_len);

        return replace_count;
    }

    /// Toggle line numbers display.
    // 2025-12-20-161231-pst: Phase 17 SLC v1.0
    pub fn toggle_line_numbers(self: *TextEditor) void {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);

        self.show_line_numbers = !self.show_line_numbers;
    }

    /// Toggle plain text mode.
    // 2025-12-20-180855-pst: Phase 20 Plain Text Mode
    pub fn toggle_plain_text_mode(self: *TextEditor) void {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);

        self.plain_text_mode = !self.plain_text_mode;
    }

    /// Convert text to plain ASCII (em dashes, smart quotes, ellipses).
    // 2025-12-20-180855-pst: Phase 20 Plain Text Mode
    fn convert_to_plain_ascii(self: *TextEditor, text: []const u8, output: []u8, output_len: *u32) bool {
        // Precondition: Output buffer must be valid
        std.debug.assert(output.len >= text.len * 3); // Worst case: ellipses expansion
        std.debug.assert(text.len > 0);

        _ = self; // Suppress unused warning

        output_len.* = 0;
        var i: u32 = 0;
        while (i < text.len and output_len.* < output.len) : (i += 1) {
            const c = text[i];
            // Em dash (—) to double dash (--)
            if (c == 0xE2 and i + 2 < text.len) {
                if (text[i + 1] == 0x80 and text[i + 2] == 0x94) {
                    // UTF-8 em dash
                    if (output_len.* + 2 <= output.len) {
                        output[output_len.*] = '-';
                        output_len.* += 1;
                        output[output_len.*] = '-';
                        output_len.* += 1;
                        i += 2; // Skip remaining UTF-8 bytes
                        continue;
                    }
                }
            }
            // Smart quotes and ellipses (UTF-8 sequences)
            if (c == 0xE2 and i + 2 < text.len) {
                // Left double quote ("")
                if (text[i + 1] == 0x80 and text[i + 2] == 0x9C) {
                    if (output_len.* < output.len) {
                        output[output_len.*] = '"';
                        output_len.* += 1;
                        i += 2;
                        continue;
                    }
                }
                // Right double quote ("")
                if (text[i + 1] == 0x80 and text[i + 2] == 0x9D) {
                    if (output_len.* < output.len) {
                        output[output_len.*] = '"';
                        output_len.* += 1;
                        i += 2;
                        continue;
                    }
                }
                // Ellipsis (…)
                if (text[i + 1] == 0x80 and text[i + 2] == 0xA6) {
                    if (output_len.* + 3 <= output.len) {
                        output[output_len.*] = '.';
                        output_len.* += 1;
                        output[output_len.*] = '.';
                        output_len.* += 1;
                        output[output_len.*] = '.';
                        output_len.* += 1;
                        i += 2;
                        continue;
                    }
                }
            }
            // Smart single quotes (UTF-8)
            if (c == 0xE2 and i + 2 < text.len) {
                // Left single quote (')
                if (text[i + 1] == 0x80 and text[i + 2] == 0x98) {
                    if (output_len.* < output.len) {
                        output[output_len.*] = '\'';
                        output_len.* += 1;
                        i += 2;
                        continue;
                    }
                }
                // Right single quote (')
                if (text[i + 1] == 0x80 and text[i + 2] == 0x99) {
                    if (output_len.* < output.len) {
                        output[output_len.*] = '\'';
                        output_len.* += 1;
                        i += 2;
                        continue;
                    }
                }
            }
            // Regular ASCII character
            if (output_len.* < output.len) {
                output[output_len.*] = c;
                output_len.* += 1;
            }
        }

        // Postcondition: Output length must be valid
        std.debug.assert(output_len.* <= output.len);

        return true;
    }

    /// Add undo entry.
    // 2025-12-20-175102-pst: Phase 18 Undo/Redo
    fn add_undo_entry(
        self: *TextEditor,
        line: u32,
        column: u32,
        action: UndoAction,
        text: []const u8,
    ) void {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);
        std.debug.assert(text.len <= MAX_LINE_LEN);

        // Discard redo history if we're not at the end
        if (self.undo_history_pos < self.undo_history_len) {
            self.undo_history_len = self.undo_history_pos;
        }

        // Check if we need to make room
        if (self.undo_history_len >= MAX_UNDO_HISTORY) {
            // Shift history left
            var i: u32 = 0;
            while (i < MAX_UNDO_HISTORY - 1) : (i += 1) {
                self.undo_history[i] = self.undo_history[i + 1];
            }
            self.undo_history_len = MAX_UNDO_HISTORY - 1;
        }

        // Add new entry
        const entry = &self.undo_history[self.undo_history_len];
        entry.line = line;
        entry.column = column;
        entry.action = action;
        @memset(&entry.text, 0);
        const text_len = @min(text.len, MAX_LINE_LEN);
        @memcpy(entry.text[0..text_len], text[0..text_len]);
        entry.text_len = @as(u32, @intCast(text_len));

        self.undo_history_len += 1;
        self.undo_history_pos = self.undo_history_len;
    }

    /// Undo last action.
    // 2025-12-20-175102-pst: Phase 18 Undo/Redo
    pub fn undo(self: *TextEditor) bool {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);

        if (self.file_state == .closed) {
            return false;
        }

        if (self.undo_history_pos == 0) {
            return false; // Nothing to undo
        }

        self.undo_history_pos -= 1;
        const entry = &self.undo_history[self.undo_history_pos];

        // Restore cursor position
        self.cursor.line = entry.line;
        self.cursor.column = entry.column;

        // Apply undo based on action type
        switch (entry.action) {
            .insert => {
                // Undo insert: delete the text
                if (entry.text_len > 0) {
                    _ = self.delete_text_internal(entry.text_len, false);
                }
            },
            .delete => {
                // Undo delete: insert the text back
                if (entry.text_len > 0) {
                    _ = self.insert_text_internal(entry.text[0..entry.text_len], false);
                }
            },
            .newline => {
                // Undo newline: remove the line break
                if (self.lines_len > 0 and self.cursor.line < self.lines_len - 1) {
                    // Merge with next line
                    const current = &self.lines[self.cursor.line];
                    const next = &self.lines[self.cursor.line + 1];
                    const remaining = MAX_LINE_LEN - current.content_len;
                    const merge_len = @min(next.content_len, remaining);
                    if (merge_len > 0) {
                        @memcpy(
                            current.content[current.content_len..current.content_len + merge_len],
                            next.content[0..merge_len],
                        );
                        current.content_len += merge_len;
                    }
                    // Remove next line
                    var i: u32 = self.cursor.line + 1;
                    while (i < self.lines_len - 1) : (i += 1) {
                        self.lines[i] = self.lines[i + 1];
                    }
                    self.lines_len -= 1;
                }
            },
            .backspace => {
                // Undo backspace: insert the text back
                if (entry.text_len > 0) {
                    _ = self.insert_text_internal(entry.text[0..entry.text_len], false);
                }
            },
        }

        // Mark as dirty
        self.file_state = .dirty;

        return true;
    }

    /// Redo last undone action.
    // 2025-12-20-175102-pst: Phase 18 Undo/Redo
    pub fn redo(self: *TextEditor) bool {
        // Precondition: File must be open
        std.debug.assert(self.file_state != .closed);

        if (self.file_state == .closed) {
            return false;
        }

        if (self.undo_history_pos >= self.undo_history_len) {
            return false; // Nothing to redo
        }

        const entry = &self.undo_history[self.undo_history_pos];
        self.undo_history_pos += 1;

        // Restore cursor position
        self.cursor.line = entry.line;
        self.cursor.column = entry.column;

        // Apply redo based on action type
        switch (entry.action) {
            .insert => {
                // Redo insert: insert the text
                if (entry.text_len > 0) {
                    _ = self.insert_text_internal(entry.text[0..entry.text_len], false);
                }
            },
            .delete => {
                // Redo delete: delete the text
                if (entry.text_len > 0) {
                    _ = self.delete_text_internal(entry.text_len, false);
                }
            },
            .newline => {
                // Redo newline: insert line break
                if (self.lines_len < MAX_LINES) {
                    // Split line at cursor
                    const current = &self.lines[self.cursor.line];
                    const split_pos = self.cursor.column;
                    if (split_pos < current.content_len) {
                        // Create new line with remaining content
                        const new_line = &self.lines[self.lines_len];
                        const remaining = current.content_len - split_pos;
                        @memcpy(new_line.content[0..remaining], current.content[split_pos..current.content_len]);
                        new_line.content_len = remaining;
                        // Truncate current line
                        current.content_len = split_pos;
                        self.lines_len += 1;
                    }
                }
            },
            .backspace => {
                // Redo backspace: delete the text
                if (entry.text_len > 0) {
                    _ = self.delete_text_internal(entry.text_len, false);
                }
            },
        }

        // Mark as dirty
        self.file_state = .dirty;

        return true;
    }

    /// Start text selection at cursor position.
    // 2025-12-23-194527-pst: Phase 30 Text Selection
    pub fn start_selection(self: *TextEditor) void {
        std.debug.assert(self.lines_len > 0);
        std.debug.assert(self.cursor.line < self.lines_len);

        self.selection.start = self.cursor;
        self.selection.end = self.cursor;
        self.selection.active = true;

        std.debug.assert(self.selection.active);
    }

    /// Extend selection to cursor position.
    // 2025-12-23-194527-pst: Phase 30 Text Selection
    pub fn extend_selection(self: *TextEditor) void {
        std.debug.assert(self.lines_len > 0);
        std.debug.assert(self.cursor.line < self.lines_len);

        if (!self.selection.active) {
            self.start_selection();
            return;
        }

        self.selection.end = self.cursor;
        self.selection.normalize();

        std.debug.assert(self.selection.active);
    }

    /// Clear selection.
    // 2025-12-23-194527-pst: Phase 30 Text Selection
    pub fn clear_selection(self: *TextEditor) void {
        self.selection.active = false;
        self.selection.start = CursorPosition.init();
        self.selection.end = CursorPosition.init();
    }

    /// Select all text.
    // 2025-12-23-194527-pst: Phase 30 Text Selection
    pub fn select_all(self: *TextEditor) void {
        std.debug.assert(self.lines_len > 0);

        if (self.lines_len == 0) {
            self.clear_selection();
            return;
        }

        // Start at beginning of first line
        self.selection.start.line = 0;
        self.selection.start.column = 0;

        // End at end of last line
        const last_line_idx = self.lines_len - 1;
        self.selection.end.line = last_line_idx;
        self.selection.end.column = self.lines[last_line_idx].content_len;
        self.selection.active = true;

        // Move cursor to end
        self.cursor = self.selection.end;

        std.debug.assert(self.selection.active);
    }

    /// Check if selection is active.
    // 2025-12-23-194527-pst: Phase 30 Text Selection
    pub fn has_selection(self: *const TextEditor) bool {
        return self.selection.active;
    }

    /// Get selected text.
    // 2025-12-23-194527-pst: Phase 30 Text Selection
    pub fn get_selected_text(self: *const TextEditor, buffer: []u8, buffer_len: *u32) bool {
        std.debug.assert(buffer.len > 0);

        if (!self.selection.active) {
            buffer_len.* = 0;
            return false;
        }

        // Normalize selection (ensure start is before end)
        var start = self.selection.start;
        var end = self.selection.end;
        if (start.line > end.line or
            (start.line == end.line and start.column > end.column))
        {
            const temp = start;
            start = end;
            end = temp;
        }

        if (start.line >= self.lines_len or end.line >= self.lines_len) {
            buffer_len.* = 0;
            return false;
        }

        var total_len: u32 = 0;
        var line_idx = start.line;

        while (line_idx <= end.line) : (line_idx += 1) {
            const line = &self.lines[line_idx];
            const start_col = if (line_idx == start.line) start.column else 0;
            const end_col = if (line_idx == end.line) end.column else line.content_len;

            if (end_col > start_col) {
                const line_text_len = end_col - start_col;
                if (total_len + line_text_len > buffer.len) {
                    buffer_len.* = total_len;
                    return false;
                }
                @memcpy(buffer[total_len..total_len + line_text_len],
                    line.content[start_col..end_col]);
                total_len += line_text_len;
            }

            // Add newline between lines (except after last line)
            if (line_idx < end.line) {
                if (total_len >= buffer.len) {
                    buffer_len.* = total_len;
                    return false;
                }
                buffer[total_len] = '\n';
                total_len += 1;
            }
        }

        buffer_len.* = total_len;
        std.debug.assert(total_len <= buffer.len);

        return true;
    }

    /// Copy selected text to clipboard.
    // 2025-12-23-194527-pst: Phase 30 Text Selection
    pub fn copy_selection(self: *TextEditor) bool {
        std.debug.assert(self.lines_len > 0);

        if (!self.selection.active) {
            return false;
        }

        var text_len: u32 = 0;
        const copied = self.get_selected_text(&self.clipboard, &text_len);
        if (!copied) {
            return false;
        }

        if (text_len > MAX_CLIPBOARD_SIZE) {
            return false;
        }

        self.clipboard_len = text_len;

        std.debug.assert(self.clipboard_len <= MAX_CLIPBOARD_SIZE);

        return true;
    }

    /// Cut selected text (copy and delete).
    // 2025-12-23-194527-pst: Phase 30 Text Selection
    pub fn cut_selection(self: *TextEditor) bool {
        std.debug.assert(self.lines_len > 0);

        if (!self.selection.active) {
            return false;
        }

        // Copy to clipboard
        if (!self.copy_selection()) {
            return false;
        }

        // Delete selected text
        if (!self.delete_selection()) {
            return false;
        }

        return true;
    }

    /// Delete selected text.
    // 2025-12-23-194527-pst: Phase 30 Text Selection
    pub fn delete_selection(self: *TextEditor) bool {
        std.debug.assert(self.lines_len > 0);

        if (!self.selection.active) {
            return false;
        }

        var sel = self.selection;
        sel.normalize();

        if (!sel.is_valid(self.lines_len)) {
            return false;
        }

        // Move cursor to selection start
        self.cursor = sel.start;

        // Delete text from start to end
        if (sel.start.line == sel.end.line) {
            // Single line selection
            const line = &self.lines[sel.start.line];
            const start_col = sel.start.column;
            const end_col = sel.end.column;

            if (end_col > start_col and end_col <= line.content_len) {
                const remaining = line.content_len - end_col;
                if (remaining > 0) {
                    @memcpy(line.content[start_col..start_col + remaining],
                        line.content[end_col..line.content_len]);
                }
                line.content_len -= (end_col - start_col);
            }
        } else {
            // Multi-line selection
            const start_line = &self.lines[sel.start.line];
            const end_line = &self.lines[sel.end.line];

            // Merge start and end lines
            const start_remaining = start_line.content_len - sel.start.column;
            const end_remaining = end_line.content_len - sel.end.column;

            if (start_remaining + end_remaining > MAX_LINE_LEN) {
                return false;
            }

            // Copy end line remaining content to start line
            if (end_remaining > 0) {
                @memcpy(start_line.content[sel.start.column..sel.start.column + end_remaining],
                    end_line.content[sel.end.column..end_line.content_len]);
            }
            start_line.content_len = sel.start.column + end_remaining;

            // Delete lines between start and end
            const lines_to_delete = sel.end.line - sel.start.line;
            var i: u32 = 0;
            while (i < lines_to_delete) : (i += 1) {
                const delete_idx = sel.start.line + 1;
                var j: u32 = delete_idx;
                while (j < self.lines_len) : (j += 1) {
                    self.lines[j - 1] = self.lines[j];
                }
                self.lines_len -= 1;
            }
        }

        // Clear selection
        self.clear_selection();

        // Mark as dirty
        self.file_state = .dirty;

        std.debug.assert(self.lines_len > 0);

        return true;
    }

    /// Paste text from clipboard at cursor position.
    // 2025-12-23-194527-pst: Phase 30 Text Selection
    pub fn paste(self: *TextEditor) bool {
        std.debug.assert(self.lines_len > 0);

        if (self.clipboard_len == 0) {
            return false;
        }

        // Delete selection if active
        if (self.selection.active) {
            _ = self.delete_selection();
        }

        // Insert clipboard content
        const pasted = self.insert_text(self.clipboard[0..self.clipboard_len]);
        if (!pasted) {
            return false;
        }

        return true;
    }

    /// Check if current file is a Zig file (by extension).
    // 2025-12-23-210000-pst: Phase 31 Syntax Highlighting
    pub fn is_zig_file(self: *const TextEditor) bool {
        std.debug.assert(self.file_path_len > 0);

        if (self.file_path_len < 4) {
            return false; // ".zig" is 4 chars
        }

        const ext_start = self.file_path_len - 4;
        const ext = self.file_path[ext_start..self.file_path_len];
        return std.mem.eql(u8, ext, ".zig");
    }

    /// Toggle syntax highlighting on/off.
    // 2025-12-23-210000-pst: Phase 31 Syntax Highlighting
    pub fn toggle_syntax_highlighting(self: *TextEditor) void {
        self.syntax_highlighting_enabled = !self.syntax_highlighting_enabled;
    }

    /// Highlight a line of Zig code and return tokens.
    // 2025-12-23-210000-pst: Phase 31 Syntax Highlighting
    pub fn highlight_zig_line(
        self: *const TextEditor,
        line_content: []const u8,
        tokens: []SyntaxToken,
        tokens_len: *u32,
    ) bool {
        std.debug.assert(tokens.len <= MAX_SYNTAX_TOKENS_PER_LINE);
        std.debug.assert(tokens_len != null);

        tokens_len.* = 0;

        if (line_content.len == 0) {
            return true;
        }

        // Zig keywords
        const zig_keywords = [_][]const u8{
            "const", "var", "fn", "pub", "priv", "export", "extern", "inline",
            "noinline", "comptime", "anytype", "anyframe", "async", "await",
            "suspend", "resume", "defer", "errdefer", "if", "else", "switch",
            "while", "for", "break", "continue", "return", "try", "catch",
            "orelse", "and", "or", "struct", "enum", "union", "error", "opaque",
            "packed", "test", "usingnamespace", "align", "linksection",
            "callconv", "allowzero", "volatile", "threadlocal", "addrspace",
        };

        var i: u32 = 0;
        var in_string = false;
        var string_char: u8 = 0; // ' or "
        var in_raw_string = false;
        var token_start: u32 = 0;
        var token_type: SyntaxTokenType = .normal;

        while (i < line_content.len and tokens_len.* < tokens.len) : (i += 1) {
            const ch = line_content[i];
            const is_whitespace = (ch == ' ' or ch == '\t' or ch == '\r');

            // Handle comments
            if (!in_string and !in_raw_string) {
                if (i + 1 < line_content.len and line_content[i] == '/' and
                    line_content[i + 1] == '/')
                {
                    // Finish previous token
                    if (token_start < i and tokens_len.* < tokens.len) {
                        tokens[tokens_len.*] = SyntaxToken{
                            .start = token_start,
                            .end = i,
                            .token_type = token_type,
                        };
                        tokens_len.* += 1;
                    }
                    // Comment spans rest of line
                    if (tokens_len.* < tokens.len) {
                        tokens[tokens_len.*] = SyntaxToken{
                            .start = i,
                            .end = @as(u32, @intCast(line_content.len)),
                            .token_type = .comment,
                        };
                        tokens_len.* += 1;
                    }
                    break;
                }
            }

            // Handle strings
            if (!in_string and !in_raw_string) {
                if (ch == '"' or ch == '\'') {
                    // Finish previous token
                    if (token_start < i and tokens_len.* < tokens.len) {
                        tokens[tokens_len.*] = SyntaxToken{
                            .start = token_start,
                            .end = i,
                            .token_type = token_type,
                        };
                        tokens_len.* += 1;
                    }
                    token_start = i;
                    token_type = .string_literal;
                    in_string = true;
                    string_char = ch;
                    // Check for raw string (c"...")
                    if (i + 1 < line_content.len and line_content[i + 1] == 'c' and
                        i + 2 < line_content.len and line_content[i + 2] == ch)
                    {
                        in_raw_string = true;
                        i += 2;
                    }
                }
            } else if (in_string) {
                if (ch == string_char) {
                    // End string
                    if (tokens_len.* < tokens.len) {
                        tokens[tokens_len.*] = SyntaxToken{
                            .start = token_start,
                            .end = i + 1,
                            .token_type = .string_literal,
                        };
                        tokens_len.* += 1;
                    }
                    in_string = false;
                    token_start = i + 1;
                    token_type = .normal;
                } else if (ch == '\\' and i + 1 < line_content.len) {
                    // Escape sequence
                    i += 1;
                }
            } else if (in_raw_string) {
                if (ch == string_char and i + 1 < line_content.len and
                    line_content[i + 1] == 'c' and i + 2 < line_content.len and
                    line_content[i + 2] == string_char)
                {
                    // End raw string
                    if (tokens_len.* < tokens.len) {
                        tokens[tokens_len.*] = SyntaxToken{
                            .start = token_start,
                            .end = i + 3,
                            .token_type = .string_literal,
                        };
                        tokens_len.* += 1;
                    }
                    in_raw_string = false;
                    i += 2;
                    token_start = i + 1;
                    token_type = .normal;
                }
            }

            // Handle numbers and identifiers
            if (!in_string and !in_raw_string) {
                if ((ch >= '0' and ch <= '9') or
                    (ch == '0' and i + 1 < line_content.len and
                    (line_content[i + 1] == 'x' or line_content[i + 1] == 'b' or
                    line_content[i + 1] == 'o')))
                {
                    if (token_type != .number_literal) {
                        if (token_start < i and tokens_len.* < tokens.len) {
                            tokens[tokens_len.*] = SyntaxToken{
                                .start = token_start,
                                .end = i,
                                .token_type = token_type,
                            };
                            tokens_len.* += 1;
                        }
                        token_start = i;
                        token_type = .number_literal;
                    }
                } else if (is_whitespace or is_operator_or_punctuation(ch)) {
                    // Finish current token
                    if (token_start < i and tokens_len.* < tokens.len) {
                        // Check if it's a keyword
                        const word_start = token_start;
                        const word_end = i;
                        if (word_end > word_start) {
                            var is_keyword = false;
                            for (zig_keywords) |keyword| {
                                if (word_end - word_start == keyword.len) {
                                    var match = true;
                                    var j: u32 = 0;
                                    while (j < keyword.len) : (j += 1) {
                                        if (line_content[word_start + j] != keyword[j]) {
                                            match = false;
                                            break;
                                        }
                                    }
                                    if (match) {
                                        is_keyword = true;
                                        break;
                                    }
                                }
                            }
                            tokens[tokens_len.*] = SyntaxToken{
                                .start = word_start,
                                .end = word_end,
                                .token_type = if (is_keyword) .keyword else token_type,
                            };
                            tokens_len.* += 1;
                        }
                    }
                    // Handle operators/punctuation
                    if (is_operator_or_punctuation(ch) and tokens_len.* < tokens.len) {
                        tokens[tokens_len.*] = SyntaxToken{
                            .start = i,
                            .end = i + 1,
                            .token_type = if (is_operator(ch)) .operator else .punctuation,
                        };
                        tokens_len.* += 1;
                    }
                    token_start = i + 1;
                    token_type = .normal;
                } else {
                    // Continue identifier
                    if (token_type != .identifier and token_type != .keyword) {
                        if (token_start < i and tokens_len.* < tokens.len) {
                            tokens[tokens_len.*] = SyntaxToken{
                                .start = token_start,
                                .end = i,
                                .token_type = token_type,
                            };
                            tokens_len.* += 1;
                        }
                        token_start = i;
                        token_type = .identifier;
                    }
                }
            }
        }

        // Finish last token
        if (token_start < line_content.len and tokens_len.* < tokens.len) {
            // Check if it's a keyword
            const word_start = token_start;
            const word_end = @as(u32, @intCast(line_content.len));
            if (word_end > word_start) {
                var is_keyword = false;
                for (zig_keywords) |keyword| {
                    if (word_end - word_start == keyword.len) {
                        var match = true;
                        var j: u32 = 0;
                        while (j < keyword.len) : (j += 1) {
                            if (line_content[word_start + j] != keyword[j]) {
                                match = false;
                                break;
                            }
                        }
                        if (match) {
                            is_keyword = true;
                            break;
                        }
                    }
                }
                tokens[tokens_len.*] = SyntaxToken{
                    .start = word_start,
                    .end = word_end,
                    .token_type = if (is_keyword) .keyword else token_type,
                };
                tokens_len.* += 1;
            }
        }

        return true;
    }

    /// Check if character is an operator.
    // 2025-12-23-210000-pst: Phase 31 Syntax Highlighting
    fn is_operator(ch: u8) bool {
        return (ch == '+' or ch == '-' or ch == '*' or ch == '/' or ch == '%' or
            ch == '=' or ch == '!' or ch == '<' or ch == '>' or ch == '&' or
            ch == '|' or ch == '^' or ch == '~' or ch == '?');
    }

    /// Check if character is operator or punctuation.
    // 2025-12-23-210000-pst: Phase 31 Syntax Highlighting
    fn is_operator_or_punctuation(ch: u8) bool {
        return (is_operator(ch) or ch == '{' or ch == '}' or ch == '(' or
            ch == ')' or ch == '[' or ch == ']' or ch == ',' or ch == ';' or
            ch == ':' or ch == '.' or ch == '?');
    }

    /// Toggle bracket matching on/off.
    // 2025-12-28-223816-pst: Phase 33 Bracket Matching
    pub fn toggle_bracket_matching(self: *TextEditor) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.bracket_matching_enabled = !self.bracket_matching_enabled;
        if (!self.bracket_matching_enabled) {
            self.bracket_match = BracketMatch.init();
        }
        std.debug.assert(self.bracket_match.found == false or self.bracket_matching_enabled);
    }

    /// Find matching bracket at cursor position.
    // 2025-12-28-223816-pst: Phase 33 Bracket Matching
    pub fn find_matching_bracket(self: *TextEditor) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(self.lines_len > 0);
        std.debug.assert(self.cursor.line < self.lines_len);

        if (!self.bracket_matching_enabled) {
            self.bracket_match = BracketMatch.init();
            return;
        }

        // Reset match
        self.bracket_match = BracketMatch.init();

        // Get bracket pairs
        const pairs = [_]BracketPair{
            BracketPair.init('{', '}'),
            BracketPair.init('(', ')'),
            BracketPair.init('[', ']'),
        };

        // Get current line and column
        const current_line = &self.lines[self.cursor.line];
        const line_content = current_line.content[0..current_line.content_len];
        const cursor_col = self.cursor.column;

        // Check if cursor is on a bracket
        if (cursor_col >= line_content.len) {
            return;
        }

        const ch = line_content[cursor_col];
        var bracket_pair: ?BracketPair = null;
        var is_opening: bool = false;

        // Find which bracket pair this character belongs to
        for (pairs) |pair| {
            if (ch == pair.open) {
                bracket_pair = pair;
                is_opening = true;
                break;
            } else if (ch == pair.close) {
                bracket_pair = pair;
                is_opening = false;
                break;
            }
        }

        if (bracket_pair == null) {
            return;
        }

        const pair = bracket_pair.?;

        // Find matching bracket
        if (is_opening) {
            // Search forward for closing bracket
            var depth: u32 = 1;
            var line_idx = self.cursor.line;
            var col_idx = cursor_col + 1;

            while (line_idx < self.lines_len) {
                const line = &self.lines[line_idx];
                const content = line.content[0..line.content_len];

                while (col_idx < content.len) {
                    const current_ch = content[col_idx];
                    if (current_ch == pair.open) {
                        depth += 1;
                    } else if (current_ch == pair.close) {
                        depth -= 1;
                        if (depth == 0) {
                            self.bracket_match.found = true;
                            self.bracket_match.line = line_idx;
                            self.bracket_match.column = col_idx;
                            self.bracket_match.is_opening = true;
                            return;
                        }
                    }
                    col_idx += 1;
                }
                line_idx += 1;
                col_idx = 0;
            }
        } else {
            // Search backward for opening bracket
            var depth: u32 = 1;
            var line_idx = self.cursor.line;
            var col_idx = if (cursor_col > 0) cursor_col - 1 else 0;

            while (true) {
                const line = &self.lines[line_idx];
                const content = line.content[0..line.content_len];

                while (col_idx < content.len) {
                    const current_ch = content[col_idx];
                    if (current_ch == pair.close) {
                        depth += 1;
                    } else if (current_ch == pair.open) {
                        depth -= 1;
                        if (depth == 0) {
                            self.bracket_match.found = true;
                            self.bracket_match.line = line_idx;
                            self.bracket_match.column = col_idx;
                            self.bracket_match.is_opening = false;
                            return;
                        }
                    }
                    if (col_idx == 0) {
                        break;
                    }
                    col_idx -= 1;
                }

                if (line_idx == 0) {
                    break;
                }
                line_idx -= 1;
                col_idx = if (self.lines[line_idx].content_len > 0) self.lines[line_idx].content_len - 1 else 0;
            }
        }
    }

    /// Toggle code folding on/off.
    // 2025-12-29-001544-pst: Phase 35 Code Folding
    pub fn toggle_code_folding(self: *TextEditor) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.code_folding_enabled = !self.code_folding_enabled;
        if (!self.code_folding_enabled) {
            self.fold_ranges_len = 0;
        }
        std.debug.assert(self.fold_ranges_len == 0 or self.code_folding_enabled);
    }

    /// Detect code blocks and create fold ranges.
    // 2025-12-29-001544-pst: Phase 35 Code Folding
    pub fn detect_fold_ranges(self: *TextEditor) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(self.lines_len > 0);

        if (!self.code_folding_enabled) {
            self.fold_ranges_len = 0;
            return;
        }

        self.fold_ranges_len = 0;

        var line_idx: u32 = 0;
        var depth: u32 = 0;
        var block_start: ?u32 = null;

        while (line_idx < self.lines_len and self.fold_ranges_len < MAX_FOLD_RANGES) : (line_idx += 1) {
            const line = &self.lines[line_idx];
            const content = line.content[0..line.content_len];

            var i: u32 = 0;
            while (i < content.len) : (i += 1) {
                if (content[i] == '{') {
                    if (block_start == null) {
                        block_start = line_idx;
                    }
                    depth += 1;
                } else if (content[i] == '}') {
                    if (depth > 0) {
                        depth -= 1;
                        if (depth == 0 and block_start != null) {
                            const start = block_start.?;
                            if (line_idx > start) {
                                self.fold_ranges[self.fold_ranges_len] = FoldRange.init(start, line_idx, 0);
                                self.fold_ranges_len += 1;
                            }
                            block_start = null;
                        }
                    }
                }
            }
        }
    }

    /// Toggle fold state at a specific line.
    // 2025-12-29-001544-pst: Phase 35 Code Folding
    pub fn toggle_fold(self: *TextEditor, line_idx: u32) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(self.lines_len > 0);
        std.debug.assert(line_idx < self.lines_len);

        if (!self.code_folding_enabled) {
            return false;
        }

        var i: u32 = 0;
        while (i < self.fold_ranges_len) : (i += 1) {
            const range = &self.fold_ranges[i];
            if (range.start_line == line_idx) {
                range.toggle();
                return true;
            }
        }

        return false;
    }

    /// Check if a line is folded.
    // 2025-12-29-001544-pst: Phase 35 Code Folding
    pub fn is_folded(self: *const TextEditor, line_idx: u32) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(line_idx < self.lines_len);

        if (!self.code_folding_enabled) {
            return false;
        }

        var i: u32 = 0;
        while (i < self.fold_ranges_len) : (i += 1) {
            const range = &self.fold_ranges[i];
            if (range.folded and line_idx > range.start_line and line_idx <= range.end_line) {
                return true;
            }
        }

        return false;
    }

    /// Fold all foldable blocks.
    // 2025-12-29-001544-pst: Phase 35 Code Folding
    pub fn fold_all(self: *TextEditor) void {
        std.debug.assert(@intFromPtr(self) != 0);

        if (!self.code_folding_enabled) {
            return;
        }

        var i: u32 = 0;
        while (i < self.fold_ranges_len) : (i += 1) {
            self.fold_ranges[i].folded = true;
        }
    }

    /// Get fold indicator information for a line (for visual rendering).
    // 2025-12-29-152539-pst: Phase 37 Visual Fold Indicators
    pub fn get_fold_indicator(self: *const TextEditor, line_idx: u32) struct { has_indicator: bool, is_folded: bool, fold_level: u32 } {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(line_idx < self.lines_len);

        if (!self.code_folding_enabled) {
            return .{ .has_indicator = false, .is_folded = false, .fold_level = 0 };
        }

        var i: u32 = 0;
        while (i < self.fold_ranges_len) : (i += 1) {
            const range = &self.fold_ranges[i];
            if (range.start_line == line_idx) {
                return .{ .has_indicator = true, .is_folded = range.folded, .fold_level = range.fold_level };
            }
        }

        return .{ .has_indicator = false, .is_folded = false, .fold_level = 0 };
    }

    /// Check if a line is a fold start line (has a foldable block starting at it).
    // 2025-12-29-152539-pst: Phase 37 Visual Fold Indicators
    pub fn is_fold_start_line(self: *const TextEditor, line_idx: u32) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(line_idx < self.lines_len);

        if (!self.code_folding_enabled) {
            return false;
        }

        var i: u32 = 0;
        while (i < self.fold_ranges_len) : (i += 1) {
            if (self.fold_ranges[i].start_line == line_idx) {
                return true;
            }
        }

        return false;
    }

    /// Unfold all folded blocks.
    // 2025-12-29-001544-pst: Phase 35 Code Folding
    pub fn unfold_all(self: *TextEditor) void {
        std.debug.assert(@intFromPtr(self) != 0);

        if (!self.code_folding_enabled) {
            return;
        }

        var i: u32 = 0;
        while (i < self.fold_ranges_len) : (i += 1) {
            self.fold_ranges[i].folded = false;
        }
    }
};
