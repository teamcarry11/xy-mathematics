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
    
    pub const Tree = struct {
        root: Node,
        source: []const u8,
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
        var nodes = std.ArrayList(Node).init(self.allocator);
        defer nodes.deinit();
        
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
                
                try nodes.append(Node{
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
                
                try nodes.append(Node{
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
            .children = try nodes.toOwnedSlice(),
        };
        
        return Tree{
            .root = root,
            .source = source,
        };
    }
    
    /// Get node at a specific position (for hover, go-to-definition, etc.).
    pub fn getNodeAt(self: *TreeSitter, tree: *const Tree, point: Point) ?Node {
        // Simple search: find node containing the point
        return self.findNodeContaining(&tree.root, point);
    }
    
    /// Find node containing a point (recursive search).
    fn findNodeContaining(self: *TreeSitter, node: *const Node, point: Point) ?Node {
        _ = self;
        
        // Check if point is within this node
        if (point.row < node.start_point.row or point.row > node.end_point.row) {
            return null;
        }
        if (point.row == node.start_point.row and point.column < node.start_point.column) {
            return null;
        }
        if (point.row == node.end_point.row and point.column > node.end_point.column) {
            return null;
        }
        
        // Check children first (more specific)
        for (node.children) |child| {
            if (self.findNodeContaining(&child, point)) |found| {
                return found;
            }
        }
        
        // This node contains the point
        return node.*;
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

