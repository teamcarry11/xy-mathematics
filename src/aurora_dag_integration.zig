const std = @import("std");
const DagCore = @import("dag_core.zig").DagCore;
const TreeSitter = @import("aurora_tree_sitter.zig").TreeSitter;

/// Editor-DAG Integration: Maps Tree-sitter AST nodes to DAG nodes, code edits to DAG events.
/// ~<~ Glow Airbend: explicit AST-to-DAG mapping, bounded conversions.
/// ~~~~ Glow Waterbend: code edits stream through DAG deterministically.
///
/// This implements Matklad's project-wide semantic understanding:
/// - AST nodes become DAG nodes (project-wide semantic graph)
/// - Code edits become DAG events (HashDAG-style ordering)
/// - Streaming updates (Hyperfiddle-style propagation)
pub const EditorDagIntegration = struct {
    allocator: std.mem.Allocator,
    dag: DagCore,
    tree_sitter: TreeSitter,
    
    // Bounded: Max 1,000 AST nodes per file
    pub const MAX_AST_NODES_PER_FILE: u32 = 1_000;
    
    // Bounded: Max 100 code edits per second
    pub const MAX_EDITS_PER_SECOND: u32 = 100;
    
    /// Initialize editor-DAG integration.
    pub fn init(allocator: std.mem.Allocator) !EditorDagIntegration {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);
        
        const dag = try DagCore.init(allocator);
        errdefer dag.deinit();
        
        const tree_sitter = TreeSitter.init(allocator);
        errdefer tree_sitter.deinit();
        
        return EditorDagIntegration{
            .allocator = allocator,
            .dag = dag,
            .tree_sitter = tree_sitter,
        };
    }
    
    /// Deinitialize editor-DAG integration.
    pub fn deinit(self: *EditorDagIntegration) void {
        self.dag.deinit();
        self.tree_sitter.deinit();
    }
    
    /// Parse source code and map AST nodes to DAG nodes.
    /// Returns array of DAG node IDs for all AST nodes.
    pub fn parseAndMapToDag(
        self: *EditorDagIntegration,
        source: []const u8,
        file_path: []const u8,
    ) ![]const u32 {
        // Assert: Source and file_path must be non-empty
        std.debug.assert(source.len > 0);
        std.debug.assert(file_path.len > 0);
        
        // Parse source code into AST
        const tree = try self.tree_sitter.parseZig(source);
        
        // Map AST nodes to DAG nodes
        var node_ids = std.ArrayList(u32).init(self.allocator);
        errdefer node_ids.deinit();
        
        try self.mapAstNodeToDag(&tree.root, file_path, &node_ids);
        
        // Assert: Node count must be within bounds
        std.debug.assert(node_ids.items.len <= MAX_AST_NODES_PER_FILE);
        
        return try node_ids.toOwnedSlice();
    }
    
    /// Recursively map AST node to DAG node.
    fn mapAstNodeToDag(
        self: *EditorDagIntegration,
        ast_node: *const TreeSitter.Node,
        file_path: []const u8,
        node_ids: *std.ArrayList(u32),
    ) !void {
        // Assert: Node IDs list must be within bounds
        std.debug.assert(node_ids.items.len < MAX_AST_NODES_PER_FILE);
        
        // Create node data (AST node type + file path + position)
        var node_data = std.ArrayList(u8).init(self.allocator);
        defer node_data.deinit();
        
        const writer = node_data.writer();
        try writer.print("{s}:{s}:{d}:{d}", .{
            file_path,
            ast_node.type,
            ast_node.start_byte,
            ast_node.end_byte,
        });
        
        // Create DAG node (AST node type)
        const dag_node_id = try self.dag.addNode(
            .ast_node,
            try node_data.toOwnedSlice(),
            .{
                .is_readonly = false,
                .readonly_start = ast_node.start_byte,
                .readonly_end = ast_node.end_byte,
                .metadata = try std.fmt.allocPrint(self.allocator, "file:{s},type:{s}", .{ file_path, ast_node.type }),
                .metadata_len = 0, // Will be set after allocation
            },
        );
        
        // Metadata length is set during allocation in addNode
        
        try node_ids.append(dag_node_id);
        
        // Recursively map children
        for (ast_node.children) |child| {
            try self.mapAstNodeToDag(&child, file_path, node_ids);
        }
        
        // Create edges (parent-child relationships)
        if (node_ids.items.len > 1) {
            const parent_id = node_ids.items[node_ids.items.len - 2];
            const child_id = node_ids.items[node_ids.items.len - 1];
            try self.dag.addEdge(parent_id, child_id, .dependency);
        }
    }
    
    /// Map code edit to DAG event (HashDAG-style).
    /// Returns event ID for the edit.
    pub fn mapEditToEvent(
        self: *EditorDagIntegration,
        node_id: u32,
        edit_type: EditType,
        old_text: []const u8,
        new_text: []const u8,
        parent_events: []const u64,
    ) !u64 {
        // Assert: Node ID must be valid
        std.debug.assert(self.dag.getNode(node_id) != null);
        
        // Assert: Edit rate must be within bounds
        // TODO: Implement rate limiting
        
        // Create event data (edit type + old text + new text)
        var event_data = std.ArrayList(u8).init(self.allocator);
        defer event_data.deinit();
        
        const writer = event_data.writer();
        try writer.print("{s}:", .{@tagName(edit_type)});
        try writer.print("old:{d}:", .{old_text.len});
        try writer.print("new:{d}:", .{new_text.len});
        try writer.writeAll(old_text);
        try writer.writeAll(new_text);
        
        // Map edit type to event type
        const event_type: DagCore.EventType = switch (edit_type) {
            .insert => .code_edit,
            .delete => .code_edit,
            .replace => .code_edit,
            .refactor => .ai_completion,
        };
        
        // Add event to DAG (HashDAG-style with parent references)
        const event_id = try self.dag.addEvent(
            event_type,
            node_id,
            try event_data.toOwnedSlice(),
            parent_events,
        );
        
        // Assert: Event was added
        std.debug.assert(event_id > 0);
        
        return event_id;
    }
    
    /// Type of code edit.
    pub const EditType = enum {
        insert, // Insert text
        delete, // Delete text
        replace, // Replace text
        refactor, // Refactor (AI-assisted)
    };
    
    /// Process pending events (streaming updates, Hyperfiddle-style).
    pub fn processEvents(self: *EditorDagIntegration) !void {
        // Process events in DAG (TigerBeetle-style state machine)
        try self.dag.processEvents();
        
        // Assert: Events were processed
        std.debug.assert(self.dag.pending_events_len == 0);
    }
    
    /// Get project-wide semantic graph (Matklad vision).
    /// Returns count of AST nodes in the DAG (across all files).
    pub fn getSemanticGraphNodeCount(self: *const EditorDagIntegration) u32 {
        // Count AST nodes in the DAG
        const nodes = self.dag.nodes[0..self.dag.nodes_len];
        var count: u32 = 0;
        
        for (nodes) |node| {
            if (node.node_type == .ast_node) {
                count += 1;
            }
        }
        
        return count;
    }
    
    /// Find DAG node by file path and byte position (for navigation, hover).
    pub fn findNodeAtPosition(
        self: *const EditorDagIntegration,
        file_path: []const u8,
        byte_pos: u32,
    ) ?u32 {
        // Assert: File path must be non-empty
        std.debug.assert(file_path.len > 0);
        
        // Search DAG nodes for matching file and position
        const nodes = self.dag.nodes[0..self.dag.nodes_len];
        
        for (nodes, 0..) |node, i| {
            if (node.node_type == .ast_node) {
                // Check if node matches file and position
                // TODO: Parse node data to extract file path and position
                // For now, return first matching node (placeholder)
                if (std.mem.indexOf(u8, node.data, file_path) != null) {
                    if (byte_pos >= node.attributes.readonly_start and
                        byte_pos <= node.attributes.readonly_end)
                    {
                        return @as(u32, @intCast(i));
                    }
                }
            }
        }
        
        return null;
    }
    
    /// Get dependency count for a node (for project-wide semantic understanding).
    pub fn getDependencyCount(self: *const EditorDagIntegration, node_id: u32) u32 {
        // Assert: Node ID must be valid
        std.debug.assert(self.dag.getNode(node_id) != null);
        
        // Get node and return parent count (dependencies)
        const node = self.dag.getNode(node_id);
        if (node) |n| {
            return n.parent_count;
        }
        
        return 0;
    }
};

