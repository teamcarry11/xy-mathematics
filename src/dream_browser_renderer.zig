const std = @import("std");
const DreamBrowserParser = @import("dream_browser_parser.zig").DreamBrowserParser;
const GrainAurora = @import("grain_aurora.zig").GrainAurora;
const GrainBuffer = @import("grain_buffer.zig").GrainBuffer;

/// Dream Browser Renderer: Layout engine and Grain Aurora rendering.
/// ~<~ Glow Airbend: explicit layout, bounded rendering.
/// ~~~~ Glow Waterbend: rendering flows deterministically through DAG.
///
/// This implements:
/// - Layout engine (block/inline flow)
/// - Render to Grain Aurora components
/// - Readonly spans for metadata (event ID, timestamp)
/// - Editable spans for content
pub const DreamBrowserRenderer = struct {
    allocator: std.mem.Allocator,
    
    // Bounded: Max 1,000 layout boxes per page
    pub const MAX_LAYOUT_BOXES: u32 = 1_000;
    
    // Bounded: Max 10,000 pixels width/height
    pub const MAX_DIMENSION: u32 = 10_000;
    
    /// Layout box (for block/inline flow).
    pub const LayoutBox = struct {
        x: u32,
        y: u32,
        width: u32,
        height: u32,
        display: DisplayType,
        node: *const DreamBrowserParser.HtmlNode,
    };
    
    /// Display type (block or inline).
    pub const DisplayType = enum {
        block, // Block-level element (div, p, etc.)
        inline, // Inline element (span, a, etc.)
    };
    
    /// Initialize renderer.
    pub fn init(allocator: std.mem.Allocator) DreamBrowserRenderer {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);
        
        return DreamBrowserRenderer{
            .allocator = allocator,
        };
    }
    
    /// Deinitialize renderer.
    pub fn deinit(self: *DreamBrowserRenderer) void {
        // No dynamic allocation to clean up
        _ = self;
    }
    
    /// Determine display type for HTML node (block or inline).
    pub fn getDisplayType(node: *const DreamBrowserParser.HtmlNode) DisplayType {
        // Assert: Node must be valid
        std.debug.assert(node.tag_name.len > 0);
        
        // Block-level elements
        const block_tags = [_][]const u8{ "div", "p", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li", "section", "article", "header", "footer", "nav" };
        for (block_tags) |tag| {
            if (std.mem.eql(u8, node.tag_name, tag)) {
                return .block;
            }
        }
        
        // Inline elements (default)
        return .inline;
    }
    
    /// Layout HTML tree (block/inline flow).
    pub fn layout(
        self: *DreamBrowserRenderer,
        root: *const DreamBrowserParser.HtmlNode,
        viewport_width: u32,
        viewport_height: u32,
    ) ![]const LayoutBox {
        // Assert: Viewport dimensions must be within bounds
        std.debug.assert(viewport_width <= MAX_DIMENSION);
        std.debug.assert(viewport_height <= MAX_DIMENSION);
        
        // Assert: Viewport must be non-zero
        std.debug.assert(viewport_width > 0);
        std.debug.assert(viewport_height > 0);
        
        var boxes = std.ArrayList(LayoutBox).init(self.allocator);
        defer boxes.deinit();
        
        // Layout root node
        try self.layoutNode(root, 0, 0, viewport_width, viewport_height, &boxes);
        
        // Assert: Box count must be within bounds
        std.debug.assert(boxes.items.len <= MAX_LAYOUT_BOXES);
        
        return try boxes.toOwnedSlice();
    }
    
    /// Layout a single HTML node (recursive).
    fn layoutNode(
        self: *DreamBrowserRenderer,
        node: *const DreamBrowserParser.HtmlNode,
        x: u32,
        y: u32,
        available_width: u32,
        available_height: u32,
        boxes: *std.ArrayList(LayoutBox),
    ) !void {
        // Assert: Node must be valid
        std.debug.assert(node.tag_name.len > 0);
        
        // Determine display type
        const display = self.getDisplayType(node);
        
        // Calculate box dimensions (simple: full width for block, content width for inline)
        var box_width: u32 = available_width;
        var box_height: u32 = 0;
        
        if (display == .block) {
            // Block-level: full width, height based on content
            box_width = available_width;
            box_height = if (node.text_content.len > 0) 20 else 0; // Simple height calculation
        } else {
            // Inline: width based on content, height based on line height
            box_width = @as(u32, @intCast(node.text_content.len * 8)); // Simple: 8px per char
            box_height = 20; // Simple: 20px line height
        }
        
        // Create layout box
        const box = LayoutBox{
            .x = x,
            .y = y,
            .width = box_width,
            .height = box_height,
            .display = display,
            .node = node,
        };
        
        try boxes.append(box);
        
        // Layout children (recursive)
        var child_y = y + box_height;
        for (node.children) |child| {
            const child_display = self.getDisplayType(&child);
            const child_x = if (child_display == .block) x else x + box_width;
            
            try self.layoutNode(&child, child_x, child_y, available_width, available_height, boxes);
            
            if (child_display == .block) {
                child_y += box.height; // Stack block elements vertically
            }
        }
    }
    
    /// Render HTML node to Grain Aurora component.
    pub fn renderToAurora(
        self: *DreamBrowserRenderer,
        node: *const DreamBrowserParser.HtmlNode,
        css_rules: []const DreamBrowserParser.CssRule,
    ) !GrainAurora.Node {
        // Assert: Node must be valid
        std.debug.assert(node.tag_name.len > 0);
        
        // Compute styles for node
        const parser = DreamBrowserParser.init(self.allocator);
        defer parser.deinit();
        const styles = try parser.computeStyles(node, css_rules);
        defer self.allocator.free(styles);
        
        // Determine display type
        const display = self.getDisplayType(node);
        
        // Render based on display type
        if (display == .block) {
            // Block-level: render as column (vertical stack)
            var children = std.ArrayList(GrainAurora.Node).init(self.allocator);
            defer children.deinit();
            
            // Add text content if present
            if (node.text_content.len > 0) {
                const text_node = GrainAurora.Node{ .text = node.text_content };
                try children.append(text_node);
            }
            
            // Render children recursively
            for (node.children) |child| {
                const child_node = try self.renderToAurora(&child, css_rules);
                try children.append(child_node);
            }
            
            return GrainAurora.Node{
                .column = GrainAurora.Column{
                    .children = try children.toOwnedSlice(),
                },
            };
        } else {
            // Inline: render as row (horizontal stack) or text
            if (node.children.len == 0) {
                // Leaf node: render as text
                return GrainAurora.Node{ .text = node.text_content };
            } else {
                // Has children: render as row
                var children = std.ArrayList(GrainAurora.Node).init(self.allocator);
                defer children.deinit();
                
                // Add text content if present
                if (node.text_content.len > 0) {
                    const text_node = GrainAurora.Node{ .text = node.text_content };
                    try children.append(text_node);
                }
                
                // Render children recursively
                for (node.children) |child| {
                    const child_node = try self.renderToAurora(&child, css_rules);
                    try children.append(child_node);
                }
                
                return GrainAurora.Node{
                    .row = GrainAurora.Row{
                        .children = try children.toOwnedSlice(),
                    },
                };
            }
        }
    }
    
    /// Create readonly spans for metadata (event ID, timestamp).
    pub fn createReadonlySpans(
        self: *DreamBrowserRenderer,
        node: *const DreamBrowserParser.HtmlNode,
        buffer: *GrainBuffer,
    ) ![]const GrainBuffer.Segment {
        // Assert: Node and buffer must be valid
        std.debug.assert(node.tag_name.len > 0);
        
        var readonly_spans = std.ArrayList(GrainBuffer.Segment).init(self.allocator);
        defer readonly_spans.deinit();
        
        // Check for metadata attributes (Nostr event ID, timestamp, author)
        for (node.attributes) |attr| {
            if (std.mem.eql(u8, attr.name, "data-event-id") or
                std.mem.eql(u8, attr.name, "data-timestamp") or
                std.mem.eql(u8, attr.name, "data-author"))
            {
                // Find attribute value in buffer text
                const buffer_text = buffer.textSlice();
                if (std.mem.indexOf(u8, buffer_text, attr.value)) |start| {
                    const end = start + attr.value.len;
                    
                    // Mark as readonly span
                    try buffer.markReadOnly(start, end);
                    
                    // Add to readonly spans list
                    const readonly_segments = buffer.getReadonlySpans();
                    for (readonly_segments) |segment| {
                        if (segment.start == start and segment.end == end) {
                            try readonly_spans.append(segment);
                            break;
                        }
                    }
                }
            }
        }
        
        // Recursively process children
        for (node.children) |child| {
            const child_spans = try self.createReadonlySpans(&child, buffer);
            try readonly_spans.appendSlice(child_spans);
        }
        
        return try readonly_spans.toOwnedSlice();
    }
    
    /// Create editable spans for content (non-metadata text).
    pub fn createEditableSpans(
        self: *DreamBrowserRenderer,
        node: *const DreamBrowserParser.HtmlNode,
        buffer: *GrainBuffer,
    ) !void {
        // Assert: Node and buffer must be valid
        std.debug.assert(node.tag_name.len > 0);
        
        // Text content is editable by default (unless marked readonly)
        if (node.text_content.len > 0) {
            const buffer_text = buffer.textSlice();
            if (std.mem.indexOf(u8, buffer_text, node.text_content)) |start| {
                const end = start + node.text_content.len;
                
                // Check if this span is already readonly
                if (!buffer.isReadOnly(start)) {
                    // Content is editable (no action needed, editable by default)
                    // But we could mark it explicitly if needed
                }
            }
        }
        
        // Recursively process children
        for (node.children) |child| {
            try self.createEditableSpans(&child, buffer);
        }
    }
    
    /// Render complete page (HTML + CSS → Grain Aurora + readonly spans).
    pub fn renderPage(
        self: *DreamBrowserRenderer,
        root: *const DreamBrowserParser.HtmlNode,
        css_rules: []const DreamBrowserParser.CssRule,
        buffer: *GrainBuffer,
    ) !RenderResult {
        // Assert: Root node must be valid
        std.debug.assert(root.tag_name.len > 0);
        
        // Render to Grain Aurora component
        const aurora_node = try self.renderToAurora(root, css_rules);
        
        // Create readonly spans for metadata
        const readonly_spans = try self.createReadonlySpans(root, buffer);
        
        // Create editable spans for content
        try self.createEditableSpans(root, buffer);
        
        return RenderResult{
            .aurora_node = aurora_node,
            .readonly_spans = readonly_spans,
        };
    }
    
    /// Render result (Aurora node + readonly spans).
    pub const RenderResult = struct {
        aurora_node: GrainAurora.Node,
        readonly_spans: []const GrainBuffer.Segment,
    };
};

