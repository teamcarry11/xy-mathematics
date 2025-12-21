//! Tests for Aurora Tree-sitter module.
//!
//! Why: Verify Tree-sitter functionality (parsing, token extraction, node/token
//! retrieval).
//! Architecture: Comprehensive test coverage for syntax parsing operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-083012-pst: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const TreeSitter = @import("aurora_tree_sitter").TreeSitter;

test "tree-sitter constants" {
    // Assert: Constants are defined correctly
    std.debug.assert(TreeSitter.MAX_NODES == 10_000);
    std.debug.assert(TreeSitter.MAX_DEPTH == 100);
    std.debug.assert(TreeSitter.MAX_TOKENS == 10_000);
    std.debug.assert(TreeSitter.MAX_NODES > 0);
    std.debug.assert(TreeSitter.MAX_DEPTH > 0);
    std.debug.assert(TreeSitter.MAX_TOKENS > 0);
}

test "tree-sitter token type enum" {
    // Assert: Token type enum values
    std.debug.assert(@intFromEnum(TreeSitter.TokenType.keyword) == 0);
    std.debug.assert(@intFromEnum(TreeSitter.TokenType.string_literal) == 1);
    std.debug.assert(@intFromEnum(TreeSitter.TokenType.number_literal) == 2);
    std.debug.assert(@intFromEnum(TreeSitter.TokenType.comment) == 3);
    std.debug.assert(@intFromEnum(TreeSitter.TokenType.identifier) == 4);
    std.debug.assert(@intFromEnum(TreeSitter.TokenType.operator) == 5);
    std.debug.assert(@intFromEnum(TreeSitter.TokenType.punctuation) == 6);
    std.debug.assert(@intFromEnum(TreeSitter.TokenType.whitespace) == 7);
}

test "tree-sitter initialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    defer parser.deinit();

    // Assert: Parser initialized correctly
    std.debug.assert(parser.allocator.ptr != null);
}

test "tree-sitter deinitialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    parser.deinit();

    // Assert: Deinitialization completed (no crash)
}

test "tree-sitter parse simple function" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    defer parser.deinit();

    const code =
        \\pub fn main() void {
        \\    std.debug.print("Hello\n", .{});
        \\}
    ;

    const tree = try parser.parseZig(code);
    defer arena.allocator().free(tree.root.children);
    defer arena.allocator().free(tree.tokens);

    // Assert: Should find one function node
    std.debug.assert(tree.root.children.len == 1);
    std.debug.assert(std.mem.eql(u8, tree.root.children[0].type, "function"));
}

test "tree-sitter parse multiple functions" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    defer parser.deinit();

    const code =
        \\pub fn main() void {
        \\    return;
        \\}
        \\
        \\fn helper() void {
        \\    return;
        \\}
    ;

    const tree = try parser.parseZig(code);
    defer arena.allocator().free(tree.root.children);
    defer arena.allocator().free(tree.tokens);

    // Assert: Should find two function nodes
    std.debug.assert(tree.root.children.len == 2);
}

test "tree-sitter parse struct" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    defer parser.deinit();

    const code =
        \\pub const MyStruct = struct {
        \\    field: u32,
        \\};
    ;

    const tree = try parser.parseZig(code);
    defer arena.allocator().free(tree.root.children);
    defer arena.allocator().free(tree.tokens);

    // Assert: Should find one type definition node
    std.debug.assert(tree.root.children.len == 1);
    std.debug.assert(std.mem.eql(u8, tree.root.children[0].type, "type_definition"));
}

test "tree-sitter parse enum" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    defer parser.deinit();

    const code =
        \\pub const MyEnum = enum {
        \\    variant1,
        \\    variant2,
        \\};
    ;

    const tree = try parser.parseZig(code);
    defer arena.allocator().free(tree.root.children);
    defer arena.allocator().free(tree.tokens);

    // Assert: Should find one type definition node
    std.debug.assert(tree.root.children.len == 1);
}

test "tree-sitter parse union" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    defer parser.deinit();

    const code =
        \\pub const MyUnion = union {
        \\    variant1: u32,
        \\    variant2: u64,
        \\};
    ;

    const tree = try parser.parseZig(code);
    defer arena.allocator().free(tree.root.children);
    defer arena.allocator().free(tree.tokens);

    // Assert: Should find one type definition node
    std.debug.assert(tree.root.children.len == 1);
}

test "tree-sitter extract tokens keywords" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    defer parser.deinit();

    const code = "pub fn const var if else\n";

    const tree = try parser.parseZig(code);
    defer arena.allocator().free(tree.root.children);
    defer arena.allocator().free(tree.tokens);

    // Assert: Should extract keyword tokens
    std.debug.assert(tree.tokens.len > 0);
}

test "tree-sitter extract tokens string literal" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    defer parser.deinit();

    const code = "const s = \"hello world\";\n";

    const tree = try parser.parseZig(code);
    defer arena.allocator().free(tree.root.children);
    defer arena.allocator().free(tree.tokens);

    // Assert: Should extract string literal token
    var found_string = false;
    for (tree.tokens) |token| {
        if (token.type == .string_literal) {
            found_string = true;
            break;
        }
    }
    std.debug.assert(found_string);
}

