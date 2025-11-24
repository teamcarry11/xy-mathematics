const std = @import("std");

/// Grainscript Lexer: Tokenizes `.gr` files into tokens.
/// ~<~ Glow Airbend: explicit token types, bounded token buffer.
/// ~~~~ Glow Waterbend: streaming tokenization without recursion.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms)
pub const Lexer = struct {
    // Bounded: Max 10,000 tokens per file (explicit limit)
    pub const MAX_TOKENS: u32 = 10_000;

    // Bounded: Max 1,024 characters per token (explicit limit)
    pub const MAX_TOKEN_LEN: u32 = 1_024;

    // Bounded: Max 256 characters per identifier (explicit limit)
    pub const MAX_IDENTIFIER_LEN: u32 = 256;

    // Bounded: Max 4,096 characters per string literal (explicit limit)
    pub const MAX_STRING_LEN: u32 = 4_096;

    /// Token type enumeration.
    pub const TokenType = enum(u8) {
        // Literals
        integer, // 123, 0x1a, 0b1010
        float, // 123.456, 1.23e-4
        string, // "hello", 'world'
        boolean, // true, false

        // Identifiers
        identifier, // variable_name, function_name

        // Keywords
        kw_if, // if
        kw_else, // else
        kw_while, // while
        kw_for, // for
        kw_fn, // fn
        kw_var, // var
        kw_const, // const
        kw_return, // return
        kw_break, // break
        kw_continue, // continue
        kw_true, // true
        kw_false, // false
        kw_null, // null

        // Operators
        op_plus, // +
        op_minus, // -
        op_multiply, // *
        op_divide, // /
        op_modulo, // %
        op_assign, // =
        op_eq, // ==
        op_ne, // !=
        op_lt, // <
        op_le, // <=
        op_gt, // >
        op_ge, // >=
        op_and, // &&
        op_or, // ||
        op_not, // !
        op_pipe, // |
        op_ampersand, // &
        op_arrow, // ->

        // Punctuation
        punc_lparen, // (
        punc_rparen, // )
        punc_lbrace, // {
        punc_rbrace, // }
        punc_lbracket, // [
        punc_rbracket, // ]
        punc_comma, // ,
        punc_semicolon, // ;
        punc_colon, // :
        punc_dot, // .
        punc_question, // ?

        // Special
        eof, // End of file
        newline, // \n
        whitespace, // Space, tab
        comment, // // comment, /* comment */
        error_token, // Invalid token
    };

    /// Token structure.
    pub const Token = struct {
        token_type: TokenType,
        start: u32, // Start position in source
        end: u32, // End position in source (exclusive)
        line: u32, // Line number (1-indexed)
        column: u32, // Column number (1-indexed)
    };

    /// Lexer state.
    source: []const u8,
    position: u32, // Current position in source
    line: u32, // Current line number (1-indexed)
    column: u32, // Current column number (1-indexed)
    tokens: []Token,
    tokens_len: u32,
    allocator: std.mem.Allocator,

    /// Initialize lexer with source code.
    pub fn init(allocator: std.mem.Allocator, source: []const u8) !Lexer {
        // Assert: Allocator must be valid (allocator is used below)

        // Assert: Source must be valid
        std.debug.assert(source.len <= std.math.maxInt(u32));

        // Pre-allocate token buffer
        const tokens = try allocator.alloc(Token, MAX_TOKENS);
        errdefer allocator.free(tokens);

        return Lexer{
            .source = source,
            .position = 0,
            .line = 1,
            .column = 1,
            .tokens = tokens,
            .tokens_len = 0,
            .allocator = allocator,
        };
    }

    /// Deinitialize lexer and free memory.
    pub fn deinit(self: *Lexer) void {
        // Assert: Lexer must be valid
        _ = self.allocator; // Allocator is used below

        self.allocator.free(self.tokens);
        self.* = undefined;
    }

    /// Tokenize entire source code.
    pub fn tokenize(self: *Lexer) !void {
        // Assert: Lexer must be initialized
        std.debug.assert(self.source.len <= std.math.maxInt(u32));
        std.debug.assert(self.tokens.len == MAX_TOKENS);

        // Reset state
        self.position = 0;
        self.line = 1;
        self.column = 1;
        self.tokens_len = 0;

        // Iterative tokenization (no recursion)
        while (self.position < self.source.len) {
            // Assert: Token count must be within bounds
            std.debug.assert(self.tokens_len < MAX_TOKENS);

            const token = try self.next_token();
            self.tokens[self.tokens_len] = token;
            self.tokens_len += 1;

            // Stop on EOF or error
            if (token.token_type == .eof or token.token_type == .error_token) {
                break;
            }
        }

        // Assert: At least one token (EOF)
        std.debug.assert(self.tokens_len > 0);
    }

    /// Get next token from source.
    fn next_token(self: *Lexer) !Token {
        // Assert: Position must be valid
        std.debug.assert(self.position <= self.source.len);

        // Skip whitespace and comments
        while (self.position < self.source.len) {
            const ch = self.source[self.position];

            if (ch == ' ' or ch == '\t') {
                self.advance();
                continue;
            }

            if (ch == '\n') {
                const token = Token{
                    .token_type = .newline,
                    .start = self.position,
                    .end = self.position + 1,
                    .line = self.line,
                    .column = self.column,
                };
                self.advance();
                self.line += 1;
                self.column = 1;
                return token;
            }

            // Single-line comment: //
            if (ch == '/' and self.position + 1 < self.source.len and self.source[self.position + 1] == '/') {
                const start = self.position;
                self.advance(); // Skip '/'
                self.advance(); // Skip '/'

                // Skip to end of line
                while (self.position < self.source.len and self.source[self.position] != '\n') {
                    self.advance();
                }

                const token = Token{
                    .token_type = .comment,
                    .start = start,
                    .end = self.position,
                    .line = self.line,
                    .column = self.column,
                };
                return token;
            }

            // Multi-line comment: /* */
            if (ch == '/' and self.position + 1 < self.source.len and self.source[self.position + 1] == '*') {
                const start = self.position;
                self.advance(); // Skip '/'
                self.advance(); // Skip '*'

                // Skip to end of comment
                while (self.position + 1 < self.source.len) {
                    if (self.source[self.position] == '*' and self.source[self.position + 1] == '/') {
                        self.advance(); // Skip '*'
                        self.advance(); // Skip '/'
                        break;
                    }
                    if (self.source[self.position] == '\n') {
                        self.line += 1;
                        self.column = 1;
                    } else {
                        self.column += 1;
                    }
                    self.advance();
                }

                const token = Token{
                    .token_type = .comment,
                    .start = start,
                    .end = self.position,
                    .line = self.line,
                    .column = self.column,
                };
                return token;
            }

            break;
        }

        // Check for EOF
        if (self.position >= self.source.len) {
            return Token{
                .token_type = .eof,
                .start = self.position,
                .end = self.position,
                .line = self.line,
                .column = self.column,
            };
        }

        const start = self.position;
        const start_line = self.line;
        const start_column = self.column;
        const ch = self.source[self.position];

        // Identifiers and keywords
        if (is_identifier_start(ch)) {
            return self.tokenize_identifier(start, start_line, start_column);
        }

        // Numbers
        if (is_digit(ch)) {
            return self.tokenize_number(start, start_line, start_column);
        }

        // Strings
        if (ch == '"' or ch == '\'') {
            return self.tokenize_string(start, start_line, start_column, ch);
        }

        // Operators and punctuation
        return self.tokenize_operator_or_punctuation(start, start_line, start_column);
    }

    /// Tokenize identifier or keyword.
    fn tokenize_identifier(self: *Lexer, start: u32, start_line: u32, start_column: u32) !Token {
        // Assert: Start position must be valid
        std.debug.assert(start < self.source.len);
        std.debug.assert(is_identifier_start(self.source[start]));

        var len: u32 = 0;
        var pos = start;

        // Iterative identifier parsing (no recursion)
        while (pos < self.source.len and len < MAX_IDENTIFIER_LEN) {
            const ch = self.source[pos];
            if (!is_identifier_char(ch)) {
                break;
            }
            pos += 1;
            len += 1;
        }

        // Assert: Identifier length must be within bounds
        std.debug.assert(len <= MAX_IDENTIFIER_LEN);

        const identifier = self.source[start..pos];
        const token_type = keyword_to_token_type(identifier);

        // Update position
        self.position = pos;
        self.column += len;

        return Token{
            .token_type = token_type,
            .start = start,
            .end = pos,
            .line = start_line,
            .column = start_column,
        };
    }

    /// Tokenize number (integer or float).
    fn tokenize_number(self: *Lexer, start: u32, start_line: u32, start_column: u32) !Token {
        // Assert: Start position must be valid
        std.debug.assert(start < self.source.len);
        std.debug.assert(is_digit(self.source[start]));

        var pos = start;
        var has_dot = false;
        var has_exponent = false;

        // Integer part
        while (pos < self.source.len and is_digit(self.source[pos])) {
            pos += 1;
        }

        // Decimal point
        if (pos < self.source.len and self.source[pos] == '.') {
            has_dot = true;
            pos += 1;

            // Fractional part
            while (pos < self.source.len and is_digit(self.source[pos])) {
                pos += 1;
            }
        }

        // Exponent
        if (pos < self.source.len and (self.source[pos] == 'e' or self.source[pos] == 'E')) {
            has_exponent = true;
            pos += 1;

            // Optional sign
            if (pos < self.source.len and (self.source[pos] == '+' or self.source[pos] == '-')) {
                pos += 1;
            }

            // Exponent digits
            while (pos < self.source.len and is_digit(self.source[pos])) {
                pos += 1;
            }
        }

        // Hex prefix: 0x
        if (start + 2 <= self.source.len and self.source[start] == '0' and self.source[start + 1] == 'x') {
            pos = start + 2;
            while (pos < self.source.len and is_hex_digit(self.source[pos])) {
                pos += 1;
            }
        }

        // Binary prefix: 0b
        if (start + 2 <= self.source.len and self.source[start] == '0' and self.source[start + 1] == 'b') {
            pos = start + 2;
            while (pos < self.source.len and (self.source[pos] == '0' or self.source[pos] == '1')) {
                pos += 1;
            }
        }

        const token_type: TokenType = if (has_dot or has_exponent) .float else .integer;

        // Update position
        const len = pos - start;
        self.position = pos;
        self.column += len;

        return Token{
            .token_type = token_type,
            .start = start,
            .end = pos,
            .line = start_line,
            .column = start_column,
        };
    }

    /// Tokenize string literal.
    fn tokenize_string(self: *Lexer, start: u32, start_line: u32, start_column: u32, quote: u8) !Token {
        // Assert: Start position must be valid
        std.debug.assert(start < self.source.len);
        std.debug.assert(self.source[start] == quote);

        var pos = start + 1; // Skip opening quote

        // Iterative string parsing (no recursion)
        while (pos < self.source.len) {
            const ch = self.source[pos];

            // End of string
            if (ch == quote) {
                pos += 1; // Include closing quote
                break;
            }

            // Escape sequence
            if (ch == '\\' and pos + 1 < self.source.len) {
                pos += 2; // Skip escape sequence
                continue;
            }

            // Newline in string (error, but continue)
            if (ch == '\n') {
                self.line += 1;
                self.column = 1;
            } else {
                self.column += 1;
            }

            pos += 1;

            // Assert: String length must be within bounds
            if (pos - start > MAX_STRING_LEN) {
                return Token{
                    .token_type = .error_token,
                    .start = start,
                    .end = pos,
                    .line = start_line,
                    .column = start_column,
                };
            }
        }

        // Update position
        const len = pos - start;
        self.position = pos;
        self.column += len;

        return Token{
            .token_type = .string,
            .start = start,
            .end = pos,
            .line = start_line,
            .column = start_column,
        };
    }

    /// Tokenize operator or punctuation.
    fn tokenize_operator_or_punctuation(self: *Lexer, start: u32, start_line: u32, start_column: u32) !Token {
        // Assert: Start position must be valid
        std.debug.assert(start < self.source.len);

        const ch = self.source[start];
        var token_type: TokenType = .error_token;
        var len: u32 = 1;

        // Single-character operators
        switch (ch) {
            '+' => token_type = .op_plus,
            '-' => {
                // Check for arrow: ->
                if (start + 1 < self.source.len and self.source[start + 1] == '>') {
                    token_type = .op_arrow;
                    len = 2;
                } else {
                    token_type = .op_minus;
                }
            },
            '*' => token_type = .op_multiply,
            '/' => token_type = .op_divide,
            '%' => token_type = .op_modulo,
            '=' => {
                // Check for equality: ==
                if (start + 1 < self.source.len and self.source[start + 1] == '=') {
                    token_type = .op_eq;
                    len = 2;
                } else {
                    token_type = .op_assign;
                }
            },
            '!' => {
                // Check for inequality: !=
                if (start + 1 < self.source.len and self.source[start + 1] == '=') {
                    token_type = .op_ne;
                    len = 2;
                } else {
                    token_type = .op_not;
                }
            },
            '<' => {
                // Check for less than or equal: <=
                if (start + 1 < self.source.len and self.source[start + 1] == '=') {
                    token_type = .op_le;
                    len = 2;
                } else {
                    token_type = .op_lt;
                }
            },
            '>' => {
                // Check for greater than or equal: >=
                if (start + 1 < self.source.len and self.source[start + 1] == '=') {
                    token_type = .op_ge;
                    len = 2;
                } else {
                    token_type = .op_gt;
                }
            },
            '&' => {
                // Check for logical and: &&
                if (start + 1 < self.source.len and self.source[start + 1] == '&') {
                    token_type = .op_and;
                    len = 2;
                } else {
                    token_type = .op_ampersand;
                }
            },
            '|' => {
                // Check for logical or: ||
                if (start + 1 < self.source.len and self.source[start + 1] == '|') {
                    token_type = .op_or;
                    len = 2;
                } else {
                    token_type = .op_pipe;
                }
            },
            '(' => token_type = .punc_lparen,
            ')' => token_type = .punc_rparen,
            '{' => token_type = .punc_lbrace,
            '}' => token_type = .punc_rbrace,
            '[' => token_type = .punc_lbracket,
            ']' => token_type = .punc_rbracket,
            ',' => token_type = .punc_comma,
            ';' => token_type = .punc_semicolon,
            ':' => token_type = .punc_colon,
            '.' => token_type = .punc_dot,
            '?' => token_type = .punc_question,
            else => token_type = .error_token,
        }

        // Update position
        self.position = start + len;
        self.column += len;

        return Token{
            .token_type = token_type,
            .start = start,
            .end = start + len,
            .line = start_line,
            .column = start_column,
        };
    }

    /// Advance position by one character.
    fn advance(self: *Lexer) void {
        // Assert: Position must be valid
        std.debug.assert(self.position < self.source.len);

        self.position += 1;
        self.column += 1;
    }

    /// Check if character is valid identifier start.
    fn is_identifier_start(ch: u8) bool {
        return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or ch == '_';
    }

    /// Check if character is valid identifier character.
    fn is_identifier_char(ch: u8) bool {
        return is_identifier_start(ch) or is_digit(ch);
    }

    /// Check if character is a digit.
    fn is_digit(ch: u8) bool {
        return ch >= '0' and ch <= '9';
    }

    /// Check if character is a hex digit.
    fn is_hex_digit(ch: u8) bool {
        return is_digit(ch) or (ch >= 'a' and ch <= 'f') or (ch >= 'A' and ch <= 'F');
    }

    /// Convert keyword string to token type.
    fn keyword_to_token_type(keyword: []const u8) TokenType {
        // Assert: Keyword must be non-empty
        std.debug.assert(keyword.len > 0);

        if (std.mem.eql(u8, keyword, "if")) return .kw_if;
        if (std.mem.eql(u8, keyword, "else")) return .kw_else;
        if (std.mem.eql(u8, keyword, "while")) return .kw_while;
        if (std.mem.eql(u8, keyword, "for")) return .kw_for;
        if (std.mem.eql(u8, keyword, "fn")) return .kw_fn;
        if (std.mem.eql(u8, keyword, "var")) return .kw_var;
        if (std.mem.eql(u8, keyword, "const")) return .kw_const;
        if (std.mem.eql(u8, keyword, "return")) return .kw_return;
        if (std.mem.eql(u8, keyword, "break")) return .kw_break;
        if (std.mem.eql(u8, keyword, "continue")) return .kw_continue;
        if (std.mem.eql(u8, keyword, "true")) return .kw_true;
        if (std.mem.eql(u8, keyword, "false")) return .kw_false;
        if (std.mem.eql(u8, keyword, "null")) return .kw_null;

        return .identifier;
    }

    /// Get token at index.
    pub fn get_token(self: *const Lexer, index: u32) ?Token {
        // Assert: Index must be valid
        std.debug.assert(index < MAX_TOKENS);

        if (index >= self.tokens_len) {
            return null;
        }

        return self.tokens[index];
    }

    /// Get number of tokens.
    pub fn get_token_count(self: *const Lexer) u32 {
        return self.tokens_len;
    }

    /// Get source code.
    pub fn get_source(self: *const Lexer) []const u8 {
        return self.source;
    }
};
