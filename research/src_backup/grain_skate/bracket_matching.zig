//! Bracket Matching: Find and highlight matching brackets/parentheses/braces.
//!
//! Why: Help users navigate nested code structures by highlighting matching brackets.
//! Architecture: Iterative bracket matching using stack-based algorithm.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-162613-pst: Active implementation

const std = @import("std");
const Editor = @import("editor.zig").Editor;

// Bounded: Max bracket stack depth (explicit limit)
// 2025-12-03-162613-pst: Active constant
pub const MAX_BRACKET_STACK_DEPTH: u32 = 1024;

// Bracket type enumeration.
// 2025-12-03-162613-pst: Active enum
pub const BracketType = enum(u8) {
    none, // No bracket
    paren_open, // (
    paren_close, // )
    bracket_open, // [
    bracket_close, // ]
    brace_open, // {
    brace_close, // }
    angle_open, // <
    angle_close, // >
};

// Bracket match result.
// 2025-12-03-162613-pst: Active struct
pub const BracketMatch = struct {
    found: bool, // Whether a match was found
    line: u32, // Line index of matching bracket (0-indexed)
    column: u32, // Column index of matching bracket (0-indexed)
    
    /// Initialize empty bracket match (no match found).
    // 2025-12-03-162613-pst: Active function
    pub fn no_match() BracketMatch {
        return BracketMatch{
            .found = false,
            .line = 0,
            .column = 0,
        };
    }
    
    /// Initialize bracket match with position.
    // 2025-12-03-162613-pst: Active function
    pub fn init(line: u32, column: u32) BracketMatch {
        std.debug.assert(line < Editor.MAX_BUFFER_SIZE / Editor.MAX_LINE_LEN); // Precondition
        std.debug.assert(column < Editor.MAX_LINE_LEN); // Precondition
        
        const match = BracketMatch{
            .found = true,
            .line = line,
            .column = column,
        };
        
        std.debug.assert(match.found == true); // Postcondition
        std.debug.assert(match.line < Editor.MAX_BUFFER_SIZE / Editor.MAX_LINE_LEN); // Postcondition
        
        return match;
    }
};

