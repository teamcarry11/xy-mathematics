const std = @import("std");
const testing = std.testing;
const grainscript = @import("grainscript");
const Lexer = grainscript.Lexer;
const Parser = grainscript.Parser;
const Interpreter = grainscript.Interpreter;

/// Test break statement in while loop.
test "interpreter break in while loop" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var i = 0;
        \\while (i < 10) {
        \\    i = i + 1;
        \\    if (i >= 5) {
        \\        break;
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

/// Test continue statement in while loop.
test "interpreter continue in while loop" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var i = 0;
        \\var sum = 0;
        \\while (i < 10) {
        \\    i = i + 1;
        \\    if (i % 2 == 0) {
        \\        continue;
        \\    }
        \\    sum = sum + i;
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

/// Test break statement in for loop.
test "interpreter break in for loop" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var i = 0;
        \\for (i = 0; i < 10; i = i + 1) {
        \\    if (i >= 5) {
        \\        break;
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

/// Test continue statement in for loop.
test "interpreter continue in for loop" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var i = 0;
        \\var sum = 0;
        \\for (i = 0; i < 10; i = i + 1) {
        \\    if (i % 2 == 0) {
        \\        continue;
        \\    }
        \\    sum = sum + i;
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

/// Test nested loops with break.
test "interpreter nested loops break" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var i = 0;
        \\var j = 0;
        \\while (i < 5) {
        \\    i = i + 1;
        \\    while (j < 5) {
        \\        j = j + 1;
        \\        if (j >= 3) {
        \\            break;
        \\        }
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

/// Test nested loops with continue.
test "interpreter nested loops continue" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var i = 0;
        \\var j = 0;
        \\while (i < 3) {
        \\    i = i + 1;
        \\    while (j < 5) {
        \\        j = j + 1;
        \\        if (j % 2 == 0) {
        \\            continue;
        \\        }
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

/// Test if/else statements.
test "interpreter if else statements" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x = 10;
        \\if (x > 5) {
        \\    x = 20;
        \\} else {
        \\    x = 30;
        \\}
        \\if (x < 5) {
        \\    x = 40;
        \\} else {
        \\    x = 50;
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

/// Test return statement.
test "interpreter return statement" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var x = 10;
        \\if (x > 5) {
        \\    return;
        \\}
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

/// Test complex control flow.
test "interpreter complex control flow" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = 
        \\var i = 0;
        \\var sum = 0;
        \\while (i < 10) {
        \\    i = i + 1;
        \\    if (i % 2 == 0) {
        \\        continue;
        \\    }
        \\    if (i >= 7) {
        \\        break;
        \\    }
        \\    sum = sum + i;
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

