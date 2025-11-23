const std = @import("std");
const testing = std.testing;
const grainscript = @import("grainscript");
const Lexer = grainscript.Lexer;
const Parser = grainscript.Parser;
const Interpreter = grainscript.Interpreter;

/// Test interpreter with literal expressions.
test "interpreter literal expressions" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "42; 3.14; \"hello\"; true; false; null;";

    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    var interpreter = try Interpreter.init(allocator, &parser);
    defer interpreter.deinit();

    try interpreter.execute();

    // Exit code should be 0
    try testing.expect(interpreter.get_exit_code() == 0);
}

/// Test interpreter with binary expressions.
test "interpreter binary expressions" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "1 + 2; 3 - 1; 2 * 3; 6 / 2; 5 % 2;";

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

/// Test interpreter with comparison expressions.
test "interpreter comparison expressions" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "1 == 1; 1 != 2; 1 < 2; 2 > 1; 1 <= 2; 2 >= 1;";

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

/// Test interpreter with logical expressions.
test "interpreter logical expressions" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "true && true; false || true; !false;";

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

/// Test interpreter with variable declarations.
test "interpreter variable declarations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = 42; var y = \"hello\"; var z = true;";

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

/// Test interpreter with constant declarations.
test "interpreter constant declarations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "const x = 42; const y = \"hello\"; const z = true;";

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

/// Test interpreter with if statements.
test "interpreter if statements" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\if (true) {
        \\    var x = 1;
        \\}
        \\if (false) {
        \\    var y = 2;
        \\} else {
        \\    var z = 3;
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

/// Test interpreter with while statements.
/// Note: Assignment not yet implemented, so this test uses a false condition.
test "interpreter while statements" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\while (false) {
        \\    var x = 1;
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

/// Test interpreter with built-in echo command.
test "interpreter builtin echo" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "echo(\"hello\", \"world\");";

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

/// Test interpreter with built-in pwd command.
test "interpreter builtin pwd" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "pwd();";

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

/// Test interpreter with built-in exit command.
test "interpreter builtin exit" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "exit(42);";

    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    var interpreter = try Interpreter.init(allocator, &parser);
    defer interpreter.deinit();

    try interpreter.execute();

    try testing.expect(interpreter.get_exit_code() == 42);
}

/// Test interpreter with string concatenation.
test "interpreter string concatenation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "\"hello\" + \" \" + \"world\";";

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

/// Test interpreter with unary expressions.
test "interpreter unary expressions" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "-42; !false;";

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

/// Test interpreter with complex expression.
test "interpreter complex expression" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "(1 + 2) * 3 - 4 / 2;";

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

