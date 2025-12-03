const std = @import("std");
const GrainBuffer = @import("grain_buffer.zig").GrainBuffer;
const AuroraFilter = @import("aurora_filter.zig");
const MacWindow = @import("platform/macos_tahoe/window.zig");

/// GrainAurora — component-first GrainStyle UI stitching engine.
// ~<~ Glow Airbend: keep renders light.
// ~~~~ Glow Waterbend: streams of components stay deterministic.
pub const GrainAurora = struct {
    pub const Node = union(enum) {
        text: []const u8,
        column: Column,
        row: Row,
        button: Button,
    };

    pub const Column = struct {
        children: []const Node,
    };

    pub const Row = struct {
        children: []const Node,
    };

    pub const Button = struct {
        id: []const u8,
        label: []const u8,
    };

    pub const Component = fn (context: *RenderContext) RenderResult;

    pub const RenderContext = struct {
        allocator: std.mem.Allocator,
        buffer: *GrainBuffer,
        route: []const u8,
    };

    // Bounded: Maximum spans per type (Grain/Tiger style: explicit limits)
    pub const MAX_DIAGNOSTIC_SPANS: u32 = 1000;
    pub const MAX_INLAY_HINT_SPANS: u32 = 500;
    pub const MAX_CODE_LENS_SPANS: u32 = 100;
    pub const MAX_DOCUMENT_HIGHLIGHT_SPANS: u32 = 100;
    pub const MAX_SEMANTIC_TOKEN_SPANS: u32 = 10000;
    pub const MAX_FOLDING_RANGE_SPANS: u32 = 1000;
    pub const MAX_SELECTION_RANGE_SPANS: u32 = 100;
    pub const MAX_DOCUMENT_LINK_SPANS: u32 = 1000;
    
    // Bounded: Maximum string lengths (Grain/Tiger style: explicit limits)
    pub const MAX_DIAGNOSTIC_MESSAGE_LEN: u32 = 1024;
    pub const MAX_INLAY_HINT_LABEL_LEN: u32 = 256;
    pub const MAX_INLAY_HINT_TOOLTIP_LEN: u32 = 512;
    pub const MAX_CODE_LENS_TITLE_LEN: u32 = 256;
    pub const MAX_CODE_LENS_COMMAND_LEN: u32 = 256;
    pub const MAX_DOCUMENT_LINK_TARGET_LEN: u32 = 4096;
    pub const MAX_DOCUMENT_LINK_TOOLTIP_LEN: u32 = 512;

    pub const RenderResult = struct {
        root: Node,
        readonly_spans: []const Span, // Owned by caller (from GrainBuffer)
        
        // Bounded arrays with explicit counts (Grain/Tiger style: fixed-size storage)
        diagnostic_spans: [MAX_DIAGNOSTIC_SPANS]DiagnosticSpan = undefined,
        diagnostic_spans_len: u32 = 0,
        
        inlay_hint_spans: [MAX_INLAY_HINT_SPANS]InlayHintSpan = undefined,
        inlay_hint_spans_len: u32 = 0,
        
        code_lens_spans: [MAX_CODE_LENS_SPANS]CodeLensSpan = undefined,
        code_lens_spans_len: u32 = 0,
        
        document_highlight_spans: [MAX_DOCUMENT_HIGHLIGHT_SPANS]DocumentHighlightSpan = undefined,
        document_highlight_spans_len: u32 = 0,
        
        semantic_token_spans: [MAX_SEMANTIC_TOKEN_SPANS]SemanticTokenSpan = undefined,
        semantic_token_spans_len: u32 = 0,
        
        folding_range_spans: [MAX_FOLDING_RANGE_SPANS]FoldingRangeSpan = undefined,
        folding_range_spans_len: u32 = 0,
        
        selection_range_spans: [MAX_SELECTION_RANGE_SPANS]SelectionRangeSpan = undefined,
        selection_range_spans_len: u32 = 0,
        
        document_link_spans: [MAX_DOCUMENT_LINK_SPANS]DocumentLinkSpan = undefined,
        document_link_spans_len: u32 = 0,
        
        ghost_spans: []const Span = &.{}, // Owned by caller (from Editor)
        
        // No deinit needed: all strings are in fixed-size buffers, no dynamic allocation
    };
    
    /// Diagnostic span (for LSP diagnostics rendering).
    /// Grain/Tiger style: fixed-size buffer, no dynamic allocation.
    pub const DiagnosticSpan = struct {
        start: u32, // Start byte position
        end: u32, // End byte position
        severity: u32, // Diagnostic severity (1=Error, 2=Warning, 3=Info, 4=Hint)
        message: [MAX_DIAGNOSTIC_MESSAGE_LEN]u8 = undefined, // Fixed-size message buffer
        message_len: u32 = 0, // Actual message length
    };
    
    /// Inlay hint span (for LSP inlay hints rendering).
    /// Grain/Tiger style: fixed-size buffers, no dynamic allocation.
    pub const InlayHintSpan = struct {
        position: u32, // Position where hint should be displayed (byte position)
        label: [MAX_INLAY_HINT_LABEL_LEN]u8 = undefined, // Fixed-size label buffer
        label_len: u32 = 0, // Actual label length
        kind: u32, // Hint kind (1=Type, 2=Parameter)
        tooltip: [MAX_INLAY_HINT_TOOLTIP_LEN]u8 = undefined, // Fixed-size tooltip buffer
        tooltip_len: u32 = 0, // Actual tooltip length (0 = no tooltip)
        padding_left: bool = false, // Padding before hint
        padding_right: bool = false, // Padding after hint
    };
    
    /// Code lens span (for LSP code lens rendering).
    /// Grain/Tiger style: fixed-size buffers, no dynamic allocation.
    pub const CodeLensSpan = struct {
        position: u32, // Position where code lens should be displayed (byte position, start of range)
        title: [MAX_CODE_LENS_TITLE_LEN]u8 = undefined, // Fixed-size title buffer
        title_len: u32 = 0, // Actual title length
        command: [MAX_CODE_LENS_COMMAND_LEN]u8 = undefined, // Fixed-size command buffer
        command_len: u32 = 0, // Actual command length (0 = no command)
        range_start: u32, // Start byte position of the range this lens applies to
        range_end: u32, // End byte position of the range this lens applies to
    };
    
    /// Document highlight span (for LSP document highlights rendering).
    pub const DocumentHighlightSpan = struct {
        start: u32, // Start byte position
        end: u32, // End byte position
        kind: u32, // Highlight kind (1=Text, 2=Read, 3=Write)
    };
    
    /// Semantic token span (for LSP semantic tokens rendering).
    pub const SemanticTokenSpan = struct {
        start: u32, // Start byte position
        end: u32, // End byte position
        token_type: u32, // Token type (SemanticTokenType)
        modifiers: u32, // Token modifiers (bit flags)
    };
    
    /// Folding range span (for LSP folding ranges rendering).
    pub const FoldingRangeSpan = struct {
        start: u32, // Start byte position
        end: u32, // End byte position
        kind: u32, // Folding range kind (1=Comment, 2=Imports, 3=Region)
    };
    
    /// Selection range span (for LSP selection ranges rendering).
    pub const SelectionRangeSpan = struct {
        start: u32, // Start byte position
        end: u32, // End byte position
        level: u32, // Selection level (0=innermost, higher=outer)
    };
    
    /// Document link span (for LSP document links rendering).
    /// Grain/Tiger style: fixed-size buffers, no dynamic allocation.
    pub const DocumentLinkSpan = struct {
        start: u32, // Start byte position
        end: u32, // End byte position
        target: [MAX_DOCUMENT_LINK_TARGET_LEN]u8 = undefined, // Fixed-size target buffer
        target_len: u32 = 0, // Actual target length (0 = no target)
        tooltip: [MAX_DOCUMENT_LINK_TOOLTIP_LEN]u8 = undefined, // Fixed-size tooltip buffer
        tooltip_len: u32 = 0, // Actual tooltip length (0 = no tooltip)
    };

    pub const Span = struct {
        start: u32, // Start byte position
        end: u32, // End byte position
    };

    allocator: std.mem.Allocator,
    buffer: GrainBuffer,

    pub fn init(allocator: std.mem.Allocator, seed: []const u8) !GrainAurora {
        const buffer = try GrainBuffer.fromSlice(allocator, seed);
        return GrainAurora{
            .allocator = allocator,
            .buffer = buffer,
        };
    }

    pub fn deinit(self: *GrainAurora) void {
        self.buffer.deinit();
        self.* = undefined;
    }

    pub fn render(
        self: *GrainAurora,
        component: Component,
        route: []const u8,
    ) !void {
        self.buffer.deinit();
        const fresh = try GrainBuffer.fromSlice(self.allocator, "");
        self.buffer = fresh;
        var ctx = RenderContext{
            .allocator = self.allocator,
            .buffer = &self.buffer,
            .route = route,
        };
        const result = component(&ctx);
        try writeNode(&self.buffer, result.root);
        for (result.readonly_spans) |span| {
            try self.buffer.markReadOnly(span.start, span.end);
        }
    }
};

