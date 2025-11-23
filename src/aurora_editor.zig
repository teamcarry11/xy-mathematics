const std = @import("std");
const GrainBuffer = @import("grain_buffer.zig").GrainBuffer;
const GrainAurora = @import("grain_aurora.zig").GrainAurora;
const LspClient = @import("aurora_lsp.zig").LspClient;
const Folding = @import("aurora_folding.zig").Folding;
const Glm46Client = @import("aurora_glm46.zig").Glm46Client;
const TreeSitter = @import("aurora_tree_sitter.zig").TreeSitter;

/// Aurora code editor: integrates GrainBuffer, GrainAurora, LSP, folding, and GLM-4.6.
/// ~<~ Glow Waterbend: editor state flows deterministically through LSP diagnostics.
pub const Editor = struct {
    allocator: std.mem.Allocator,
    buffer: GrainBuffer,
    aurora: GrainAurora,
    lsp: LspClient,
    folding: Folding,
    tree_sitter: TreeSitter,
    glm46: ?Glm46Client = null,
    file_uri: []const u8,
    cursor_line: u32 = 0,
    cursor_char: u32 = 0,

    pub fn init(
        allocator: std.mem.Allocator,
        file_uri: []const u8,
        initial_text: []const u8,
    ) !Editor {
        var buffer = try GrainBuffer.fromSlice(allocator, initial_text);
        errdefer buffer.deinit();
        var aurora = try GrainAurora.init(allocator, initial_text);
        errdefer aurora.deinit();
        const lsp = LspClient.init(allocator);
        var folding = Folding.init(allocator);
        errdefer folding.deinit();
        var tree_sitter = TreeSitter.init(allocator);
        errdefer tree_sitter.deinit();
        
        // Parse initial text for folds and syntax tree
        try folding.parse(initial_text);
        _ = try tree_sitter.parseZig(initial_text);

        return Editor{
            .allocator = allocator,
            .buffer = buffer,
            .aurora = aurora,
            .lsp = lsp,
            .folding = folding,
            .tree_sitter = tree_sitter,
            .file_uri = file_uri,
        };
    }

    pub fn deinit(self: *Editor) void {
        if (self.glm46) |*glm46| {
            glm46.deinit();
        }
        self.tree_sitter.deinit();
        self.folding.deinit();
        self.lsp.deinit();
        self.aurora.deinit();
        self.buffer.deinit();
        self.* = undefined;
    }

    /// Start LSP server and initialize for this editor session.
    pub fn startLsp(self: *Editor, zls_path: []const u8, root_uri: []const u8) !void {
        try self.lsp.startServer(zls_path);
        try self.lsp.initialize(root_uri);
    }

    /// Request completions at current cursor position.
    /// Uses GLM-4.6 if available, falls back to LSP.
    pub fn requestCompletions(self: *Editor) !void {
        // Try GLM-4.6 first (1,000 tps)
        if (self.glm46) |*glm46| {
            const text = self.buffer.textSlice();
            const messages = [_]Glm46Client.Message{
                .{ .role = "system", .content = "You are a Zig code completion assistant." },
                .{ .role = "user", .content = try std.fmt.allocPrint(
                    self.allocator,
                    "Complete this code at line {d}, char {d}:\n{s}",
                    .{ self.cursor_line, self.cursor_char, text },
                ) },
            };
            defer self.allocator.free(messages[1].content);
            
            // Request completion (streaming callback)
            try glm46.requestCompletion(&messages, struct {
                fn callback(chunk: []const u8) void {
                    // TODO: Display ghost text in editor
                    _ = chunk;
                }
            }.callback);
            return;
        }
        
        // Fall back to LSP
        _ = try self.lsp.requestCompletion(
            self.file_uri,
            self.cursor_line,
            self.cursor_char,
        );
    }
    
    /// Enable GLM-4.6 code completion (requires API key).
    pub fn enableGlm46(self: *Editor, api_key: []const u8) !void {
        // Assert: API key must be non-empty
        std.debug.assert(api_key.len > 0);
        
        self.glm46 = Glm46Client.init(self.allocator, api_key);
    }
    
    /// Toggle fold at current line.
    pub fn toggleFold(self: *Editor, line: u32) void {
        self.folding.toggleFold(line);
    }
    
    /// Check if a line is folded.
    pub fn isFolded(self: *const Editor, line: u32) bool {
        return self.folding.isFolded(line);
    }
    
    /// Get syntax tree for current buffer (for syntax highlighting, navigation).
    pub fn getSyntaxTree(self: *Editor) !TreeSitter.Tree {
        const text = self.buffer.textSlice();
        return try self.tree_sitter.parseZig(text);
    }
    
    /// Get node at current cursor position (for hover, go-to-definition).
    pub fn getNodeAtCursor(self: *Editor) !?TreeSitter.Node {
        const tree = try self.getSyntaxTree();
        const point = TreeSitter.Point{
            .row = self.cursor_line,
            .column = self.cursor_char,
        };
        return self.tree_sitter.getNodeAt(&tree, point);
    }

    /// Insert text at cursor; triggers LSP didChange notification.
    /// Prevents insertion into readonly spans.
    pub fn insert(self: *Editor, text: []const u8) !void {
        const pos = self.cursor_line * 80 + self.cursor_char;
        
        // Assert: Position must be within bounds
        std.debug.assert(pos <= self.buffer.textSlice().len);
        
        // Check if position is in readonly span
        if (self.buffer.isReadOnly(pos)) {
            return error.ReadOnlyViolation;
        }
        
        try self.buffer.insert(pos, text);
        self.cursor_char += @as(u32, @intCast(text.len));
        // TODO: send textDocument/didChange to LSP.
    }

    /// Move cursor; may trigger hover requests.
    pub fn moveCursor(self: *Editor, line: u32, char: u32) void {
        self.cursor_line = line;
        self.cursor_char = char;
        // TODO: request hover info if cursor hovers over symbol.
    }

    /// Render editor view: buffer content + LSP diagnostics overlay.
    /// Includes readonly spans for visual distinction.
    pub fn render(self: *Editor) !GrainAurora.RenderResult {
        const text = self.buffer.textSlice();
        const readonly_spans = self.buffer.getReadonlySpans();
        
        // Convert GrainBuffer segments to Aurora spans
        const AuroraSpan = @import("structs/aurora.zig").Span;
        var spans = try std.ArrayList(AuroraSpan).initCapacity(
            self.allocator,
            readonly_spans.len,
        );
        defer spans.deinit();
        
        for (readonly_spans) |segment| {
            try spans.append(AuroraSpan{
                .start = segment.start,
                .end = segment.end,
            });
        }
        
        return GrainAurora.RenderResult{
            .root = .{ .text = text },
            .readonly_spans = try spans.toOwnedSlice(),
        };
    }
};

test "editor lifecycle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var editor = try Editor.init(
        arena.allocator(),
        "file:///test.zig",
        "const std = @import(\"std\");\n",
    );
    defer editor.deinit();
    try editor.insert("pub fn main() void {}\n");
}

