const std = @import("std");
const BrowserDagIntegration = @import("dream_browser_dag_integration.zig").BrowserDagIntegration;

/// Dream Browser Parser: HTML/CSS parser for Zig-native browser.
/// ~<~ Glow Airbend: explicit parsing, bounded tree depth.
/// ~~~~ Glow Waterbend: parsing flows deterministically through DAG.
///
/// This implements a subset of HTML5 and CSS3:
/// - HTML parser (subset: div, span, p, a, img, etc.)
/// - CSS parser (subset: color, background, font-size, etc.)
/// - DOM tree construction (bounded depth, explicit nodes)
/// - Style computation (cascade, specificity)
pub const DreamBrowserParser = struct {
    allocator: std.mem.Allocator,
    
    // Bounded: Max 100 tree depth
    pub const MAX_TREE_DEPTH: u32 = 100;
    
    // Bounded: Max 10,000 DOM nodes per page
    pub const MAX_DOM_NODES: u32 = 10_000;
    
    // Bounded: Max 1,000 CSS rules per stylesheet
    pub const MAX_CSS_RULES: u32 = 1_000;
    
    /// HTML element node (DOM node).
    pub const HtmlNode = struct {
        tag_name: []const u8, // "div", "span", "p", etc.
        attributes: []const Attribute,
        children: []const HtmlNode,
        text_content: []const u8, // Text content (for text nodes)
        parent: ?*HtmlNode = null,
        depth: u32 = 0, // Tree depth (for bounds checking)
    };
    
    /// HTML attribute.
    pub const Attribute = struct {
        name: []const u8,
        value: []const u8,
    };
    
    /// CSS rule (selector + declarations).
    pub const CssRule = struct {
        selector: []const u8, // "div", ".class", "#id", etc.
        declarations: []const Declaration,
    };
    
    /// CSS declaration (property + value).
    pub const Declaration = struct {
        property: []const u8, // "color", "background", "font-size", etc.
        value: []const u8, // "red", "#ff0000", "16px", etc.
    };
    
    /// Initialize parser.
    pub fn init(allocator: std.mem.Allocator) DreamBrowserParser {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);
        
        return DreamBrowserParser{
            .allocator = allocator,
        };
    }
    
    /// Deinitialize parser.
    pub fn deinit(self: *DreamBrowserParser) void {
        // No dynamic allocation to clean up
        _ = self;
    }
    
    /// Parse HTML string into DOM tree.
    pub fn parseHtml(
        self: *DreamBrowserParser,
        html: []const u8,
    ) !HtmlNode {
        // Assert: HTML must be non-empty
        std.debug.assert(html.len > 0);
        
        // Simple HTML parser (subset of HTML5)
        // For now, parse basic structure: <tag>content</tag>
        // TODO: Implement full HTML5 parser
        
        // Find first tag
        const tag_start = std.mem.indexOf(u8, html, "<") orelse return error.InvalidHtml;
        const tag_end = std.mem.indexOf(u8, html[tag_start..], ">") orelse return error.InvalidHtml;
        
        const tag_str = html[tag_start + 1..tag_start + tag_end];
        
        // Parse tag name and attributes
        const space_idx = std.mem.indexOfScalar(u8, tag_str, ' ') orelse tag_str.len;
        const tag_name = tag_str[0..space_idx];
        
        // Parse attributes (simple: name="value")
        // Pre-allocate capacity (optimization: reduce reallocations)
        var attributes = std.ArrayList(Attribute){ .items = &.{}, .capacity = 0 };
        defer attributes.deinit(self.allocator);
        try attributes.ensureTotalCapacity(self.allocator, 10); // Pre-allocate for common case
        
        var attr_start = space_idx;
        while (attr_start < tag_str.len) {
            // Skip whitespace
            while (attr_start < tag_str.len and tag_str[attr_start] == ' ') {
                attr_start += 1;
            }
            if (attr_start >= tag_str.len) break;
            
            // Find attribute name
            const attr_name_start = attr_start;
            const attr_name_end = std.mem.indexOfScalar(u8, tag_str[attr_name_start..], '=') orelse break;
            const attr_name = tag_str[attr_name_start..attr_name_start + attr_name_end];
            
            // Find attribute value
            const attr_value_start = attr_name_start + attr_name_end + 2; // Skip '='
            const attr_value_end = std.mem.indexOfScalar(u8, tag_str[attr_value_start..], '"') orelse break;
            const attr_value = tag_str[attr_value_start..attr_value_start + attr_value_end];
            
            try attributes.append(Attribute{
                .name = try self.allocator.dupe(u8, attr_name),
                .value = try self.allocator.dupe(u8, attr_value),
            });
            
            attr_start = attr_value_start + attr_value_end + 1;
        }
        
        // Find closing tag
        const closing_tag = try std.fmt.allocPrint(self.allocator, "</{s}>", .{tag_name});
        defer self.allocator.free(closing_tag);
        
        const content_start = tag_start + tag_end + 1;
        const content_end = std.mem.indexOf(u8, html[content_start..], closing_tag) orelse html.len;
        const content = html[content_start..content_start + content_end];
        
        // Create HTML node
        const node = HtmlNode{
            .tag_name = try self.allocator.dupe(u8, tag_name),
            .attributes = try attributes.toOwnedSlice(),
            .children = &.{}, // TODO: Parse children recursively
            .text_content = try self.allocator.dupe(u8, content),
            .parent = null,
            .depth = 0,
        };
        
        // Assert: Tree depth must be within bounds
        std.debug.assert(node.depth < MAX_TREE_DEPTH);
        
        return node;
    }
    
    /// Parse CSS string into rules.
    pub fn parseCss(
        self: *DreamBrowserParser,
        css: []const u8,
    ) ![]const CssRule {
        // Assert: CSS must be non-empty
        std.debug.assert(css.len > 0);
        
        // Simple CSS parser (subset of CSS3)
        // For now, parse basic structure: selector { property: value; }
        // TODO: Implement full CSS3 parser
        
        // Pre-allocate capacity (optimization: reduce reallocations)
        var rules = std.ArrayList(CssRule){ .items = &.{}, .capacity = 0 };
        defer rules.deinit(self.allocator);
        try rules.ensureTotalCapacity(self.allocator, @min(MAX_CSS_RULES, 50)); // Pre-allocate for common case
        
        // Find first rule
        var pos: usize = 0;
        while (pos < css.len) {
            // Skip whitespace
            while (pos < css.len and (css[pos] == ' ' or css[pos] == '\n' or css[pos] == '\t')) {
                pos += 1;
            }
            if (pos >= css.len) break;
            
            // Find selector
            const selector_start = pos;
            const selector_end = std.mem.indexOfScalar(u8, css[selector_start..], '{') orelse break;
            const selector = css[selector_start..selector_start + selector_end];
            
            // Find declarations
            const decl_start = selector_start + selector_end + 1;
            const decl_end = std.mem.indexOfScalar(u8, css[decl_start..], '}') orelse break;
            const decl_str = css[decl_start..decl_start + decl_end];
            
            // Parse declarations (simple: property: value;)
            // Pre-allocate capacity (optimization: reduce reallocations)
            var declarations = std.ArrayList(Declaration){ .items = &.{}, .capacity = 0 };
            defer declarations.deinit(self.allocator);
            try declarations.ensureTotalCapacity(self.allocator, 10); // Pre-allocate for common case
            
            var decl_pos: usize = 0;
            while (decl_pos < decl_str.len) {
                // Skip whitespace
                while (decl_pos < decl_str.len and (decl_str[decl_pos] == ' ' or decl_str[decl_pos] == '\n' or decl_str[decl_pos] == '\t')) {
                    decl_pos += 1;
                }
                if (decl_pos >= decl_str.len) break;
                
                // Find property
                const prop_start = decl_pos;
                const prop_end = std.mem.indexOfScalar(u8, decl_str[prop_start..], ':') orelse break;
                const property = decl_str[prop_start..prop_start + prop_end];
                
                // Find value
                const value_start = prop_start + prop_end + 1;
                const value_end = std.mem.indexOfScalar(u8, decl_str[value_start..], ';') orelse decl_str.len;
                const value = decl_str[value_start..value_start + value_end];
                
                try declarations.append(Declaration{
                    .property = try self.allocator.dupe(u8, property),
                    .value = try self.allocator.dupe(u8, value),
                });
                
                decl_pos = value_start + value_end + 1;
            }
            
            // Create CSS rule
            try rules.append(CssRule{
                .selector = try self.allocator.dupe(u8, selector),
                .declarations = try declarations.toOwnedSlice(),
            });
            
            // Assert: Rule count must be within bounds
            std.debug.assert(rules.items.len <= MAX_CSS_RULES);
            
            pos = decl_start + decl_end + 1;
        }
        
        return try rules.toOwnedSlice();
    }
    
    /// Compute styles for HTML node (cascade, specificity).
    pub fn computeStyles(
        self: *DreamBrowserParser,
        node: *const HtmlNode,
        css_rules: []const CssRule,
    ) ![]const Declaration {
        // Assert: Node and CSS rules must be valid
        std.debug.assert(node.tag_name.len > 0);
        
        // Simple style computation (cascade, specificity)
        // For now, match selectors to node tag name
        // TODO: Implement full CSS cascade and specificity
        
        var styles = std.ArrayList(Declaration).init(self.allocator);
        defer styles.deinit();
        
        // Match CSS rules to node
        for (css_rules) |rule| {
            // Simple selector matching (tag name only)
            if (std.mem.eql(u8, rule.selector, node.tag_name)) {
                // Add declarations to styles
                try styles.appendSlice(rule.declarations);
            }
        }
        
        return try styles.toOwnedSlice();
    }
    
    /// Convert HTML node to BrowserDagIntegration.DomNode (for DAG integration).
    pub fn toDomNode(
        self: *DreamBrowserParser,
        html_node: *const HtmlNode,
    ) !BrowserDagIntegration.DomNode {
        // Assert: HTML node must be valid
        std.debug.assert(html_node.tag_name.len > 0);
        
        // Convert attributes
        var attributes = std.ArrayList(BrowserDagIntegration.DomNode.Attribute).init(self.allocator);
        defer attributes.deinit();
        
        for (html_node.attributes) |attr| {
            try attributes.append(BrowserDagIntegration.DomNode.Attribute{
                .name = attr.name,
                .value = attr.value,
            });
        }
        
        // Convert children (recursive)
        var children = std.ArrayList(BrowserDagIntegration.DomNode).init(self.allocator);
        defer children.deinit();
        
        for (html_node.children) |child| {
            const child_dom = try self.toDomNode(&child);
            try children.append(child_dom);
        }
        
        return BrowserDagIntegration.DomNode{
            .tag_name = html_node.tag_name,
            .attributes = try attributes.toOwnedSlice(),
            .children = try children.toOwnedSlice(),
            .text_content = html_node.text_content,
            .parent_id = null, // Will be set by DAG integration
        };
    }
};

