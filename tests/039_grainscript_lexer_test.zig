const std = @import("std");
const testing = std.testing;
const grainscript = @import("grainscript");
const Lexer = grainscript.Lexer;

test "grain.lexer.init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "hello world";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    // Assert: Lexer must be initialized
    std.debug.assert(lexer.source.len == source.len);
    std.debug.assert(lexer.position == 0);
    std.debug.assert(lexer.line == 1);
    std.debug.assert(lexer.column == 1);
    std.debug.assert(lexer.tokens_len == 0);
}

test "grain.lexer.tokenize_identifier" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "hello";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have at least EOF token
    std.debug.assert(lexer.tokens_len > 0);

    const token = lexer.get_token(0);
    std.debug.assert(token != null);
    std.debug.assert(token.?.token_type == .identifier);
    std.debug.assert(token.?.start == 0);
    std.debug.assert(token.?.end == 5);
    std.debug.assert(token.?.line == 1);
    std.debug.assert(token.?.column == 1);
}

test "grain.lexer.tokenize_keywords" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "if else while for fn var const return break continue true false null";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have keywords + EOF
    std.debug.assert(lexer.tokens_len >= 12);

    const expected_types = [_]Lexer.TokenType{
        .kw_if,
        .kw_else,
        .kw_while,
        .kw_for,
        .kw_fn,
        .kw_var,
        .kw_const,
        .kw_return,
        .kw_break,
        .kw_continue,
        .kw_true,
        .kw_false,
        .kw_null,
    };

    for (expected_types, 0..) |expected_type, i| {
        const token = lexer.get_token(@intCast(i));
        std.debug.assert(token != null);
        std.debug.assert(token.?.token_type == expected_type);
    }
}

test "grain.lexer.tokenize_integer" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "123 0x1a 0b1010";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have 3 integer tokens + EOF
    std.debug.assert(lexer.tokens_len >= 3);

    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .integer);
    std.debug.assert(token1.?.start == 0);
    std.debug.assert(token1.?.end == 3);

    const token2 = lexer.get_token(1);
    std.debug.assert(token2 != null);
    std.debug.assert(token2.?.token_type == .integer);
    std.debug.assert(token2.?.start == 4);
    std.debug.assert(token2.?.end == 8);

    const token3 = lexer.get_token(2);
    std.debug.assert(token3 != null);
    std.debug.assert(token3.?.token_type == .integer);
    std.debug.assert(token3.?.start == 9);
    std.debug.assert(token3.?.end == 16);
}

test "grain.lexer.tokenize_float" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "123.456 1.23e-4";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have 2 float tokens + EOF
    std.debug.assert(lexer.tokens_len >= 2);

    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .float);
    std.debug.assert(token1.?.start == 0);
    std.debug.assert(token1.?.end == 7);

    const token2 = lexer.get_token(1);
    std.debug.assert(token2 != null);
    std.debug.assert(token2.?.token_type == .float);
    std.debug.assert(token2.?.start == 8);
    std.debug.assert(token2.?.end == 15);
}

test "grain.lexer.tokenize_string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "\"hello\" 'world'";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have 2 string tokens + EOF
    std.debug.assert(lexer.tokens_len >= 2);

    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .string);
    std.debug.assert(token1.?.start == 0);
    std.debug.assert(token1.?.end == 7);

    const token2 = lexer.get_token(1);
    std.debug.assert(token2 != null);
    std.debug.assert(token2.?.token_type == .string);
    std.debug.assert(token2.?.start == 8);
    std.debug.assert(token2.?.end == 15);
}

test "grain.lexer.tokenize_operators" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "+ - * / % = == != < <= > >= && || ! | & ->";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have operator tokens + EOF
    std.debug.assert(lexer.tokens_len >= 16);

    const expected_types = [_]Lexer.TokenType{
        .op_plus,
        .op_minus,
        .op_multiply,
        .op_divide,
        .op_modulo,
        .op_assign,
        .op_eq,
        .op_ne,
        .op_lt,
        .op_le,
        .op_gt,
        .op_ge,
        .op_and,
        .op_or,
        .op_not,
        .op_pipe,
        .op_ampersand,
        .op_arrow,
    };

    for (expected_types, 0..) |expected_type, i| {
        const token = lexer.get_token(@intCast(i));
        std.debug.assert(token != null);
        std.debug.assert(token.?.token_type == expected_type);
    }
}