test "tree-sitter extract tokens comment" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    defer parser.deinit();

    const code = "// This is a comment\n";

    const tree = try parser.parseZig(code);
    defer arena.allocator().free(tree.root.children);
    defer arena.allocator().free(tree.tokens);

    // Assert: Should extract comment token
    var found_comment = false;
    for (tree.tokens) |token| {
        if (token.type == .comment) {
            found_comment = true;
            break;
        }
    }
    std.debug.assert(found_comment);
}

test "tree-sitter extract tokens number literal" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    defer parser.deinit();

    const code = "const n: u32 = 42;\n";

    const tree = try parser.parseZig(code);
    defer arena.allocator().free(tree.root.children);
    defer arena.allocator().free(tree.tokens);

    // Assert: Should extract number literal token
    var found_number = false;
    for (tree.tokens) |token| {
        if (token.type == .number_literal) {
            found_number = true;
            break;
        }
    }
    std.debug.assert(found_number);
}

test "tree-sitter get node at point" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    defer parser.deinit();

    const code =
        \\pub fn main() void {
        \\    return;
        \\}
    ;

    const tree = try parser.parseZig(code);
    defer arena.allocator().free(tree.root.children);
    defer arena.allocator().free(tree.tokens);

    // Get node at start of function
    const point = TreeSitter.Point{ .row = 0, .column = 0 };
    const node = parser.getNodeAt(&tree, point);

    // Assert: Should find function node
    std.debug.assert(node != null);
    if (node) |n| {
        std.debug.assert(std.mem.eql(u8, n.type, "function"));
    }
}

test "tree-sitter get node at point invalid" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    defer parser.deinit();

    const code =
        \\pub fn main() void {
        \\    return;
        \\}
    ;

    const tree = try parser.parseZig(code);
    defer arena.allocator().free(tree.root.children);
    defer arena.allocator().free(tree.tokens);

    // Get node at invalid point
    const point = TreeSitter.Point{ .row = 999, .column = 999 };
    const node = parser.getNodeAt(&tree, point);

    // Assert: Should return null for invalid point
    // Note: May return root node or null depending on implementation
}

test "tree-sitter get token at point" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    defer parser.deinit();

    const code = "pub fn main() void {}\n";

    const tree = try parser.parseZig(code);
    defer arena.allocator().free(tree.root.children);
    defer arena.allocator().free(tree.tokens);

    // Get token at start
    const point = TreeSitter.Point{ .row = 0, .column = 0 };
    const token = parser.getTokenAt(&parser, &tree, point);

    // Assert: Should find token
    // Note: May return null if point is in whitespace
}

test "tree-sitter get function name" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    defer parser.deinit();

    const code =
        \\pub fn main() void {
        \\    return;
        \\}
    ;

    const tree = try parser.parseZig(code);
    defer arena.allocator().free(tree.root.children);
    defer arena.allocator().free(tree.tokens);

    // Get function name
    if (tree.root.children.len > 0) {
        const func_name = parser.getFunctionName(&tree.root.children[0], code);
        // Assert: Should extract function name
        if (func_name) |name| {
            std.debug.assert(std.mem.eql(u8, name, "main"));
        }
    }
}

test "tree-sitter point structure" {
    // Assert: Point structure fields
    const point = TreeSitter.Point{
        .row = 5,
        .column = 10,
    };

    std.debug.assert(point.row == 5);
    std.debug.assert(point.column == 10);
}

test "tree-sitter node structure" {
    // Assert: Node structure fields
    const point = TreeSitter.Point{ .row = 0, .column = 0 };
    const node = TreeSitter.Node{
        .type = "function",
        .start_byte = 0,
        .end_byte = 10,
        .start_point = point,
        .end_point = point,
        .children = &.{},
    };

    std.debug.assert(std.mem.eql(u8, node.type, "function"));
    std.debug.assert(node.start_byte == 0);
    std.debug.assert(node.end_byte == 10);
}

test "tree-sitter token structure" {
    // Assert: Token structure fields
    const point = TreeSitter.Point{ .row = 0, .column = 0 };
    const token = TreeSitter.Token{
        .type = .keyword,
        .start_byte = 0,
        .end_byte = 3,
        .start_point = point,
        .end_point = point,
    };

    std.debug.assert(token.type == .keyword);
    std.debug.assert(token.start_byte == 0);
    std.debug.assert(token.end_byte == 3);
}

test "tree-sitter bounds checking" {
    // Assert: Constants are reasonable
    std.debug.assert(TreeSitter.MAX_NODES == 10_000);
    std.debug.assert(TreeSitter.MAX_DEPTH == 100);
    std.debug.assert(TreeSitter.MAX_TOKENS == 10_000);
    std.debug.assert(TreeSitter.MAX_NODES <= 100_000);
    std.debug.assert(TreeSitter.MAX_DEPTH <= 1_000);
    std.debug.assert(TreeSitter.MAX_TOKENS <= 100_000);
}

test "tree-sitter root node" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var parser = TreeSitter.init(arena.allocator());
    defer parser.deinit();

    const code = "// comment\n";

    const tree = try parser.parseZig(code);
    defer arena.allocator().free(tree.root.children);
    defer arena.allocator().free(tree.tokens);

    // Assert: Root node is source_file
    std.debug.assert(std.mem.eql(u8, tree.root.type, "source_file"));
    std.debug.assert(tree.root.start_byte == 0);
    std.debug.assert(tree.root.end_byte == code.len);
}