// Bracket matching state.
// 2025-12-03-162613-pst: Active struct
pub const BracketMatcher = struct {
    /// Get bracket type from character.
    // 2025-12-03-162613-pst: Active function
    pub fn get_bracket_type(ch: u8) BracketType {
        return switch (ch) {
            '(' => .paren_open,
            ')' => .paren_close,
            '[' => .bracket_open,
            ']' => .bracket_close,
            '{' => .brace_open,
            '}' => .brace_close,
            '<' => .angle_open,
            '>' => .angle_close,
            else => .none,
        };
    }
    
    /// Check if bracket is opening bracket.
    // 2025-12-03-162613-pst: Active function
    pub fn is_open_bracket(bracket_type: BracketType) bool {
        return switch (bracket_type) {
            .paren_open, .bracket_open, .brace_open, .angle_open => true,
            else => false,
        };
    }
    
    /// Check if bracket is closing bracket.
    // 2025-12-03-162613-pst: Active function
    pub fn is_close_bracket(bracket_type: BracketType) bool {
        return switch (bracket_type) {
            .paren_close, .bracket_close, .brace_close, .angle_close => true,
            else => false,
        };
    }
    
    /// Get matching bracket type (open -> close, close -> open).
    // 2025-12-03-162613-pst: Active function
    pub fn get_matching_bracket(bracket_type: BracketType) BracketType {
        return switch (bracket_type) {
            .paren_open => .paren_close,
            .paren_close => .paren_open,
            .bracket_open => .bracket_close,
            .bracket_close => .bracket_open,
            .brace_open => .brace_close,
            .brace_close => .brace_open,
            .angle_open => .angle_close,
            .angle_close => .angle_open,
            else => .none,
        };
    }
    
    /// Find matching bracket at cursor position (iterative, stack-based).
    // Returns matching bracket position or no match if not found.
    // 2025-12-03-162613-pst: Active function
    pub fn find_matching_bracket(
        editor: *const Editor.EditorState,
        cursor_line: u32,
        cursor_column: u32,
    ) BracketMatch {
        // Precondition: Cursor must be valid
        std.debug.assert(cursor_line < editor.buffer.lines_len);
        std.debug.assert(cursor_column <= Editor.MAX_LINE_LEN);
        
        // Get bracket at cursor position
        if (cursor_line >= editor.buffer.lines_len) {
            return BracketMatch.no_match();
        }
        const line_text = editor.buffer.lines[cursor_line];
        if (cursor_column >= line_text.len) {
            return BracketMatch.no_match();
        }
        const ch = line_text[cursor_column];
        const bracket_type = get_bracket_type(ch);
        
        if (bracket_type == .none) {
            return BracketMatch.no_match();
        }
        
        // Find matching bracket based on bracket type
        if (is_open_bracket(bracket_type)) {
            return find_matching_close_bracket(editor, cursor_line, cursor_column, bracket_type);
        } else if (is_close_bracket(bracket_type)) {
            return find_matching_open_bracket(editor, cursor_line, cursor_column, bracket_type);
        }
        
        return BracketMatch.no_match();
    }
    
    /// Find matching closing bracket for opening bracket (iterative, forward search).
    // 2025-12-03-162613-pst: Active function
    fn find_matching_close_bracket(
        editor: *const Editor.EditorState,
        start_line: u32,
        start_column: u32,
        open_bracket: BracketType,
    ) BracketMatch {
        std.debug.assert(start_line < editor.buffer.lines_len); // Precondition
        std.debug.assert(is_open_bracket(open_bracket)); // Precondition
        
        const close_bracket = get_matching_bracket(open_bracket);
        var depth: u32 = 1; // Track nesting depth (start at 1 for initial bracket)
        
        // Search forward from cursor position
        var line: u32 = start_line;
        var column: u32 = start_column + 1;
        
        while (line < editor.buffer.lines_len) : (line += 1) {
            const line_text = editor.buffer.lines[line];
            const start_col = if (line == start_line) column else 0;
            
            var col: u32 = start_col;
            while (col < line_text.len) : (col += 1) {
                std.debug.assert(depth <= MAX_BRACKET_STACK_DEPTH); // Invariant
                
                const ch = line_text[col];
                const bracket_type = get_bracket_type(ch);
                
                if (bracket_type == open_bracket) {
                    // Found another opening bracket of same type (increase depth)
                    depth += 1;
                    if (depth > MAX_BRACKET_STACK_DEPTH) {
                        return BracketMatch.no_match(); // Stack overflow
                    }
                } else if (bracket_type == close_bracket) {
                    // Found closing bracket of same type (decrease depth)
                    depth -= 1;
                    if (depth == 0) {
                        // Found matching closing bracket
                        std.debug.assert(line < editor.buffer.lines_len); // Postcondition
                        std.debug.assert(col < Editor.MAX_LINE_LEN); // Postcondition
                        return BracketMatch.init(line, col);
                    }
                }
            }
        }
        
        // No matching closing bracket found
        return BracketMatch.no_match();
    }
    
    /// Find matching opening bracket for closing bracket (iterative, backward search).
    // 2025-12-03-162613-pst: Active function
    fn find_matching_open_bracket(
        editor: *const Editor.EditorState,
        start_line: u32,
        start_column: u32,
        close_bracket: BracketType,
    ) BracketMatch {
        std.debug.assert(start_line < editor.buffer.lines_len); // Precondition
        std.debug.assert(is_close_bracket(close_bracket)); // Precondition
        
        const open_bracket = get_matching_bracket(close_bracket);
        var depth: u32 = 1; // Track nesting depth (start at 1 for initial bracket)
        
        // Search backward from cursor position
        var line: u32 = start_line;
        var col: u32 = if (start_column > 0) start_column - 1 else 0;
        
        while (true) {
            if (line >= editor.buffer.lines_len) {
                break;
            }
            const line_text = editor.buffer.lines[line];
            
            // Adjust column for current line (start at end of line if not on start line)
            if (line < start_line) {
                col = if (line_text.len > 0) line_text.len - 1 else 0;
            }
            
            while (true) {
                std.debug.assert(depth <= MAX_BRACKET_STACK_DEPTH); // Invariant
                
                if (col >= line_text.len) {
                    break;
                }
                const ch = line_text[col];
                const bracket_type = get_bracket_type(ch);
                
                if (bracket_type == close_bracket) {
                    // Found another closing bracket of same type (increase depth)
                    depth += 1;
                    if (depth > MAX_BRACKET_STACK_DEPTH) {
                        return BracketMatch.no_match(); // Stack overflow
                    }
                } else if (bracket_type == open_bracket) {
                    // Found opening bracket of same type (decrease depth)
                    depth -= 1;
                    if (depth == 0) {
                        // Found matching opening bracket
                        std.debug.assert(line < editor.buffer.lines_len); // Postcondition
                        std.debug.assert(col < Editor.MAX_LINE_LEN); // Postcondition
                        return BracketMatch.init(line, col);
                    }
                }
                
                if (col == 0) {
                    break;
                }
                col -= 1;
            }
            
            if (line == 0) {
                break;
            }
            line -= 1;
        }
        
        // No matching opening bracket found
        return BracketMatch.no_match();
    }
};