test "grain.lexer.tokenize_punctuation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "() {} [] , ; : . ?";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have punctuation tokens + EOF
    std.debug.assert(lexer.tokens_len >= 9);

    const expected_types = [_]Lexer.TokenType{
        .punc_lparen,
        .punc_rparen,
        .punc_lbrace,
        .punc_rbrace,
        .punc_lbracket,
        .punc_rbracket,
        .punc_comma,
        .punc_semicolon,
        .punc_colon,
        .punc_dot,
        .punc_question,
    };

    for (expected_types, 0..) |expected_type, i| {
        const token = lexer.get_token(@intCast(i));
        std.debug.assert(token != null);
        std.debug.assert(token.?.token_type == expected_type);
    }
}

test "grain.lexer.tokenize_comments" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "// single line comment\n/* multi\nline\ncomment */";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have comment tokens + EOF
    std.debug.assert(lexer.tokens_len >= 2);

    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .comment);

    const token2 = lexer.get_token(1);
    std.debug.assert(token2 != null);
    std.debug.assert(token2.?.token_type == .comment);
}

test "grain.lexer.tokenize_newlines" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "hello\nworld\n";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have identifier + newline + identifier + newline + EOF
    std.debug.assert(lexer.tokens_len >= 5);

    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .identifier);
    std.debug.assert(token1.?.line == 1);

    const token2 = lexer.get_token(1);
    std.debug.assert(token2 != null);
    std.debug.assert(token2.?.token_type == .newline);
    std.debug.assert(token2.?.line == 1);

    const token3 = lexer.get_token(2);
    std.debug.assert(token3 != null);
    std.debug.assert(token3.?.token_type == .identifier);
    std.debug.assert(token3.?.line == 2);
}

test "grain.lexer.tokenize_eof" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have EOF token
    std.debug.assert(lexer.tokens_len == 1);

    const token = lexer.get_token(0);
    std.debug.assert(token != null);
    std.debug.assert(token.?.token_type == .eof);
}

test "grain.lexer.tokenize_complex" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source =
        \\fn add(a: i32, b: i32) -> i32 {
        \\    return a + b;
        \\}
    ;
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have tokens
    std.debug.assert(lexer.tokens_len > 0);

    // Check first token: fn
    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .kw_fn);

    // Check last token: EOF
    const last_token = lexer.get_token(lexer.tokens_len - 1);
    std.debug.assert(last_token != null);
    std.debug.assert(last_token.?.token_type == .eof);
}


const grainscript = @import("grainscript");
const Lexer = grainscript.Lexer;

test "grain.lexer.init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "hello world";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    // Assert: Lexer must be initialized
    std.debug.assert(lexer.source.len == source.len);
    std.debug.assert(lexer.position == 0);
    std.debug.assert(lexer.line == 1);
    std.debug.assert(lexer.column == 1);
    std.debug.assert(lexer.tokens_len == 0);
}

test "grain.lexer.tokenize_identifier" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "hello";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have at least EOF token
    std.debug.assert(lexer.tokens_len > 0);

    const token = lexer.get_token(0);
    std.debug.assert(token != null);
    std.debug.assert(token.?.token_type == .identifier);
    std.debug.assert(token.?.start == 0);
    std.debug.assert(token.?.end == 5);
    std.debug.assert(token.?.line == 1);
    std.debug.assert(token.?.column == 1);
}

test "grain.lexer.tokenize_keywords" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "if else while for fn var const return break continue true false null";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have keywords + EOF
    std.debug.assert(lexer.tokens_len >= 12);

    const expected_types = [_]Lexer.TokenType{
        .kw_if,
        .kw_else,
        .kw_while,
        .kw_for,
        .kw_fn,
        .kw_var,
        .kw_const,
        .kw_return,
        .kw_break,
        .kw_continue,
        .kw_true,
        .kw_false,
        .kw_null,
    };

    for (expected_types, 0..) |expected_type, i| {
        const token = lexer.get_token(@intCast(i));
        std.debug.assert(token != null);
        std.debug.assert(token.?.token_type == expected_type);
    }
}

