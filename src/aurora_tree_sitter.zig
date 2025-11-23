const std = @import("std");

/// Tree-sitter integration for syntax highlighting and structural editing.
/// ~<~ Glow Airbend: explicit tree nodes, bounded parsing.
/// ~~~~ Glow Waterbend: syntax trees flow deterministically from source.
pub const TreeSitter = struct {
    allocator: std.mem.Allocator,
    
    // Bounded: Max 10,000 tree nodes
    pub const MAX_NODES: u32 = 10_000;
    
    // Bounded: Max tree depth of 100
    pub const MAX_DEPTH: u32 = 100;
    
    pub const Node = struct {
        type: []const u8,
        start_byte: u32,
        end_byte: u32,
        start_point: Point,
        end_point: Point,
        children: []const Node,
    };
    
    pub const Point = struct {
        row: u32,
        column: u32,
    };
    
    /// Syntax token: for syntax highlighting (keywords, strings, comments, etc.).
    pub const Token = struct {
        type: TokenType,
        start_byte: u32,
        end_byte: u32,
        start_point: Point,
        end_point: Point,
    };
    
    /// Token types for syntax highlighting.
    pub const TokenType = enum {
        keyword,
        string_literal,
        number_literal,
        comment,
        identifier,
        operator,
        punctuation,
        whitespace,
    };
    
    pub const Tree = struct {
        root: Node,
        source: []const u8,
        tokens: []const Token,
    };
    
    pub fn init(allocator: std.mem.Allocator) TreeSitter {
        return TreeSitter{
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *TreeSitter) void {
        self.* = undefined;
    }
    
    /// Parse Zig source code (simple regex-based parser for now).
    /// TODO: Integrate actual Tree-sitter C library bindings.
    pub fn parseZig(self: *TreeSitter, source: []const u8) !Tree {
        // Assert: Source must be non-empty
        std.debug.assert(source.len > 0);
        
        // Simple parser: identify function definitions, structs, etc.
        // This is a placeholder until we integrate the actual Tree-sitter library.
        var nodes = std.ArrayList(Node){ .items = &.{}, .capacity = 0 };
        defer nodes.deinit(self.allocator);
        
        var lines = std.mem.splitSequence(u8, source, "\n");
        var row: u32 = 0;
        var byte_offset: u32 = 0;
        
        while (lines.next()) |line| : (row += 1) {
            const trimmed = std.mem.trim(u8, line, " \t");
            
            // Check for function definitions
            if (std.mem.indexOf(u8, trimmed, "pub fn ") != null or
                std.mem.indexOf(u8, trimmed, "fn ") != null or
                std.mem.indexOf(u8, trimmed, "const fn ") != null)
            {
                const start_byte = byte_offset;
                const end_byte = byte_offset + @as(u32, @intCast(line.len));
                
                // Find matching closing brace (simplified)
                var brace_count: u32 = 0;
                var found_start = false;
                var end_row = row;
                var end_byte_final = end_byte;
                
                var search_lines = std.mem.splitSequence(u8, source[byte_offset..], "\n");
                while (search_lines.next()) |search_line| : (end_row += 1) {
                    for (search_line) |ch| {
                        if (ch == '{') {
                            brace_count += 1;
                            found_start = true;
                        } else if (ch == '}') {
                            if (brace_count > 0) {
                                brace_count -= 1;
                                if (brace_count == 0 and found_start) {
                                    end_byte_final = byte_offset + @as(u32, @intCast(std.mem.indexOf(u8, source[byte_offset..], search_line).? + search_line.len));
                                    break;
                                }
                            }
                        }
                    }
                    if (brace_count == 0 and found_start) break;
                }
                
                try nodes.append(self.allocator, Node{
                    .type = "function",
                    .start_byte = start_byte,
                    .end_byte = end_byte_final,
                    .start_point = Point{ .row = row, .column = 0 },
                    .end_point = Point{ .row = end_row, .column = 0 },
                    .children = &.{},
                });
            }
            
            // Check for struct/enum/union definitions
            if (std.mem.indexOf(u8, trimmed, "pub const ") != null and
                (std.mem.indexOf(u8, trimmed, "= struct") != null or
                 std.mem.indexOf(u8, trimmed, "= enum") != null or
                 std.mem.indexOf(u8, trimmed, "= union") != null))
            {
                const start_byte = byte_offset;
                const end_byte = byte_offset + @as(u32, @intCast(line.len));
                
                try nodes.append(self.allocator, Node{
                    .type = "type_definition",
                    .start_byte = start_byte,
                    .end_byte = end_byte,
                    .start_point = Point{ .row = row, .column = 0 },
                    .end_point = Point{ .row = row, .column = @as(u32, @intCast(line.len)) },
                    .children = &.{},
                });
            }
            
            byte_offset += @as(u32, @intCast(line.len + 1)); // +1 for newline
            
            // Assert: Nodes must be within bounds
            std.debug.assert(nodes.items.len <= MAX_NODES);
        }
        
        // Create root node containing all parsed nodes
        const root = Node{
            .type = "source_file",
            .start_byte = 0,
            .end_byte = @as(u32, @intCast(source.len)),
            .start_point = Point{ .row = 0, .column = 0 },
            .end_point = Point{ .row = row, .column = 0 },
            .children = try nodes.toOwnedSlice(self.allocator),
        };
        
        // Extract syntax tokens for highlighting
        const tokens = try self.extractTokens(source);
        
        return Tree{
            .root = root,
            .source = source,
            .tokens = tokens,
        };
    }
    
    /// Extract syntax tokens from source code (for syntax highlighting).
    /// Bounded: Max 10,000 tokens per file.
    pub const MAX_TOKENS: u32 = 10_000;
    
    fn extractTokens(self: *TreeSitter, source: []const u8) ![]const Token {
        // Assert: Source must be non-empty
        std.debug.assert(source.len > 0);
        std.debug.assert(source.len <= 100 * 1024 * 1024); // Bounded source size (100MB)
        
        var tokens = std.ArrayList(Token){ .items = &.{}, .capacity = 0 };
        errdefer tokens.deinit(self.allocator);
        
        // Zig keywords (common subset)
        const keywords = [_][]const u8{
            "pub", "fn", "const", "var", "if", "else", "while", "for",
            "return", "break", "continue", "defer", "errdefer", "try",
            "catch", "switch", "struct", "enum", "union", "error", "comptime",
        };
        
        var i: u32 = 0;
        var row: u32 = 0;
        var column: u32 = 0;
        
        while (i < source.len) {
            // Assert: Bounded tokens
            std.debug.assert(tokens.items.len < MAX_TOKENS);
            
            const start_byte = i;
            const start_point = Point{ .row = row, .column = column };
            
            const ch = source[i];
            
            // String literals
            if (ch == '"') {
                i += 1;
                column += 1;
                var escaped = false;
                while (i < source.len) {
                    if (escaped) {
                        escaped = false;
                        i += 1;
                        column += 1;
                    } else if (source[i] == '\\') {
                        escaped = true;
                        i += 1;
                        column += 1;
                    } else if (source[i] == '"') {
                        i += 1;
                        column += 1;
                        break;
                    } else {
                        if (source[i] == '\n') {
                            row += 1;
                            column = 0;
                        } else {
                            column += 1;
                        }
                        i += 1;
                    }
                }
                const end_byte = i;
                const end_point = Point{ .row = row, .column = column };
                try tokens.append(self.allocator, Token{
                    .type = .string_literal,
                    .start_byte = start_byte,
                    .end_byte = end_byte,
                    .start_point = start_point,
                    .end_point = end_point,
                });
                continue;
            }
            
            // Line comments
            if (i + 1 < source.len and source[i] == '/' and source[i + 1] == '/') {
                i += 2;
                column += 2;
                while (i < source.len and source[i] != '\n') {
                    i += 1;
                    column += 1;
                }
                const end_byte = i;
                const end_point = Point{ .row = row, .column = column };
                try tokens.append(self.allocator, Token{
                    .type = .comment,
                    .start_byte = start_byte,
                    .end_byte = end_byte,
                    .start_point = start_point,
                    .end_point = end_point,
                });
                continue;
            }
            
            // Block comments
            if (i + 1 < source.len and source[i] == '/' and source[i + 1] == '*') {
                i += 2;
                column += 2;
                while (i + 1 < source.len) {
                    if (source[i] == '*' and source[i + 1] == '/') {
                        i += 2;
                        column += 2;
                        break;
                    }
                    if (source[i] == '\n') {
                        row += 1;
                        column = 0;
                    } else {
                        column += 1;
                    }
                    i += 1;
                }
                const end_byte = i;
                const end_point = Point{ .row = row, .column = column };
                try tokens.append(self.allocator, Token{
                    .type = .comment,
                    .start_byte = start_byte,
                    .end_byte = end_byte,
                    .start_point = start_point,
                    .end_point = end_point,
                });
                continue;
            }
            
            // Whitespace
            if (std.ascii.isWhitespace(ch)) {
                i += 1;
                if (ch == '\n') {
                    row += 1;
                    column = 0;
                } else {
                    column += 1;
                }
                continue;
            }
            
            // Numbers
            if (std.ascii.isDigit(ch)) {
                i += 1;
                column += 1;
                while (i < source.len and (std.ascii.isAlphanumeric(source[i]) or source[i] == '.' or source[i] == '_')) {
                    i += 1;
                    column += 1;
                }
                const end_byte = i;
                const end_point = Point{ .row = row, .column = column };
                try tokens.append(self.allocator, Token{
                    .type = .number_literal,
                    .start_byte = start_byte,
                    .end_byte = end_byte,
                    .start_point = start_point,
                    .end_point = end_point,
                });
                continue;
            }
            
            // Operators and punctuation
            const operators = "=+-*/%<>!&|^~?:.";
            if (std.mem.indexOfScalar(u8, operators, ch) != null) {
                i += 1;
                column += 1;
                const end_byte = i;
                const end_point = Point{ .row = row, .column = column };
                try tokens.append(self.allocator, Token{
                    .type = if (ch == '(' or ch == ')' or ch == '{' or ch == '}' or ch == '[' or ch == ']' or ch == ',' or ch == ';' or ch == ':') .punctuation else .operator,
                    .start_byte = start_byte,
                    .end_byte = end_byte,
                    .start_point = start_point,
                    .end_point = end_point,
                });
                continue;
            }
            
            // Identifiers and keywords
            if (std.ascii.isAlphabetic(ch) or ch == '_') {
                i += 1;
                column += 1;
                while (i < source.len and (std.ascii.isAlphanumeric(source[i]) or source[i] == '_')) {
                    i += 1;
                    column += 1;
                }
                const end_byte = i;
                const end_point = Point{ .row = row, .column = column };
                const token_text = source[start_byte..end_byte];
                
                // Check if keyword
                var is_keyword = false;
                for (keywords) |keyword| {
                    if (std.mem.eql(u8, token_text, keyword)) {
                        is_keyword = true;
                        break;
                    }
                }
                
                try tokens.append(self.allocator, Token{
                    .type = if (is_keyword) .keyword else .identifier,
                    .start_byte = start_byte,
                    .end_byte = end_byte,
                    .start_point = start_point,
                    .end_point = end_point,
                });
                continue;
            }
            
            // Unknown character: skip
            i += 1;
            column += 1;
        }
        
        // Assert: Tokens extracted successfully
        std.debug.assert(tokens.items.len <= MAX_TOKENS);
        
        return try tokens.toOwnedSlice(self.allocator);
    }
    
    /// Get token at a specific position (for syntax highlighting).
    /// Returns the token containing the point, or null if none.
    pub fn getTokenAt(_: *TreeSitter, tree: *const Tree, point: Point) ?Token {
        // Assert: Point must be valid
        std.debug.assert(point.row <= MAX_DEPTH * 1000); // Bounded row
        std.debug.assert(point.column <= 1000); // Bounded column
        
        // Find token containing the point
        for (tree.tokens) |token| {
            if (point.row >= token.start_point.row and point.row <= token.end_point.row) {
                if (point.row == token.start_point.row and point.column < token.start_point.column) {
                    continue;
                }
                if (point.row == token.end_point.row and point.column > token.end_point.column) {
                    continue;
                }
                return token;
            }
        }
        
        return null;
    }
    
    /// Get node at a specific position (for hover, go-to-definition, etc.).
    pub fn getNodeAt(self: *TreeSitter, tree: *const Tree, point: Point) ?Node {
        // Simple search: find node containing the point
        return self.findNodeContaining(&tree.root, point);
    }
    
    /// Find node containing a point (iterative search to avoid recursion).
    /// GrainStyle: No recursion, use explicit stack.
    fn findNodeContaining(self: *TreeSitter, node: *const Node, point: Point) ?Node {
        _ = self;
        
        // Assert: Point must be valid
        std.debug.assert(point.row <= MAX_DEPTH * 1000); // Bounded row
        std.debug.assert(point.column <= 1000); // Bounded column
        
        // Use explicit stack instead of recursion (GrainStyle)
        // Bounded: Max stack depth of MAX_DEPTH
        var stack: [MAX_DEPTH]?*const Node = undefined;
        var stack_len: u32 = 0;
        
        stack[stack_len] = node;
        stack_len += 1;
        
        var best_match: ?*const Node = null;
        
        while (stack_len > 0) {
            // Assert: Stack depth within bounds
            std.debug.assert(stack_len <= MAX_DEPTH);
            
            stack_len -= 1;
            const current = stack[stack_len].?;
            
            // Check if point is within this node
            if (point.row < current.start_point.row or point.row > current.end_point.row) {
                continue;
            }
            if (point.row == current.start_point.row and point.column < current.start_point.column) {
                continue;
            }
            if (point.row == current.end_point.row and point.column > current.end_point.column) {
                continue;
            }
            
            // This node contains the point, check children for more specific match
            best_match = current;
            
            // Check children (more specific)
            for (current.children) |*child| {
                // Assert: Stack has room
                std.debug.assert(stack_len < MAX_DEPTH);
                stack[stack_len] = child;
                stack_len += 1;
            }
        }
        
        if (best_match) |match| {
            return match.*;
        }
        return null;
    }
    
    /// Extract function name from function node.
    pub fn getFunctionName(self: *TreeSitter, node: *const Node, source: []const u8) ?[]const u8 {
        _ = self;
        
        if (!std.mem.eql(u8, node.type, "function")) {
            return null;
        }
        
        // Simple extraction: find "fn " and get the next word
        // TODO: Use proper Tree-sitter query API when integrated
        if (node.start_byte >= source.len) return null;
        const node_text = source[node.start_byte..@min(node.end_byte, source.len)];
        
        if (std.mem.indexOf(u8, node_text, "fn ")) |fn_pos| {
            const after_fn = node_text[fn_pos + 3..];
            if (std.mem.indexOfScalar(u8, after_fn, '(')) |paren_pos| {
                return after_fn[0..paren_pos];
            }
        }
        
        return null;
    }
};

test "tree-sitter parse simple function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
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
    
    // Assert: Should find one function node
    try std.testing.expectEqual(@as(usize, 1), tree.root.children.len);
    try std.testing.expect(std.mem.eql(u8, tree.root.children[0].type, "function"));
}

test "tree-sitter get node at point" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
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
    
    // Get node at start of function
    const point = TreeSitter.Point{ .row = 0, .column = 0 };
    const node = parser.getNodeAt(&tree, point);
    
    // Assert: Should find function node
    try std.testing.expect(node != null);
    if (node) |n| {
        try std.testing.expect(std.mem.eql(u8, n.type, "function"));
    }
}