fn writeNode(buffer: *GrainBuffer, node: GrainAurora.Node) !void {
    switch (node) {
        .text => |value| try buffer.append(value),
        .button => |btn| {
            try buffer.append("[");
            try buffer.append(btn.label);
            try buffer.append("]");
        },
        .row => |row| {
            try buffer.append("{ ");
            for (row.children, 0..) |child, index| {
                if (index > 0) try buffer.append(" | ");
                try writeNode(buffer, child);
            }
            try buffer.append(" }");
        },
        .column => |col| {
            for (col.children) |child| {
                try writeNode(buffer, child);
                try buffer.append("\n");
            }
        },
    }
}

test "grain aurora renders simple column" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var aurora = try GrainAurora.init(arena.allocator(), "");
    defer aurora.deinit();

    const component = struct {
        fn view(ctx: *GrainAurora.RenderContext) GrainAurora.RenderResult {
            _ = ctx;
            return GrainAurora.RenderResult{
                .root = .{ .column = .{
                    .children = &.{
                        .{ .text = "Hello" },
                        .{ .button = .{ .id = "submit", .label = "Submit" } },
                    },
                } },
                .readonly_spans = &.{
                    .{ .start = 0, .end = 5 },
                },
            };
        }
    }.view;

    try aurora.render(component, "/hello");
    const rendered = aurora.buffer.textSlice();
    try std.testing.expect(std.mem.startsWith(u8, rendered, "Hello\n[Submit]"));
}

pub fn demo() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var window = try MacWindow.Window.init(gpa.allocator(), "Aurora Sandbox");
    defer window.deinit();
    try window.show();

    var pixels = [_]u8{ 180, 160, 150, 255, 200, 120, 100, 255 };
    var state = AuroraFilter.FluxState{};
    state.toggle(.darkroom);
    AuroraFilter.apply(state, &pixels);
    std.debug.print("Applied darkroom filter to {d} pixels\n", .{pixels.len / 4});
}
