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

/// Test interpreter with user-defined function declaration and call.
test "interpreter user defined function" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\fn add(a, b) {
        \\    return a + b;
        \\}
        \\var result = add(1, 2);
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

/// Test interpreter with user-defined function returning value.
test "interpreter user defined function return" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\fn multiply(x, y) {
        \\    return x * y;
        \\}
        \\var product = multiply(3, 4);
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

/// Test interpreter with user-defined function without return.
test "interpreter user defined function no return" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\fn greet(name) {
        \\    echo("Hello", name);
        \\}
        \\greet("World");
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

/// Test interpreter with built-in len function.
test "interpreter builtin len" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = len(\"hello\");";

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

/// Test interpreter with built-in substr function.
test "interpreter builtin substr" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = substr(\"hello\", 1, 4);";

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

/// Test interpreter with built-in trim function.
test "interpreter builtin trim" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = trim(\"  hello  \");";

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

/// Test interpreter with built-in abs function.
test "interpreter builtin abs" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = abs(-42); var y = abs(42);";

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

/// Test interpreter with built-in min function.
test "interpreter builtin min" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = min(10, 20); var y = min(3.14, 2.71);";

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

/// Test interpreter with built-in max function.
test "interpreter builtin max" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = max(10, 20); var y = max(3.14, 2.71);";

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

/// Test interpreter with built-in floor function.
test "interpreter builtin floor" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = floor(3.7); var y = floor(3.2);";

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

/// Test interpreter with built-in ceil function.
test "interpreter builtin ceil" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = ceil(3.2); var y = ceil(3.7);";

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

/// Test interpreter with built-in round function.
test "interpreter builtin round" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = round(3.4); var y = round(3.6);";

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

/// Test interpreter with built-in isNull function.
test "interpreter builtin isNull" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = isNull(null); var y = isNull(42);";

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

/// Test interpreter with built-in isEmpty function.
test "interpreter builtin isEmpty" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = isEmpty(\"\"); var y = isEmpty(\"hello\");";

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

/// Test interpreter with built-in isNumber function.
test "interpreter builtin isNumber" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = isNumber(42); var y = isNumber(3.14); var z = isNumber(\"hello\");";

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

/// Test interpreter with built-in isString function.
test "interpreter builtin isString" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = isString(\"hello\"); var y = isString(42);";

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

/// Test interpreter with built-in isBoolean function.
test "interpreter builtin isBoolean" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = isBoolean(true); var y = isBoolean(42);";

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

/// Test interpreter with built-in split function.
test "interpreter builtin split" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = split(\"hello,world\", \",\");";

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

/// Test interpreter with built-in join function.
test "interpreter builtin join" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x = join(\"hello\", \",\");";

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
