const std = @import("std");
const testing = std.testing;
const grainscript = @import("grainscript");
const Lexer = grainscript.Lexer;
const Parser = grainscript.Parser;

test "grain.parser.init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "123";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    // Assert: Parser must be initialized
    std.debug.assert(parser.token_index == 0);
    std.debug.assert(parser.nodes_len == 0);
    std.debug.assert(parser.nodes.len == Parser.MAX_AST_NODES);
}

test "grain.parser.parse_integer" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "123";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    // Assert: Must have parsed at least one node
    std.debug.assert(parser.nodes_len > 0);

    const node_opt = parser.get_node(0);
    std.debug.assert(node_opt != null);
    const node = node_opt.?;
    std.debug.assert(node.node_type == .expr_literal);
    std.debug.assert(node.data.literal.literal_type == .integer);
}

test "grain.parser.parse_float" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "123.456";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    // Assert: Must have parsed at least one node
    std.debug.assert(parser.nodes_len > 0);

    const node_opt = parser.get_node(0);
    std.debug.assert(node_opt != null);
    const node = node_opt.?;
    std.debug.assert(node.node_type == .expr_literal);
    std.debug.assert(node.data.literal.literal_type == .float);
}

test "grain.parser.parse_string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "\"hello\"";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    // Assert: Must have parsed at least one node
    std.debug.assert(parser.nodes_len > 0);

    const node_opt = parser.get_node(0);
    std.debug.assert(node_opt != null);
    const node = node_opt.?;
    std.debug.assert(node.node_type == .expr_literal);
    std.debug.assert(node.data.literal.literal_type == .string);
}

test "grain.parser.parse_boolean" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "true false";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    // Assert: Must have parsed at least two nodes
    std.debug.assert(parser.nodes_len >= 2);

    const node1 = parser.get_node(0);
    std.debug.assert(node1 != null);
    std.debug.assert(node1.?.node_type == .expr_literal);
    std.debug.assert(node1.?.data.literal.literal_type == .boolean_true);

    const node2 = parser.get_node(1);
    std.debug.assert(node2 != null);
    std.debug.assert(node2.?.node_type == .expr_literal);
    std.debug.assert(node2.?.data.literal.literal_type == .boolean_false);
}

test "grain.parser.parse_identifier" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "hello";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    // Assert: Must have parsed at least one node
    std.debug.assert(parser.nodes_len > 0);

    const node_opt = parser.get_node(0);
    std.debug.assert(node_opt != null);
    const node = node_opt.?;
    std.debug.assert(node.node_type == .expr_identifier);
    std.debug.assert(std.mem.eql(u8, node.?.data.identifier.name, "hello"));
}

test "grain.parser.parse_binary_expression" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "1 + 2";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    // Assert: Must have parsed nodes
    std.debug.assert(parser.nodes_len >= 3);

    // Check for binary expression node
    var found_binary = false;
    var i: u32 = 0;
    while (i < parser.nodes_len) : (i += 1) {
        const node_opt = parser.get_node(i);
        if (node_opt) |node| {
            if (node.node_type == .expr_binary) {
                std.debug.assert(node.data.binary.operator == .add);
                found_binary = true;
                break;
            }
        }
    }
    std.debug.assert(found_binary);
}

test "grain.parser.parse_unary_expression" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "-123";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    // Assert: Must have parsed nodes
    std.debug.assert(parser.nodes_len >= 2);

    // Check for unary expression node
    var found_unary = false;
    var i: u32 = 0;
    while (i < parser.nodes_len) : (i += 1) {
        const node_opt = parser.get_node(i);
        if (node_opt) |node| {
            if (node.node_type == .expr_unary) {
                std.debug.assert(node.data.unary.operator == .negate);
                found_unary = true;
                break;
            }
    }
    std.debug.assert(found_unary);
}

test "grain.parser.parse_function_call" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "foo(1, 2)";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    // Assert: Must have parsed nodes
    std.debug.assert(parser.nodes_len >= 4);

    // Check for call expression node
    var found_call = false;
    var i: u32 = 0;
    while (i < parser.nodes_len) : (i += 1) {
        const node_opt = parser.get_node(i);
        if (node_opt) |node| {
            if (node.node_type == .expr_call) {
                std.debug.assert(node.data.call.args_len == 2);
                found_call = true;
                break;
            }
    }
    std.debug.assert(found_call);
}