test "grain.lexer.tokenize_integer" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "123 0x1a 0b1010";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have 3 integer tokens + EOF
    std.debug.assert(lexer.tokens_len >= 3);

    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .integer);
    std.debug.assert(token1.?.start == 0);
    std.debug.assert(token1.?.end == 3);

    const token2 = lexer.get_token(1);
    std.debug.assert(token2 != null);
    std.debug.assert(token2.?.token_type == .integer);
    std.debug.assert(token2.?.start == 4);
    std.debug.assert(token2.?.end == 8);

    const token3 = lexer.get_token(2);
    std.debug.assert(token3 != null);
    std.debug.assert(token3.?.token_type == .integer);
    std.debug.assert(token3.?.start == 9);
    std.debug.assert(token3.?.end == 16);
}

test "grain.lexer.tokenize_float" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "123.456 1.23e-4";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have 2 float tokens + EOF
    std.debug.assert(lexer.tokens_len >= 2);

    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .float);
    std.debug.assert(token1.?.start == 0);
    std.debug.assert(token1.?.end == 7);

    const token2 = lexer.get_token(1);
    std.debug.assert(token2 != null);
    std.debug.assert(token2.?.token_type == .float);
    std.debug.assert(token2.?.start == 8);
    std.debug.assert(token2.?.end == 15);
}

test "grain.lexer.tokenize_string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "\"hello\" 'world'";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have 2 string tokens + EOF
    std.debug.assert(lexer.tokens_len >= 2);

    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .string);
    std.debug.assert(token1.?.start == 0);
    std.debug.assert(token1.?.end == 7);

    const token2 = lexer.get_token(1);
    std.debug.assert(token2 != null);
    std.debug.assert(token2.?.token_type == .string);
    std.debug.assert(token2.?.start == 8);
    std.debug.assert(token2.?.end == 15);
}

test "grain.lexer.tokenize_operators" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "+ - * / % = == != < <= > >= && || ! | & ->";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have operator tokens + EOF
    std.debug.assert(lexer.tokens_len >= 16);

    const expected_types = [_]Lexer.TokenType{
        .op_plus,
        .op_minus,
        .op_multiply,
        .op_divide,
        .op_modulo,
        .op_assign,
        .op_eq,
        .op_ne,
        .op_lt,
        .op_le,
        .op_gt,
        .op_ge,
        .op_and,
        .op_or,
        .op_not,
        .op_pipe,
        .op_ampersand,
        .op_arrow,
    };

    for (expected_types, 0..) |expected_type, i| {
        const token = lexer.get_token(@intCast(i));
        std.debug.assert(token != null);
        std.debug.assert(token.?.token_type == expected_type);
    }
}

test "grain.lexer.tokenize_punctuation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "() {} [] , ; : . ?";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have punctuation tokens + EOF
    std.debug.assert(lexer.tokens_len >= 9);

    const expected_types = [_]Lexer.TokenType{
        .punc_lparen,
        .punc_rparen,
        .punc_lbrace,
        .punc_rbrace,
        .punc_lbracket,
        .punc_rbracket,
        .punc_comma,
        .punc_semicolon,
        .punc_colon,
        .punc_dot,
        .punc_question,
    };

    for (expected_types, 0..) |expected_type, i| {
        const token = lexer.get_token(@intCast(i));
        std.debug.assert(token != null);
        std.debug.assert(token.?.token_type == expected_type);
    }
}

test "grain.lexer.tokenize_comments" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "// single line comment\n/* multi\nline\ncomment */";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have comment tokens + EOF
    std.debug.assert(lexer.tokens_len >= 2);

    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .comment);

    const token2 = lexer.get_token(1);
    std.debug.assert(token2 != null);
    std.debug.assert(token2.?.token_type == .comment);
}