test "editor dag integration initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = try EditorDagIntegration.init(arena.allocator());
    defer integration.deinit();
    
    // Assert: Integration initialized
    try std.testing.expect(integration.dag.nodes_len == 0);
    try std.testing.expect(integration.dag.edges_len == 0);
}

test "editor dag parse and map" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = try EditorDagIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const source = "pub fn main() void { }";
    const file_path = "test.zig";
    
    const node_ids = try integration.parseAndMapToDag(source, file_path);
    defer arena.allocator.free(node_ids);
    
    // Assert: Nodes were created
    try std.testing.expect(node_ids.len > 0);
    try std.testing.expect(integration.dag.nodes_len > 0);
}

test "editor dag map edit to event" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var integration = try EditorDagIntegration.init(arena.allocator());
    defer integration.deinit();
    
    const source = "pub fn main() void { }";
    const file_path = "test.zig";
    
    const node_ids = try integration.parseAndMapToDag(source, file_path);
    defer arena.allocator.free(node_ids);
    
    // Map edit to event
    const event_id = try integration.mapEditToEvent(
        node_ids[0],
        .insert,
        "",
        "test",
        &.{},
    );
    
    // Assert: Event was created
    try std.testing.expect(event_id > 0);
    try std.testing.expect(integration.dag.pending_events_len == 1);
}

