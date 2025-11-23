const std = @import("std");
const testing = std.testing;
const grainscript = @import("grainscript");
const Lexer = grainscript.Lexer;
const Parser = grainscript.Parser;
const Interpreter = grainscript.Interpreter;

/// Test variable assignment.
test "interpreter variable assignment" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x = 10;
        \\x = 20;
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

/// Test variable assignment with different types.
test "interpreter variable assignment types" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x = 10;
        \\var y = "hello";
        \\var z = true;
        \\x = 20;
        \\y = "world";
        \\z = false;
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

/// Test constant assignment (should fail).
test "interpreter constant assignment error" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\const x = 10;
        \\x = 20;
    ;

    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    var interpreter = try Interpreter.init(allocator, &parser);
    defer interpreter.deinit();

    // This should fail (cannot assign to constant)
    interpreter.execute() catch |err| {
        // Expected error
        _ = err;
        return;
    };

    // Should not reach here
    try testing.expect(false);
}

/// Test variable scope (local vs global).
test "interpreter variable scope" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x = 10;
        \\if (true) {
        \\    var y = 20;
        \\    x = 30;
        \\}
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

/// Test variable scope isolation.
test "interpreter variable scope isolation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x = 10;
        \\if (true) {
        \\    var x = 20;
        \\}
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
        \\var x = 10;
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

/// Test assignment in expression.
test "interpreter assignment in expression" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x = 10;
        \\var y = x = 20;
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

/// Test assignment to undefined variable (should fail).
test "interpreter assignment undefined variable" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "x = 10;";

    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    var interpreter = try Interpreter.init(allocator, &parser);
    defer interpreter.deinit();

    // This should fail (variable not found)
    interpreter.execute() catch |err| {
        // Expected error
        _ = err;
        return;
    };

    // Should not reach here
    try testing.expect(false);
}

/// Test nested scope.
test "interpreter nested scope" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x = 10;
        \\if (true) {
        \\    var y = 20;
        \\    if (true) {
        \\        var z = 30;
        \\        x = 40;
        \\        y = 50;
        \\    }
        \\}
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

/// Test variable lookup with scope.
test "interpreter variable lookup scope" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x = 10;
        \\if (true) {
        \\    var x = 20;
        \\    var y = x;
        \\}
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