test "grain.lexer.tokenize_newlines" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "hello\nworld\n";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have identifier + newline + identifier + newline + EOF
    std.debug.assert(lexer.tokens_len >= 5);

    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .identifier);
    std.debug.assert(token1.?.line == 1);

    const token2 = lexer.get_token(1);
    std.debug.assert(token2 != null);
    std.debug.assert(token2.?.token_type == .newline);
    std.debug.assert(token2.?.line == 1);

    const token3 = lexer.get_token(2);
    std.debug.assert(token3 != null);
    std.debug.assert(token3.?.token_type == .identifier);
    std.debug.assert(token3.?.line == 2);
}

test "grain.lexer.tokenize_eof" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have EOF token
    std.debug.assert(lexer.tokens_len == 1);

    const token = lexer.get_token(0);
    std.debug.assert(token != null);
    std.debug.assert(token.?.token_type == .eof);
}

test "grain.lexer.tokenize_complex" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source =
        \\fn add(a: i32, b: i32) -> i32 {
        \\    return a + b;
        \\}
    ;
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have tokens
    std.debug.assert(lexer.tokens_len > 0);

    // Check first token: fn
    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .kw_fn);

    // Check last token: EOF
    const last_token = lexer.get_token(lexer.tokens_len - 1);
    std.debug.assert(last_token != null);
    std.debug.assert(last_token.?.token_type == .eof);
}


const grainscript = @import("grainscript");
const Lexer = grainscript.Lexer;

test "grain.lexer.init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "hello world";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    // Assert: Lexer must be initialized
    std.debug.assert(lexer.source.len == source.len);
    std.debug.assert(lexer.position == 0);
    std.debug.assert(lexer.line == 1);
    std.debug.assert(lexer.column == 1);
    std.debug.assert(lexer.tokens_len == 0);
}

test "grain.lexer.tokenize_identifier" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "hello";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have at least EOF token
    std.debug.assert(lexer.tokens_len > 0);

    const token = lexer.get_token(0);
    std.debug.assert(token != null);
    std.debug.assert(token.?.token_type == .identifier);
    std.debug.assert(token.?.start == 0);
    std.debug.assert(token.?.end == 5);
    std.debug.assert(token.?.line == 1);
    std.debug.assert(token.?.column == 1);
}

test "grain.lexer.tokenize_keywords" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "if else while for fn var const return break continue true false null";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have keywords + EOF
    std.debug.assert(lexer.tokens_len >= 12);

    const expected_types = [_]Lexer.TokenType{
        .kw_if,
        .kw_else,
        .kw_while,
        .kw_for,
        .kw_fn,
        .kw_var,
        .kw_const,
        .kw_return,
        .kw_break,
        .kw_continue,
        .kw_true,
        .kw_false,
        .kw_null,
    };

    for (expected_types, 0..) |expected_type, i| {
        const token = lexer.get_token(@intCast(i));
        std.debug.assert(token != null);
        std.debug.assert(token.?.token_type == expected_type);
    }
}

test "grain.lexer.tokenize_integer" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "123 0x1a 0b1010";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have 3 integer tokens + EOF
    std.debug.assert(lexer.tokens_len >= 3);

    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .integer);
    std.debug.assert(token1.?.start == 0);
    std.debug.assert(token1.?.end == 3);

    const token2 = lexer.get_token(1);
    std.debug.assert(token2 != null);
    std.debug.assert(token2.?.token_type == .integer);
    std.debug.assert(token2.?.start == 4);
    std.debug.assert(token2.?.end == 8);

    const token3 = lexer.get_token(2);
    std.debug.assert(token3 != null);
    std.debug.assert(token3.?.token_type == .integer);
    std.debug.assert(token3.?.start == 9);
    std.debug.assert(token3.?.end == 16);
}

test "grain.lexer.tokenize_float" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "123.456 1.23e-4";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have 2 float tokens + EOF
    std.debug.assert(lexer.tokens_len >= 2);

    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .float);
    std.debug.assert(token1.?.start == 0);
    std.debug.assert(token1.?.end == 7);

    const token2 = lexer.get_token(1);
    std.debug.assert(token2 != null);
    std.debug.assert(token2.?.token_type == .float);
    std.debug.assert(token2.?.start == 8);
    std.debug.assert(token2.?.end == 15);
}