test "browser renderer initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var renderer = DreamBrowserRenderer.init(arena.allocator());
    defer renderer.deinit();
    
    // Assert: Renderer initialized
    try std.testing.expect(renderer.allocator.ptr != null);
}

test "browser renderer get display type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var renderer = DreamBrowserRenderer.init(arena.allocator());
    defer renderer.deinit();
    
    var parser = DreamBrowserParser.init(arena.allocator());
    defer parser.deinit();
    
    const html = "<div>Hello</div>";
    const node = try parser.parseHtml(html);
    defer {
        parser.allocator.free(node.tag_name);
        parser.allocator.free(node.text_content);
        parser.allocator.free(node.attributes);
    }
    
    const display = renderer.getDisplayType(&node);
    
    // Assert: Block element has block display type
    try std.testing.expect(display == .block);
}

test "browser renderer layout" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var renderer = DreamBrowserRenderer.init(arena.allocator());
    defer renderer.deinit();
    
    var parser = DreamBrowserParser.init(arena.allocator());
    defer parser.deinit();
    
    const html = "<div>Hello</div>";
    const node = try parser.parseHtml(html);
    defer {
        parser.allocator.free(node.tag_name);
        parser.allocator.free(node.text_content);
        parser.allocator.free(node.attributes);
    }
    
    const boxes = try renderer.layout(&node, 800, 600);
    defer arena.allocator.free(boxes);
    
    // Assert: Layout boxes created
    try std.testing.expect(boxes.len > 0);
    try std.testing.expect(boxes[0].width > 0);
}

test "browser renderer render to aurora" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var renderer = DreamBrowserRenderer.init(arena.allocator());
    defer renderer.deinit();
    
    var parser = DreamBrowserParser.init(arena.allocator());
    defer parser.deinit();
    
    const html = "<div>Hello</div>";
    const node = try parser.parseHtml(html);
    defer {
        parser.allocator.free(node.tag_name);
        parser.allocator.free(node.text_content);
        parser.allocator.free(node.attributes);
    }
    
    const css_rules = &.{};
    const aurora_node = try renderer.renderToAurora(&node, css_rules);
    
    // Assert: Aurora node created
    try std.testing.expect(aurora_node == .column);
}