test "browser parser initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var parser = DreamBrowserParser.init(arena.allocator());
    defer parser.deinit();
    
    // Assert: Parser initialized
    try std.testing.expect(parser.allocator.ptr != null);
}

test "browser parser parse html" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var parser = DreamBrowserParser.init(arena.allocator());
    defer parser.deinit();
    
    const html = "<div>Hello, World!</div>";
    const node = try parser.parseHtml(html);
    defer {
        parser.allocator.free(node.tag_name);
        parser.allocator.free(node.text_content);
        for (node.attributes) |attr| {
            parser.allocator.free(attr.name);
            parser.allocator.free(attr.value);
        }
        parser.allocator.free(node.attributes);
    }
    
    // Assert: Node parsed correctly
    try std.testing.expect(std.mem.eql(u8, node.tag_name, "div"));
    try std.testing.expect(std.mem.eql(u8, node.text_content, "Hello, World!"));
}

test "browser parser parse css" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var parser = DreamBrowserParser.init(arena.allocator());
    defer parser.deinit();
    
    const css = "div { color: red; background: blue; }";
    const rules = try parser.parseCss(css);
    defer {
        for (rules) |rule| {
            parser.allocator.free(rule.selector);
            for (rule.declarations) |decl| {
                parser.allocator.free(decl.property);
                parser.allocator.free(decl.value);
            }
            parser.allocator.free(rule.declarations);
        }
        parser.allocator.free(rules);
    }
    
    // Assert: Rules parsed correctly
    try std.testing.expect(rules.len == 1);
    try std.testing.expect(std.mem.eql(u8, rules[0].selector, "div"));
    try std.testing.expect(rules[0].declarations.len == 2);
}