test "grain.lexer.tokenize_string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "\"hello\" 'world'";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have 2 string tokens + EOF
    std.debug.assert(lexer.tokens_len >= 2);

    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .string);
    std.debug.assert(token1.?.start == 0);
    std.debug.assert(token1.?.end == 7);

    const token2 = lexer.get_token(1);
    std.debug.assert(token2 != null);
    std.debug.assert(token2.?.token_type == .string);
    std.debug.assert(token2.?.start == 8);
    std.debug.assert(token2.?.end == 15);
}

test "grain.lexer.tokenize_operators" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "+ - * / % = == != < <= > >= && || ! | & ->";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have operator tokens + EOF
    std.debug.assert(lexer.tokens_len >= 16);

    const expected_types = [_]Lexer.TokenType{
        .op_plus,
        .op_minus,
        .op_multiply,
        .op_divide,
        .op_modulo,
        .op_assign,
        .op_eq,
        .op_ne,
        .op_lt,
        .op_le,
        .op_gt,
        .op_ge,
        .op_and,
        .op_or,
        .op_not,
        .op_pipe,
        .op_ampersand,
        .op_arrow,
    };

    for (expected_types, 0..) |expected_type, i| {
        const token = lexer.get_token(@intCast(i));
        std.debug.assert(token != null);
        std.debug.assert(token.?.token_type == expected_type);
    }
}

test "grain.lexer.tokenize_punctuation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "() {} [] , ; : . ?";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have punctuation tokens + EOF
    std.debug.assert(lexer.tokens_len >= 9);

    const expected_types = [_]Lexer.TokenType{
        .punc_lparen,
        .punc_rparen,
        .punc_lbrace,
        .punc_rbrace,
        .punc_lbracket,
        .punc_rbracket,
        .punc_comma,
        .punc_semicolon,
        .punc_colon,
        .punc_dot,
        .punc_question,
    };

    for (expected_types, 0..) |expected_type, i| {
        const token = lexer.get_token(@intCast(i));
        std.debug.assert(token != null);
        std.debug.assert(token.?.token_type == expected_type);
    }
}

test "grain.lexer.tokenize_comments" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "// single line comment\n/* multi\nline\ncomment */";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have comment tokens + EOF
    std.debug.assert(lexer.tokens_len >= 2);

    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .comment);

    const token2 = lexer.get_token(1);
    std.debug.assert(token2 != null);
    std.debug.assert(token2.?.token_type == .comment);
}

test "grain.lexer.tokenize_newlines" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "hello\nworld\n";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have identifier + newline + identifier + newline + EOF
    std.debug.assert(lexer.tokens_len >= 5);

    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .identifier);
    std.debug.assert(token1.?.line == 1);

    const token2 = lexer.get_token(1);
    std.debug.assert(token2 != null);
    std.debug.assert(token2.?.token_type == .newline);
    std.debug.assert(token2.?.line == 1);

    const token3 = lexer.get_token(2);
    std.debug.assert(token3 != null);
    std.debug.assert(token3.?.token_type == .identifier);
    std.debug.assert(token3.?.line == 2);
}

test "grain.lexer.tokenize_eof" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have EOF token
    std.debug.assert(lexer.tokens_len == 1);

    const token = lexer.get_token(0);
    std.debug.assert(token != null);
    std.debug.assert(token.?.token_type == .eof);
}

test "grain.lexer.tokenize_complex" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source =
        \\fn add(a: i32, b: i32) -> i32 {
        \\    return a + b;
        \\}
    ;
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    // Assert: Must have tokens
    std.debug.assert(lexer.tokens_len > 0);

    // Check first token: fn
    const token1 = lexer.get_token(0);
    std.debug.assert(token1 != null);
    std.debug.assert(token1.?.token_type == .kw_fn);

    // Check last token: EOF
    const last_token = lexer.get_token(lexer.tokens_len - 1);
    std.debug.assert(last_token != null);
    std.debug.assert(last_token.?.token_type == .eof);
}

