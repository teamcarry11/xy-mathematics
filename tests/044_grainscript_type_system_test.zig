const std = @import("std");
const testing = std.testing;
const grainscript = @import("grainscript");
const Lexer = grainscript.Lexer;
const Parser = grainscript.Parser;
const Interpreter = grainscript.Interpreter;

/// Test explicit type annotations.
test "interpreter explicit type annotations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x: i64 = 42;
        \\var y: string = "hello";
        \\var z: bool = true;
    ;

    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    var interpreter = try Interpreter.init(allocator, &parser);
    defer interpreter.deinit();

    try interpreter.execute();

    try testing.expect(interpreter.get_exit_code() == 0);
}

/// Test type inference.
test "interpreter type inference" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x = 42;
        \\var y = "hello";
        \\var z = true;
        \\var w = 3.14;
    ;

    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    var interpreter = try Interpreter.init(allocator, &parser);
    defer interpreter.deinit();

    try interpreter.execute();

    try testing.expect(interpreter.get_exit_code() == 0);
}

/// Test type checking on assignment.
test "interpreter type checking assignment" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x: i64 = 42;
        \\x = 100;
    ;

    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    var interpreter = try Interpreter.init(allocator, &parser);
    defer interpreter.deinit();

    try interpreter.execute();

    try testing.expect(interpreter.get_exit_code() == 0);
}

/// Test type mismatch error.
test "interpreter type mismatch error" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x: string = "hello";
        \\x = 42;
    ;

    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    var interpreter = try Interpreter.init(allocator, &parser);
    defer interpreter.deinit();

    // This should fail (type mismatch)
    interpreter.execute() catch |err| {
        // Expected error
        _ = err;
        return;
    };

    // Should not reach here
    try testing.expect(false);
}

/// Test type checking on declaration.
test "interpreter type checking declaration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x: i64 = "hello";
    ;

    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    var interpreter = try Interpreter.init(allocator, &parser);
    defer interpreter.deinit();

    // This should fail (type mismatch)
    interpreter.execute() catch |err| {
        // Expected error
        _ = err;
        return;
    };

    // Should not reach here
    try testing.expect(false);
}

/// Test type inference with constants.
test "interpreter type inference constants" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\const x = 42;
        \\const y: string = "hello";
    ;

    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    var interpreter = try Interpreter.init(allocator, &parser);
    defer interpreter.deinit();

    try interpreter.execute();

    try testing.expect(interpreter.get_exit_code() == 0);
}

/// Test numeric type compatibility.
test "interpreter numeric type compatibility" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x: i64 = 42;
        \\x = 3.14;
    ;

    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    var interpreter = try Interpreter.init(allocator, &parser);
    defer interpreter.deinit();

    // Integer and float should be compatible
    try interpreter.execute();

    try testing.expect(interpreter.get_exit_code() == 0);
}

/// Test multiple type aliases.
test "interpreter type aliases" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x: int = 42;
        \\var y: float = 3.14;
        \\var z: str = "hello";
        \\var w: boolean = true;
    ;

    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    var interpreter = try Interpreter.init(allocator, &parser);
    defer interpreter.deinit();

    try interpreter.execute();

    try testing.expect(interpreter.get_exit_code() == 0);
}

