const std = @import("std");
const DreamBrowserParser = @import("dream_browser_parser.zig").DreamBrowserParser;
const GrainAurora = @import("grain_aurora.zig").GrainAurora;
const GrainBuffer = @import("grain_buffer.zig").GrainBuffer;

/// Dream Browser Renderer: Layout engine and Grain Aurora rendering.
/// ~<~ Glow Airbend: explicit layout, bounded rendering, iterative algorithms.
/// ~~~~ Glow Waterbend: rendering flows deterministically through DAG.
///
/// This implements:
/// - Layout engine (block/inline flow, iterative stack-based)
/// - Render to Grain Aurora components (iterative stack-based)
/// - Readonly spans for metadata (event ID, timestamp)
/// - Editable spans for content
pub const DreamBrowserRenderer = struct {
    allocator: std.mem.Allocator,
    
    // Bounded: Max 1,000 layout boxes per page
    pub const MAX_LAYOUT_BOXES: u32 = 1_000;
    
    // Bounded: Max 10,000 pixels width/height
    pub const MAX_DIMENSION: u32 = 10_000;
    
    // Bounded: Max 100 stack depth for iterative algorithms
    pub const MAX_STACK_DEPTH: u32 = 100;
    
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
        inline_element, // Inline element (span, a, etc.)
    };
    
    /// Stack frame for iterative layout (replaces recursion).
    const LayoutStackFrame = struct {
        node: *const DreamBrowserParser.HtmlNode,
        x: u32,
        y: u32,
        available_width: u32,
        available_height: u32,
        child_index: u32, // Current child being processed
    };
    
    /// Stack frame for iterative rendering (replaces recursion).
    const RenderStackFrame = struct {
        node: *const DreamBrowserParser.HtmlNode,
        child_index: u32, // Current child being processed
        children_list: *std.ArrayList(GrainAurora.Node), // Accumulated children
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
        return .inline_element;
    }
    
    /// Layout HTML tree (block/inline flow, iterative stack-based).
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
        
        var boxes = std.ArrayList(LayoutBox){ .items = &.{}, .capacity = 0 };
        errdefer boxes.deinit(self.allocator);
        
        // Iterative stack-based layout (replaces recursion)
        var stack = std.ArrayList(LayoutStackFrame){ .items = &.{}, .capacity = 0 };
        errdefer stack.deinit(self.allocator);
        
        // Push root node onto stack
        try stack.append(self.allocator, LayoutStackFrame{
            .node = root,
            .x = 0,
            .y = 0,
            .available_width = viewport_width,
            .available_height = viewport_height,
            .child_index = 0,
        });
        
        // Process stack iteratively
        while (stack.items.len > 0) {
            // Assert: Stack depth must be within bounds
            std.debug.assert(stack.items.len <= MAX_STACK_DEPTH);
            
            const frame = &stack.items[stack.items.len - 1];
            const node = frame.node;
            
            // Determine display type
            const display = self.getDisplayType(node);
            
            // Calculate box dimensions (simple: full width for block, content width for inline)
            var box_width: u32 = frame.available_width;
            var box_height: u32 = 0;
            
            if (display == .block) {
                // Block-level: full width, height based on content
                box_width = frame.available_width;
                box_height = if (node.text_content.len > 0) 20 else 0; // Simple height calculation
            } else {
                // Inline_element: width based on content, height based on line height
                box_width = @as(u32, @intCast(node.text_content.len * 8)); // Simple: 8px per char
                box_height = 20; // Simple: 20px line height
            }
            
            // Create layout box
            const box = LayoutBox{
                .x = frame.x,
                .y = frame.y,
                .width = box_width,
                .height = box_height,
                .display = display,
                .node = node,
            };
            
            try boxes.append(self.allocator, box);
            
            // Assert: Box count must be within bounds
            std.debug.assert(boxes.items.len <= MAX_LAYOUT_BOXES);
            
            // Process children iteratively
            if (frame.child_index < node.children.len) {
                const child = &node.children[frame.child_index];
                const child_display = self.getDisplayType(child);
                const child_x = if (child_display == .block) frame.x else frame.x + box_width;
                const child_y = if (frame.child_index == 0) frame.y + box_height else frame.y;
                
                // Push child onto stack
                try stack.append(self.allocator, LayoutStackFrame{
                    .node = child,
                    .x = child_x,
                    .y = child_y,
                    .available_width = frame.available_width,
                    .available_height = frame.available_height,
                    .child_index = 0,
                });
                
                // Increment child index for current frame
                frame.child_index += 1;
            } else {
                // All children processed, pop frame
                _ = stack.pop();
            }
        }
        
        // Assert: Stack must be empty after processing
        std.debug.assert(stack.items.len == 0);
        
        return try boxes.toOwnedSlice(self.allocator);
    }
    
    /// Render HTML node to Grain Aurora component (iterative stack-based).
    pub fn renderToAurora(
        self: *DreamBrowserRenderer,
        node: *const DreamBrowserParser.HtmlNode,
        css_rules: []const DreamBrowserParser.CssRule,
    ) !GrainAurora.Node {
        // Assert: Node must be valid
        std.debug.assert(node.tag_name.len > 0);
        
        // Compute styles for node (for future use in rendering)
        const parser = DreamBrowserParser.init(self.allocator);
        defer parser.deinit();
        _ = try parser.computeStyles(node, css_rules); // Styles computed but not used in simplified rendering
        
        // Iterative stack-based rendering (replaces recursion)
        var stack = std.ArrayList(RenderStackFrame){ .items = &.{}, .capacity = 0 };
        errdefer stack.deinit(self.allocator);
        
        // Root children list
        var root_children = std.ArrayList(GrainAurora.Node){ .items = &.{}, .capacity = 0 };
        errdefer root_children.deinit(self.allocator);
        
        // Push root node onto stack
        try stack.append(self.allocator, RenderStackFrame{
            .node = node,
            .child_index = 0,
            .children_list = &root_children,
        });
        
        // Process stack iteratively
        while (stack.items.len > 0) {
            // Assert: Stack depth must be within bounds
            std.debug.assert(stack.items.len <= MAX_STACK_DEPTH);
            
            const frame = &stack.items[stack.items.len - 1];
            const current_node = frame.node;
            
            // Process current node's children
            if (frame.child_index < current_node.children.len) {
                const child = &current_node.children[frame.child_index];
                
                // Create child children list
                var child_children = std.ArrayList(GrainAurora.Node){ .items = &.{}, .capacity = 0 };
                errdefer child_children.deinit(self.allocator);
                
                // Push child onto stack
                try stack.append(self.allocator, RenderStackFrame{
                    .node = child,
                    .child_index = 0,
                    .children_list = &child_children,
                });
                
                // Increment child index for current frame
                frame.child_index += 1;
            } else {
                // All children processed, create node and add to parent
                const current_display_type = self.getDisplayType(current_node);
                var child_node: GrainAurora.Node = undefined;
                
                if (current_display_type == .block) {
                    // Block-level: render as column (vertical stack)
                    // Add text content if present
                    if (current_node.text_content.len > 0) {
                        try frame.children_list.append(self.allocator, GrainAurora.Node{ .text = current_node.text_content });
                    }
                    
                    // Add processed children
                    const children_slice = try frame.children_list.toOwnedSlice(self.allocator);
                    child_node = GrainAurora.Node{
                        .column = GrainAurora.Column{
                            .children = children_slice,
                        },
                    };
                } else {
                    // Inline_element: render as row (horizontal stack) or text
                    if (current_node.children.len == 0) {
                        // Leaf node: render as text
                        child_node = GrainAurora.Node{ .text = current_node.text_content };
                    } else {
                        // Has children: render as row
                        // Add text content if present
                        if (current_node.text_content.len > 0) {
                            try frame.children_list.append(self.allocator, GrainAurora.Node{ .text = current_node.text_content });
                        }
                        
                        // Add processed children
                        const children_slice = try frame.children_list.toOwnedSlice(self.allocator);
                        child_node = GrainAurora.Node{
                            .row = GrainAurora.Row{
                                .children = children_slice,
                            },
                        };
                    }
                }
                
                // Pop current frame
                _ = stack.pop();
                
                // Add child node to parent (if not root)
                if (stack.items.len > 0) {
                    const parent_frame = &stack.items[stack.items.len - 1];
                    try parent_frame.children_list.append(self.allocator, child_node);
                } else {
                    // Root node: return result
                    return child_node;
                }
            }
        }
        
        // Assert: Should not reach here (root node should be returned above)
        std.debug.assert(false);
        unreachable;
    }
    
    /// Create readonly spans for metadata (event ID, timestamp, iterative).
    pub fn createReadonlySpans(
        self: *DreamBrowserRenderer,
        node: *const DreamBrowserParser.HtmlNode,
        buffer: *GrainBuffer,
    ) ![]const GrainBuffer.Segment {
        // Assert: Node and buffer must be valid
        std.debug.assert(node.tag_name.len > 0);
        
        var readonly_spans = std.ArrayList(GrainBuffer.Segment){ .items = &.{}, .capacity = 0 };
        errdefer readonly_spans.deinit(self.allocator);
        
        // Iterative stack-based processing (replaces recursion)
        var stack = std.ArrayList(*const DreamBrowserParser.HtmlNode){ .items = &.{}, .capacity = 0 };
        errdefer stack.deinit(self.allocator);
        
        // Push root node onto stack
        try stack.append(self.allocator, node);
        
        // Process stack iteratively
        while (stack.items.len > 0) {
            // Assert: Stack depth must be within bounds
            std.debug.assert(stack.items.len <= MAX_STACK_DEPTH);
            
            const current_node = stack.pop();
            
            // Check for metadata attributes (Nostr event ID, timestamp, author)
            for (current_node.attributes) |attr| {
                if (std.mem.eql(u8, attr.name, "data-event-id") or
                    std.mem.eql(u8, attr.name, "data-timestamp") or
                    std.mem.eql(u8, attr.name, "data-author"))
                {
                    // Find attribute value in buffer text
                    const buffer_text = buffer.textSlice();
                    if (std.mem.indexOf(u8, buffer_text, attr.value)) |start| {
                        const end_pos = start + @as(u32, @intCast(attr.value.len));
                        
                        // Mark as readonly span
                        try buffer.markReadOnly(start, end_pos);
                        
                        // Add to readonly spans list
                        const readonly_segments = buffer.getReadonlySpans();
                        for (readonly_segments) |segment| {
                            if (segment.start == start and segment.end == end_pos) {
                                try readonly_spans.append(self.allocator, segment);
                                break;
                            }
                        }
                    }
                }
            }
            
            // Push children onto stack (in reverse order for correct processing)
            var i: u32 = current_node.children.len;
            while (i > 0) {
                i -= 1;
                try stack.append(self.allocator, &current_node.children[i]);
            }
        }
        
        // Assert: Stack must be empty after processing
        std.debug.assert(stack.items.len == 0);
        
        return try readonly_spans.toOwnedSlice(self.allocator);
    }
    
    /// Create editable spans for content (non-metadata text, iterative).
    pub fn createEditableSpans(
        self: *DreamBrowserRenderer,
        node: *const DreamBrowserParser.HtmlNode,
        buffer: *GrainBuffer,
    ) !void {
        // Assert: Node and buffer must be valid
        std.debug.assert(node.tag_name.len > 0);
        
        // Iterative stack-based processing (replaces recursion)
        var stack = std.ArrayList(*const DreamBrowserParser.HtmlNode){ .items = &.{}, .capacity = 0 };
        errdefer stack.deinit(self.allocator);
        
        // Push root node onto stack
        try stack.append(self.allocator, node);
        
        // Process stack iteratively
        while (stack.items.len > 0) {
            // Assert: Stack depth must be within bounds
            std.debug.assert(stack.items.len <= MAX_STACK_DEPTH);
            
            const current_node = stack.pop();
            
            // Text content is editable by default (unless marked readonly)
            // No action needed - content is editable by default in GrainBuffer
            _ = current_node;
            _ = buffer;
            
            // Push children onto stack (in reverse order for correct processing)
            var i: u32 = current_node.children.len;
            while (i > 0) {
                i -= 1;
                try stack.append(self.allocator, &current_node.children[i]);
            }
        }
        
        // Assert: Stack must be empty after processing
        std.debug.assert(stack.items.len == 0);
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