test "grain.parser.parse_variable_declaration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "var x: i32 = 123;";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    // Assert: Must have parsed nodes
    std.debug.assert(parser.nodes_len >= 3);

    // Check for variable declaration node
    var found_var = false;
    var i: u32 = 0;
    while (i < parser.nodes_len) : (i += 1) {
        const node_opt = parser.get_node(i);
        if (node_opt) |node| {
            if (node.node_type == .decl_var or node.node_type == .stmt_var) {
                // Variable declarations can be top-level (decl_var) or statement-level (stmt_var)
                found_var = true;
                break;
            }
        }
    }
    std.debug.assert(found_var);
}

test "grain.parser.parse_constant_declaration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "const x: i32 = 123;";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    // Assert: Must have parsed nodes
    std.debug.assert(parser.nodes_len >= 3);

    // Check for constant declaration node
    var found_const = false;
    var i: u32 = 0;
    while (i < parser.nodes_len) : (i += 1) {
        const node_opt = parser.get_node(i);
        if (node_opt) |node| {
            if (node.node_type == .decl_const or node.node_type == .stmt_const) {
                // Constant declarations can be top-level (decl_const) or statement-level (stmt_const)
                found_const = true;
                break;
            }
    }
    std.debug.assert(found_const);
}

test "grain.parser.parse_if_statement" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "if (true) { var x = 1; }";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    // Assert: Must have parsed nodes
    std.debug.assert(parser.nodes_len >= 3);

    // Check for if statement node
    var found_if = false;
    var i: u32 = 0;
    while (i < parser.nodes_len) : (i += 1) {
        const node_opt = parser.get_node(i);
        if (node_opt) |node| {
            if (node.node_type == .stmt_if) {
                found_if = true;
                break;
            }
    }
    std.debug.assert(found_if);
}

test "grain.parser.parse_while_statement" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "while (true) { var x = 1; }";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    // Assert: Must have parsed nodes
    std.debug.assert(parser.nodes_len >= 3);

    // Check for while statement node
    var found_while = false;
    var i: u32 = 0;
    while (i < parser.nodes_len) : (i += 1) {
        const node_opt = parser.get_node(i);
        if (node_opt) |node| {
            if (node.node_type == .stmt_while) {
                found_while = true;
                break;
            }
    }
    std.debug.assert(found_while);
}

test "grain.parser.parse_function_declaration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "fn add(a: i32, b: i32) -> i32 { return a + b; }";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    // Assert: Must have parsed nodes
    std.debug.assert(parser.nodes_len >= 5);

    // Check for function declaration node
    var found_fn = false;
    var i: u32 = 0;
    while (i < parser.nodes_len) : (i += 1) {
        const node_opt = parser.get_node(i);
        if (node_opt) |node| {
            if (node.node_type == .decl_fn) {
                std.debug.assert(std.mem.eql(u8, node.data.fn_decl.name, "add"));
                std.debug.assert(node.data.fn_decl.params_len == 2);
                found_fn = true;
                break;
            }
    }
    std.debug.assert(found_fn);
}

test "grain.parser.parse_complex_expression" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "1 + 2 * 3";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    // Assert: Must have parsed nodes (precedence should be handled)
    std.debug.assert(parser.nodes_len >= 4);
}

test "grain.parser.parse_block" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "{ var x = 1; var y = 2; }";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    try lexer.tokenize();

    var parser = try Parser.init(allocator, &lexer);
    defer parser.deinit();

    try parser.parse();

    // Assert: Must have parsed nodes
    std.debug.assert(parser.nodes_len >= 3);

    // Check for block statement node
    var found_block = false;
    var i: u32 = 0;
    while (i < parser.nodes_len) : (i += 1) {
        const node_opt = parser.get_node(i);
        if (node_opt) |node| {
            if (node.node_type == .stmt_block) {
                std.debug.assert(node.data.block.statements_len >= 2);
                found_block = true;
                break;
            }
    }
    std.debug.assert(found_block);
}
